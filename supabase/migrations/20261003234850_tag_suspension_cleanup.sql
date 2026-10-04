-- Suspensions revoke positions and cached hints without waiting for the player heartbeat.
create or replace function tag_private.cleanup() returns void language plpgsql security invoker set search_path='' as $$
begin
 update tag_private.players set left_at=now(),ready=false,consented=false where left_at is null and (seen_at<now()-interval '90 seconds' or exists(select 1 from social_private.members m where m.id=member_id and m.banned));
 update tag_private.lobbies l set host_id=(select p.member_id from tag_private.players p where p.lobby_id=l.id and p.left_at is null order by p.joined_at limit 1)
 where l.state='lobby' and not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.member_id=l.host_id and p.left_at is null)
 and exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null);
 update tag_private.lobbies l set state='cancelled',finished_at=now() where state in ('lobby','hiding','seeking') and not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null);
 update tag_private.lobbies l set state='finished',winner=case when not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and p.role='hider' and not p.caught) then 'seekers' else 'hiders' end,finished_at=now()
 where state in ('hiding','seeking') and (not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and p.role='hider' and not p.caught) or not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and p.role='seeker'));
 update tag_private.lobbies set state='seeking' where state='hiding' and seek_at<=now();
 update tag_private.lobbies set state='finished',winner='hiders',finished_at=now() where state in ('hiding','seeking') and ends_at<=now();
 update tag_private.lobbies set state='cancelled',finished_at=now() where state='lobby' and expires_at<=now();
 update tag_private.lobbies set center_lat=null,center_lon=null where state in ('finished','cancelled');
 update tag_private.players set latitude=null,longitude=null,accuracy=null,location_at=null,hints='[]',hint_at=null
 where (latitude is not null or hints<>'[]'::jsonb) and (location_at<now()-interval '60 seconds' or left_at is not null or caught
 or exists(select 1 from tag_private.lobbies l where l.id=lobby_id and l.state in ('finished','cancelled')));
 update tag_private.catches set status='expired' where status='pending' and (expires_at<=now() or exists(select 1 from tag_private.players p where p.id in (seeker_id,hider_id) and p.left_at is not null));
 delete from tag_private.lobbies where coalesce(finished_at,expires_at)<now()-interval '1 hour';
 delete from tag_private.limits where window_at<now()-interval '1 day';
end; $$;

create or replace function tag_private.snapshot(p_lobby uuid,p_member uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare l tag_private.lobbies; me tag_private.players; v_hints jsonb; outside bool;
begin
 select * into l from tag_private.lobbies where id=p_lobby;
 select * into me from tag_private.players where lobby_id=p_lobby and member_id=p_member and left_at is null;
 if me.id is null or l.id is null then return jsonb_build_object('state','idle','server_time',extract(epoch from now())); end if;
 if exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and social_private.blocked(p_member,p.member_id)) then
  return jsonb_build_object('error','This lobby contains a blocked account. Leave to stop sharing.','code','blocked');
 end if;
 outside := me.location_at>now()-interval '45 seconds' and l.center_lat is not null and tag_private.distance(me.latitude,me.longitude,l.center_lat,l.center_lon)>l.radius_m;
 if l.state='seeking' and me.role='seeker' and me.location_at>now()-interval '45 seconds'
 and (me.hint_at is null or me.hint_at<now()-interval '30 seconds') then
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'username',m.username,
   'direction',(array['N','NE','E','SE','S','SW','W','NW'])[1+(floor((degrees(atan2((p.longitude-me.longitude)*cos(radians(me.latitude)),p.latitude-me.latitude))+382.5)/45)::int % 8)],
   'distance',case when tag_private.distance(me.latitude,me.longitude,p.latitude,p.longitude)<50 then 'Within 50 m' when tag_private.distance(me.latitude,me.longitude,p.latitude,p.longitude)<100 then '50–100 m' when tag_private.distance(me.latitude,me.longitude,p.latitude,p.longitude)<200 then '100–200 m' when tag_private.distance(me.latitude,me.longitude,p.latitude,p.longitude)<400 then '200–400 m' else '400+ m' end,
   'recorded_at',extract(epoch from p.location_at))), '[]') into v_hints
   from tag_private.players p join social_private.members m on m.id=p.member_id
   where p.lobby_id=l.id and p.role='hider' and p.left_at is null and not p.caught and not m.banned
    and p.location_at>now()-interval '45 seconds'
    and (l.center_lat is null or tag_private.distance(p.latitude,p.longitude,l.center_lat,l.center_lon)<=l.radius_m);
  update tag_private.players set hints=v_hints, hint_at=now() where id=me.id;
  me.hints:=v_hints; me.hint_at:=now();
 end if;
 return jsonb_build_object('state',l.state,'server_time',extract(epoch from now()),
 'lobby',jsonb_build_object('id',l.id,'code',l.code,'title',l.title,'area',l.area,'capacity',l.capacity,'duration_seconds',l.duration_seconds,'hide_seconds',l.hide_seconds,'radius_m',l.radius_m,'host',l.host_id=p_member,'seek_at',extract(epoch from l.seek_at),'ends_at',extract(epoch from l.ends_at),'expires_at',extract(epoch from l.expires_at),'winner',l.winner,'center_lat',l.center_lat,'center_lon',l.center_lon),
 'me',jsonb_build_object('id',me.id,'role',me.role,'ready',me.ready,'consented',me.consented,'caught',me.caught,'outside',coalesce(outside,false),'location_fresh',coalesce(me.location_at>now()-interval '45 seconds',false)),
 'players',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'username',m.username,'role',p.role,'ready',p.ready,'caught',p.caught,'online',p.seen_at>now()-interval '30 seconds') order by p.joined_at),'[]') from tag_private.players p join social_private.members m on m.id=p.member_id where p.lobby_id=l.id and p.left_at is null and not m.banned),
 'hints',case when l.state='seeking' and me.role='seeker' and me.location_at>now()-interval '45 seconds' and not coalesce(outside,false) then (select coalesce(jsonb_agg(h),'[]') from jsonb_array_elements(me.hints) h where (h->>'recorded_at')::numeric>extract(epoch from now()-interval '45 seconds') and exists(select 1 from tag_private.players hp join social_private.members hm on hm.id=hp.member_id where hp.id=(h->>'id')::uuid and hp.lobby_id=l.id and hp.left_at is null and not hp.caught and not hm.banned and hp.location_at>now()-interval '45 seconds')) else '[]'::jsonb end,
 'next_hint_at',extract(epoch from coalesce(me.hint_at,now())+interval '30 seconds'),
 'catches',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'requester',c.seeker_id,'target',c.hider_id,'requester_name',sm.username,'target_name',hm.username,'expires_at',extract(epoch from c.expires_at))),'[]') from tag_private.catches c join tag_private.players sp on sp.id=c.seeker_id join tag_private.players hp on hp.id=c.hider_id join social_private.members sm on sm.id=sp.member_id join social_private.members hm on hm.id=hp.member_id where c.lobby_id=l.id and c.status='pending' and c.expires_at>now() and (c.seeker_id=me.id or c.hider_id=me.id)),
 'messages',(select coalesce(jsonb_agg(row),'[]') from (select t.id,t.body,m.username,t.team,extract(epoch from t.created_at) as created_at from tag_private.messages t join tag_private.players p on p.id=t.player_id join social_private.members m on m.id=p.member_id where t.lobby_id=l.id and (t.team is null or t.team=me.role) order by t.id desc limit 40) row));
end; $$;
