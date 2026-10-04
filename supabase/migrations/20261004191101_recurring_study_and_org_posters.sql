create schema if not exists activity_private;
revoke all on schema activity_private from public,anon,authenticated;
grant usage on schema activity_private to service_role;
create table activity_private.series(
 id uuid primary key default gen_random_uuid(),owner uuid not null references social_private.members(id) on delete cascade,
 nonce uuid not null,input jsonb not null,created_at timestamptz not null default now(),unique(owner,nonce)
);
create table activity_private.occurrences(
 series uuid not null references activity_private.series(id) on delete cascade,
 activity uuid not null unique references social_private.activities(id) on delete cascade,
 ordinal int not null check(ordinal between 1 and 8),primary key(series,ordinal)
);
create table activity_private.publications(
 owner uuid not null references social_private.members(id) on delete cascade,nonce uuid not null,input jsonb not null,
 activity uuid not null unique references social_private.activities(id) on delete cascade,primary key(owner,nonce)
);
create table activity_private.posters(
 activity uuid primary key references social_private.activities(id) on delete cascade,
 attachment uuid not null unique references social_private.attachments(id) on delete cascade
);
alter table activity_private.series enable row level security;
alter table activity_private.occurrences enable row level security;
alter table activity_private.publications enable row level security;
alter table activity_private.posters enable row level security;
create policy series_service on activity_private.series for all to service_role using(true)with check(true);
create policy occurrences_service on activity_private.occurrences for all to service_role using(true)with check(true);
create policy publications_service on activity_private.publications for all to service_role using(true)with check(true);
create policy posters_service on activity_private.posters for all to service_role using(true)with check(true);
revoke all on all tables in schema activity_private from public,anon,authenticated;
grant all on all tables in schema activity_private to service_role;
alter table social_private.attachments drop constraint attachments_purpose_check;
alter table social_private.attachments add constraint attachments_purpose_check check(purpose in('content','group_photo','member_photo','organization_poster'));

create or replace function public.activity_plans(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path='' as $$
declare me uuid; a social_private.activities; s activity_private.series; pub activity_private.publications; att social_private.attachments;
 aid uuid; sid uuid; oid uuid; non uuid; count_value int; n int; stamp timestamptz; local_stamp timestamp; args jsonb; result jsonb; ids jsonb:='[]'; old uuid; old_path text; can_manage bool;
begin
 me:=social_private.require_member(p_hash);
 perform pg_advisory_xact_lock(hashtextextended('activity-plans:'||me::text,0));
 if p_action in('series.create','promotion.create')then
  non:=(p_input->>'nonce')::uuid;if non is null then raise exception 'invalid:Save a draft identifier before publishing.';end if;
  args:=p_input-'nonce'-'feed_community';
  if p_action='series.create'then
   select *into s from activity_private.series where owner=me and nonce=non;
   if s.id is not null then
    if s.input<>args then raise exception 'conflict:This draft was already published with different details.';end if;
    select jsonb_agg(activity::text order by ordinal)into ids from activity_private.occurrences where series=s.id;
    return jsonb_build_object('series_id',s.id,'activity_ids',ids);
   end if;
   count_value:=(args->>'weeks')::int;
   if count_value is null or count_value not between 2 and 8 then raise exception 'invalid:Choose 2–8 weekly meetings.';end if;
   if char_length(btrim(coalesce(args->>'title','')))not between 1 and 100 or char_length(btrim(coalesce(args->>'place','')))not between 1 and 200 or char_length(coalesce(args->>'details',''))>2000 or char_length(coalesce(args->>'course',''))>40 then raise exception 'invalid:Enter a title, place and details within the limits.';end if;
   if coalesce((args->>'capacity')::int,0)not between 2 and 100 then raise exception 'invalid:Choose 2–100 spots.';end if;
   stamp:=to_timestamp((args->>'starts')::double precision);
   if stamp is null or not isfinite(stamp)or stamp<=now()or stamp>now()+interval '180 days'then raise exception 'invalid:Choose a first meeting within the next 180 days.';end if;
   if(select count(*)from social_private.activities where host=me and created_at>now()-interval '1 day')+count_value>20 then raise exception 'rate_limit:You can create up to 20 meetings per day.';end if;
   insert into activity_private.series(owner,nonce,input)values(me,non,args)returning id into sid;
   for n in 0..count_value-1 loop
    local_stamp:=(stamp at time zone 'America/Chicago')+n*interval '7 days';
    if ((local_stamp at time zone 'America/Chicago')at time zone 'America/Chicago')<>local_stamp then raise exception 'invalid:A meeting falls in the daylight-saving time change. Choose a different start time.';end if;
    aid:=gen_random_uuid();
    insert into social_private.rooms(id,kind,title)values(aid::text,'activity',btrim(args->>'title'));
    insert into social_private.activities(id,room,host,nonce,title,kind,place,starts,capacity,details,course,approval_required)
      values(aid,aid::text,me,gen_random_uuid(),btrim(args->>'title'),'Study',btrim(args->>'place'),local_stamp at time zone 'America/Chicago',(args->>'capacity')::int,coalesce(args->>'details',''),nullif(btrim(args->>'course'),''),coalesce((args->>'approval_required')::boolean,false));
    insert into social_private.room_members(room,member,role)values(aid::text,me,'owner');
    insert into activity_private.occurrences(series,activity,ordinal)values(sid,aid,n+1);
    ids:=ids||jsonb_build_array(aid::text);
   end loop;
   return jsonb_build_object('series_id',sid,'activity_ids',ids);
  end if;
  oid:=(args->>'organization_id')::uuid;
  if not exists(select 1 from social_private.organizations o join social_private.organization_admins x on x.organization=o.id where o.id=oid and o.status='verified'and x.member=me)then raise exception 'forbidden:Only verified organization administrators can publish.';end if;
  select *into pub from activity_private.publications where owner=me and nonce=non;
  if pub.activity is not null then
   if pub.input<>args then raise exception 'conflict:This promotion was already published with different details.';end if;
   return jsonb_build_object('activity_id',pub.activity);
  end if;
  if(select count(*)from activity_private.publications where owner=me and activity in(select id from social_private.activities where created_at>now()-interval '1 day'))>=10 then raise exception 'rate_limit:You can publish up to 10 organization promotions per day.';end if;
  result:=public.social_gateway('organization.publish',p_hash,p_input||jsonb_build_object('kind','Organizations'));
  if result?'error'then return result;end if;
  aid:=(result->>'resource_id')::uuid;if aid is null then raise exception 'invalid:The promotion could not be published.';end if;
  insert into activity_private.publications(owner,nonce,input,activity)values(me,non,args,aid);
  return jsonb_build_object('activity_id',aid);
 end if;
 aid:=(p_input->>'activity_id')::uuid;
 select *into a from social_private.activities where id=aid;
 if a.id is null or a.host is null or social_private.blocked(me,a.host)or exists(select 1 from social_private.members where id=a.host and banned)then raise exception 'forbidden:This plan is unavailable.';end if;
 if p_action in('series.info','series.cancel_future')then
  select sr.*into s from activity_private.series sr join activity_private.occurrences o on o.series=sr.id where o.activity=a.id;
  if s.id is null then return jsonb_build_object('is_series',false);end if;
  if p_action='series.cancel_future'then
   if s.owner<>me then raise exception 'forbidden:Only the host can cancel this series.';end if;
   for aid in select act.id from social_private.activities act join activity_private.occurrences occ on occ.activity=act.id where occ.series=s.id and act.starts>=now()and not act.cancelled order by act.starts loop
    result:=public.social_gateway('activity.cancel',p_hash,jsonb_build_object('activity_id',aid));
    if result?'error'then raise exception 'forbidden:This series could not be cancelled.';end if;
   end loop;
  end if;
  select jsonb_agg(jsonb_build_object('id',act.id,'starts',extract(epoch from act.starts),'cancelled',act.cancelled)order by occ.ordinal)into ids from activity_private.occurrences occ join social_private.activities act on act.id=occ.activity where occ.series=s.id;
  return jsonb_build_object('is_series',true,'can_manage',s.owner=me,'series_id',s.id,'occurrences',ids);
 end if;
 select (meta->>'organization')::uuid into oid from social_private.rooms where id=a.room;
 if oid is null or not exists(select 1 from social_private.organizations where id=oid and status='verified')then raise exception 'forbidden:This organization promotion is unavailable.';end if;
 can_manage:=exists(select 1 from social_private.organization_admins where organization=oid and member=me);
 if p_action='poster.read'then
  if a.cancelled then raise exception 'forbidden:This promotion was cancelled.';end if;
  select at.*into att from activity_private.posters p join social_private.attachments at on at.id=p.attachment where p.activity=a.id and at.ready;
  if att.id is null then return jsonb_build_object('has_poster',false);end if;
  return jsonb_build_object('has_poster',true,'path',att.path,'attachment_id',att.id);
 end if;
 if not can_manage or a.cancelled then raise exception 'forbidden:Only current administrators can update this promotion.';end if;
 perform pg_advisory_xact_lock(hashtextextended('poster:'||a.id::text,0));
 if p_action='poster.authorize'then return jsonb_build_object('authorized',true);
 elsif p_action='poster.reserve'then
  if p_input->>'path'!~'^[a-f0-9-]{36}\.jpg$'or coalesce((p_input->>'size')::int,0)not between 1 and 2000000 then raise exception 'invalid:Choose a JPEG poster under 2 MB.';end if;
  if(select count(*)from social_private.attachments where owner=me and created_at>now()-interval '1 hour')>=30 then raise exception 'rate_limit:Upload limit reached. Please try later.';end if;
  insert into social_private.attachments(owner,room,kind,mime,size,path,purpose)values(me,a.room,'image','image/jpeg',(p_input->>'size')::int,p_input->>'path','organization_poster')returning *into att;
  return jsonb_build_object('attachment_id',att.id,'path',att.path);
 elsif p_action='poster.commit'then
  select *into att from social_private.attachments where id=(p_input->>'attachment_id')::uuid for update;
  if att.id is null or att.owner<>me or att.room<>a.room or att.purpose<>'organization_poster'then raise exception 'forbidden:This upload cannot be a promotion poster.';end if;
  select attachment into old from activity_private.posters where activity=a.id;
  update social_private.attachments set ready=true where id=att.id;
  insert into activity_private.posters(activity,attachment)values(a.id,att.id)on conflict(activity)do update set attachment=excluded.attachment;
 elsif p_action='poster.remove'then delete from activity_private.posters where activity=a.id returning attachment into old;
 else raise exception 'invalid:Unknown plan action.';end if;
 if old is not null and old is distinct from att.id then
  delete from social_private.attachments where id=old returning path into old_path;
  if old_path is not null then insert into social_private.storage_deletions(path)values(old_path)on conflict do nothing;end if;
 end if;
 return jsonb_build_object('saved',true,'attachment_id',att.id);
exception when others then
 if position(':'in sqlerrm)>0 then return jsonb_build_object('code',split_part(sqlerrm,':',1),'error',substring(sqlerrm from position(':'in sqlerrm)+1));end if;
 return jsonb_build_object('code','invalid','error','This plan could not be saved.');
end $$;
revoke all on function public.activity_plans(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.activity_plans(text,text,jsonb)to service_role;
