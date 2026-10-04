begin;
set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;old_post uuid;secret_post uuid;tag_value text:='tg_'||substr(ha,1,8);cap_tag text:='cap_'||substr(ha,1,8);out jsonb;obj jsonb;choice uuid;
begin
 if has_function_privilege('anon','social_private.visible_posts(uuid,text,text,integer)','EXECUTE')or has_function_privilege('authenticated','public.social_gateway(text,text,jsonb)','EXECUTE')then raise exception 'Tag query exposed outside authenticated Edge';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'tag_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'tag_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'tag_c_'||substr(hc,1,8),true,hc)returning id into c;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Old tagged post','tags',jsonb_build_array(tag_value),'poll',jsonb_build_object('question','Still discoverable?','options',jsonb_build_array('Yes','No'),'duration_hours',24)));old_post:=(out->>'resource_id')::uuid;
 update social_private.posts set created_at='2000-01-01Z'where id=old_post;
 -- These are rolled-back fixtures only, used to prove this is a server query
 -- rather than another filter over the newest 150 posts in the feed.
 insert into social_private.posts(author,nonce,body,created_at)
 select c,gen_random_uuid(),'Newer untagged fixture',now()+interval '1 day'+i*interval '1 second'from generate_series(1,160)i;
 if exists(select 1 from jsonb_array_elements(social_private.snapshot(b)->'posts')p where p->>'id'=old_post::text)then raise exception 'Old fixture unexpectedly in bounded feed';end if;
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag','#'||upper(tag_value),'community','Texas A&M'));
 if jsonb_array_length(out->'posts')<>1 or out->'posts'->0->>'id'<>old_post::text or out->>'tag'<>tag_value then raise exception 'Server discovery missed old matching post %',out;end if;
 obj:=out->'posts'->0;choice:=(obj->'poll'->'options'->0->>'id')::uuid;
 if obj->>'author'<>'Anonymous'or obj::text like '%'||a::text||'%'or obj::text like '%tag_a_%'then raise exception 'Tag serializer leaked anonymous identity';end if;
 out:=public.social_gateway('poll.vote',hb,jsonb_build_object('post_id',old_post,'option_id',choice));
 out:=public.social_gateway('post.vote',hb,jsonb_build_object('post_id',old_post,'value',1));
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value,'community','Texas A&M'));obj:=out->'posts'->0;
 if(obj->>'score')::int<>1 or(obj->>'vote')::int<>1 or obj->'poll'->>'myOptionID'<>choice::text then raise exception 'Tag page lost canonical post/poll votes';end if;
 out:=public.social_gateway('posts.tag',hb,'{"tag":"bad tag","community":"Texas A&M"}');if out->>'code'is distinct from 'invalid'then raise exception 'Invalid tag accepted';end if;
 out:=public.social_gateway('posts.tag',hb,'{"tag":1}');if out->>'code'is distinct from 'invalid'then raise exception 'Nontext tag accepted';end if;
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value,'community','Other'));if out->>'code'is distinct from 'invalid'then raise exception 'Invalid community accepted';end if;
 insert into social_private.hidden(member,post)values(b,old_post);
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value));if jsonb_array_length(out->'posts')<>0 then raise exception 'Hidden post leaked through tag query';end if;
 delete from social_private.hidden where member=b and post=old_post;
 insert into social_private.blocks(blocker,blocked)values(b,a);
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value));if jsonb_array_length(out->'posts')<>0 then raise exception 'Blocked author leaked through tag query';end if;
 delete from social_private.blocks where blocker=b and blocked=a;
 update social_private.members set banned=true where id=a;
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value));if jsonb_array_length(out->'posts')<>0 then raise exception 'Banned author leaked through tag query';end if;
 update social_private.members set banned=false,nsfw_enabled=true where id=a;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Adult tag fixture','community','NSFW','tags',jsonb_build_array(tag_value)));secret_post:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value,'community','NSFW'));if out->>'code'is distinct from 'forbidden'then raise exception 'NSFW opt-out bypassed';end if;
 out:=public.social_gateway('posts.tag',ha,jsonb_build_object('tag',tag_value,'community','Texas A&M'));if jsonb_array_length(out->'posts')<>1 or out->'posts'->0->>'id'<>old_post::text then raise exception 'Community filter mixed adult/campus posts';end if;
 out:=public.social_gateway('posts.tag',ha,jsonb_build_object('tag',tag_value,'community','NSFW'));if jsonb_array_length(out->'posts')<>1 or out->'posts'->0->>'id'<>secret_post::text then raise exception 'Authorized adult tag missing';end if;
 out:=public.social_gateway('post.delete',ha,jsonb_build_object('post_id',old_post));
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',tag_value));if jsonb_array_length(out->'posts')<>0 then raise exception 'Deleted post retained in tag query';end if;
 insert into social_private.posts(author,nonce,body,tags,created_at)
 select c,gen_random_uuid(),'Cap fixture '||i,array[cap_tag],now()+interval '2 days'+i*interval '1 second'from generate_series(1,110)i;
 out:=public.social_gateway('posts.tag',hb,jsonb_build_object('tag',cap_tag,'limit',10000));
 if jsonb_array_length(out->'posts')<>100 or out->'posts'->0->>'text'<>'Cap fixture 110'or out->'posts'->99->>'text'<>'Cap fixture 11'then raise exception 'Newest100 tag bound violated';end if;
end $$;
select 'PASS old-post server discovery, newest100 bound, shared serializer/canonical votes, hidden/block/ban/deleted filtering and adult community isolation' result;
rollback;
