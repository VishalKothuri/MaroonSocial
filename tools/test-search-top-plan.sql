-- Query-plan checks for server search (20261008100000_post_search) and Top (20261008110000_feed_top).
-- LOCAL STACK ONLY: the checks need ANALYZE on seeded rows, and ANALYZE writes the table's page and
-- row estimates outside the transaction, so the rollback does not undo them. The file re-analyzes the
-- table after the rollback so the local estimates match the real rows again. Never run it against
-- the live project.
--
-- posts_search and feed_top are plpgsql, whose statements run with their variables as parameters
-- and (as long as they are cheaper) custom plans for the values given; the checks explain the same
-- predicates with values. 3,000 seeded rows and ANALYZE make the planner's choice the real one: no
-- planner overrides are needed.
begin;
create temporary table qa(k text primary key,v text) on commit drop;
do $$
declare hc text:=encode(extensions.gen_random_bytes(32),'hex');c uuid;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'search_plan_'||substr(hc,1,8),true,hc)returning id into c;
 insert into qa values('c',c),('tok','qp'||substr(md5(random()::text),1,10));
end $$;
insert into social_private.posts(author,nonce,community,body,topic,score,created_at)
 select (select v::uuid from qa where k='c'),gen_random_uuid(),(array['Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates'])[1+g%6],
  'Plan QA post '||g||' about '||md5(g::text)||case when g%500=0 then ' '||(select v from qa where k='tok') else '' end,
  (array['academics','aggie_life','questions','housing','sports','relationships','confessions','memes',null])[1+g%9],g%37,now()-make_interval(hours=>g)
 from generate_series(1,3000)g;
analyze social_private.posts;
do $$
declare plan text;me uuid:=(select v::uuid from qa where k='c');q tsquery:=social_private.post_search_query((select v from qa where k='tok'));
begin
 -- A search's text match (posts_search runs it as its own materialized step) walks the GIN index
 -- over the post text instead of parsing every post.
 execute format('explain (format json) select p from social_private.posts p where not p.deleted and social_private.post_search_document(p.body,p.tags)@@%L::tsquery',q) into plan;
 if strpos(plan,'"Index Name": "posts_search"')=0 or strpos(plan,'Seq Scan')>0 then raise exception 'Search does not use posts_search: %',plan;end if;
 -- With the community (and topic) applied in the same step, as posts_search runs it, the planner
 -- reads either the text index or the scope's own index, whichever reads fewer rows, never the table.
 execute format('explain (format json) select p,social_private.post_search_document(p.body,p.tags) from social_private.posts p where not p.deleted and social_private.post_search_document(p.body,p.tags)@@%L::tsquery and p.community=%L',q,'Juniors') into plan;
 if strpos(plan,'"Index Name"')=0 or strpos(plan,'Seq Scan')>0 then raise exception 'Search in a community scans the table: %',plan;end if;
 execute format('explain (format json) select p,social_private.post_search_document(p.body,p.tags) from social_private.posts p where not p.deleted and social_private.post_search_document(p.body,p.tags)@@%L::tsquery and p.community=%L and p.topic=%L',q,'Juniors','sports') into plan;
 if strpos(plan,'"Index Name"')=0 or strpos(plan,'Seq Scan')>0 then raise exception 'Search in a topic scans the table: %',plan;end if;
 if strpos(pg_get_functiondef('social_private.posts_search(uuid,jsonb)'::regprocedure),'with matched as materialized(')=0 then raise exception 'posts_search no longer isolates the text match';end if;
 -- Top, All time, one community: the first page reads posts_top in order (no sort of the community).
 execute format('explain (format json) select p.id from social_private.posts p where not p.deleted and p.community=%L and social_private.can_read_post(%L,p.id)
  order by p.score desc,p.created_at desc,p.id desc limit 21',
  'Juniors',me) into plan;
 if strpos(plan,'"Index Name": "posts_top"')=0 or strpos(plan,'"Node Type": "Sort"')>0 then raise exception 'Top (all time) does not walk posts_top: %',plan;end if;
 -- Top with a topic reads a topic index (posts_top_topic, or posts_topic_feed when the topic's
 -- rows in the window are few; either way the community is never scanned whole).
 execute format('explain (format json) select p.id from social_private.posts p where not p.deleted and p.community=%L and p.topic=%L and social_private.can_read_post(%L,p.id)
  order by p.score desc,p.created_at desc,p.id desc limit 21',
  'Juniors','sports',me) into plan;
 if (strpos(plan,'"Index Name": "posts_top_topic"')=0 and strpos(plan,'"Index Name": "posts_topic_feed"')=0) or strpos(plan,'Seq Scan')>0 then raise exception 'Top with a topic does not use a topic index: %',plan;end if;
 raise notice 'PASS search uses posts_search; Top pages walk posts_top in order and topic pages read a topic index (analyzed fixtures, no planner overrides)';
end $$;
rollback;
-- Restore the estimates to the real rows (ANALYZE is not undone by the rollback).
analyze social_private.posts;
