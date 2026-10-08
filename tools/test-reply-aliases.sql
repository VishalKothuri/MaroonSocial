-- Transactional checks for anonymous reply names (social_private.comment_json, as comments.page
-- returns them). Run as the database owner with psql; everything rolls back. Gateway calls run as
-- service_role (the edge function's role).
-- An anonymous reply is shown as "Aggie xxxx": the same person keeps one name within a post, gets a
-- different name on another post, and every reader sees the same name. The post's author shows as
-- "OP", a named reply shows its username, and a reader's own replies show their own username.
begin;
set local role service_role;
do $$
declare
 ho text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 o uuid;b uuid;c uuid;p1 uuid;p2 uuid;out jsonb;mine jsonb;theirs jsonb;alias1 text;alias2 text;bname text;cname text;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ho,'alias_o_'||substr(ho,1,8),true,ho)returning id into o;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'alias_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'alias_c_'||substr(hc,1,8),true,hc)returning id into c;
 insert into social_private.guidelines_acceptances(member,version)select m,required_version from social_private.guidelines_settings,unnest(array[o,b,c])m;
 bname:='alias_b_'||substr(hb,1,8);cname:='alias_c_'||substr(hc,1,8);

 out:=public.social_gateway('post.create',ho,'{"text":"Alias QA first post","anonymous":true}');if out?'error' then raise exception 'Post 1 %',out;end if;p1:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',ho,'{"text":"Alias QA second post","anonymous":true}');if out?'error' then raise exception 'Post 2 %',out;end if;p2:=(out->>'resource_id')::uuid;
 -- b replies twice on post 1 and once on post 2 (anonymous by default), plus one named reply.
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',p1,'text','b first reply'));if out?'error' then raise exception 'Reply %',out;end if;
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',p1,'text','b second reply'));if out?'error' then raise exception 'Reply %',out;end if;
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',p2,'text','b on the second post'));if out?'error' then raise exception 'Reply %',out;end if;
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',p1,'text','b named reply','anonymous',false));if out?'error' then raise exception 'Named reply %',out;end if;
 -- The author replies on their own anonymous post; c replies too.
 out:=public.social_gateway('comment.create',ho,jsonb_build_object('post_id',p1,'text','op reply'));if out?'error' then raise exception 'OP reply %',out;end if;
 out:=public.social_gateway('comment.create',hc,jsonb_build_object('post_id',p1,'text','c reply'));if out?'error' then raise exception 'c reply %',out;end if;

 -- Reader c, post 1.
 out:=public.social_gateway('comments.page',hc,jsonb_build_object('post_id',p1));if out?'error' then raise exception 'Page %',out;end if;
 select jsonb_object_agg(value->>'text',value->>'author')into theirs from jsonb_array_elements(out->'comments');
 alias1:=theirs->>'b first reply';
 if alias1 !~ '^Aggie [0-9a-f]{4}$' then raise exception 'Anonymous reply is not an alias: %',theirs;end if;
 if theirs->>'b second reply' is distinct from alias1 then raise exception 'Same person, same post, different names: %',theirs;end if;
 if alias1 is distinct from 'Aggie '||substr(md5(p1::text||b::text),1,4) then raise exception 'Alias is not the per-post name: %',alias1;end if;
 if theirs->>'b named reply' is distinct from bname then raise exception 'Named reply lost its username: %',theirs;end if;
 if theirs->>'op reply' is distinct from 'OP' then raise exception 'Author not shown as OP: %',theirs;end if;
 if theirs->>'c reply' is distinct from cname then raise exception 'Own reply not shown with own username: %',theirs;end if;
 if exists(select 1 from jsonb_array_elements(out->'comments') where value->>'text' in('b first reply','b second reply') and (value->>'anonymous')::boolean is not true) then raise exception 'Alias reply not marked anonymous';end if;

 -- Reader c, post 2: b has a different name there.
 out:=public.social_gateway('comments.page',hc,jsonb_build_object('post_id',p2));if out?'error' then raise exception 'Page %',out;end if;
 select value->>'author' into alias2 from jsonb_array_elements(out->'comments') where value->>'text'='b on the second post';
 if alias2 !~ '^Aggie [0-9a-f]{4}$' or alias2 is distinct from 'Aggie '||substr(md5(p2::text||b::text),1,4) then raise exception 'Second post alias wrong: %',alias2;end if;
 -- Four hex digits can collide by chance (1 in 65,536); the names differ whenever the hashes do.
 if alias2=alias1 and substr(md5(p1::text||b::text),1,4)<>substr(md5(p2::text||b::text),1,4) then raise exception 'Same name on two posts: %',alias1;end if;

 -- Another reader (the author) sees the same alias; b sees their own replies under their username.
 out:=public.social_gateway('comments.page',ho,jsonb_build_object('post_id',p1));
 select jsonb_object_agg(value->>'text',value->>'author')into theirs from jsonb_array_elements(out->'comments');
 if theirs->>'b first reply' is distinct from alias1 or theirs->>'b second reply' is distinct from alias1 then raise exception 'Alias depends on the reader: %',theirs;end if;
 if theirs->>'op reply' is distinct from 'alias_o_'||substr(ho,1,8) then raise exception 'OP does not see own username: %',theirs;end if;
 out:=public.social_gateway('comments.page',hb,jsonb_build_object('post_id',p1));
 select jsonb_object_agg(value->>'text',value->>'author')into mine from jsonb_array_elements(out->'comments');
 if mine->>'b first reply' is distinct from bname or mine->>'b second reply' is distinct from bname then raise exception 'Own anonymous replies not shown with own username: %',mine;end if;
 if mine->>'c reply' is not distinct from cname or mine->>'c reply' !~ '^Aggie [0-9a-f]{4}$' then raise exception 'Other reply not an alias for b: %',mine;end if;

 -- The post's embedded replies (feed.posts) use the same names.
 out:=public.social_gateway('feed.posts',hc,jsonb_build_object('ids',jsonb_build_array(p1)));
 if out?'error' then raise exception 'feed.posts %',out;end if;
 if not exists(select 1 from jsonb_array_elements(out->'posts')p,jsonb_array_elements(p.value->'comments')r where r.value->>'text'='b first reply' and r.value->>'author'=alias1)
 then raise exception 'Embedded replies use a different name: %',out;end if;
end $$;
select 'PASS reply aliases: one name per person per post, a different name on another post, the same for every reader, OP, named and own replies' result;
rollback;
