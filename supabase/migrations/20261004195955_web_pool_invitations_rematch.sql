-- New pool invitations and rematches use the isolated 3.0 engine. Historical 2.x tables stay untouched.
alter table web_pool_private.games drop constraint games_status_check;
alter table web_pool_private.games add constraint games_status_check check(status in('pending','active','finished','declined','expired'));
alter table web_pool_private.games add column room text references social_private.rooms(id)on delete cascade,
 add column invite_nonce uuid,add column rematch_of uuid references web_pool_private.games(id)on delete set null,
 add column expires_at timestamptz not null default now()+interval '1 day';
create unique index web_pool_invite_nonce on web_pool_private.games(a,invite_nonce)where invite_nonce is not null;
create unique index web_pool_rematch_parent on web_pool_private.games(rematch_of)where rematch_of is not null;
create index web_pool_room on web_pool_private.games(room)where room is not null;
create function web_pool_private.available(g web_pool_private.games)returns boolean language sql stable security invoker set search_path=''as $$
 select not social_private.blocked(g.a,g.b)and not exists(select 1 from social_private.members where id in(g.a,g.b)and banned)
 and(g.room is null or(social_private.can_message(g.a,g.room)and social_private.can_message(g.b,g.room)))
$$;
create function web_pool_private.player_name(g web_pool_private.games,person uuid)returns text language sql stable security invoker set search_path=''as $$
 select case when g.room is null then 'Player '||case when person=g.a then '1'else '2'end
 when r.anonymous then 'Player '||case when person=g.a then '1'else '2'end
 when r.meta?'discovery_names'then coalesce(r.meta->'discovery_names'->>person::text,'Former member')
 when r.kind='group'then community_private.display_name(g.room,person)
 else coalesce((select username from social_private.members where id=person),'Former member')end
 from (select 1)one left join social_private.rooms r on r.id=g.room
$$;
create or replace function web_pool_private.snapshot(g web_pool_private.games,me uuid)returns jsonb language sql stable security invoker set search_path=''as $$
 select jsonb_build_object('id',g.id,'roomID',coalesce(g.room,''),'kind','pool','rules','maroon-web-pool-3.0.0',
 'status',case when g.status='pending'and g.expires_at<=now()then 'expired'else g.status end,'yourSeat',case when g.a=me then 0 else 1 end,
 'players',jsonb_build_array(web_pool_private.player_name(g,g.a),web_pool_private.player_name(g,g.b)),
 'version',g.version,'state',g.state,'replay',g.replay,'updatedAt',extract(epoch from g.updated_at),'expiresAt',extract(epoch from g.expires_at),
 'rematch',(select jsonb_build_object('id',r.id,'status',case when r.status='pending'and r.expires_at<=now()then 'expired'else r.status end,'yourSeat',case when r.a=me then 0 else 1 end)from web_pool_private.games r where r.rematch_of=g.id))
$$;
create function web_pool_private.invite_limit(me uuid)returns void language plpgsql security invoker set search_path=''as $$begin
 if(select count(*)from web_pool_private.games where a=me and created_at>now()-interval '1 day')>=30 or(select count(*)from web_pool_private.games where a=me and status='pending'and expires_at>now())>=5 then raise exception 'rate_limit:Finish or cancel an invitation before starting another.';end if;
end $$;
create function web_pool_private.action(p_action text,me uuid,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare g web_pool_private.games;parent_game web_pool_private.games;q web_pool_private.queue;peer web_pool_private.queue;oldturn web_pool_private.turns;seat int;request_nonce uuid;msg text;code text;room_id text;other uuid;named_group boolean;result jsonb;
begin
 if p_action='list'then
  select coalesce(jsonb_agg(web_pool_private.snapshot(s,me)-'replay'order by s.updated_at desc),'[]')into result from(select *from web_pool_private.games where me in(a,b)and web_pool_private.available(games)order by updated_at desc limit 50)s;
  return jsonb_build_object('games',result);
 elsif p_action='invite'then
  request_nonce:=(p_input->>'nonce')::uuid;room_id:=p_input->>'room';
  if request_nonce is null then raise exception 'invalid:Missing invitation identifier.';end if;
  if not social_private.can_message(me,room_id)then raise exception 'forbidden:Accept the conversation before inviting someone.';end if;
  select kind='group'into named_group from social_private.rooms where id=room_id and(kind='dm'or(kind='group'and not anonymous));
  if not found then raise exception 'invalid:Invite a player from a direct conversation or group.';end if;
  if named_group then
   select rm.member into other from social_private.room_members rm join community_private.identities i on i.room=rm.room and i.member=rm.member where rm.room=room_id and rm.member<>me and rm.status='accepted'and i.member_key=(p_input->>'opponent_member_key')::uuid;
   if other is null then raise exception 'invalid:Choose a current group member to invite.';end if;
  else select member into other from social_private.room_members where room=room_id and member<>me and status='accepted'limit 1;end if;
  if other is null or not social_private.can_message(other,room_id)or social_private.blocked(me,other)or exists(select 1 from social_private.members where id=other and banned)then raise exception 'forbidden:That player is unavailable.';end if;
  select *into g from web_pool_private.games where a=me and invite_nonce=request_nonce;
  if g.id is not null then
   if g.room is distinct from room_id or g.b<>other or g.rematch_of is not null then raise exception 'conflict:That invitation identifier is already used.';end if;
  else
   perform web_pool_private.invite_limit(me);
   if p_input->'state'->>'rules'is distinct from 'maroon-web-pool-3.0.0'then raise exception 'invalid:Unsupported pool version.';end if;
   insert into web_pool_private.games(a,b,room,state,status,invite_nonce)values(me,other,room_id,p_input->'state','pending',request_nonce)returning *into g;
   insert into social_private.messages(room,author,nonce,body,game,game_session_id)values(room_id,me,request_nonce,'Pool invitation. Accept to start.','8 Ball',g.id);
  end if;
  return jsonb_build_object('game',web_pool_private.snapshot(g,me));
 elsif p_action='card'then
  select *into g from web_pool_private.games where id=(p_input->>'id')::uuid;
  if g.id is null or g.room is null or not social_private.can_read_room(me,g.room)or social_private.blocked(me,g.a)or social_private.blocked(me,g.b)then raise exception 'not_found:This invitation is unavailable.';end if;
  return jsonb_build_object('invitation',jsonb_build_object('id',g.id,'kind','pool','players',jsonb_build_array(web_pool_private.player_name(g,g.a),web_pool_private.player_name(g,g.b)),
  'status',case when not web_pool_private.available(g)then 'unavailable'when g.status='pending'and g.expires_at<=now()then 'expired'else g.status end,'canOpen',me in(g.a,g.b)and web_pool_private.available(g)));
 end if;
 if p_action='active'then
  select *into g from web_pool_private.games where me in(a,b)and status in('active','pending')and (status<>'pending'or expires_at>now())and web_pool_private.available(games)order by (status='active')desc,updated_at desc limit 1;
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
   select *into g from web_pool_private.games where me in(a,b)and status='active'and web_pool_private.available(games)order by updated_at desc limit 1;
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
 if not web_pool_private.available(g)then raise exception 'forbidden:This match is no longer available.';end if;
 seat:=case when g.a=me then 0 else 1 end;
 if g.status='pending'and g.expires_at<=now()then update web_pool_private.games set status='expired',version=version+1,updated_at=now()where id=g.id returning *into g;end if;
 if p_action in('accept','decline','cancel_invite')then
  if(p_action='cancel_invite'and seat<>0)or(p_action<>'cancel_invite'and seat<>1)then raise exception 'forbidden:Only the invited player can respond.';end if;
  if g.status='pending'then
   update web_pool_private.games set status=case when p_action='accept'then 'active'else 'declined'end,version=version+1,updated_at=now()where id=g.id returning *into g;
   if p_action='accept'then update web_pool_private.queue set status='cancelled'where member in(g.a,g.b)and status='waiting';end if;
  elsif not(p_action='accept'and g.status='active')and not(p_action<>'accept'and g.status='declined')then raise exception 'conflict:This invitation is no longer pending.';end if;
 elsif p_action='rematch'then
  if g.status<>'finished'then raise exception 'conflict:Finish this match before inviting a rematch.';end if;
  parent_game:=g;other:=case when g.a=me then g.b else g.a end;room_id:=g.room;
  select *into g from web_pool_private.games where rematch_of=parent_game.id;
  if g.id is null then
   perform web_pool_private.invite_limit(me);
   if p_input->'state'->>'rules'is distinct from 'maroon-web-pool-3.0.0'then raise exception 'invalid:Unsupported pool version.';end if;
   request_nonce:=(p_input->>'nonce')::uuid;if request_nonce is null then raise exception 'invalid:Missing invitation identifier.';end if;
   insert into web_pool_private.games(a,b,room,state,status,invite_nonce,rematch_of)values(me,other,room_id,p_input->'state','pending',request_nonce,parent_game.id)returning *into g;
   if room_id is not null then insert into social_private.messages(room,author,nonce,body,game,game_session_id)values(room_id,me,request_nonce,'Pool rematch invitation. Accept to start.','8 Ball',g.id);end if;
  end if;
 elsif p_action='forfeit'then
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

create or replace function public.web_pool_gateway(p_action text,p_scope_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;member_hash text;origin_auth uuid;origin_session uuid;auth_result jsonb;
begin
 select m.id,s.origin_hash,s.auth_id,s.auth_session into me,member_hash,origin_auth,origin_session from web_pool_private.browser_sessions s join social_private.members m on m.id=s.member where s.token_hash=p_scope_hash and s.expires_at>now();
 if me is null then raise exception 'unauthorized:Reopen pool in the app to refresh your game session.';end if;
 if origin_auth is not null then
  auth_result:=public.social_auth_bridge('resolve',origin_auth,origin_session,'{}');
  if auth_result->>'state' is distinct from 'linked'or auth_result->>'token_hash' is distinct from member_hash then raise exception 'unauthorized:Reopen pool in the app.';end if;
 end if;
 perform social_private.require_member(member_hash);
 return web_pool_private.action(p_action,me,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));end $$;
create function public.web_pool_social(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;begin
 me:=social_private.require_member(p_hash);
 if p_action not in('list','invite','card','get','accept','decline','cancel_invite','rematch','forfeit')then raise exception 'invalid:Unknown pool action.';end if;
 return web_pool_private.action(p_action,me,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));end $$;
revoke all on function public.web_pool_social(text,text,jsonb),web_pool_private.action(text,uuid,jsonb),web_pool_private.available(web_pool_private.games),web_pool_private.player_name(web_pool_private.games,uuid),web_pool_private.invite_limit(uuid)from public,anon,authenticated;
grant execute on function public.web_pool_social(text,text,jsonb),web_pool_private.action(text,uuid,jsonb),web_pool_private.available(web_pool_private.games),web_pool_private.player_name(web_pool_private.games,uuid),web_pool_private.invite_limit(uuid)to service_role;
-- Pending invitations expire even when neither participant opens the app.
do $patch$declare d text;begin d:=pg_get_functiondef('web_pool_private.cleanup()'::regprocedure);d:=replace(d,'begin',E'begin\n update web_pool_private.games set status=''expired'',version=version+1,updated_at=now()where status=''pending''and expires_at<=now();');execute d;end $patch$;
