-- Public university data only. Enrollment and social data are not public.
create table public.campus_cache (
  id text primary key check (id = 'current'),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  refreshed_at timestamptz not null default now()
);
alter table public.campus_cache enable row level security;
revoke all on public.campus_cache from anon, authenticated;
grant select on public.campus_cache to anon, authenticated;
grant all on public.campus_cache to service_role;
create policy "Anyone may read the public campus snapshot" on public.campus_cache
for select to anon, authenticated using (id = 'current');

create table public.campus_refresh_lock (
  id text primary key check (id = 'current'),
  claimed_at timestamptz not null default '-infinity'
);
alter table public.campus_refresh_lock enable row level security;
revoke all on public.campus_refresh_lock from anon, authenticated;
grant all on public.campus_refresh_lock to service_role;
insert into public.campus_refresh_lock(id) values ('current');
create function public.claim_campus_refresh() returns boolean language sql security invoker
set search_path = '' as $$
  with claimed as (
    update public.campus_refresh_lock set claimed_at = now()
    where id = 'current' and claimed_at < now() - interval '55 minutes'
    returning id
  ) select exists(select 1 from claimed);
$$;
revoke execute on function public.claim_campus_refresh() from public, anon, authenticated;
grant execute on function public.claim_campus_refresh() to service_role;
