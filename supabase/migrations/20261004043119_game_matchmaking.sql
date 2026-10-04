-- One expiring search per member; games still use the existing authoritative turn gateway.
create table games_private.match_queue (
 member uuid primary key references social_private.members on delete cascade,
 nonce uuid not null, kind text not null check(kind in ('pool','pong','chess')),
 status text not null check(status in ('waiting','matched','cancelled')),
 session uuid references games_private.sessions on delete cascade,
 joined_at timestamptz not null default now(), heartbeat_at timestamptz not null default now(),
 constraint queue_match_session check(status <> 'matched' or session is not null)
);
create index game_queue_waiting on games_private.match_queue(kind,joined_at) where status='waiting';
create index game_queue_session on games_private.match_queue(session) where session is not null;
alter table games_private.match_queue enable row level security;
revoke all on games_private.match_queue from public,anon,authenticated;
grant all on games_private.match_queue to service_role;
create policy game_queue_service on games_private.match_queue to service_role using(true) with check(true);

create function public.games_matchmaking(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare me uuid; q games_private.match_queue; peer games_private.match_queue; g games_private.sessions;
 rid text; requested_nonce uuid; k text; msg text; code text;
begin
 -- All queue mutations take this short lock before account locks, so two joins cannot
 -- assign one waiting player twice or deadlock while creating the two-member room.
 perform pg_advisory_xact_lock(739126481);
 me:=social_private.require_member(p_hash);
 requested_nonce:=(p_input->>'nonce')::uuid;
 if requested_nonce is null then raise exception 'invalid:Missing search identifier.';end if;
 k:=p_input->>'kind';
 if k is null or k not in('pool','pong','chess') then raise exception 'invalid:Choose a supported game.';end if;
 select * into q from games_private.match_queue where member=me for update;
 if p_action='match.cancel' then
  if q.nonce=requested_nonce and q.kind=k and q.status='waiting' then
   update games_private.match_queue set status='cancelled',heartbeat_at=now() where member=me;
   return jsonb_build_object('queue',jsonb_build_object('status','cancelled'));
  end if;
  -- A match may have won the race with Cancel; leave it available in My matches.
  if q.nonce is distinct from requested_nonce or q.kind is distinct from k or q.status<>'matched' then
   return jsonb_build_object('queue',jsonb_build_object('status','cancelled'));
  end if;
 elsif p_action='match.join' then
  if q.nonce is distinct from requested_nonce or q.kind is distinct from k then
   if q.status='waiting' and q.heartbeat_at>now()-interval '45 seconds' then raise exception 'conflict:Cancel your current search first.';end if;
   if exists(select 1 from games_private.sessions s join social_private.rooms r on r.id=s.room where me in(s.inviter,s.opponent) and s.kind=k and s.status='active' and r.meta->>'gameMatchmaking'='true' and not social_private.blocked(s.inviter,s.opponent) and social_private.can_message(s.inviter,s.room) and social_private.can_message(s.opponent,s.room)) then
    select s.* into g from games_private.sessions s join social_private.rooms r on r.id=s.room where me in(s.inviter,s.opponent) and s.kind=k and s.status='active' and r.meta->>'gameMatchmaking'='true' and not social_private.blocked(s.inviter,s.opponent) and social_private.can_message(s.inviter,s.room) and social_private.can_message(s.opponent,s.room) order by s.updated_at desc limit 1;
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
 if p_input->>'rules' is distinct from 'maroon-games-2.1.0' or jsonb_typeof(p_input->'state') is distinct from 'object' or p_input->'state'->>'rules' is distinct from p_input->>'rules' then raise exception 'invalid:Unsupported game rules.';end if;
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
end $$;
revoke all on function public.games_matchmaking(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.games_matchmaking(text,text,jsonb) to service_role;
