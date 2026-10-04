-- Fixed-name privileged setup for the project owner; no client grant or arbitrary
-- Vault read/write is exposed. The service key is used only by the local operator tool.
create function public.push_setup_worker(p_secret text)returns jsonb language plpgsql security definer set search_path=''as $$declare existing uuid;begin
 if p_secret!~'^[a-f0-9]{64}$'then raise exception 'Invalid worker secret';end if;
 select id into existing from vault.secrets where name='maroon_push_worker';
 if existing is null then perform vault.create_secret(p_secret,'maroon_push_worker','APNs queue worker authentication');else perform vault.update_secret(existing,p_secret,'maroon_push_worker','APNs queue worker authentication');end if;
 return jsonb_build_object('configured',true);
end $$;
revoke all on function public.push_setup_worker(text)from public,anon,authenticated;
grant execute on function public.push_setup_worker(text)to service_role;
-- Avoid PL/pgSQL composite-variable/table-alias ambiguity in the game inbox.
do $p$declare d text;begin d:=pg_get_functiondef('public.push_devices(text,text,jsonb)'::regprocedure);d:=replace(d,'select j.*from push_private.jobs j where recipient=me','select source_job.*from push_private.jobs source_job where recipient=me');d:=replace(d,'and push_private.route(j)is not null and(read_at is not null or push_private.deliverable(j))','and push_private.route(source_job)is not null and(read_at is not null or push_private.deliverable(source_job))');execute d;end $p$;
