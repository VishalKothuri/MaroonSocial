create table web_pool_private.cancelled_searches(member uuid not null references social_private.members on delete cascade,nonce uuid not null,created_at timestamptz not null default now(),primary key(member,nonce));
alter table web_pool_private.cancelled_searches enable row level security;
revoke all on web_pool_private.cancelled_searches from public,anon,authenticated;
grant all on web_pool_private.cancelled_searches to service_role;
create policy web_pool_cancelled_service on web_pool_private.cancelled_searches to service_role using(true)with check(true);
create or replace function public.web_pool_gateway(p_action text,p_scope_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
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
   insert into web_pool_private.cancelled_searches(member,nonce)values(me,request_nonce)on conflict do nothing;
   if q.nonce=request_nonce and q.status='waiting'then update web_pool_private.queue set status='cancelled'where member=me;q.status:='cancelled';end if;
   if q.nonce is distinct from request_nonce or q.status<>'matched'then return '{"queue":"cancelled"}'::jsonb;end if;
  elsif p_action='join'and exists(select 1 from web_pool_private.cancelled_searches where member=me and nonce=request_nonce)then return '{"queue":"cancelled"}'::jsonb;
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
create or replace function public.web_pool_session(p_hash text,p_scope_hash text,p_action text,p_auth_id uuid default null,p_auth_session uuid default null)returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;
begin
 me:=social_private.require_member(p_hash);
 if p_action='revoke'then if exists(select 1 from web_pool_private.browser_sessions where token_hash=p_scope_hash and member=me)then update web_pool_private.queue set status='cancelled'where member=me and status='waiting';end if;delete from web_pool_private.browser_sessions where token_hash=p_scope_hash and member=me;return '{"revoked":true}'::jsonb;end if;
 if p_action<>'create'or p_scope_hash !~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid browser session.';end if;
 delete from web_pool_private.browser_sessions where expires_at<now()or(member=me and created_at<now()-interval '50 minutes');
 if(select count(*)from web_pool_private.browser_sessions where member=me)>=5 then raise exception 'rate_limit:Close another pool window first.';end if;
 insert into web_pool_private.browser_sessions(token_hash,member,origin_hash,auth_id,auth_session)values(p_scope_hash,me,p_hash,p_auth_id,p_auth_session);
 return jsonb_build_object('expiresAt',extract(epoch from now()+interval '1 hour'));
end $$;
create or replace function web_pool_private.cleanup()returns void language plpgsql security invoker set search_path=''as $$
begin
 delete from web_pool_private.cancelled_searches where created_at<now()-interval '1 day';
 delete from web_pool_private.browser_sessions where expires_at<now();
 delete from web_pool_private.queue where seen_at<now()-interval '1 day';
 update web_pool_private.games set status='finished',version=version+1,replay=null,state=state||'{"finished":true,"status":"Match expired after seven days without a turn."}'::jsonb where status='active'and updated_at<now()-interval '7 days';
 delete from web_pool_private.games where updated_at<now()-interval '30 days';
end $$;
