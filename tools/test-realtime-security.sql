-- Protocol checks for caching phase 3 (Realtime pokes), after 20261005200000_realtime_pokes.sql and
-- 20261005210000_realtime_pokes_review_fixes.sql.
-- Run as the database owner with psql:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tools/test-realtime-security.sql
-- Everything runs in one transaction and rolls back (fixture members, rooms, pokes).
begin;

-- 1. Grants: the private helpers stay private; only the self-only policy wrapper is callable.
do $$
begin
 if has_function_privilege('anon','social_private.realtime_topic_allowed(uuid,text)','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_topic_allowed(uuid,text)','EXECUTE')
  or has_function_privilege('anon','social_private.realtime_member_allowed(uuid)','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_member_allowed(uuid)','EXECUTE')
  or has_function_privilege('anon','public.social_realtime(text,text,jsonb)','EXECUTE')
  or has_function_privilege('authenticated','public.social_realtime(text,text,jsonb)','EXECUTE')
  or has_function_privilege('anon','social_private.realtime_message_poke()','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_message_poke()','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_message_change_poke()','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_member_poke()','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_room_poke()','EXECUTE')
  or has_function_privilege('authenticated','social_private.realtime_call_poke()','EXECUTE')
  or has_function_privilege('anon','realtime_access.can_receive(text)','EXECUTE')
  or has_schema_privilege('anon','realtime_access','USAGE')
  or has_schema_privilege('authenticated','social_private','USAGE')
 then raise exception 'Realtime helper exposed';end if;
 if not has_function_privilege('authenticated','realtime_access.can_receive(text)','EXECUTE') then raise exception 'Policy wrapper not callable by authenticated';end if;
 if exists(select 1 from pg_policy where polrelid='realtime.messages'::regclass and polcmd in ('a','w','*') and 'authenticated'::regrole=any(polroles)) then raise exception 'Clients may broadcast';end if;
 if not exists(select 1 from pg_policy where polrelid='realtime.messages'::regclass and polname='maroon members receive their topics' and polcmd='r') then raise exception 'Receive policy missing';end if;
 if exists(select 1 from information_schema.role_table_grants where grantee='authenticated' and table_schema not in ('realtime','information_schema','pg_catalog','storage','graphql','graphql_public','extensions','auth','vault') and not (table_schema='public' and table_name='campus_cache')) then raise exception 'A realtime token would open more than the channels';end if;
end $$;

-- 2. Topic predicate, member resolution and pokes, as the gateway's service role.
set local role service_role;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;post uuid;dm_room text;grp text;out jsonb;last_seq bigint;grp_seq bigint;before_count integer;was_required boolean;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'rt_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'rt_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'rt_c_'||substr(hc,1,8),true,hc)returning id into c;
 if (public.social_realtime('member',ha,'{}'))->>'member' is distinct from a::text then raise exception 'Member resolution wrong';end if;
 if (public.social_realtime('member',encode(extensions.gen_random_bytes(32),'hex'),'{}'))->>'code' is distinct from 'unauthorized' then raise exception 'Unknown credential resolved';end if;
 if (public.social_realtime('other',ha,'{}'))->>'code' is distinct from 'invalid' then raise exception 'Unknown realtime action accepted';end if;

 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Realtime QA','anonymous',true,'community','Graduates','acceptsDM',true));post:=(out->>'resource_id')::uuid;
 if post is null then raise exception 'Fixture post failed %',out;end if;
 out:=public.social_gateway('dm.request',hb,jsonb_build_object('post_id',post,'text','Realtime QA hello'));dm_room:=out->>'resource_id';
 if dm_room is null then raise exception 'DM request failed %',out;end if;
 -- Pending request: the requester reads it; the invited recipient reads an invited DM too.
 if not social_private.realtime_topic_allowed(b,'room:'||dm_room) then raise exception 'Requester cannot receive own DM room';end if;
 -- Accepting pokes the open room and the requester's inbox (b asked, a answers).
 select count(*) into before_count from realtime.messages where topic='member:'||b and event='inbox' and payload->>'room'=dm_room and not payload?'seq';
 perform set_config('maroon.rt_changes',(select count(*) from realtime.messages where topic='room:'||dm_room and event='change')::text,true);
 out:=public.social_gateway('dm.accept',ha,jsonb_build_object('room_id',dm_room));if out?'error' then raise exception 'Accept failed %',out;end if;
 if (select count(*) from realtime.messages where topic='member:'||b and event='inbox' and payload->>'room'=dm_room and not payload?'seq')<=before_count then raise exception 'Requester not poked about the accept';end if;
 if (select count(*) from realtime.messages where topic='room:'||dm_room and event='change')<=current_setting('maroon.rt_changes')::int then raise exception 'Open DM not poked about the accept';end if;

 if not social_private.realtime_topic_allowed(a,'member:'||a) then raise exception 'Member topic refused';end if;
 if social_private.realtime_topic_allowed(a,'member:'||b) then raise exception 'Foreign member topic allowed';end if;
 if social_private.realtime_topic_allowed(a,'member:'||upper(a::text)) then raise exception 'Member topic not exact';end if;
 if not social_private.realtime_topic_allowed(a,'room:'||dm_room) or not social_private.realtime_topic_allowed(b,'room:'||dm_room) then raise exception 'Room members refused';end if;
 if social_private.realtime_topic_allowed(c,'room:'||dm_room) then raise exception 'Stranger may receive the DM room';end if;
 if social_private.realtime_topic_allowed(a,'room:') or social_private.realtime_topic_allowed(a,'room:missing-room') or social_private.realtime_topic_allowed(a,'presence:'||dm_room)
  or social_private.realtime_topic_allowed(a,dm_room) or social_private.realtime_topic_allowed(null,'member:') or social_private.realtime_topic_allowed(a,null) then raise exception 'Foreign topic allowed';end if;
 insert into social_private.blocks values(a,b)on conflict do nothing;
 if social_private.realtime_topic_allowed(a,'room:'||dm_room) or social_private.realtime_topic_allowed(b,'room:'||dm_room) then raise exception 'Blocked DM still receivable';end if;
 delete from social_private.blocks where blocker=a and blocked=b;
 update social_private.members set banned=true where id=c;
 if social_private.realtime_topic_allowed(c,'member:'||c) then raise exception 'Suspended member may receive';end if;

 -- A message pokes the room and both members' inboxes with ids only.
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',dm_room,'text','Secret realtime body','nonce',gen_random_uuid()));
 if out?'error' then raise exception 'Send failed %',out;end if;
 select max(m.seq) into last_seq from social_private.messages m where m.room=dm_room;
 perform set_config('maroon.rt_a',a::text,true);perform set_config('maroon.rt_b',b::text,true);perform set_config('maroon.rt_c',c::text,true);
 perform set_config('maroon.rt_room',dm_room,true);perform set_config('maroon.rt_seq',last_seq::text,true);
 -- Typing and reactions poke the open room.
 out:=public.social_gateway('room.typing',hb,jsonb_build_object('room_id',dm_room));if out?'error' then raise exception 'Typing failed %',out;end if;
 select count(*) into before_count from realtime.messages where topic='room:'||dm_room and event='change';
 out:=public.social_gateway('room.react',hb,jsonb_build_object('message_id',(select m.id from social_private.messages m where m.room=dm_room and m.seq=last_seq),'emoji','👍'));if out?'error' then raise exception 'React failed %',out;end if;
 if (select count(*) from realtime.messages where topic='room:'||dm_room and event='change')<=before_count then raise exception 'Reaction poke missing';end if;

 -- A pending group invitee gets the invitation poke but no message pokes (it cannot read the room).
 insert into social_private.rooms(kind,title)values('group','Realtime QA group')returning id into grp;
 insert into social_private.room_members(room,member,role,status)values(grp,a,'owner','accepted');
 insert into social_private.room_members(room,member,role,status)values(grp,b,'member','invited');
 if not exists(select 1 from realtime.messages where topic='member:'||b and event='inbox' and payload->>'room'=grp and not payload?'seq') then raise exception 'Group invitation poke missing';end if;
 if social_private.realtime_topic_allowed(b,'room:'||grp) or not social_private.realtime_topic_allowed(a,'room:'||grp) then raise exception 'Group room topic wrong';end if;
 select coalesce(max(m.seq),0)+1 into grp_seq from social_private.messages m;
 insert into social_private.messages(room,author,nonce,body,seq)values(grp,a,gen_random_uuid(),'Secret group body',grp_seq);
 if not exists(select 1 from realtime.messages where topic='member:'||a and event='inbox' and payload->>'room'=grp and (payload->>'seq')::bigint=grp_seq) then raise exception 'Group member inbox poke missing';end if;
 if exists(select 1 from realtime.messages where topic='member:'||b and payload->>'room'=grp and payload?'seq') then raise exception 'Group invitee poked about a message';end if;

 -- A call pokes the room on ring and answer (not on presence heartbeats) and rings the callee's inbox.
 select count(*) into before_count from realtime.messages where topic='room:'||dm_room and event='change';
 perform set_config('maroon.rt_inbox_b',(select count(*) from realtime.messages where topic='member:'||b and event='inbox' and payload->>'room'=dm_room)::text,true);
 insert into social_private.calls(room,caller,callee,mode,transport,nonce)values(dm_room,a,b,'voice','relay',gen_random_uuid());
 if (select count(*) from realtime.messages where topic='room:'||dm_room and event='change')<>before_count+1 then raise exception 'Ring did not poke the room';end if;
 if (select count(*) from realtime.messages where topic='member:'||b and event='inbox' and payload->>'room'=dm_room)<>current_setting('maroon.rt_inbox_b')::int+1 then raise exception 'Ring did not reach the callee inbox';end if;
 update social_private.calls set callee_seen=now() where room=dm_room and caller=a;
 if (select count(*) from realtime.messages where topic='room:'||dm_room and event='change')<>before_count+1 then raise exception 'Call heartbeat poked the room';end if;
 update social_private.calls set state='connected',connected_at=now() where room=dm_room and caller=a;
 if (select count(*) from realtime.messages where topic='room:'||dm_room and event='change')<>before_count+2 then raise exception 'Answer did not poke the room';end if;

 -- Receiving needs what the gateway needs: a current TAMU verification while it is required.
 select coalesce((select s.require_verified from verification_private.settings s where s.id),false) into was_required;
 insert into verification_private.settings(id,require_verified)values(true,true)on conflict(id)do update set require_verified=true;
 if social_private.realtime_topic_allowed(a,'member:'||a) or social_private.realtime_topic_allowed(a,'room:'||dm_room) then raise exception 'Unverified member may receive';end if;
 insert into verification_private.memberships(member,email_hash,expires_at)values(a,encode(extensions.gen_random_bytes(32),'hex'),now()+interval '1 day');
 if not social_private.realtime_topic_allowed(a,'member:'||a) or not social_private.realtime_topic_allowed(a,'room:'||dm_room) then raise exception 'Verified member refused';end if;
 update verification_private.memberships set expires_at=now()-interval '1 minute' where member=a;
 if social_private.realtime_topic_allowed(a,'member:'||a) then raise exception 'Lapsed verification may receive';end if;
 delete from verification_private.memberships where member=a;
 update verification_private.settings set require_verified=was_required where id;
 perform set_config('maroon.rt_grp',grp,true);
end $$;
reset role;

do $$
declare room text:=current_setting('maroon.rt_room');grp text:=current_setting('maroon.rt_grp');a text:=current_setting('maroon.rt_a');b text:=current_setting('maroon.rt_b');last_seq text:=current_setting('maroon.rt_seq');
begin
 if not exists(select 1 from realtime.messages where topic='room:'||room and event='message' and private and payload->>'seq'=last_seq and payload->>'room'=room) then raise exception 'Room poke missing';end if;
 if (select count(*) from realtime.messages where event='inbox' and payload->>'seq'=last_seq and topic in ('member:'||a,'member:'||b))<>2 then raise exception 'Inbox pokes missing';end if;
 if exists(select 1 from realtime.messages where (topic in ('room:'||room,'room:'||grp) or topic in ('member:'||a,'member:'||b))
   and (payload::text like '%Secret%body%' or exists(select 1 from jsonb_object_keys(payload) k where k not in ('room','seq','id')))) then raise exception 'A poke carries more than ids';end if;
 if not exists(select 1 from realtime.messages where topic='room:'||room and event='typing') then raise exception 'Typing poke missing';end if;
 if not exists(select 1 from realtime.messages where topic='room:'||room and event='change') then raise exception 'Reaction poke missing';end if;
end $$;

-- 3. The RLS policy itself, as Realtime evaluates a join: role authenticated, the JWT subject,
-- and realtime.topic() set to the topic being joined.
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('role','authenticated','sub',current_setting('maroon.rt_b'))::text,true);
select set_config('realtime.topic','member:'||current_setting('maroon.rt_b'),true);
do $$ begin if not exists(select 1 from realtime.messages where event='inbox') then raise exception 'Own inbox not receivable';end if;end $$;
select set_config('realtime.topic','member:'||current_setting('maroon.rt_a'),true);
do $$ begin if exists(select 1 from realtime.messages) then raise exception 'Another member''s inbox receivable';end if;end $$;
select set_config('realtime.topic','room:'||current_setting('maroon.rt_room'),true);
do $$ begin if not exists(select 1 from realtime.messages where event='message') then raise exception 'Own room not receivable';end if;end $$;
select set_config('request.jwt.claims',json_build_object('role','authenticated','sub',current_setting('maroon.rt_c'))::text,true);
do $$ begin if exists(select 1 from realtime.messages) then raise exception 'Stranger receives the room';end if;end $$;
do $$ begin
 begin
  insert into realtime.messages(topic,extension,event,payload,private)values('room:'||current_setting('maroon.rt_room'),'broadcast','message','{}',true);
  raise exception 'Client broadcast accepted';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ begin
 begin
  if exists(select 1 from realtime.messages) then raise exception 'Anonymous receives private pokes';end if;
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;

select 'PASS realtime: private helpers not executable by anon/authenticated, member/room/foreign topics, blocks, suspensions and lapsed verification, id-only message/inbox/typing/reaction/call/answer pokes, no message pokes for pending group invitees, receive-only RLS for the member''s own topics' result;
rollback;
