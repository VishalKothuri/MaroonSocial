-- Lock order for call admission.
-- 20261004203656 wrapped the three gateways: sorted per-member admission locks,
-- then admission_cleanup (UPDATEs on social_private.calls, group_call_private
-- peers/calls and discovery_private sessions/presence/requests), then the inner
-- gateway, which only then took its feature lock (group: social_private.rooms row
-- for update then pg_advisory_xact_lock(77833002) on join; dm: 77833002 on invite
-- and calls rows for no key update; discovery: 77833003 then discovery cleanup).
-- Non-admission actions bypass the wrappers and lock feature-first then rows:
--   discovery request/leave/ack/...: 77833003 -> discovery rows (heartbeat, list,
--     send, signal, media: discovery rows only, never an advisory lock);
--   dm poll/end/decline/signal/media: calls rows only (77833002 is taken only by
--     invite, which is always wrapped);
--   group poll/end/decline/signal/media: rooms row for update -> peers -> calls rows
--     (77833002 is taken only by the join branch, which is always wrapped).
-- So a wrapper could hold cleanup row locks while waiting for 77833003, 77833002 or
-- the room row held by a non-admission transaction waiting on those rows: deadlock.
-- Fix: after the member locks and BEFORE any row write, every wrapper acquires
-- 77833003, then 77833002, then (group only) the group's rooms row. Why this is
-- consistent with every non-admission path:
--  * The order member locks < 77833003 < 77833002 < rooms row < table rows is the
--    only order any transaction uses. Member locks are taken only by wrappers and
--    only first. Discovery takes 77833003 as its first lock and never waits for
--    77833002 or a rooms row. The dm and group non-admission paths never take an
--    advisory lock; group takes its rooms row first and only then peers -> calls,
--    which is also the order admission_cleanup and group_call_private.cleanup use.
--    discovery enter calls member_random_before_continue, which takes no advisory lock.
--  * Nothing ever holds a table row while waiting for an advisory lock or a rooms
--    row, so the wait-for graph among those locks is acyclic.
--  * pg_advisory_xact_lock and row locks are reentrant, so the inner gateways' own
--    lock statements become no-ops when reached through a wrapper.
-- Residual deadlocks (two multi-row UPDATEs meeting the same rows in different scan
-- orders) now surface as a retryable 'busy' result instead of a 500.

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
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');when deadlock_detected then return jsonb_build_object('error','Please try again.','code','busy');end $$;

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
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');when deadlock_detected then return jsonb_build_object('error','Please try again.','code','busy');end $$;

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
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');when deadlock_detected then return jsonb_build_object('error','Please try again.','code','busy');end $$;

-- An invite retry or accept by a peer who is already joined previously fell through
-- to 'Unknown group call action.'; such calls are idempotent and answer like poll.
do $p$declare d text;n text:='elsif p_action<>''poll''then raise exception ''invalid:Unknown group call action.'';end if;';begin
 d:=pg_get_functiondef('public.group_call_before_admission(text,text,jsonb)'::regprocedure);
 if strpos(d,n)=0 then raise exception 'Group call action anchor missing';end if;
 execute replace(d,n,'elsif p_action not in(''poll'',''invite'',''accept'')then raise exception ''invalid:Unknown group call action.'';end if;');
end $p$;

revoke all on function public.discovery_gateway(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb),public.discovery_before_admission(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.group_call_before_admission(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.discovery_gateway(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb),public.discovery_before_admission(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.group_call_before_admission(text,text,jsonb)to service_role;
