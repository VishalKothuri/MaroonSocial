-- Durable, server-simulated games. Only the authenticated Edge gateway can execute these RPCs.
create schema games_private;
revoke all on schema games_private from public,anon,authenticated;
grant usage on schema games_private to service_role;
create table games_private.sessions(
 id uuid primary key default gen_random_uuid(), room text not null references social_private.rooms on delete cascade,
 kind text not null check(kind in('pool','pong','chess')), rules text not null,
 inviter uuid not null references social_private.members on delete cascade,
 opponent uuid not null references social_private.members on delete cascade,
 invite_nonce uuid not null, status text not null default 'pending' check(status in('pending','active','finished','declined','expired')),
 version bigint not null default 0, state jsonb not null, replay jsonb,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '7 days',
 unique(inviter,invite_nonce),check(inviter<>opponent)
);
create index games_inviter_recent on games_private.sessions(inviter,updated_at desc);
create index games_opponent_recent on games_private.sessions(opponent,updated_at desc);
create index games_room on games_private.sessions(room);
create table games_private.turns(
 session uuid references games_private.sessions on delete cascade, nonce uuid not null, actor uuid not null references social_private.members on delete cascade,
 version bigint not null, input jsonb not null, created_at timestamptz not null default now(),primary key(session,nonce)
);
create index games_turn_actor on games_private.turns(actor);
alter table games_private.sessions enable row level security;
alter table games_private.turns enable row level security;
grant all on all tables in schema games_private to service_role;
create function games_private.snapshot(p_game games_private.sessions,p_me uuid,p_replay boolean default true) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('id',p_game.id,'roomID',p_game.room,'kind',p_game.kind,'rules',p_game.rules,'status',case when p_game.status='pending' and p_game.expires_at<now() then 'expired' else p_game.status end,'version',p_game.version,
 'players',jsonb_build_array(case when r.anonymous then 'Player 1' else a.username end,case when r.anonymous then 'Player 2' else b.username end),
 'yourSeat',case when p_game.inviter=p_me then 0 else 1 end,'state',p_game.state,'replay',case when p_replay then p_game.replay else null end,
 'updatedAt',extract(epoch from p_game.updated_at),'expiresAt',extract(epoch from p_game.expires_at))
 from social_private.members a,social_private.members b,social_private.rooms r where a.id=p_game.inviter and b.id=p_game.opponent and r.id=p_game.room
$$;
create function public.games_gateway(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
declare me uuid; other uuid; g games_private.sessions; prior games_private.turns; room_id text; nonce_id uuid; seat int; result jsonb; code text; msg text;
begin
 me:=social_private.require_member(p_hash);
 if p_action='list' then
  select coalesce(jsonb_agg(games_private.snapshot(s,me,false) order by s.updated_at desc),'[]') into result from
   (select * from games_private.sessions where (inviter=me or opponent=me) and not social_private.blocked(inviter,opponent) order by updated_at desc limit 50)s;
  return jsonb_build_object('games',result);
 elsif p_action='invite' then
  nonce_id:=(p_input->>'nonce')::uuid;
  select * into g from games_private.sessions where inviter=me and invite_nonce=nonce_id;
  if found then return jsonb_build_object('game',games_private.snapshot(g,me));end if;
  room_id:=p_input->>'room';
  if not social_private.can_message(me,room_id) then raise exception 'forbidden:Accept the conversation before inviting someone.';end if;
  if not exists(select 1 from social_private.rooms where id=room_id and kind='dm') then raise exception 'invalid:Start a direct conversation to invite a player.';end if;
  select member into other from social_private.room_members where room=room_id and member<>me and status='accepted' limit 1;
  if other is null or social_private.blocked(me,other) or exists(select 1 from social_private.members where id=other and banned) then raise exception 'forbidden:That player is not available.';end if;
  if (select count(*) from games_private.sessions where inviter=me and created_at>now()-interval '1 day')>=30 or (select count(*) from games_private.sessions where inviter=me and status='pending' and expires_at>now())>=5 then raise exception 'rate_limit:Finish or cancel a pending invitation before starting another.';end if;
  if p_input->>'kind' not in('pool','pong','chess') or p_input->>'rules'<>'maroon-games-2.0.0' or jsonb_typeof(p_input->'state')<>'object' then raise exception 'invalid:Unsupported game.';end if;
  insert into games_private.sessions(room,kind,rules,inviter,opponent,invite_nonce,state)values(room_id,p_input->>'kind',p_input->>'rules',me,other,nonce_id,p_input->'state') returning * into g;
  insert into social_private.messages(room,author,nonce,body,game,game_session_id)values(room_id,me,nonce_id,'Let’s play! Accept this invitation to begin.',case g.kind when 'pool' then '8 Ball' when 'pong' then 'Cup Pong' else 'Chess' end,g.id);
  return jsonb_build_object('game',games_private.snapshot(g,me));
 end if;
 select * into g from games_private.sessions where id=(p_input->>'id')::uuid for update;
 if not found or me not in(g.inviter,g.opponent) then raise exception 'not_found:This match is not available.';end if;
 if social_private.blocked(g.inviter,g.opponent) or exists(select 1 from social_private.members where id in(g.inviter,g.opponent) and banned) then raise exception 'forbidden:This match is no longer available.';end if;
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
revoke all on function games_private.snapshot(games_private.sessions,uuid,boolean),public.games_gateway(text,text,jsonb) from public,anon,authenticated;
grant execute on function games_private.snapshot(games_private.sessions,uuid,boolean),public.games_gateway(text,text,jsonb) to service_role;
