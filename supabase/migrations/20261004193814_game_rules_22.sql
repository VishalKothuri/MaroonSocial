-- New 2.2 trajectories apply only to newly created sessions; frozen resolvers retain 2.0/2.1.
CREATE OR REPLACE FUNCTION public.games_gateway(p_action text, p_hash text, p_input jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me uuid; other uuid; g games_private.sessions; prior games_private.turns; room_id text; nonce_id uuid; seat int; named_group boolean; available boolean; opponent_name text; result jsonb; code text; msg text;
begin
 me:=social_private.require_member(p_hash);
 if p_action='list' then
  select coalesce(jsonb_agg(games_private.snapshot(s,me,false) order by s.updated_at desc),'[]') into result from
   (select * from games_private.sessions where (inviter=me or opponent=me) and not social_private.blocked(inviter,opponent) and social_private.can_message(inviter,room) and social_private.can_message(opponent,room) and not exists(select 1 from social_private.members u where u.id in(inviter,opponent) and u.banned) order by updated_at desc limit 50)s;
  return jsonb_build_object('games',result);
 elsif p_action='invite' then
  nonce_id:=(p_input->>'nonce')::uuid;
  select * into g from games_private.sessions where inviter=me and invite_nonce=nonce_id;
  if found then
   if g.room is distinct from p_input->>'room' or g.kind is distinct from p_input->>'kind' then raise exception 'conflict:That invitation identifier was already used.';end if;
   if exists(select 1 from social_private.rooms where id=g.room and kind='group')and not exists(select 1 from community_private.identities where room=g.room and member=g.opponent and member_key=(p_input->>'opponent_member_key')::uuid)then raise exception 'conflict:That invitation already names another player.';end if;
   if not social_private.can_message(g.inviter,g.room)or not social_private.can_message(g.opponent,g.room)or social_private.blocked(g.inviter,g.opponent)or exists(select 1 from social_private.members where id in(g.inviter,g.opponent)and banned)then raise exception 'forbidden:This match is no longer available.';end if;
   return jsonb_build_object('game',games_private.snapshot(g,me));
  end if;
  room_id:=p_input->>'room';
  if not social_private.can_message(me,room_id) then raise exception 'forbidden:Accept the conversation before inviting someone.';end if;
  select kind='group' into named_group from social_private.rooms where id=room_id and (kind='dm'or(kind='group'and not anonymous));
  if not found then raise exception 'invalid:Invite a player from a direct conversation or named group chat.';end if;
  if named_group then
   select rm.member,i.alias into other,opponent_name from social_private.room_members rm join community_private.identities i on i.room=rm.room and i.member=rm.member
   where rm.room=room_id and rm.member<>me and rm.status='accepted'and i.member_key=(p_input->>'opponent_member_key')::uuid;
   if other is null then raise exception 'invalid:Choose a current group member to invite.';end if;
  else
   select member into other from social_private.room_members where room=room_id and member<>me and status='accepted'limit 1;
  end if;
  if other is null or social_private.blocked(me,other) or exists(select 1 from social_private.members where id=other and banned) then raise exception 'forbidden:That player is not available.';end if;
  if (select count(*) from games_private.sessions where inviter=me and created_at>now()-interval '1 day')>=30 or (select count(*) from games_private.sessions where inviter=me and status='pending' and expires_at>now())>=5 then raise exception 'rate_limit:Finish or cancel a pending invitation before starting another.';end if;
  if p_input->>'kind' not in('pool','pong','chess') or p_input->>'rules'not in('maroon-games-2.0.0','maroon-games-2.1.0','maroon-games-2.2.0') or jsonb_typeof(p_input->'state')<>'object' then raise exception 'invalid:Unsupported game.';end if;
  insert into games_private.sessions(room,kind,rules,inviter,opponent,invite_nonce,state)values(room_id,p_input->>'kind',p_input->>'rules',me,other,nonce_id,p_input->'state') returning * into g;
  insert into social_private.messages(room,author,nonce,body,game,game_session_id)values(room_id,me,nonce_id,case when named_group then '@'||opponent_name||' — game invitation. Accept to begin.'else 'Let’s play! Accept this invitation to begin.'end,case g.kind when 'pool' then '8 Ball' when 'pong' then 'Cup Pong' else 'Chess' end,g.id);
  return jsonb_build_object('game',games_private.snapshot(g,me));
 end if;
 if p_action='card'then
  select *into g from games_private.sessions where id=(p_input->>'id')::uuid;
  if not found or not social_private.can_read_room(me,g.room)or social_private.blocked(me,g.inviter)then raise exception 'not_found:This invitation is unavailable.';end if;
  available:=social_private.can_message(g.inviter,g.room)and social_private.can_message(g.opponent,g.room)and not social_private.blocked(g.inviter,g.opponent)and not exists(select 1 from social_private.members where id in(g.inviter,g.opponent)and banned);
  return jsonb_build_object('invitation',jsonb_build_object('id',g.id,'kind',g.kind,'players',games_private.snapshot(g,me,false)->'players',
  'status',case when not available then 'unavailable'when g.status='pending'and g.expires_at<now()then 'expired'else g.status end,'canOpen',me in(g.inviter,g.opponent)and available));
 end if;
 select * into g from games_private.sessions where id=(p_input->>'id')::uuid for update;
 if not found or me not in(g.inviter,g.opponent) then raise exception 'not_found:This match is not available.';end if;
 if social_private.blocked(g.inviter,g.opponent) or exists(select 1 from social_private.members where id in(g.inviter,g.opponent) and banned) or not social_private.can_message(g.inviter,g.room) or not social_private.can_message(g.opponent,g.room) then raise exception 'forbidden:This match is no longer available.';end if;
 seat:=case when me=g.inviter then 0 else 1 end;
 if g.status='pending' and g.expires_at<now() then update games_private.sessions set status='expired',updated_at=now() where id=g.id returning * into g;end if;
 if p_action='get' then return jsonb_build_object('game',games_private.snapshot(g,me));
 elsif p_action in('accept','decline','cancel') then
  if g.status<>'pending' then raise exception 'conflict:This invitation is no longer pending.';end if;
  if (p_action='cancel' and seat<>0) or (p_action<>'cancel' and seat<>1) then raise exception 'forbidden:Only the invited player can respond.';end if;
  if p_action='accept' and (not social_private.can_message(me,g.room) or not social_private.can_message(g.inviter,g.room)) then raise exception 'forbidden:The conversation must still be active.';end if;
  update games_private.sessions set status=case when p_action='accept' then 'active' else 'declined' end,version=version+1,updated_at=now() where id=g.id returning * into g;
 elsif p_action='forfeit' then
  if g.status<>'active' then raise exception 'conflict:This match is not active.';end if;
  update games_private.sessions set status='finished',state=state||jsonb_build_object('winner',1-seat,'finished',true,'status','Player '||(2-seat)::text||' wins by resignation.'),version=version+1,replay=null,updated_at=now() where id=g.id returning * into g;
 elsif p_action in('prepare','commit') then
  nonce_id:=(p_input->>'nonce')::uuid;
  select * into prior from games_private.turns where session=g.id and nonce=nonce_id;
  if found then
   if prior.actor<>me or prior.input is distinct from p_input->'input' then raise exception 'conflict:That turn identifier is already in use.';end if;
   return jsonb_build_object('game',games_private.snapshot(g,me),'duplicate',true);
  end if;
  if g.status<>'active' then raise exception 'conflict:This match is not active.';end if;
  if (g.state->>'turn')::int<>seat then raise exception 'turn:Wait for the other player’s turn.';end if;
  if g.version<>(p_input->>'version')::bigint then raise exception 'conflict:The match changed. Refresh and try again.';end if;
  if p_action='prepare' then return jsonb_build_object('game',games_private.snapshot(g,me));end if;
  if jsonb_typeof(p_input->'state')<>'object' or p_input->'state'->>'rules'<>g.rules or (p_input->'state'->>'shots')::int<>(g.state->>'shots')::int+1 then raise exception 'invalid:Invalid canonical state.';end if;
  insert into games_private.turns(session,nonce,actor,version,input)values(g.id,nonce_id,me,g.version+1,p_input->'input');
  update games_private.sessions set state=p_input->'state',replay=p_input->'replay',version=version+1,status=case when p_input->'state'->>'winner' is not null or coalesce((p_input->'state'->>'finished')::bool,false) then 'finished' else 'active' end,updated_at=now() where id=g.id returning * into g;
 else raise exception 'invalid:Unknown game action.';
 end if;
 return jsonb_build_object('game',games_private.snapshot(g,me));
exception when others then
 msg:=sqlerrm;code:=split_part(msg,':',1);
 if code not in('unauthorized','forbidden','not_found','invalid','conflict','rate_limit','turn') then code:='invalid';msg:='invalid:The game request could not be processed.';end if;
 return jsonb_build_object('error',substring(msg from position(':' in msg)+1),'code',code);
end $function$
;
CREATE OR REPLACE FUNCTION public.games_matchmaking(p_action text, p_hash text, p_input jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare me uuid; q games_private.match_queue; peer games_private.match_queue; g games_private.sessions;
 rid text; requested_nonce uuid; k text; msg text; code text;
begin
 -- All queue mutations take this short lock before account locks, so two joins cannot
 -- assign one waiting player twice or deadlock while creating the two-member room.
 -- Reject unavailable credentials without taking the shared matchmaking lock.
 -- require_member below still revalidates under its account lock; this preflight
 -- never changes the global-before-account lock order.
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' or not exists(select 1 from social_private.members where token_hash=p_hash) then
  raise exception 'unauthorized:Your account credential is unavailable.';
 end if;
 if exists(select 1 from social_private.members where token_hash=p_hash and banned) then
  raise exception 'forbidden:This account is suspended.';
 end if;
 perform pg_advisory_xact_lock(739126481);
 me:=social_private.require_member(p_hash);
 requested_nonce:=(p_input->>'nonce')::uuid;
 if requested_nonce is null then raise exception 'invalid:Missing search identifier.';end if;
 k:=p_input->>'kind';
 if k is null or k not in('pool','pong','chess') then raise exception 'invalid:Choose a supported game.';end if;
 update games_private.match_queue set status='cancelled' where status='waiting' and heartbeat_at<now()-interval '45 seconds';
 select * into q from games_private.match_queue where member=me for update;
 delete from games_private.cancelled_searches where created_at<now()-interval '1 day';
 if p_action='match.cancel' then
  insert into games_private.cancelled_searches(member,nonce)values(me,requested_nonce)on conflict do nothing;
  if q.nonce=requested_nonce and q.kind=k and q.status='waiting' then
   update games_private.match_queue set status='cancelled',heartbeat_at=now() where member=me;
   return jsonb_build_object('queue',jsonb_build_object('status','cancelled'));
  end if;
  -- A match may have won the race with Cancel; leave it available in My matches.
  if q.nonce is distinct from requested_nonce or q.kind is distinct from k or q.status<>'matched' then
   return jsonb_build_object('queue',jsonb_build_object('status','cancelled'));
  end if;
 elsif p_action='match.join' then
  if exists(select 1 from games_private.cancelled_searches where member=me and nonce=requested_nonce) then
   return jsonb_build_object('queue',jsonb_build_object('status','cancelled'));
  end if;
  if q.nonce is distinct from requested_nonce or q.kind is distinct from k then
   if q.status='waiting' and q.heartbeat_at>now()-interval '45 seconds' then raise exception 'conflict:Cancel your current search first.';end if;
   if exists(select 1 from games_private.sessions s join social_private.rooms r on r.id=s.room where me in(s.inviter,s.opponent) and s.kind=k and s.status='active' and r.meta->>'gameMatchmaking'='true' and not exists(select 1 from social_private.members suspended where suspended.id in(s.inviter,s.opponent) and suspended.banned) and not social_private.blocked(s.inviter,s.opponent) and social_private.can_message(s.inviter,s.room) and social_private.can_message(s.opponent,s.room)) then
    select s.* into g from games_private.sessions s join social_private.rooms r on r.id=s.room where me in(s.inviter,s.opponent) and s.kind=k and s.status='active' and r.meta->>'gameMatchmaking'='true' and not exists(select 1 from social_private.members suspended where suspended.id in(s.inviter,s.opponent) and suspended.banned) and not social_private.blocked(s.inviter,s.opponent) and social_private.can_message(s.inviter,s.room) and social_private.can_message(s.opponent,s.room) order by s.updated_at desc limit 1;
    return jsonb_build_object('game',games_private.snapshot(g,me),'queue',jsonb_build_object('status','matched'));
   end if;
   if (select count(*) from games_private.sessions where (inviter=me or opponent=me) and created_at>now()-interval '1 day')>=30 then raise exception 'rate_limit:You’ve reached today’s new-match limit.';end if;
   insert into games_private.match_queue(member,nonce,kind,status)values(me,requested_nonce,k,'waiting')
   on conflict(member) do update set nonce=excluded.nonce,kind=excluded.kind,status='waiting',session=null,joined_at=now(),heartbeat_at=now() returning * into q;
  end if;
 elsif p_action<>'match.status' then raise exception 'invalid:Unknown matchmaking action.';
 end if;
 if q.member is null or q.nonce is distinct from requested_nonce or q.kind is distinct from k then
  return jsonb_build_object('queue',jsonb_build_object('status','expired'));
 end if;
 if q.status='matched' then
  select * into g from games_private.sessions where id=q.session;
  if g.id is null or social_private.blocked(g.inviter,g.opponent) or not social_private.can_message(g.inviter,g.room) or not social_private.can_message(g.opponent,g.room) or exists(select 1 from social_private.members where id in(g.inviter,g.opponent) and banned) then raise exception 'forbidden:This match is no longer available.';end if;
  return jsonb_build_object('game',games_private.snapshot(g,me),'queue',jsonb_build_object('status','matched'));
 end if;
 if q.status<>'waiting' or q.heartbeat_at<now()-interval '45 seconds' then
  update games_private.match_queue set status='cancelled' where member=me;
  return jsonb_build_object('queue',jsonb_build_object('status','expired'));
 end if;
 update games_private.match_queue set heartbeat_at=now() where member=me;
 if p_input->>'rules' not in ('maroon-games-2.1.0','maroon-games-2.2.0') or jsonb_typeof(p_input->'state') is distinct from 'object' or p_input->'state'->>'rules' is distinct from p_input->>'rules' then raise exception 'invalid:Unsupported game rules.';end if;
 select candidate.* into peer from games_private.match_queue candidate join social_private.members m on m.id=candidate.member
 where candidate.member<>me and candidate.kind=k and candidate.status='waiting' and candidate.heartbeat_at>now()-interval '45 seconds'
 and not m.banned and not social_private.blocked(me,m.id)
 and (not(select require_verified from verification_private.settings where id) or exists(select 1 from verification_private.memberships v where v.member=m.id and v.expires_at>now()))
 and (select count(*) from games_private.sessions s where (s.inviter=m.id or s.opponent=m.id) and s.created_at>now()-interval '1 day')<30
 order by candidate.joined_at,candidate.member limit 1 for update of candidate;
 if peer.member is null then return jsonb_build_object('queue',jsonb_build_object('status','waiting'));end if;
 insert into social_private.rooms(kind,title,anonymous,meta)values('dm',case k when 'pool' then '8 Ball match' when 'pong' then 'Cup Pong match' else 'Chess match' end,true,jsonb_build_object('gameMatchmaking',true)) returning id into rid;
 insert into social_private.room_members(room,member)values(rid,peer.member),(rid,me);
 insert into games_private.sessions(room,kind,rules,inviter,opponent,invite_nonce,state,status)
 values(rid,k,p_input->>'rules',peer.member,me,gen_random_uuid(),p_input->'state','active') returning * into g;
 update games_private.match_queue set status='matched',session=g.id,heartbeat_at=now() where member in(me,peer.member);
 insert into social_private.messages(room,author,nonce,body,game,game_session_id)
 values(rid,peer.member,gen_random_uuid(),'Matched for a game. Take turns and play at your own pace.',case k when 'pool' then '8 Ball' when 'pong' then 'Cup Pong' else 'Chess' end,g.id);
 return jsonb_build_object('game',games_private.snapshot(g,me),'queue',jsonb_build_object('status','matched'));
exception when others then
 msg:=sqlerrm;code:=split_part(msg,':',1);
 if code not in('unauthorized','verification_required','forbidden','not_found','invalid','conflict','rate_limit') then code:='invalid';msg:='invalid:The search could not be processed.';end if;
 return jsonb_build_object('error',substring(msg from position(':' in msg)+1),'code',code);
end $function$
;
