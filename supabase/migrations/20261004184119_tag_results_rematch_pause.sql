-- Foreground navigation keeps a match. Pausing removes location immediately;
-- the existing clock continues and the player has a bounded 90-second grace.
alter table tag_private.players add column paused_at timestamptz;
alter table tag_private.catches add column resolved_at timestamptz;
alter table tag_private.lobbies add column rematch_id uuid references tag_private.lobbies(id) on delete set null;
create index tag_players_paused on tag_private.players(paused_at) where paused_at is not null and left_at is null;
create index tag_lobbies_rematch on tag_private.lobbies(rematch_id) where rematch_id is not null;

create function tag_private.catch_resolved() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if old.status='pending' and new.status<>'pending' then new.resolved_at:=now();end if;
 return new;
end $$;
create trigger tag_catch_resolved before update of status on tag_private.catches for each row execute function tag_private.catch_resolved();

create function tag_private.enhanced_snapshot(p_lobby uuid,p_member uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare value jsonb; l tag_private.lobbies; me tag_private.players; result jsonb;
begin
 value:=tag_private.snapshot(p_lobby,p_member);
 if value?'error' or value->>'state'='idle' then return value;end if;
 select * into l from tag_private.lobbies where id=p_lobby;
 select * into me from tag_private.players where lobby_id=p_lobby and member_id=p_member and left_at is null;
 value:=jsonb_set(value,'{me,paused_at}',coalesce(to_jsonb(extract(epoch from me.paused_at)),'null'));
 if l.rematch_id is not null and not exists(select 1 from tag_private.players p where p.lobby_id=l.rematch_id and p.left_at is null and social_private.blocked(p_member,p.member_id)) then
  value:=value||jsonb_build_object('rematch_code',(select code from tag_private.lobbies where id=l.rematch_id and state='lobby' and expires_at>now()));
 end if;
 if l.state in('finished','cancelled') then
  select jsonb_build_object(
   'duration_seconds',greatest(0,floor(extract(epoch from coalesce(l.finished_at,now())-l.seek_at))),
   'total_catches',(select count(*) from tag_private.catches where lobby_id=p_lobby and status='confirmed'),
   'players',coalesce(jsonb_agg(jsonb_build_object(
    'id',p.id,'username',m.username,'role',p.role,'caught',p.caught,'left',p.left_at is not null,
    'catches',(select count(*) from tag_private.catches c where c.seeker_id=p.id and c.status='confirmed'),
    'survived_seconds',case when p.role='hider' and l.seek_at is not null then greatest(0,floor(extract(epoch from least(coalesce(p.left_at,l.finished_at,now()),coalesce((select min(coalesce(c.resolved_at,c.created_at)) from tag_private.catches c where c.hider_id=p.id and c.status='confirmed'),l.finished_at,now()))-l.seek_at)))else null end
   )order by p.joined_at),'[]')) into result
   from tag_private.players p join social_private.members m on m.id=p.member_id
   where p.lobby_id=p_lobby and not m.banned and not social_private.blocked(p_member,p.member_id);
  value:=value||jsonb_build_object('results',result);
 end if;
 return value;
end $$;

do $patch$
declare d text; marker text;
begin
 d:=pg_get_functiondef('tag_private.cleanup()'::regprocedure);
 marker:='seen_at<now()-interval ''90 seconds'' or exists';
 if strpos(d,marker)=0 then raise exception 'Tag cleanup target missing';end if;
 execute replace(d,marker,'seen_at<now()-interval ''90 seconds'' or paused_at<now()-interval ''90 seconds'' or exists');

 d:=pg_get_functiondef('public.tag_gateway(text,text,jsonb)'::regprocedure);
 d:=replace(d,'tag_private.snapshot(','tag_private.enhanced_snapshot(');
 marker:='''report'',''block'') then return jsonb_build_object(''error'',''Unknown Tag action.'')';
 if strpos(d,marker)=0 then raise exception 'Tag action target missing';end if;
 d:=replace(d,marker,'''report'',''block'',''pause'',''resume'',''rematch'') then return jsonb_build_object(''error'',''Unknown Tag action.'')');
 marker:=' if p_action=''create'' then';
 if strpos(d,marker)=0 then raise exception 'Tag rematch target missing';end if;
 d:=replace(d,marker,$branch$
 if p_action='rematch' then
  select * into l from tag_private.lobbies where id=(p_input->>'lobby')::uuid for update;
  if l.id is null or l.host_id<>member or l.state not in('finished','cancelled') or not exists(select 1 from tag_private.players where lobby_id=l.id and member_id=member and left_at is null) then return jsonb_build_object('error','Only the host can start a rematch from these results.','code','forbidden');end if;
  if l.rematch_id is not null then
   if exists(select 1 from tag_private.players p join tag_private.lobbies g on g.id=p.lobby_id where p.lobby_id=l.rematch_id and p.member_id=member and p.left_at is null and g.state='lobby') then return tag_private.enhanced_snapshot(l.rematch_id,member);end if;
   return jsonb_build_object('error','This rematch has already closed. Create a new lobby.','code','closed');
  end if;
  if me.id is not null then return jsonb_build_object('error','Leave your current lobby before starting another.','code','conflict');end if;
  v_nonce:=(p_input->>'nonce')::uuid;
  if v_nonce is null then return jsonb_build_object('error','A rematch identifier is required.','code','invalid');end if;
  if exists(select 1 from tag_private.lobbies where request_id=v_nonce)then return jsonb_build_object('error','That rematch identifier is already in use.','code','conflict');end if;
  if(select count(*) from tag_private.lobbies where host_id=member and created_at>now()-interval '1 hour')>=6 then return jsonb_build_object('error','You have created several lobbies. Try again later.','code','rate_limit');end if;
  lid:=gen_random_uuid();v_code:=upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,8));
  insert into tag_private.lobbies(id,code,host_id,request_id,title,area,capacity,duration_seconds,hide_seconds,radius_m)
  values(lid,v_code,member,v_nonce,l.title,l.area,l.capacity,l.duration_seconds,l.hide_seconds,l.radius_m);
  insert into tag_private.players(lobby_id,member_id,role)select lid,member,role from tag_private.players where lobby_id=l.id and member_id=member;
  update tag_private.lobbies set rematch_id=lid where id=l.id;
  return tag_private.enhanced_snapshot(lid,member);
 end if;
 if p_action='create' then$branch$);
 marker:=' if p_action in (''report'',''block'') then';
 if strpos(d,marker)=0 then raise exception 'Tag pause target missing';end if;
 d:=replace(d,marker,$branch$
 if p_action='pause' then
  update tag_private.players set paused_at=coalesce(paused_at,now()),consented=false,ready=false,latitude=null,longitude=null,accuracy=null,location_at=null,hints='[]',hint_at=null where id=me.id;
  update tag_private.catches set status='expired' where status='pending' and (seeker_id=me.id or hider_id=me.id);
  return tag_private.enhanced_snapshot(lid,member);
 elsif p_action='resume' then
  if l.state not in('lobby','hiding','seeking') or me.caught or not coalesce((p_input->>'consent')::bool,false) then return jsonb_build_object('error','Consent again to resume location in this active match.','code','invalid');end if;
  if exists(select 1 from tag_private.players p where p.lobby_id=lid and p.left_at is null and social_private.blocked(member,p.member_id))then return jsonb_build_object('error','This lobby contains a blocked account.','code','blocked');end if;
  update tag_private.players set paused_at=null,consented=true,ready=false where id=me.id;
  return tag_private.enhanced_snapshot(lid,member);
 end if;
 if p_action in ('report','block') then$branch$);
 -- New lobby readiness/join is a fresh explicit consent, not a stale pause.
 d:=replace(d,'consented=v_consent where id=me.id','consented=v_consent,paused_at=null where id=me.id');
 d:=replace(d,'seen_at=now(),caught=false','seen_at=now(),caught=false,paused_at=null');
 execute d;
end $patch$;
revoke all on function tag_private.catch_resolved(),tag_private.enhanced_snapshot(uuid,uuid) from public,anon,authenticated;
grant execute on function tag_private.catch_resolved(),tag_private.enhanced_snapshot(uuid,uuid) to service_role;
