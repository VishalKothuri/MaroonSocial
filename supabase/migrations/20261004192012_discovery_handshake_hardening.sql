drop function discovery_private.cleanup();
create function discovery_private.cleanup(p_member uuid default null)returns void language plpgsql security invoker set search_path=''as $$begin
 update discovery_private.sessions s set ended_at=now()where(p_member is null or p_member in(s.a,s.b))and s.ended_at is null and(s.ends_at<=now()or(s.room is null and s.ack_deadline<=now())or not discovery_private.eligible(s.a,s.b)or not exists(select 1 from discovery_private.presence where member=s.a and instance=s.instance_a and seen_at>now()-interval '15 seconds')or not exists(select 1 from discovery_private.presence where member=s.b and instance=s.instance_b and seen_at>now()-interval '15 seconds'));
 update random_private.rooms r set ended_at=coalesce(r.ended_at,now()),end_reason='ended'from discovery_private.sessions s where(p_member is null or p_member in(s.a,s.b))and s.room=r.id and s.ended_at is not null and r.ended_at is null;
 delete from discovery_private.presence p where(p_member is null or p.member=p_member)and(p.seen_at<=now()-interval '15 seconds'or exists(select 1 from social_private.members where id=p.member and banned)or(p.state<>'waiting'and not exists(select 1 from discovery_private.sessions s where p.member in(s.a,s.b)and s.ended_at is null)));
 update discovery_private.requests r set status='expired'where(p_member is null or p_member in(r.sender,r.recipient))and r.status='pending'and(r.expires_at<=now()or not discovery_private.eligible(r.sender,r.recipient)or not exists(select 1 from discovery_private.presence where member=r.sender and state='waiting')or not exists(select 1 from discovery_private.presence where member=r.recipient and id=r.target and state='waiting'));
 if p_member is null then delete from discovery_private.sessions where ended_at<now()-interval '1 day';delete from discovery_private.requests where created_at<now()-interval '1 day'and status<>'pending';end if;
end $$;
create or replace function public.discovery_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;instance_value uuid;mine discovery_private.presence;target discovery_private.presence;request_value discovery_private.requests;s discovery_private.sessions;profile discovery_private.profiles;peer discovery_private.profiles;tags_value text[];result jsonb;people jsonb;incoming jsonb;outgoing jsonb;state_value text:='idle';participant_a uuid;participant_b uuid;random_hash text;random_result jsonb:='{}';room_id text;body_value text;direct boolean:=coalesce((p_input->>'allow_direct')::boolean,false);
begin
 me:=social_private.require_member(p_hash);instance_value:=(p_input->>'instance')::uuid;
 if instance_value is null then raise exception 'invalid:Open a fresh discovery screen.';end if;
 if p_action not in('heartbeat','list','send','signal','media')then perform pg_advisory_xact_lock(77833003);end if;
 perform discovery_private.cleanup(me);
 select *into mine from discovery_private.presence where member=me;
 if mine.member is not null and mine.instance<>instance_value then
  if p_action='leave'then return jsonb_build_object('state','idle');end if;
  raise exception 'conflict:Discovery is already open on another device or browser. Leave there first.';
 end if;
 select *into profile from discovery_private.profiles where member=me;
 if p_action='profile'then
  if mine.member is not null then raise exception 'busy:Leave discovery before changing your profile.';end if;
  if coalesce(p_input->>'username','')!~'^[A-Za-z0-9_]{3,20}$'or jsonb_typeof(p_input->'tags')is distinct from 'array'or jsonb_array_length(p_input->'tags')>6 then raise exception 'invalid:Choose a 3–20 character username and up to six interests.';end if;
  if exists(select 1 from jsonb_array_elements(p_input->'tags')t where jsonb_typeof(t)<>'string'or(t#>>'{}')!~'^[A-Za-z0-9_]{1,24}$')then raise exception 'invalid:Interests use letters, numbers and underscores, up to 24 characters.';end if;
  select coalesce(array_agg(distinct lower(t)),'{}')into tags_value from jsonb_array_elements_text(p_input->'tags')t;
  if cardinality(tags_value)<>jsonb_array_length(p_input->'tags')then raise exception 'invalid:Choose different interests.';end if;
  insert into discovery_private.profiles(member,username,tags)values(me,p_input->>'username',tags_value)on conflict(member)do update set username=excluded.username,tags=excluded.tags returning *into profile;
 elsif p_action='enter'then
  if profile.member is null then raise exception 'profile_required:Choose your discovery username and interests first.';end if;
  if p_input->>'transport'='direct'and not direct then raise exception 'consent:Agree to direct video before entering discovery.';end if;
  if exists(select 1 from social_private.calls where me in(caller,callee)and state<>'ended')or exists(select 1 from group_call_private.peers p join group_call_private.calls c on c.id=p.call where p.member=me and p.left_at is null and c.ended_at is null and c.ends_at>now()and p.seen_at>now()-interval '35 seconds')then raise exception 'busy:End your other call before entering discovery.';end if;
  if mine.member is null and(select count(*)from discovery_private.presence where seen_at>now()-interval '15 seconds')>=100 then raise exception 'full:The waiting area is full. Try again shortly.';end if;
  perform public.member_random_before_continue('capabilities',p_hash,'{}');
  if mine.member is null then insert into discovery_private.presence(member,instance,state,allow_direct)values(me,instance_value,'waiting',direct)returning *into mine;else update discovery_private.presence set seen_at=now()where member=me returning *into mine;end if;
 elsif p_action in('heartbeat','list')then
  if mine.member is not null then update discovery_private.presence set seen_at=now()where member=me;end if;
 elsif p_action='request'then
  if mine.member is null or mine.state<>'waiting'then raise exception 'unavailable:Enter the waiting area first.';end if;
  select *into request_value from discovery_private.requests where sender=me and nonce=(p_input->>'nonce')::uuid;
  if request_value.id is not null then
   if request_value.target is distinct from(p_input->>'target')::uuid then raise exception 'conflict:Retry the original request.';end if;
  else
   select *into target from discovery_private.presence where id=(p_input->>'target')::uuid and state='waiting'and seen_at>now()-interval '15 seconds';
   if target.member is null or not discovery_private.eligible(me,target.member)then raise exception 'unavailable:That person is no longer waiting.';end if;
   if exists(select 1 from discovery_private.requests where sender=me and status='pending')then raise exception 'busy:Cancel your current request before sending another.';end if;
   if(select count(*)from discovery_private.requests where sender=me and created_at>now()-interval '1 minute')>=6 or exists(select 1 from discovery_private.requests where sender=me and recipient=target.member and created_at>now()-interval '30 seconds')then raise exception 'rate_limit:Wait before sending another request.';end if;
   if(select count(*)from discovery_private.requests where recipient=target.member and status='pending')>=5 then raise exception 'busy:That person has several requests. Try someone else.';end if;
   insert into discovery_private.requests(sender,recipient,target,nonce)values(me,target.member,target.id,(p_input->>'nonce')::uuid)returning *into request_value;
  end if;
  update discovery_private.presence set seen_at=now()where member=me;
 elsif p_action in('accept','decline','cancel')then
  select *into request_value from discovery_private.requests where id=(p_input->>'request_id')::uuid and me in(sender,recipient);
  if request_value.id is null then raise exception 'unavailable:This request is unavailable.';end if;
  if p_action='cancel'and request_value.sender<>me or p_action in('accept','decline')and request_value.recipient<>me then raise exception 'forbidden:This request is not yours to answer.';end if;
  if p_action='accept'then
   if request_value.status='accepted'then select *into s from discovery_private.sessions where request=request_value.id;
   elsif request_value.status<>'pending'or mine.member is null or mine.state<>'waiting'or not discovery_private.eligible(me,request_value.sender)then raise exception 'unavailable:Both people must still be waiting.';
   else
    select *into target from discovery_private.presence where member=request_value.sender and state='waiting'and seen_at>now()-interval '15 seconds';
    if target.member is null or mine.id<>request_value.target then raise exception 'unavailable:Both people must still be waiting.';end if;
    if(select count(*)from discovery_private.sessions where me in(a,b)and created_at>now()-interval '1 day')>=30 or(select count(*)from discovery_private.sessions where request_value.sender in(a,b)and created_at>now()-interval '1 day')>=30 then raise exception 'rate_limit:Today’s video limit is reached.';end if;
    if p_input->>'transport'='direct'and(not mine.allow_direct or not target.allow_direct)then raise exception 'consent:Both people must agree to direct video.';end if;
    insert into discovery_private.sessions(request,a,b,instance_a,instance_b,transport)values(request_value.id,request_value.sender,me,target.instance,mine.instance,p_input->>'transport')returning *into s;
    update discovery_private.presence set state='connecting',seen_at=now()where member in(s.a,s.b);
    update discovery_private.requests set status=case when id=request_value.id then 'accepted'else 'expired'end where status='pending'and(sender in(s.a,s.b)or recipient in(s.a,s.b));
   end if;
  elsif request_value.status='pending'then update discovery_private.requests set status=case when p_action='decline'then 'declined'else 'cancelled'end where id=request_value.id;end if;
 elsif p_action='leave'then
  update discovery_private.sessions set ended_at=coalesce(ended_at,now())where me in(a,b)and ended_at is null;
  delete from discovery_private.presence where member=me;
  perform discovery_private.cleanup(me);
 elsif p_action in('ack','send','signal','media','continue','block','report')then
  select *into s from discovery_private.sessions where id=(p_input->>'session_id')::uuid and me in(a,b)and ended_at is null;
  if s.id is null or mine.member is null or(mine.instance<>case when s.a=me then s.instance_a else s.instance_b end)then raise exception 'ended:This conversation has ended.';end if;
  update discovery_private.presence set seen_at=now()where member=me;
  if p_action='ack'then
   if s.room is null then
    if s.ack_deadline<=now()then raise exception 'ended:The other person did not confirm in time.';end if;
    update discovery_private.sessions set ack_a=ack_a or a=me,ack_b=ack_b or b=me where id=s.id returning *into s;
    if s.ack_a and s.ack_b then
     -- Create signaling identities only after both foreground confirmations.
     select participant into participant_a from random_private.member_links where member=s.a;select participant into participant_b from random_private.member_links where member=s.b;
     update random_private.rooms set ended_at=coalesce(ended_at,now()),end_reason='ended'where(a in(participant_a,participant_b)or b in(participant_a,participant_b))and ended_at is null;
     delete from random_private.queue where participant in(participant_a,participant_b);
     insert into random_private.rooms(a,b,mode)values(participant_a,participant_b,'video')returning id into s.room;
     update discovery_private.sessions set room=s.room where id=s.id;
     update random_private.participants set active_instance=case when id=participant_a then s.instance_a else s.instance_b end,seen_at=now()where id in(participant_a,participant_b);
     update discovery_private.presence set state='connected',seen_at=now()where member in(s.a,s.b);
    end if;
   end if;
  elsif s.room is null then raise exception 'consent:Both people must confirm before connecting.';
  elsif p_action='continue'then
   if s.conversation is null then
    insert into social_private.rooms(kind,title,status,anonymous,requester,meta)values('dm','Discovery conversation','pending',false,me,jsonb_build_object('discovery_session',s.id,'discovery_names',jsonb_build_object(s.a::text,(select username from discovery_private.profiles where member=s.a),s.b::text,(select username from discovery_private.profiles where member=s.b))))returning id into room_id;
    insert into social_private.room_members(room,member,status)values(room_id,me,'accepted'),(room_id,case when s.a=me then s.b else s.a end,'invited');
    insert into social_private.messages(room,author,nonce,body)values(room_id,me,gen_random_uuid(),'I would like to keep chatting.');
    update discovery_private.sessions set conversation=room_id where id=s.id;
   else select id into room_id from social_private.rooms where id=s.conversation and status<>'closed';if room_id is null then raise exception 'unavailable:This request is closed.';end if;end if;
  elsif p_action in('send','signal','block','report')then
   random_result:=public.member_random_before_continue(p_action,p_hash,p_input||jsonb_build_object('room',s.room));
   if random_result?'error'then return random_result;end if;
   if p_action in('block','report')then update discovery_private.sessions set ended_at=now()where id=s.id;delete from discovery_private.presence where member in(s.a,s.b);end if;
  elsif p_action='media'and s.transport='direct'and not mine.allow_direct then raise exception 'consent:Direct video requires your consent.';end if;
 else raise exception 'invalid:Unknown discovery action.';end if;
 perform discovery_private.cleanup(me);
 select *into mine from discovery_private.presence where member=me and instance=instance_value;
 select *into s from discovery_private.sessions where me in(a,b)and(case when a=me then instance_a else instance_b end)=instance_value order by created_at desc limit 1;
 state_value:=case when mine.member is not null then mine.state when s.id is not null then 'ended'else 'idle'end;
 if s.id is not null then select *into peer from discovery_private.profiles where member=case when s.a=me then s.b else s.a end;end if;
 if s.room is not null and s.ended_at is null then random_result:=public.member_random_before_continue('poll',p_hash,p_input||jsonb_build_object('room',s.room));if random_result?'error'then return random_result;end if;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'username',f.username,'tags',f.tags)order by p.entered_at),'[]')into people from(select *from discovery_private.presence where state='waiting'and seen_at>now()-interval '15 seconds'order by entered_at limit 100)p join discovery_private.profiles f on f.member=p.member where p.member<>me and discovery_private.eligible(me,p.member);
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'from',jsonb_build_object('username',f.username,'tags',f.tags),'expires_at',extract(epoch from r.expires_at))order by r.created_at),'[]')into incoming from discovery_private.requests r join discovery_private.profiles f on f.member=r.sender where r.recipient=me and r.status='pending';
 select jsonb_build_object('id',r.id,'to',jsonb_build_object('username',f.username,'tags',f.tags),'expires_at',extract(epoch from r.expires_at))into outgoing from discovery_private.requests r join discovery_private.profiles f on f.member=r.recipient where r.sender=me and r.status='pending'limit 1;
 result:=jsonb_build_object('profile',case when profile.member is not null then jsonb_build_object('username',profile.username,'tags',profile.tags)else null end,'state',state_value,'people',case when mine.state='waiting'then people else '[]'::jsonb end,'incoming',incoming,'outgoing',outgoing,'session',case when s.id is not null then jsonb_build_object('id',s.id,'room',s.room,'peer',jsonb_build_object('username',peer.username,'tags',peer.tags),'initiator',s.a=me,'ends_at',extract(epoch from s.ends_at))else null end,'messages',coalesce(random_result->'messages','[]'),'signals',coalesce(random_result->'signals','[]'),'media_transport',coalesce(s.transport,p_input->>'transport','direct'));
 if room_id is not null then result:=result||jsonb_build_object('continue_room',room_id);end if;
 return result;
exception when unique_violation then return jsonb_build_object('error','That discovery username is already taken.','code','username_taken');when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation or not_null_violation or check_violation then return jsonb_build_object('error','Invalid discovery request.','code','invalid');end $$;
revoke all on function discovery_private.cleanup(uuid)from public,anon,authenticated;grant execute on function discovery_private.cleanup(uuid)to service_role;
-- Every participant-visible projection uses the agreed discovery names.
do $p$declare d text;begin
 d:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 d:=replace(d,'when r.anonymous then ''Anonymous conversation''','when r.meta?''discovery_names''then coalesce((select r.meta->''discovery_names''->>o.member::text from social_private.room_members o where o.room=r.id and o.member<>p_me limit 1),''Discovery conversation'') when r.anonymous then ''Anonymous conversation''');
 d:=replace(d,'case when r.anonymous then ''Them''','case when r.meta?''discovery_names''then coalesce(r.meta->''discovery_names''->>t.member::text,''Former member'') when r.anonymous then ''Them''');execute d;
 d:=pg_get_functiondef('games_private.snapshot(games_private.sessions,uuid,boolean)'::regprocedure);
 d:=replace(d,'case when r.kind=''group''then community_private.display_name(r.id,a.id)','case when r.meta?''discovery_names''then coalesce(r.meta->''discovery_names''->>a.id::text,''Player 1'') when r.kind=''group''then community_private.display_name(r.id,a.id)');
 d:=replace(d,'case when r.kind=''group''then community_private.display_name(r.id,b.id)','case when r.meta?''discovery_names''then coalesce(r.meta->''discovery_names''->>b.id::text,''Player 2'') when r.kind=''group''then community_private.display_name(r.id,b.id)');execute d;
 d:=pg_get_functiondef('social_private.message_list(uuid,text)'::regprocedure);d:=replace(d,'when r.kind=''group''and m.game_session_id is not null','when (r.kind=''group''or r.meta?''discovery_names'')and m.game_session_id is not null');execute d;
end $p$;
