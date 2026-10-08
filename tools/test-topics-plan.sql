-- Query-plan checks for topic pages (20261006210000_topic_feed_sync). LOCAL STACK ONLY: the check
-- needs ANALYZE on seeded rows, and ANALYZE writes the table's page and row estimates outside the
-- transaction, so the rollback does not undo them. The file re-analyzes the table after the
-- rollback so the local estimates match the real rows again. Never run it against the live project.
--
-- feed_page is a SQL function with SET search_path, so it is not inlined and its statement gets a
-- generic plan; the checks prepare the function's own text (parameters renamed to $n) with a forced
-- generic plan. 3,000 seeded rows and ANALYZE make the planner's choice the real one: no planner
-- overrides are needed.
begin;
create temporary table qa(k text primary key,v text) on commit drop;
do $$
declare hc text:=encode(extensions.gen_random_bytes(32),'hex');c uuid;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'topic_plan_'||substr(hc,1,8),true,hc)returning id into c;
 insert into qa values('c',c);
end $$;
insert into social_private.posts(author,nonce,community,body,topic)
 select (select v::uuid from qa where k='c'),gen_random_uuid(),(array['Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates'])[1+g%6],'Plan QA '||g,
  (array['academics','aggie_life','questions','housing','sports','relationships','confessions','memes',null])[1+g%9]
 from generate_series(1,3000)g;
analyze social_private.posts;
do $$
declare src text;plan text;line text;executed int:=0;
begin
 select prosrc into src from pg_proc where oid='social_private.feed_page(uuid,text,timestamptz,uuid,integer,text)'::regprocedure;
 src:=regexp_replace(src,'\mp_me\M','$1','g');src:=regexp_replace(src,'\mp_community\M','$2','g');src:=regexp_replace(src,'\mp_before_created\M','$3','g');
 src:=regexp_replace(src,'\mp_before_id\M','$4','g');src:=regexp_replace(src,'\mp_limit\M','$5','g');src:=regexp_replace(src,'\mp_topic\M','$6','g');
 execute 'prepare qa_topic_page(uuid,text,timestamptz,uuid,integer,text) as '||src;
 set local plan_cache_mode=force_generic_plan;
 -- A topic page in one community walks posts_topic_feed.
 execute format('explain (format json) execute qa_topic_page(%L,%L,null,null,30,%L)',(select v from qa where k='c'),'Juniors','sports') into plan;
 if strpos(plan,'"Index Name": "posts_topic_feed"')=0 then raise exception 'Topic page does not use posts_topic_feed: %',plan;end if;
 -- With no community and no topic (callers that omit feed_community), only the All branch runs:
 -- the two topic branches are skipped by their one-time filters instead of scanning posts.
 for line in execute format('explain (analyze, costs off, timing off, summary off, format text) execute qa_topic_page(%L,null,null,null,30,null)',(select v from qa where k='c')) loop
  if line ~ 'Scan.* on posts [a-z_0-9]+' and line !~ 'never executed' then executed:=executed+1;end if;
 end loop;
 deallocate qa_topic_page;
 if executed<>1 then raise exception 'A page without community or topic ran % scans of posts (expected 1)',executed;end if;
 raise notice 'PASS topic page plan uses posts_topic_feed; topic branches are skipped without a topic (generic plan, analyzed fixtures, no planner overrides)';
end $$;
rollback;
-- Restore the estimates to the real rows (ANALYZE is not undone by the rollback).
analyze social_private.posts;
