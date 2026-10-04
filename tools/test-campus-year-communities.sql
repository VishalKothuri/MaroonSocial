begin;
set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;community text;out jsonb;post_id uuid;tag_value text:='cohort_'||substr(ha,1,8);private_post uuid;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'cohorta_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'cohortb_'||substr(hb,1,8),true,hb)returning id into b;
 foreach community in array array['Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates']loop
  out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Cohort test','community',community,'anonymous',true,'tags',jsonb_build_array(tag_value),'feed_community',community));
  if out?'error'then raise exception 'Create failed for %: %',community,out;end if;
  post_id:=(out->>'resource_id')::uuid;
  out:=public.social_gateway('snapshot',hb,jsonb_build_object('feed_community',community));
  if out->'snapshot'->>'feedCommunity'<>community or not exists(select 1 from jsonb_array_elements(out->'snapshot'->'posts')p where p->>'id'=post_id::text and p->>'author'='Anonymous')then raise exception 'Shared private-author feed failed: %',community;end if;
  if exists(select 1 from jsonb_array_elements(out->'snapshot'->'posts')p where p->>'community'<>community)then raise exception 'Feed mixed communities';end if;
  out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value,'community',community));
  if not exists(select 1 from jsonb_array_elements(out->'posts')p where p->>'id'=post_id::text)then raise exception 'Scoped tag failed';end if;
  out:=public.social_gateway('post.vote',hb,jsonb_build_object('post_id',post_id,'value',1,'feed_community',community));
  if out?'error'then raise exception 'Vote failed';end if;
 end loop;
 -- Busy freshman traffic cannot push a main-campus post out of its own window.
 insert into social_private.posts(author,nonce,community,body,created_at)select a,gen_random_uuid(),'Freshmen','Busy cohort fixture',now()+make_interval(secs=>i)from generate_series(1,160)i;
 out:=public.social_gateway('snapshot',hb,jsonb_build_object('feed_community','Texas A&M'));
 if not exists(select 1 from jsonb_array_elements(out->'snapshot'->'posts')p where p->'tags' ? tag_value)then raise exception 'Main feed starved by cohort traffic';end if;
 update social_private.members set nsfw_enabled=true where id=a;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Adult only','community','NSFW'));private_post:=(out->>'resource_id')::uuid;
 if social_private.can_read_post(b,private_post)then raise exception 'Cohorts bypassed NSFW gate';end if;
 out:=public.social_gateway('snapshot',hb,jsonb_build_object('feed_community','NSFW'));
 if jsonb_array_length(out->'snapshot'->'posts')<>0 then raise exception 'Unjoined adult feed leaked';end if;
 out:=public.social_gateway('snapshot',hb,jsonb_build_object('feed_community','Unknown'));
 if out->>'code'<>'invalid'then raise exception 'Unknown feed accepted';end if;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Invalid feed','community','Unknown'));
 if out->>'code'<>'invalid'then raise exception 'Unknown post community accepted';end if;
 if has_function_privilege('anon','social_private.can_read_post(uuid,uuid)','EXECUTE')then raise exception 'Private access function exposed';end if;
end $$;
rollback;
