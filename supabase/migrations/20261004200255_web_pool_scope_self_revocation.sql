-- Possession of a pool-only credential permits deleting that exact scope even
-- after native account logout. It cannot revoke another scope or mutate games.
create function public.web_pool_close(p_scope_hash text)returns jsonb language plpgsql security invoker set search_path=''as $$begin
 if p_scope_hash is null or p_scope_hash!~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid pool session.';end if;
 delete from web_pool_private.browser_sessions where token_hash=p_scope_hash;
 return '{"revoked":true}'::jsonb;
end $$;
revoke all on function public.web_pool_close(text)from public,anon,authenticated;
grant execute on function public.web_pool_close(text)to service_role;
