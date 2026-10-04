-- GPL web pool stays separate from native 2.x state, replays and queues.
create schema web_pool_private;
revoke all on schema web_pool_private from public,anon,authenticated;
grant usage on schema web_pool_private to service_role;
create table web_pool_private.browser_sessions(
 token_hash text primary key check(token_hash~'^[a-f0-9]{64}$'),member uuid not null references social_private.members on delete cascade,
 origin_hash text not null,auth_id uuid,auth_session uuid,
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '1 hour'
);
create index web_pool_browser_member on web_pool_private.browser_sessions(member);
create table web_pool_private.games(
 id uuid primary key default gen_random_uuid(),a uuid not null references social_private.members on delete cascade,b uuid not null references social_private.members on delete cascade,
 state jsonb not null,replay jsonb,version bigint not null default 0,status text not null default 'active'check(status in('active','finished')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(a<>b)
);
create index web_pool_games_a on web_pool_private.games(a,updated_at desc);
create index web_pool_games_b on web_pool_private.games(b,updated_at desc);
create table web_pool_private.queue(
 member uuid primary key references social_private.members on delete cascade,nonce uuid not null,
 game uuid references web_pool_private.games on delete cascade,status text not null check(status in('waiting','matched','cancelled')),
 created_at timestamptz not null default now(),seen_at timestamptz not null default now()
);
create index web_pool_queue_game on web_pool_private.queue(game);
create index web_pool_queue_waiting on web_pool_private.queue(created_at)where status='waiting';
create table web_pool_private.turns(
 game uuid references web_pool_private.games on delete cascade,nonce uuid not null,actor uuid not null references social_private.members on delete cascade,input jsonb not null,
 primary key(game,nonce)
);
create index web_pool_turn_actor on web_pool_private.turns(actor);
alter table web_pool_private.browser_sessions enable row level security;
alter table web_pool_private.games enable row level security;
alter table web_pool_private.queue enable row level security;
alter table web_pool_private.turns enable row level security;
revoke all on all tables in schema web_pool_private from public,anon,authenticated;
grant all on all tables in schema web_pool_private to service_role;
create policy web_pool_browser_service on web_pool_private.browser_sessions to service_role using(true)with check(true);
create policy web_pool_games_service on web_pool_private.games to service_role using(true)with check(true);
create policy web_pool_queue_service on web_pool_private.queue to service_role using(true)with check(true);
create policy web_pool_turn_service on web_pool_private.turns to service_role using(true)with check(true);
create function public.web_pool_session(p_hash text,p_scope_hash text,p_action text,p_auth_id uuid default null,p_auth_session uuid default null)returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;
begin
 me:=social_private.require_member(p_hash);
 if p_action='revoke'then delete from web_pool_private.browser_sessions where token_hash=p_scope_hash and member=me;return '{"revoked":true}'::jsonb;end if;
 if p_action<>'create'or p_scope_hash !~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid browser session.';end if;
 delete from web_pool_private.browser_sessions where expires_at<now()or(member=me and created_at<now()-interval '50 minutes');
 if(select count(*)from web_pool_private.browser_sessions where member=me)>=5 then raise exception 'rate_limit:Close another pool window first.';end if;
 insert into web_pool_private.browser_sessions(token_hash,member,origin_hash,auth_id,auth_session)values(p_scope_hash,me,p_hash,p_auth_id,p_auth_session);
 return jsonb_build_object('expiresAt',extract(epoch from now()+interval '1 hour'));
end $$;
create function web_pool_private.snapshot(g web_pool_private.games,me uuid)returns jsonb language sql stable security invoker set search_path=''as $$
 select jsonb_build_object('id',g.id,'rules','maroon-web-pool-3.0.0','status',g.status,'yourSeat',case when g.a=me then 0 else 1 end,
 'players',jsonb_build_array('Player 1','Player 2'),'version',g.version,'state',g.state,'replay',g.replay,'updatedAt',extract(epoch from g.updated_at))
$$;
create function public.web_pool_gateway(p_action text,p_scope_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid; member_hash text; origin_auth uuid; origin_session uuid; auth_result jsonb; g web_pool_private.games; q web_pool_private.queue; peer web_pool_private.queue; oldturn web_pool_private.turns; seat int; request_nonce uuid; msg text; code text;
begin
 select m.id,s.origin_hash,s.auth_id,s.auth_session into me,member_hash,origin_auth,origin_session from web_pool_private.browser_sessions s join social_private.members m on m.id=s.member where s.token_hash=p_scope_hash and s.expires_at>now();
 if me is null then raise exception 'unauthorized:Reopen pool in the app to refresh your game session.';end if;
 if origin_auth is not null then
  auth_result:=public.social_auth_bridge('resolve',origin_auth,origin_session,'{}');
  if auth_result->>'state' is distinct from 'linked'or auth_result->>'token_hash' is distinct from member_hash then raise exception 'unauthorized:Reopen pool in the app.';end if;
 end if;
 perform social_private.require_member(member_hash);
 if p_action='active'then
  select *into g from web_pool_private.games where me in(a,b)and status='active'and not social_private.blocked(a,b)and not exists(select 1 from social_private.members m where m.id in(a,b)and m.banned)order by updated_at desc limit 1;
  return case when g.id is null then '{}'::jsonb else jsonb_build_object('game',web_pool_private.snapshot(g,me))end;
 end if;
 if p_action in('join','poll_queue','cancel')then
  perform pg_advisory_xact_lock(739126483);
  request_nonce:=(p_input->>'nonce')::uuid;
  if request_nonce is null then raise exception 'invalid:Missing search identifier.';end if;
  select *into q from web_pool_private.queue where member=me for update;
  if p_action='cancel'then
   if q.nonce=request_nonce and q.status='waiting'then update web_pool_private.queue set status='cancelled'where member=me;q.status:='cancelled';end if;
   if q.nonce is distinct from request_nonce or q.status<>'matched'then return '{"queue":"cancelled"}'::jsonb;end if;
  elsif p_action='join'and q.nonce is distinct from request_nonce then
   select *into g from web_pool_private.games where me in(a,b)and status='active'and not social_private.blocked(a,b)and not exists(select 1 from social_private.members m where m.id in(a,b)and m.banned)order by updated_at desc limit 1;
   if g.id is not null then return jsonb_build_object('game',web_pool_private.snapshot(g,me),'queue','matched');end if;
   if q.status='waiting'and q.seen_at>now()-interval '45 seconds'then raise exception 'conflict:Cancel your current search first.';end if;
   if(select count(*)from web_pool_private.games where me in(a,b)and created_at>now()-interval '1 day')>=30 then raise exception 'rate_limit:You have reached today’s new-match limit.';end if;
   insert into web_pool_private.queue(member,nonce,status)values(me,request_nonce,'waiting')on conflict(member)do update set nonce=excluded.nonce,status='waiting',game=null,created_at=now(),seen_at=now()returning *into q;
  end if;
  if q.member is null or q.nonce is distinct from request_nonce then return '{"queue":"expired"}'::jsonb;end if;
  if q.status='matched'then select *into g from web_pool_private.games where id=q.game;
  elsif q.status<>'waiting'or q.seen_at<now()-interval '45 seconds'then update web_pool_private.queue set status='cancelled'where member=me;return '{"queue":"expired"}'::jsonb;
  else
   update web_pool_private.queue set seen_at=now()where member=me;
   if p_input->'state'->>'rules' is distinct from 'maroon-web-pool-3.0.0'then raise exception 'invalid:Unsupported pool version.';end if;
   select candidate.*into peer from web_pool_private.queue candidate join social_private.members m on m.id=candidate.member
    where candidate.member<>me and candidate.status='waiting'and candidate.seen_at>now()-interval '45 seconds'and not m.banned and not social_private.blocked(me,m.id)
    and(not(select require_verified from verification_private.settings where id)or exists(select 1 from verification_private.memberships v where v.member=m.id and v.expires_at>now()))
    and(select count(*)from web_pool_private.games where m.id in(a,b)and created_at>now()-interval '1 day')<30
    order by candidate.created_at limit 1 for update of candidate;
   if peer.member is null then return '{"queue":"waiting"}'::jsonb;end if;
   insert into web_pool_private.games(a,b,state)values(peer.member,me,p_input->'state')returning *into g;
   update web_pool_private.queue set status='matched',game=g.id,seen_at=now()where member in(me,peer.member);
  end if;
 else select *into g from web_pool_private.games where id=(p_input->>'id')::uuid for update;
 end if;
 if g.id is null or me not in(g.a,g.b)then raise exception 'not_found:This match is not available.';end if;
 if social_private.blocked(g.a,g.b)or exists(select 1 from social_private.members m where m.id in(g.a,g.b)and m.banned)then raise exception 'forbidden:This match is no longer available.';end if;
 seat:=case when g.a=me then 0 else 1 end;
 if p_action='forfeit'then
  if g.status='active'then update web_pool_private.games set status='finished',version=version+1,replay=null,updated_at=now(),state=state||jsonb_build_object('winner',1-seat,'finished',true,'status','Player '||(2-seat)::text||' wins by resignation.')where id=g.id returning *into g;end if;
 elsif p_action in('prepare','commit')then
  request_nonce:=(p_input->>'nonce')::uuid;
  if request_nonce is null then raise exception 'invalid:Missing turn identifier.';end if;
  select *into oldturn from web_pool_private.turns where game=g.id and nonce=request_nonce;
  if found then
   if oldturn.actor<>me or oldturn.input is distinct from p_input->'input'then raise exception 'conflict:This turn identifier is already used.';end if;
   return jsonb_build_object('game',web_pool_private.snapshot(g,me),'duplicate',true);
  end if;
  if g.status<>'active'then raise exception 'conflict:This game is finished.';end if;
  if(g.state->>'turn')::int<>seat then raise exception 'turn:Wait for your opponent.';end if;
  if g.version is distinct from(p_input->>'version')::bigint then raise exception 'conflict:The game changed. Refresh and retry.';end if;
  if p_action='commit'then
   if p_input->'state'->>'rules' is distinct from 'maroon-web-pool-3.0.0'or(p_input->'state'->>'shots')::int is distinct from(g.state->>'shots')::int+1 then raise exception 'invalid:Invalid canonical state.';end if;
   insert into web_pool_private.turns(game,nonce,actor,input)values(g.id,request_nonce,me,p_input->'input');
   update web_pool_private.games set state=p_input->'state',replay=p_input->'replay',version=version+1,updated_at=now(),status=case when p_input->'state'->>'winner' is not null then 'finished'else 'active'end where id=g.id returning *into g;
  end if;
 elsif p_action not in('join','poll_queue','cancel','get')then raise exception 'invalid:Unknown pool action.';
 end if;
 return jsonb_build_object('game',web_pool_private.snapshot(g,me),'queue','matched');
exception when others then
 msg:=sqlerrm;code:=split_part(msg,':',1);if code not in('unauthorized','verification_required','forbidden','not_found','invalid','conflict','rate_limit','turn')then code:='invalid';msg:='invalid:This pool action could not be processed.';end if;
 return jsonb_build_object('error',substring(msg from position(':'in msg)+1),'code',code);
end $$;
revoke all on function public.web_pool_session(text,text,text,uuid,uuid),public.web_pool_gateway(text,text,jsonb),web_pool_private.snapshot(web_pool_private.games,uuid)from public,anon,authenticated;
grant execute on function public.web_pool_session(text,text,text,uuid,uuid),public.web_pool_gateway(text,text,jsonb),web_pool_private.snapshot(web_pool_private.games,uuid)to service_role;

-- Bounded private retention. Leaving the browser cancels its queue; stale queues
-- expire regardless. A week without a turn ends an abandoned match as a draw.
create function web_pool_private.cleanup()returns void language plpgsql security invoker set search_path=''as $$
begin
 delete from web_pool_private.browser_sessions where expires_at<now();
 delete from web_pool_private.queue where seen_at<now()-interval '1 day';
 update web_pool_private.games set status='finished',version=version+1,replay=null,state=state||'{"finished":true,"status":"Match expired after seven days without a turn."}'::jsonb where status='active'and updated_at<now()-interval '7 days';
 delete from web_pool_private.games where updated_at<now()-interval '30 days';
end $$;
revoke all on function web_pool_private.cleanup()from public,anon,authenticated;
grant execute on function web_pool_private.cleanup()to service_role;
select cron.schedule('web-pool-retention','13 * * * *','select web_pool_private.cleanup()');
