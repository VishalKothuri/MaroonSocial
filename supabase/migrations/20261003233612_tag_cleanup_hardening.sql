-- Session cleanup, account deletion cascades and fail-closed catch identifiers.
alter table tag_private.lobbies drop constraint lobbies_host_id_fkey, add constraint lobbies_host_id_fkey foreign key(host_id) references social_private.members(id) on delete cascade;
alter table tag_private.players drop constraint players_member_id_fkey, add constraint players_member_id_fkey foreign key(member_id) references social_private.members(id) on delete cascade;
alter table tag_private.catches drop constraint catches_seeker_id_fkey, add constraint catches_seeker_id_fkey foreign key(seeker_id) references tag_private.players(id) on delete cascade;
alter table tag_private.catches drop constraint catches_hider_id_fkey, add constraint catches_hider_id_fkey foreign key(hider_id) references tag_private.players(id) on delete cascade;
alter table tag_private.messages drop constraint messages_player_id_fkey, add constraint messages_player_id_fkey foreign key(player_id) references tag_private.players(id) on delete cascade;
alter table tag_private.limits drop constraint limits_member_id_fkey, add constraint limits_member_id_fkey foreign key(member_id) references social_private.members(id) on delete cascade;
create index tag_players_location_expiry on tag_private.players(location_at) where latitude is not null;
create policy tag_lobbies_server on tag_private.lobbies for all to service_role using(true) with check(true);
create policy tag_players_server on tag_private.players for all to service_role using(true) with check(true);
create policy tag_catches_server on tag_private.catches for all to service_role using(true) with check(true);
create policy tag_messages_server on tag_private.messages for all to service_role using(true) with check(true);
create policy tag_limits_server on tag_private.limits for all to service_role using(true) with check(true);
create or replace function tag_private.cleanup() returns void language plpgsql security invoker set search_path='' as $$
begin
 update tag_private.players set left_at=now(),ready=false,consented=false where left_at is null and seen_at<now()-interval '90 seconds';
 update tag_private.lobbies l set host_id=(select p.member_id from tag_private.players p where p.lobby_id=l.id and p.left_at is null order by p.joined_at limit 1)
 where l.state='lobby' and not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.member_id=l.host_id and p.left_at is null)
 and exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null);
 update tag_private.lobbies l set state='cancelled',finished_at=now() where state in ('lobby','hiding','seeking') and not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null);
 update tag_private.lobbies l set state='finished',winner=case when not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and p.role='hider' and not p.caught) then 'seekers' else 'hiders' end,finished_at=now()
 where state in ('hiding','seeking') and (not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and p.role='hider' and not p.caught) or not exists(select 1 from tag_private.players p where p.lobby_id=l.id and p.left_at is null and p.role='seeker'));
 update tag_private.lobbies set center_lat=null,center_lon=null where state in ('finished','cancelled');
 update tag_private.lobbies set state='seeking' where state='hiding' and seek_at<=now();
 update tag_private.lobbies set state='finished',winner='hiders',finished_at=now() where state in ('hiding','seeking') and ends_at<=now();
 update tag_private.lobbies set state='cancelled',finished_at=now() where state='lobby' and expires_at<=now();
 update tag_private.players set latitude=null,longitude=null,accuracy=null,location_at=null,hints='[]',hint_at=null
 where (latitude is not null or hints<>'[]'::jsonb) and (location_at<now()-interval '60 seconds' or left_at is not null or caught
 or exists(select 1 from tag_private.lobbies l where l.id=lobby_id and l.state in ('finished','cancelled')));
 update tag_private.catches set status='expired' where status='pending' and expires_at<=now();
 delete from tag_private.lobbies where coalesce(finished_at,expires_at)<now()-interval '1 hour';
 delete from tag_private.limits where window_at<now()-interval '1 day';
end; $$;


create or replace function public.tag_gateway(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare member uuid; l tag_private.lobbies; me tag_private.players; other tag_private.players; c tag_private.catches;
 lid uuid; v_code text; v_role text; lat double precision; lon double precision; acc double precision; seen timestamptz;
 request_count int; v_body text; v_nonce uuid; v_consent bool; v_ready bool; v_winner text;
begin
 member:=social_private.require_member(p_hash);
 if member is null then return jsonb_build_object('error','Sign in again to play.','code','unauthorized'); end if;
 perform pg_advisory_xact_lock(hashtextextended(member::text,715));
 insert into tag_private.limits(member_id,requests) values(member,1) on conflict(member_id) do update set
 requests=case when tag_private.limits.window_at<now()-interval '1 minute' then 1 else tag_private.limits.requests+1 end,
 window_at=case when tag_private.limits.window_at<now()-interval '1 minute' then now() else tag_private.limits.window_at end returning requests into request_count;
 if request_count>120 then return jsonb_build_object('error','A little too fast. Try again in a minute.','code','rate_limit'); end if;
 perform tag_private.cleanup();
 if p_action not in ('poll','create','join','ready','role','start','location','catch','confirm','message','leave','end') then return jsonb_build_object('error','Unknown Tag action.'); end if;
 select p.* into me from tag_private.players p join tag_private.lobbies g on g.id=p.lobby_id where p.member_id=member and p.left_at is null and g.state in ('lobby','hiding','seeking') order by p.joined_at desc limit 1;
 if p_action='create' then
  if me.id is not null then return tag_private.snapshot(me.lobby_id,member); end if;
  v_nonce:=(p_input->>'nonce')::uuid;
  select id into lid from tag_private.lobbies where request_id=v_nonce and host_id=member;
  if lid is not null then return tag_private.snapshot(lid,member); end if;
  if (select count(*) from tag_private.lobbies where host_id=member and created_at>now()-interval '1 hour')>=6 then return jsonb_build_object('error','You have created several lobbies. Join an existing one or try later.','code','rate_limit'); end if;
  v_body:=btrim(coalesce(p_input->>'title','Campus Tag'));
  if length(v_body) not between 1 and 60 or length(btrim(coalesce(p_input->>'area',''))) not between 3 and 120 then return jsonb_build_object('error','Add a lobby name and agreed public outdoor meeting area.'); end if;
  v_code:=upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,8));
  insert into tag_private.lobbies(code,host_id,request_id,title,area,capacity,duration_seconds,hide_seconds,radius_m)
  values(v_code,member,v_nonce,v_body,btrim(p_input->>'area'),coalesce((p_input->>'capacity')::int,8),coalesce((p_input->>'duration_seconds')::int,600),coalesce((p_input->>'hide_seconds')::int,60),coalesce((p_input->>'radius_m')::int,300)) returning * into l;
  insert into tag_private.players(lobby_id,member_id,role) values(l.id,member,'seeker');
  return tag_private.snapshot(l.id,member);
 elsif p_action='join' then
  v_code:=upper(regexp_replace(coalesce(p_input->>'code',''),'[^A-Za-z0-9]','','g'));
  select * into l from tag_private.lobbies where tag_private.lobbies.code=v_code for update;
  if l.id is null or l.state<>'lobby' or l.expires_at<=now() then return jsonb_build_object('error','That lobby is unavailable or has already started.'); end if;
  if me.id is not null and me.lobby_id<>l.id then return jsonb_build_object('error','Leave your current lobby before joining another.'); end if;
  if exists(select 1 from tag_private.players where lobby_id=l.id and member_id=member and left_at is null) then return tag_private.snapshot(l.id,member); end if;
  if (select count(*) from tag_private.players where lobby_id=l.id and left_at is null)>=l.capacity then return jsonb_build_object('error','This lobby is full.'); end if;
  insert into tag_private.players(lobby_id,member_id,role) values(l.id,member,'hider') on conflict(lobby_id,member_id) do update set left_at=null,ready=false,consented=false,role='hider',seen_at=now(),caught=false;
  return tag_private.snapshot(l.id,member);
 end if;
 lid:=nullif(p_input->>'lobby','')::uuid;
 if lid is null then lid:=me.lobby_id; end if;
 if lid is null then return jsonb_build_object('state','idle','server_time',extract(epoch from now())); end if;
 select * into l from tag_private.lobbies where id=lid for update;
 select * into me from tag_private.players where lobby_id=lid and member_id=member and left_at is null;
 if me.id is null then return jsonb_build_object('state','idle','server_time',extract(epoch from now())); end if;
 update tag_private.players set seen_at=now() where id=me.id;
 if p_action='leave' then
  update tag_private.players set left_at=now(),latitude=null,longitude=null,accuracy=null,location_at=null,consented=false,ready=false,hints='[]' where id=me.id;
  update tag_private.catches set status='declined' where status='pending' and (seeker_id=me.id or hider_id=me.id);
  if not exists(select 1 from tag_private.players where lobby_id=lid and left_at is null) then update tag_private.lobbies set state='cancelled',finished_at=now() where id=lid;
  elsif l.host_id=member then update tag_private.lobbies set host_id=(select member_id from tag_private.players where lobby_id=lid and left_at is null order by joined_at limit 1) where id=lid; end if;
  perform tag_private.cleanup();
  return jsonb_build_object('state','idle','server_time',extract(epoch from now()));
 elsif p_action='end' then
  if l.host_id<>member then return jsonb_build_object('error','Only the host can end everyone’s match.'); end if;
  update tag_private.lobbies set state='cancelled',finished_at=now() where id=lid;
 elsif p_action in ('ready','role') then
  if l.state<>'lobby' then return jsonb_build_object('error','Roles and readiness are locked after starting.'); end if;
  if p_action='role' then
   v_role:=p_input->>'role'; if v_role not in ('hider','seeker') then return jsonb_build_object('error','Choose Hider or Seeker.'); end if;
   update tag_private.players set role=v_role,ready=false where id=me.id;
  else
   v_ready:=coalesce((p_input->>'ready')::bool,false); v_consent:=coalesce((p_input->>'consent')::bool,false);
   if v_ready and not v_consent then return jsonb_build_object('error','Location consent is required before becoming ready.'); end if;
   update tag_private.players set ready=v_ready,consented=v_consent where id=me.id;
  end if;
 elsif p_action='start' then
  if l.host_id<>member or l.state<>'lobby' then return jsonb_build_object('error','Only the host can start this lobby.'); end if;
  if (select count(*) from tag_private.players where lobby_id=lid and left_at is null)<2
   or exists(select 1 from tag_private.players where lobby_id=lid and left_at is null and (not ready or not consented or seen_at<now()-interval '30 seconds'))
   or not exists(select 1 from tag_private.players where lobby_id=lid and left_at is null and role='hider')
   or not exists(select 1 from tag_private.players where lobby_id=lid and left_at is null and role='seeker')
  then return jsonb_build_object('error','At least one hider and seeker must be online and ready.'); end if;
  update tag_private.lobbies set state='hiding',seek_at=now()+make_interval(secs=>hide_seconds),ends_at=now()+make_interval(secs=>hide_seconds+duration_seconds),expires_at=now()+make_interval(secs=>hide_seconds+duration_seconds+3600) where id=lid;
 elsif p_action='location' then
  if l.state not in ('hiding','seeking') or not me.consented or me.caught then return jsonb_build_object('error','Location sharing is not active for this player.'); end if;
  lat:=(p_input->>'latitude')::double precision; lon:=(p_input->>'longitude')::double precision; acc:=(p_input->>'accuracy')::double precision;
  seen:=to_timestamp((p_input->>'captured_at')::double precision);
  if lat is null or lon is null or acc is null or seen is null or not(lat between -90 and 90) or not(lon between -180 and 180) or not(acc between 0 and 75) or seen<now()-interval '20 seconds' or seen>now()+interval '10 seconds' then return jsonb_build_object('error','A recent location accurate within 75 m is needed.'); end if;
  update tag_private.players set latitude=round(lat::numeric,4),longitude=round(lon::numeric,4),accuracy=acc,location_at=now() where id=me.id;
  if l.host_id=member and l.center_lat is null then update tag_private.lobbies set center_lat=round(lat::numeric,3),center_lon=round(lon::numeric,3) where id=lid; end if;
 elsif p_action='catch' then
  if l.state<>'seeking' or me.role<>'seeker' then return jsonb_build_object('error','Catch requests open for seekers after hiding time.'); end if;
  select * into other from tag_private.players where id=(p_input->>'target')::uuid and lobby_id=lid and role='hider' and left_at is null and not caught;
  if other.id is null or me.location_at is null or other.location_at is null or least(me.location_at,other.location_at)<now()-interval '30 seconds' or tag_private.distance(me.latitude,me.longitude,other.latitude,other.longitude)>80 then return jsonb_build_object('error','Both players need fresh locations and must be near each other. Ask the hider to open Tag.'); end if;
  if not exists(select 1 from tag_private.catches where seeker_id=me.id and hider_id=other.id and status='pending' and expires_at>now()) then insert into tag_private.catches(lobby_id,seeker_id,hider_id) values(lid,me.id,other.id); end if;
 elsif p_action='confirm' then
  select * into c from tag_private.catches where id=(p_input->>'catch')::uuid and lobby_id=lid for update;
  if c.id is null or l.state<>'seeking' or c.hider_id<>me.id or c.status<>'pending' or c.expires_at<=now() then return jsonb_build_object('error','This catch request has expired or does not belong to you.'); end if;
  if coalesce((p_input->>'accept')::bool,false) then
   select * into other from tag_private.players where id=c.seeker_id and left_at is null;
   if other.id is null or me.location_at is null or other.location_at is null or least(me.location_at,other.location_at)<now()-interval '30 seconds' or tag_private.distance(me.latitude,me.longitude,other.latitude,other.longitude)>80 then return jsonb_build_object('error','Refresh both locations before confirming this catch.'); end if;
   update tag_private.players set caught=true,latitude=null,longitude=null,accuracy=null,location_at=null,hints='[]' where id=me.id;
   update tag_private.catches set status='confirmed' where id=c.id;
   update tag_private.catches set status='expired' where hider_id=me.id and status='pending';
  else update tag_private.catches set status='declined' where id=c.id; end if;
 elsif p_action='message' then
  v_body:=btrim(coalesce(p_input->>'body','')); v_nonce:=(p_input->>'nonce')::uuid;
  if length(v_body) not between 1 and 500 then return jsonb_build_object('error','Write a message under 500 characters.'); end if;
  insert into tag_private.messages(lobby_id,player_id,nonce,body,team) values(lid,me.id,v_nonce,v_body,case when coalesce((p_input->>'team')::bool,false) and l.state<>'lobby' then me.role else null end) on conflict(player_id,nonce) do nothing;
 end if;
 if l.state in ('hiding','seeking') then
  if not exists(select 1 from tag_private.players where lobby_id=lid and left_at is null and role='hider' and not caught) then v_winner:='seekers';
  elsif not exists(select 1 from tag_private.players where lobby_id=lid and left_at is null and role='seeker') then v_winner:='hiders'; end if;
  if v_winner is not null then update tag_private.lobbies set state='finished',winner=v_winner,finished_at=now() where id=lid; end if;
 end if;
 perform tag_private.cleanup();
 return tag_private.snapshot(lid,member);
exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation then
 return jsonb_build_object('error','Some game settings are invalid. Check them and try again.');
end; $$;
