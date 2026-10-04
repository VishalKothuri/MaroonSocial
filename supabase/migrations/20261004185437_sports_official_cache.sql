-- Official public sports facts are cached once per project. The API authenticates
-- callers; only this service-role RPC can lease or replace the shared snapshot.
create schema sports_private;
revoke all on schema sports_private from public,anon,authenticated;
grant usage on schema sports_private to service_role;
create table sports_private.cache (
 id bool primary key default true check(id), payload jsonb, updated_at timestamptz,
 lease uuid, lease_until timestamptz, attempted_at timestamptz
);
alter table sports_private.cache enable row level security;
revoke all on sports_private.cache from public,anon,authenticated;
grant all on sports_private.cache to service_role;
insert into sports_private.cache(id) values(true);
create function public.sports_cache(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare row sports_private.cache; claimed uuid;
begin
 perform social_private.require_member(p_hash);
 if p_action='read' then
  select * into row from sports_private.cache where id;
  return jsonb_build_object('payload',row.payload,'fresh',coalesce(row.updated_at>now()-interval '2 minutes',false));
 elsif p_action='claim' then
  claimed:=gen_random_uuid();
  update sports_private.cache set lease=claimed,lease_until=now()+interval '30 seconds',attempted_at=now()
   where id and(updated_at is null or updated_at<now()-interval '2 minutes')
    and(lease_until is null or lease_until<now())
    and(attempted_at is null or attempted_at<now()-interval '30 seconds') returning * into row;
  return jsonb_build_object('lease',case when found then claimed else null end);
 elsif p_action='publish' then
  if jsonb_typeof(p_input->'payload')<>'object' or jsonb_typeof(p_input->'payload'->'games')<>'array'
   or jsonb_array_length(p_input->'payload'->'games')>200 or octet_length(p_input::text)>512000 then
   raise exception 'invalid:Invalid sports payload';end if;
  update sports_private.cache set payload=p_input->'payload',updated_at=now(),lease=null,lease_until=null
   where id and lease=(p_input->>'lease')::uuid and lease_until>now();
  return jsonb_build_object('published',found);
 end if;
 raise exception 'invalid:Unknown sports cache operation';
end $$;
revoke all on function public.sports_cache(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.sports_cache(text,text,jsonb) to service_role;
