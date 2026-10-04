-- Members row first for call admission.
-- 20261004212249 made every wrapper take 77833003, 77833002 and (group) the
-- social_private.rooms row before calling the inner gateway, whose first statement
-- is social_private.require_member -> require_account: 'select ... from
-- social_private.members where token_hash=p_hash for no key update' plus an UPDATE
-- of that row. Every unwrapped action therefore holds the caller's members row and
-- only then waits for 77833003 (discovery request/leave/accept/decline/cancel/...)
-- or the rooms row (group poll/end/decline/signal/media), while a wrapped admission
-- by the same member held those first and then waited for the members row: a
-- deadlock, seen live as a group poll answering {code:'busy'} during that member's
-- own accept/invite retry (build/oct4-call-admission-deadlock-probe-prefix.log).
-- Fix: admission_member locks the caller's members row (for no key update, no rate
-- accounting; the inner require_account re-locks it reentrantly and counts once),
-- so the global order for every transaction touching these objects is
--   caller's members row -> per-member admission locks (sorted) -> 77833003
--   -> 77833002 -> group rooms row -> table rows (dm calls; group peers -> calls;
--   discovery sessions -> random rooms -> presence -> requests).
-- Why every path respects it:
--  * Every gateway, wrapped or not, begins with its own members row and no call,
--    discovery or random path locks another member's row, so members rows never
--    form a cycle on their own, and two transactions of one member are serialized
--    there before they touch anything else.
--  * Admission locks are taken only by wrappers, immediately after the members
--    row; nothing that holds an admission lock ever waits for a members row.
--  * discovery unwrapped: members row -> 77833003 -> discovery rows (heartbeat,
--    list, send, signal, media: members row -> discovery rows); never 77833002 or
--    a rooms row. member_random_before_continue (discovery enter and the random
--    actions) takes members row -> random rows and no advisory lock.
--  * dm unwrapped (poll/end/decline/signal/media): members row -> calls rows;
--    77833002 is taken only by invite, which is always wrapped and already holds it.
--  * group unwrapped: members row -> rooms row for update -> peers -> calls rows;
--    77833002 is taken only by the join branch, always wrapped and already held.
--  * wrappers: members row -> admission locks -> 77833003 -> 77833002 -> rooms
--    row -> admission_cleanup rows -> inner gateway, whose own lock statements are
--    reentrant no-ops by then.
--  * No path holds a table row while waiting for a members row, an advisory lock
--    or a rooms row, so the wait-for graph over these objects is acyclic.
-- A residual deadlock (two multi-row UPDATEs meeting the same rows in different
-- scan orders) is reported as code 'retry' ('Please try again.') rather than
-- 'busy', so clients and the race suite can tell a transient retry from a genuine
-- admission refusal.

create or replace function group_call_private.admission_member(p_hash text) returns uuid
language plpgsql security invoker set search_path='' as $$
declare m social_private.members;
begin
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'unauthorized:Sign in to continue.'; end if;
 -- First lock of every admission: the caller's members row, which every unwrapped action also takes first.
 select * into m from social_private.members where token_hash=p_hash for no key update;
 if m.id is null then raise exception 'unauthorized:Your account credential is unavailable.'; end if;
 if m.banned then raise exception 'forbidden:This account is suspended.'; end if;
 if (select require_verified from verification_private.settings where id) and not exists(select 1 from verification_private.memberships where member=m.id and expires_at>now()) then raise exception 'verification_required:Verify your TAMU mailbox to access the community.'; end if;
 -- The original gateway performs the authoritative check and rate count on the row already held.
 return m.id;
end $$;

create or replace function public.discovery_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;other_member uuid;participants uuid[];
begin
 if p_action not in('enter','accept','ack')then return public.discovery_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 if p_action='accept'then select sender into other_member from discovery_private.requests where id=(p_input->>'request_id')::uuid and recipient=me;
 elsif p_action='ack'then select case when a=me then b else a end into other_member from discovery_private.sessions where id=(p_input->>'session_id')::uuid and me in(a,b);end if;
 participants:=array[me,other_member];
 perform group_call_private.admission_lock(participants);
 perform pg_advisory_xact_lock(77833003);perform pg_advisory_xact_lock(77833002);
 perform group_call_private.admission_cleanup(participants);
 perform group_call_private.admission_assert(participants,'discovery');
 return public.discovery_before_admission(p_action,p_hash,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');when deadlock_detected then return jsonb_build_object('error','Please try again.','code','retry');end $$;

create or replace function public.social_call_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;other_member uuid;participants uuid[];call_id uuid;
begin
 if p_action not in('invite','accept')then return public.social_call_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 select rm.member into other_member from social_private.room_members rm join social_private.rooms r on r.id=rm.room where r.id=p_input->>'room_id'and r.kind='dm'and rm.member<>me and rm.status='accepted'and exists(select 1 from social_private.room_members where room=r.id and member=me and status='accepted')limit 1;
 participants:=array[me,other_member];
 perform group_call_private.admission_lock(participants);
 perform pg_advisory_xact_lock(77833003);perform pg_advisory_xact_lock(77833002);
 perform group_call_private.admission_cleanup(participants);
 if p_action='invite'then select id into call_id from social_private.calls where caller=me and nonce=(p_input->>'nonce')::uuid and room=p_input->>'room_id';
 else select id into call_id from social_private.calls where id=(p_input->>'call_id')::uuid and room=p_input->>'room_id'and me in(caller,callee);end if;
 perform group_call_private.admission_assert(participants,'dm',call_id);
 return public.social_call_before_admission(p_action,p_hash,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');when deadlock_detected then return jsonb_build_object('error','Please try again.','code','retry');end $$;

create or replace function public.group_call_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;call_id uuid;
begin
 if p_action not in('invite','accept')then return public.group_call_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 perform group_call_private.admission_lock(array[me]);
 perform pg_advisory_xact_lock(77833003);perform pg_advisory_xact_lock(77833002);
 -- Same rooms row the inner gateway re-locks reentrantly; a missing or non-group room is left to its forbidden check.
 perform 1 from social_private.rooms where id=p_input->>'room_id'and kind='group'for update;
 perform group_call_private.admission_cleanup(array[me]);
 if p_action='invite'then select id into call_id from group_call_private.calls where creator=me and nonce=(p_input->>'nonce')::uuid and room=p_input->>'room_id';
 else select id into call_id from group_call_private.calls where id=(p_input->>'call_id')::uuid and room=p_input->>'room_id';end if;
 perform group_call_private.admission_assert(array[me],'group',call_id);
 return public.group_call_before_admission(p_action,p_hash,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');when deadlock_detected then return jsonb_build_object('error','Please try again.','code','retry');end $$;

revoke all on function group_call_private.admission_member(text),public.discovery_gateway(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb),public.discovery_before_admission(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.group_call_before_admission(text,text,jsonb)from public,anon,authenticated;
grant execute on function group_call_private.admission_member(text),public.discovery_gateway(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb),public.discovery_before_admission(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.group_call_before_admission(text,text,jsonb)to service_role;
