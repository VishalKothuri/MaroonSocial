-- Explicit two-player invitations in named group/community rooms. No group autoadmission.
-- Revoke games along with a closed DM or a suspended participant, including match list projections.
create or replace function public.games_gateway(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
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
   if exists(select 1 from social_private.rooms where id=g.room and kind='group')and not exists(select 1 from social_private.members where id=g.opponent and username=lower(btrim(coalesce(p_input->>'opponent_username',''))))then raise exception 'conflict:That invitation already names another player.';end if;
   if not social_private.can_message(g.inviter,g.room)or not social_private.can_message(g.opponent,g.room)or social_private.blocked(g.inviter,g.opponent)or exists(select 1 from social_private.members where id in(g.inviter,g.opponent)and banned)then raise exception 'forbidden:This match is no longer available.';end if;
   return jsonb_build_object('game',games_private.snapshot(g,me));
  end if;
  room_id:=p_input->>'room';
  if not social_private.can_message(me,room_id) then raise exception 'forbidden:Accept the conversation before inviting someone.';end if;
  select kind='group' into named_group from social_private.rooms where id=room_id and (kind='dm'or(kind='group'and not anonymous));
  if not found then raise exception 'invalid:Invite a player from a direct conversation or named group chat.';end if;
  if named_group then
   opponent_name:=lower(btrim(coalesce(p_input->>'opponent_username','')));
   if opponent_name !~ '^[a-z0-9_]{3,20}$' then raise exception 'invalid:Choose a current group member to invite.';end if;
   select rm.member into other from social_private.room_members rm join social_private.members m on m.id=rm.member where rm.room=room_id and rm.member<>me and rm.status='accepted'and m.username=opponent_name;
  else
   select member into other from social_private.room_members where room=room_id and member<>me and status='accepted'limit 1;
  end if;
  if other is null or social_private.blocked(me,other) or exists(select 1 from social_private.members where id=other and banned) then raise exception 'forbidden:That player is not available.';end if;
  if (select count(*) from games_private.sessions where inviter=me and created_at>now()-interval '1 day')>=30 or (select count(*) from games_private.sessions where inviter=me and status='pending' and expires_at>now())>=5 then raise exception 'rate_limit:Finish or cancel a pending invitation before starting another.';end if;
  if p_input->>'kind' not in('pool','pong','chess') or p_input->>'rules'not in('maroon-games-2.0.0','maroon-games-2.1.0') or jsonb_typeof(p_input->'state')<>'object' then raise exception 'invalid:Unsupported game.';end if;
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
end $$;
