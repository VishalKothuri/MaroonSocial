begin;
set local role service_role;
do $$
declare fixture_member uuid:=gen_random_uuid(); h text:=encode(extensions.gen_random_bytes(32),'hex'); r jsonb; lease uuid;
begin
 insert into social_private.members(id,token_hash,username,adult,network_hash)values(fixture_member,h,'scoreqa_'||substr(replace(fixture_member::text,'-',''),1,10),true,'transactional');
 update sports_private.cache set updated_at=null,lease_until=null,attempted_at=null;
 r:=public.sports_cache('claim',h);lease:=(r->>'lease')::uuid;
 if lease is null then raise exception 'No initial lease';end if;
 if public.sports_cache('claim',h)->>'lease' is not null then raise exception 'Duplicate lease';end if;
 r:=public.sports_cache('publish',h,jsonb_build_object('lease',gen_random_uuid(),'payload','{"games":[]}'::jsonb));
 if(r->>'published')::bool then raise exception 'Wrong lease wrote';end if;
 r:=public.sports_cache('publish',h,jsonb_build_object('lease',lease,'payload','{"games":[]}'::jsonb));
 if not(r->>'published')::bool then raise exception 'Correct lease failed';end if;
 r:=public.sports_cache('read',h);
 if not(r->>'fresh')::bool or r->'payload'->'games'<>'[]'::jsonb then raise exception 'Published cache missing';end if;
 if has_function_privilege('anon','public.sports_cache(text,text,jsonb)','EXECUTE')or has_table_privilege('authenticated','sports_private.cache','SELECT')then raise exception 'Cache publicly writable';end if;
 begin perform public.sports_cache('read',repeat('0',64));raise exception 'Invalid credential passed';exception when others then if sqlerrm not like 'unauthorized:%'then raise;end if;end;
 update social_private.members set banned=true where social_private.members.id=fixture_member;
 begin perform public.sports_cache('read',h);raise exception 'Banned account passed';exception when others then if sqlerrm not like 'forbidden:%'then raise;end if;end;
end $$;
rollback;
