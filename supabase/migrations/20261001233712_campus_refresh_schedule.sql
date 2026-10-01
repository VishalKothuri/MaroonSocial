create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
create policy "Server manages the refresh lease" on public.campus_refresh_lock
for all to service_role using (true) with check (true);
-- Vault configuration is supplied separately, never committed in migration text.
select cron.schedule(
  'maroon-campus-hourly', '17 * * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='maroon_project_url') || '/functions/v1/refresh-campus',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='maroon_campus_anon_jwt')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $job$
);
