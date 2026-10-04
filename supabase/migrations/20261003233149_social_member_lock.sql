-- Preserve serialized account quotas without blocking foreign-key membership checks.
create or replace function social_private.require_member(p_hash text) returns uuid language plpgsql security invoker set search_path='' as $$
declare m social_private.members; begin
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'unauthorized:Sign in to continue.'; end if;
 select * into m from social_private.members where token_hash=p_hash for no key update;
 if m.id is null then raise exception 'unauthorized:Your account credential is unavailable.'; end if;
 if m.banned then raise exception 'forbidden:This account is suspended.'; end if;
 if m.rate_window>now()-interval '1 minute' and m.rate_count>=600 then raise exception 'rate_limit:Please slow down and try again shortly.'; end if;
 update social_private.members set seen_at=now(),rate_window=case when rate_window<now()-interval '1 minute' then now() else rate_window end,rate_count=case when rate_window<now()-interval '1 minute' then 1 else rate_count+1 end where id=m.id;
 return m.id;
end $$;
