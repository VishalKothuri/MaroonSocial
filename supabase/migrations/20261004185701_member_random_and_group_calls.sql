-- Random matching shares the authenticated member's eligibility, blocks and bans.
-- The private bridge never exposes the member UUID, credential or stable random ID.
create table random_private.member_links(member uuid primary key references social_private.members on delete cascade,participant uuid unique not null references random_private.participants on delete cascade);
alter table random_private.member_links enable row level security;
create policy server_only on random_private.member_links to service_role using(true)with check(true);
revoke all on random_private.member_links from public,anon,authenticated;
grant all on random_private.member_links to service_role;
create function random_private.eligible_pair(a uuid,b uuid)returns boolean language sql stable security invoker set search_path=''as $$
 select exists(select 1 from random_private.member_links x join random_private.member_links y on y.participant=b join social_private.members m on m.id=y.member where x.participant=a and x.member<>y.member and not m.banned and not social_private.blocked(x.member,y.member)
 and(not(select require_verified from verification_private.settings where id)or exists(select 1 from verification_private.memberships v where v.member=y.member and v.expires_at>now())))
$$;
do $p$declare d text;n text;begin d:=pg_get_functiondef('public.random_chat_gateway(text,text,jsonb)'::regprocedure);n:='where q.participant<>me.id and q.mode=mode_value and not p.banned';if strpos(d,n)=0 then raise exception 'Random match guard target missing';end if;execute replace(d,n,n||' and random_private.eligible_pair(me.id,q.participant)');end $p$;

create function public.member_random_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;pid uuid;ph text;peer uuid;rid uuid;result jsonb;report_id uuid;active_room random_private.rooms;
begin
 me:=social_private.require_member(p_hash);
 select p.id,p.token_hash into pid,ph from random_private.member_links l join random_private.participants p on p.id=l.participant where l.member=me;
 if pid is null then
  ph:=encode(extensions.gen_random_bytes(32),'hex');insert into random_private.participants(token_hash,network_hash)values(ph,encode(extensions.digest('member:'||me::text,'sha256'),'hex'))returning id into pid;
  insert into random_private.member_links(member,participant)values(me,pid);
 end if;
 -- A long-lived account retains account blocks even if an inactive random session was purged.
 update random_private.participants set seen_at=now()where id=pid and seen_at<now()-interval '30 days';
 select *into active_room from random_private.rooms where pid in(a,b)order by created_at desc limit 1;
 if active_room.id is not null and active_room.ended_at is null then
  if active_room.created_at<now()-interval '20 minutes'or not random_private.eligible_pair(pid,case when active_room.a=pid then active_room.b else active_room.a end)then
   update random_private.rooms set ended_at=now(),end_reason='ended'where id=active_room.id;active_room.ended_at:=now();
  end if;
 end if;
 if p_action in('join','next')and coalesce(p_input->>'mode','text')<>'text'and(p_action='next'or active_room.id is null or active_room.ended_at is not null)then
  if(select count(*)from random_private.rooms where pid in(a,b)and mode<>'text'and created_at>now()-interval '24 hours')>=30 then raise exception 'rate_limit:Today’s call limit is reached. Text chat is still available.';end if;
 end if;
 if p_action in('block','report')then
  rid:=(p_input->>'room')::uuid;
  if rid is distinct from active_room.id then raise exception 'ended:That conversation has ended.';end if;
  select member into peer from random_private.member_links where participant=case when active_room.a=pid then active_room.b else active_room.a end;
 end if;
 result:=public.random_chat_gateway(case when p_action in('register','capabilities','media')then 'poll'else p_action end,ph,p_input);
 if result?'error'then return result;end if;
 if p_action in('block','report')and peer is not null then
  insert into social_private.blocks(blocker,blocked)values(me,peer)on conflict do nothing;
  if p_action='report'then
   select id into report_id from social_private.reports where reporter=me and target_type='random_member'and target_id=peer::text and evidence->>'room'=rid::text limit 1;
   if report_id is null then insert into social_private.reports(reporter,target_type,target_id,reason,evidence)values(me,'random_member',peer::text,left(p_input->>'reason',500),jsonb_build_object('room',rid,'messages',(select coalesce(jsonb_agg(jsonb_build_object('mine',sender=pid,'body',body,'created_at',created_at)order by id),'[]')from(select *from random_private.messages where room=rid order by id desc limit 50)x)))returning id into report_id;end if;
   result:=result||jsonb_build_object('report_id',report_id);
  end if;
 end if;
 return result||jsonb_build_object('member_bound',true);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid chat request.','code','invalid');
end $$;
create function random_private.member_revoked()returns trigger language plpgsql security invoker set search_path=''as $$declare pid uuid;begin
 select participant into pid from random_private.member_links where member=old.id;
 if tg_op='DELETE'then delete from random_private.participants where id=pid;return old;end if;
 if new.banned then update random_private.participants set banned=true where id=pid;delete from random_private.queue where participant=pid;update random_private.rooms set ended_at=coalesce(ended_at,now()),end_reason='ended'where pid in(a,b)and ended_at is null;end if;return new;end $$;
create trigger member_random_delete before delete on social_private.members for each row execute function random_private.member_revoked();
create trigger member_random_suspend after update of banned on social_private.members for each row execute function random_private.member_revoked();
create function random_private.member_blocked()returns trigger language plpgsql security invoker set search_path=''as $$begin
 update random_private.rooms r set ended_at=now(),end_reason='ended'from random_private.member_links a,random_private.member_links b where r.ended_at is null and a.member=new.blocker and b.member=new.blocked and((r.a=a.participant and r.b=b.participant)or(r.b=a.participant and r.a=b.participant));return new;end $$;
create trigger member_random_block after insert on social_private.blocks for each row execute function random_private.member_blocked();
-- The same privileged review workflow can resolve a random report without revealing its target publicly.
do $p$declare d text;n text;begin
 d:=pg_get_functiondef('social_private.operator_before_notifications(text,jsonb,text)'::regprocedure);
 n:='if rep.target_type=''post''then';
 if strpos(d,n)=0 then raise exception 'Operator target missing';end if;
 d:=replace(d,n,'if rep.target_type=''random_member''then update social_private.members set banned=true where id=rep.target_id::uuid;elsif rep.target_type=''post''then');
 -- The first substitution also affects the suspension resolver; replace its branch with a lookup.
 d:=replace(d,'if rep.target_type=''random_member''then update social_private.members set banned=true where id=rep.target_id::uuid;elsif rep.target_type=''post''then select author into target','if rep.target_type=''random_member''then select id into target from social_private.members where id=rep.target_id::uuid;elsif rep.target_type=''post''then select author into target');
 execute d;
end $p$;

create schema group_call_private;
revoke all on schema group_call_private from public,anon,authenticated;
grant usage on schema group_call_private to service_role;
create table group_call_private.calls(id uuid primary key default gen_random_uuid(),room text not null references social_private.rooms on delete cascade,creator uuid references social_private.members on delete set null,nonce uuid not null,mode text not null check(mode in('voice','video')),transport text not null check(transport in('direct','relay')),created_at timestamptz not null default now(),ends_at timestamptz not null default now()+interval '20 minutes',ended_at timestamptz,unique(creator,nonce));
create unique index group_call_active_room on group_call_private.calls(room)where ended_at is null;
create index group_call_creator_time on group_call_private.calls(creator,created_at);
create table group_call_private.peers(call uuid references group_call_private.calls on delete cascade,member uuid references social_private.members on delete cascade,seat uuid not null default gen_random_uuid(),accepted_at timestamptz not null default now(),seen_at timestamptz not null default now(),left_at timestamptz,allow_direct boolean not null,primary key(call,member),unique(call,seat));
create index group_call_peer_member on group_call_private.peers(member,seen_at);
create table group_call_private.signals(id bigint generated always as identity primary key,call uuid not null references group_call_private.calls on delete cascade,sender uuid not null,recipient uuid not null,kind text not null check(kind in('offer','answer','ice','media')),payload jsonb not null check(jsonb_typeof(payload)='object'and octet_length(payload::text)<=24000),nonce uuid not null,created_at timestamptz not null default now(),unique(call,sender,nonce));
create index group_call_signal_recipient on group_call_private.signals(call,recipient,id);
do $$declare t text;begin foreach t in array array['calls','peers','signals']loop execute format('alter table group_call_private.%I enable row level security',t);execute format('create policy server_only on group_call_private.%I to service_role using(true)with check(true)',t);end loop;end $$;
revoke all on all tables in schema group_call_private from public,anon,authenticated;
grant all on all tables in schema group_call_private to service_role;
grant usage,select on all sequences in schema group_call_private to service_role;
create function group_call_private.cleanup(p_room text default null)returns void language plpgsql security invoker set search_path=''as $$begin
 update group_call_private.peers p set left_at=now()from group_call_private.calls c where c.id=p.call and(p_room is null or c.room=p_room)and p.left_at is null and(c.ended_at is not null or c.ends_at<=now()or p.seen_at<now()-interval '35 seconds'or not social_private.can_message(p.member,c.room)or exists(select 1 from social_private.members m where m.id=p.member and m.banned)or((select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships v where v.member=p.member and v.expires_at>now())));
 update group_call_private.calls c set ended_at=now()where(p_room is null or c.room=p_room)and c.ended_at is null and(c.ends_at<=now()or not exists(select 1 from group_call_private.peers p where p.call=c.id and p.left_at is null));
 if p_room is null then delete from group_call_private.calls where ended_at<now()-interval '1 day';end if;
end $$;
create function public.group_call_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;rid text:=p_input->>'room_id';c group_call_private.calls;mine group_call_private.peers;target group_call_private.peers;roster jsonb;signals jsonb;result jsonb;transport_value text:=p_input->>'transport';
begin
 me:=social_private.require_member(p_hash);
 perform 1 from social_private.rooms where id=rid and kind='group'for update;
 if not found or not social_private.can_message(me,rid)then raise exception 'forbidden:Calls require current accepted group membership.';end if;
 perform group_call_private.cleanup(rid);
 if p_action='invite'then
  if p_input->>'mode'not in('voice','video')or transport_value not in('direct','relay')or p_input->>'nonce'is null then raise exception 'invalid:Choose a call type.';end if;
  select *into c from group_call_private.calls where creator=me and nonce=(p_input->>'nonce')::uuid;
  if c.id is not null and(c.room<>rid or c.mode<>p_input->>'mode')then raise exception 'conflict:Retry the original call invitation.';end if;
  if c.id is null then
   if exists(select 1 from group_call_private.calls where room=rid and ended_at is null)then raise exception 'busy:A call is already open in this group.';end if;
   if(select count(*)from group_call_private.calls where creator=me and created_at>now()-interval '24 hours')>=20 then raise exception 'rate_limit:Today’s group call invitation limit is reached.';end if;
   insert into group_call_private.calls(room,creator,nonce,mode,transport)values(rid,me,(p_input->>'nonce')::uuid,p_input->>'mode',transport_value)returning *into c;
  end if;
 elsif p_input->>'call_id'is not null then select *into c from group_call_private.calls where id=(p_input->>'call_id')::uuid and room=rid;
 else select *into c from group_call_private.calls where room=rid and ended_at is null order by created_at desc limit 1;end if;
 if c.id is null or c.ended_at is not null then
  if p_action in('poll','end','decline')then return jsonb_build_object('call',null,'transport',transport_value);end if;
  raise exception 'ended:This group call has ended.';
 end if;
 select *into mine from group_call_private.peers where call=c.id and member=me;
 if p_action in('invite','accept')and(mine.call is null or mine.left_at is not null)then
  perform pg_advisory_xact_lock(77833002);
  if c.transport='direct'and not coalesce((p_input->>'allow_direct')::boolean,false)then raise exception 'consent:Direct group calls require your consent.';end if;
  if(select count(*)from group_call_private.peers where call=c.id and left_at is null)>=4 then raise exception 'full:This call already has four participants.';end if;
  if exists(select 1 from group_call_private.peers p join group_call_private.calls ac on ac.id=p.call where p.member=me and p.left_at is null and ac.ended_at is null and p.call<>c.id)or exists(select 1 from social_private.calls where state<>'ended'and me in(caller,callee))then raise exception 'busy:End your current call before joining another.';end if;
  if exists(select 1 from group_call_private.peers where call=c.id and left_at is null and social_private.blocked(me,member))then raise exception 'forbidden:This call is unavailable.';end if;
  insert into group_call_private.peers(call,member,allow_direct)values(c.id,me,coalesce((p_input->>'allow_direct')::boolean,false))on conflict(call,member)do update set seat=gen_random_uuid(),accepted_at=now(),seen_at=now(),left_at=null,allow_direct=excluded.allow_direct returning *into mine;
 elsif p_action in('end','decline')then
  update group_call_private.peers set left_at=coalesce(left_at,now())where call=c.id and member=me;
  if not exists(select 1 from group_call_private.peers where call=c.id and left_at is null)then update group_call_private.calls set ended_at=now()where id=c.id;end if;
  return jsonb_build_object('call',null,'transport',transport_value);
 elsif p_action in('signal','media')then
  if mine.call is null or mine.left_at is not null then raise exception 'consent:Join this call before connecting media.';end if;
  if c.transport='direct'and(not mine.allow_direct or not coalesce((p_input->>'allow_direct')::boolean,false))then raise exception 'consent:Direct calls require your consent.';end if;
  if p_action='signal'then
   select *into target from group_call_private.peers where call=c.id and seat=(p_input->>'to')::uuid and left_at is null and member<>me;
   if target.call is null or social_private.blocked(me,target.member)then raise exception 'forbidden:That call participant is unavailable.';end if;
   if(select count(*)from group_call_private.signals where call=c.id and sender=mine.seat)>=1200 then raise exception 'rate_limit:Call signaling limit reached.';end if;
   insert into group_call_private.signals(call,sender,recipient,kind,payload,nonce)values(c.id,mine.seat,target.seat,p_input->>'kind',p_input->'payload',(p_input->>'nonce')::uuid)on conflict(call,sender,nonce)do nothing;
  end if;
 elsif p_action<>'poll'then raise exception 'invalid:Unknown group call action.';end if;
 if mine.call is not null and mine.left_at is null then update group_call_private.peers set seen_at=now()where call=c.id and member=me;end if;
 select coalesce(jsonb_agg(jsonb_build_object('seat',p.seat,'alias',community_private.display_name(rid,p.member),'avatar',i.avatar,'is_me',p.member=me)order by p.accepted_at),'[]')into roster from group_call_private.peers p join community_private.identities i on i.room=rid and i.member=p.member where p.call=c.id and p.left_at is null and not social_private.blocked(me,p.member);
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'from',s.sender,'kind',s.kind,'payload',s.payload)order by s.id),'[]')into signals from(select s.*from group_call_private.signals s where s.call=c.id and s.recipient=mine.seat and s.id>coalesce((p_input->>'after')::bigint,0)and exists(select 1 from group_call_private.peers p where p.call=c.id and p.seat=s.sender and p.left_at is null and not social_private.blocked(me,p.member))order by s.id limit 200)s;
 return jsonb_build_object('transport',transport_value,'call',jsonb_build_object('id',c.id,'room_id',rid,'mode',c.mode,'transport',c.transport,'state','open','joined',mine.call is not null and mine.left_at is null,'my_seat',case when mine.left_at is null then mine.seat else null end,'participants',roster,'signals',signals,'ends_at',extract(epoch from c.ends_at),'capacity',4));
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Invalid group call request.','code','invalid');
end $$;
-- Existing direct-call admission must also respect accepted group calls.
do $p$declare d text;n text;begin d:=pg_get_functiondef('public.social_call_gateway(text,text,jsonb)'::regprocedure);n:='if exists(select 1 from social_private.calls where state<>''ended''and(me in(caller,callee)or peer in(caller,callee)))then';if strpos(d,n)=0 then raise exception 'DM call admission guard missing';end if;execute replace(d,n,'if exists(select 1 from group_call_private.peers p join group_call_private.calls gc on gc.id=p.call where p.member in(me,peer)and p.left_at is null and gc.ended_at is null and gc.ends_at>now()and p.seen_at>now()-interval ''35 seconds'')or exists(select 1 from social_private.calls where state<>''ended''and(me in(caller,callee)or peer in(caller,callee)))then');end $p$;
revoke all on all functions in schema random_private,group_call_private from public,anon,authenticated;
grant execute on all functions in schema random_private,group_call_private to service_role;
revoke all on function public.member_random_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.member_random_gateway(text,text,jsonb),public.group_call_gateway(text,text,jsonb)to service_role;
select cron.schedule('group_call_cleanup','* * * * *','select group_call_private.cleanup()');

create function group_call_private.membership_changed()returns trigger language plpgsql security invoker set search_path=''as $$begin
 update group_call_private.peers p set left_at=coalesce(left_at,now())from group_call_private.calls c where c.id=p.call and c.room=old.room and p.member=old.member and(tg_op='DELETE'or new.status<>'accepted');return old;end $$;
create trigger group_call_member_leave after delete or update of status on social_private.room_members for each row execute function group_call_private.membership_changed();
create function group_call_private.block_changed()returns trigger language plpgsql security invoker set search_path=''as $$begin
 update group_call_private.peers p set left_at=now()where p.left_at is null and p.member in(new.blocker,new.blocked)and exists(select 1 from group_call_private.peers a join group_call_private.peers b on b.call=a.call where a.call=p.call and a.member=new.blocker and b.member=new.blocked and a.left_at is null and b.left_at is null);return new;end $$;
create trigger group_call_block after insert on social_private.blocks for each row execute function group_call_private.block_changed();
create table group_call_private.media_grants(member uuid references social_private.members on delete cascade,kind text,reference uuid,requests integer not null default 0,created_at timestamptz not null default now(),primary key(member,kind,reference));
alter table group_call_private.media_grants enable row level security;
create policy server_only on group_call_private.media_grants to service_role using(true)with check(true);
revoke all on group_call_private.media_grants from public,anon,authenticated;
grant all on group_call_private.media_grants to service_role;
create function public.call_media_admit(p_hash text,p_kind text,p_reference uuid)returns jsonb language plpgsql security invoker set search_path=''as $$declare me uuid;deadline timestamptz;n integer;begin
 me:=social_private.require_member(p_hash);
 if p_kind='random'then select r.created_at+interval '20 minutes'into deadline from random_private.rooms r join random_private.member_links l on l.participant in(r.a,r.b)where r.id=p_reference and l.member=me and r.ended_at is null and r.mode<>'text';
 elsif p_kind='group'then select c.ends_at into deadline from group_call_private.calls c join group_call_private.peers p on p.call=c.id where c.id=p_reference and p.member=me and p.left_at is null and c.ended_at is null and social_private.can_message(me,c.room);
 elsif p_kind='dm'then select c.connected_at+interval '2 hours'into deadline from social_private.calls c where c.id=p_reference and me in(c.caller,c.callee)and c.state='connected'and social_private.can_message(me,c.room);end if;
 if deadline is null or deadline<=now()then return jsonb_build_object('error','This call has ended.','code','ended');end if;
 insert into group_call_private.media_grants(member,kind,reference,requests)values(me,p_kind,p_reference,1)on conflict(member,kind,reference)do update set requests=group_call_private.media_grants.requests+1 returning requests into n;
 if n>6 then return jsonb_build_object('error','Relay retry limit reached for this call. End it and try later.','code','rate_limit');end if;
 return jsonb_build_object('ttl',greatest(60,least(7200,ceil(extract(epoch from deadline-now())))));
end $$;
revoke all on function public.call_media_admit(text,text,uuid),group_call_private.membership_changed(),group_call_private.block_changed()from public,anon,authenticated;
grant execute on function public.call_media_admit(text,text,uuid),group_call_private.membership_changed(),group_call_private.block_changed()to service_role;

-- Private report evidence has the same bounded retention as the random transcript.
select cron.schedule('member_call_retention','17 * * * *',$job$delete from social_private.reports where target_type='random_member'and created_at<now()-interval '90 days';delete from group_call_private.media_grants where created_at<now()-interval '1 day';$job$);
