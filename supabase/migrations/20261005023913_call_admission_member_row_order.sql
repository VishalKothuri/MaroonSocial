-- Members row first for call admission.
--
-- 20261004212249 made every wrapper take 77833003, 77833002 and (group) the
-- social_private.rooms row BEFORE calling the inner gateway, whose first statement
-- is social_private.require_member -> require_account: 'select ... from
-- social_private.members where token_hash=p_hash for no key update' followed by an
-- UPDATE of that row. Every unwrapped action therefore holds the caller's members
-- row and only then waits for 77833003 (discovery request/leave/decline/cancel/
-- profile/...) or the group's rooms row (group poll/end/decline/signal/media), while
-- a wrapped admission by the SAME member held those first and then waited for its
-- own members row inside the inner gateway: a deadlock, reproduced live as a group
-- poll answering {code:'busy',error:'Please try again.'} during that member's own
-- accept/invite retry (build/oct4-call-admission-deadlock-probe-prefix.log,
-- build/oct4-call-admission-review-deadlock-probe.log).
--
-- Fix: right after admission_member resolves the caller, every wrapper takes the
-- caller's own members row 'for no key update' - the same row, the same lock mode
-- and the same position (first) as require_account inside every gateway - and only
-- then the admission locks, 77833003, 77833002, the rooms row, the cleanup rows and
-- the inner gateway, whose own lock statements are then reentrant no-ops.
-- admission_member itself stays stable and lock-free; the lock sits in the wrapper
-- where its position relative to the other locks is visible and testable.
--
-- Global order. Every transaction over these objects acquires in this order:
--   caller's members row (for no key update)
--   < per-member admission advisory locks, sorted by member id (wrappers only)
--   < 77833003 (discovery)
--   < 77833002 (dm invite / group join)
--   < social_private.rooms row for update (group)
--   < call, peer and discovery rows (admission_cleanup: social_private.calls ->
--     group_call_private.peers -> group_call_private.calls -> discovery sessions ->
--     random rooms -> presence -> requests; group: peers -> calls -> signals;
--     dm: calls -> call_signals)
--   < 77330001 (random_chat_gateway, reached only through
--     public.member_random_before_continue)
--   < random_private participants/queue/messages/signals/blocks/reports.
-- Correction to 20261004212249: member_random_before_continue does take an advisory
-- lock - it forwards to public.random_chat_gateway, which always takes 77330001
-- (20261002004959 line 26, 20261004185701 line 39). It is acquired AFTER the
-- discovery rows (enter via 'capabilities'; heartbeat/send/signal/media/ack of a
-- connected session via 'poll'), which is consistent because the code that runs
-- under 77330001 touches random_private rows alone and never waits for a members
-- row, an admission lock, 77833003, 77833002, a rooms row or a call/discovery row.
--
-- Path by path. M = the caller's own members row; every unwrapped path starts with
-- M through require_account and every wrapped path now starts with M through the
-- pre-lock below:
--  * discovery heartbeat/list/send/signal/media (unwrapped): M -> discovery rows
--    (discovery_private.cleanup: sessions, random rooms, presence, requests; then
--    presence) -> [77330001 -> random rows when the session has a room]. Never an
--    advisory lock before a row, never 77833002, never a rooms row.
--  * discovery request/leave/decline/cancel/profile/continue/block/report
--    (unwrapped): M -> 77833003 -> discovery rows -> [77330001 -> random rows].
--  * discovery enter/accept/ack (wrapped): M -> admission locks(me[,peer]) ->
--    77833003 -> 77833002 -> admission_cleanup rows -> inner gateway: M (held),
--    77833003 (held), discovery rows, [77330001 -> random rows].
--  * dm poll/end/decline/signal/media (unwrapped): M -> social_private.calls rows
--    (expiry UPDATE, then the call row for no key update) -> call_signals.
--    77833002 is taken only by invite, which is always wrapped and already holds it.
--  * dm invite/accept (wrapped): M -> admission locks(me,peer) -> 77833003 ->
--    77833002 -> admission_cleanup rows -> inner gateway: M (held), calls rows,
--    77833002 (held), insert into calls (FOR KEY SHARE on the peer's members row).
--  * group poll/end/decline/signal/media (unwrapped): M -> rooms row for update ->
--    group_call_private.cleanup(room): peers -> calls; then peers(me) -> signals.
--    77833002 is taken only by the join branch, always wrapped and already held.
--  * group invite/accept (wrapped): M -> admission locks(me) -> 77833003 ->
--    77833002 -> rooms row -> admission_cleanup rows -> inner gateway: M (held),
--    rooms row (held), peers -> calls, 77833002 (held), peers upsert.
--  * random chat actions (member_random_gateway, random_chat_gateway, unwrapped):
--    M -> [continue:<room> advisory] -> random rooms/participants -> 77330001 ->
--    random rows. They touch no call or discovery row and take no admission lock,
--    77833003, 77833002 or rooms row.
-- Why the wait-for graph is acyclic:
--  * A members row is locked in a conflicting mode only by its own member's
--    transactions (every gateway locks exactly the caller's row; nothing locks
--    another member's row), and always as the first lock, so two transactions of
--    one member serialize there before either holds anything else. Other members
--    only take FOR KEY SHARE on it through foreign keys (calls.caller/callee,
--    peers.member, requests.sender/recipient, sessions.a/b, presence.member), which
--    does not conflict with FOR NO KEY UPDATE - the mode of require_account, of this
--    pre-lock and of require_account's UPDATE (seen_at/rate_* are non-key columns).
--  * Admission locks are taken only by wrappers, immediately after the members row,
--    and nothing that holds an admission lock ever waits for a members row.
--  * 77833003, 77833002 and the rooms row are taken only while holding nothing but
--    earlier entries of the list, never while holding a table row.
--  * No path holds a call or discovery row while waiting for a members row, an
--    admission lock, 77833003, 77833002 or a rooms row.
--  * 77330001 is taken only after those rows, and its holder waits only for
--    random_private rows.
-- Why the dm wrapper does NOT take the peer's members row: neither the wrapper nor
-- the inner dm gateway locks the peer's row (require_account locks the caller only;
-- admission_cleanup and discovery_private.cleanup only read members); the only wait
-- on it is the new calls row's FOR KEY SHARE, compatible with the peer's own
-- poll/heartbeat lock, so no cycle through it exists. Taking it would put every poll
-- of the peer behind the caller's admission for no exclusion gain (the sorted
-- per-member admission locks already reserve both participants) and would make the
-- members-row level depend on sorted acquisition everywhere instead of the simpler
-- invariant "each transaction locks only its own row, first". The only conflicting
-- locks on a members row are the FOR UPDATE paths outside calling (username change,
-- credential rotation, account deletion), which take no call lock; a collision with
-- one of those is covered by the backstop.
-- Residuals, unchanged and outside this order: two multi-row cleanup UPDATEs
-- meeting the same discovery rows from different starting members, and
-- random_private.rooms being written both before 77330001 (discovery_private.cleanup,
-- member_random_before_continue) and under it (random_chat_gateway). A deadlock in a
-- wrapped admission now answers code 'retry' ('Please try again.'), distinguishable
-- from an admission refusal (code 'busy'); clients keep the call or session and
-- retry (the next poll, or the same nonce).

create or replace function public.discovery_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;other_member uuid;participants uuid[];
begin
 if p_action not in('enter','accept','ack')then return public.discovery_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 -- First lock: the caller's own members row, as require_account takes it inside every gateway.
 perform 1 from social_private.members where id=me for no key update;
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
 -- First lock: the caller's own members row, as require_account takes it inside every gateway.
 perform 1 from social_private.members where id=me for no key update;
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
 -- First lock: the caller's own members row, as require_account takes it inside every gateway.
 perform 1 from social_private.members where id=me for no key update;
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

revoke all on function public.discovery_gateway(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb),public.discovery_before_admission(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.group_call_before_admission(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.discovery_gateway(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb),public.discovery_before_admission(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.group_call_before_admission(text,text,jsonb)to service_role;
