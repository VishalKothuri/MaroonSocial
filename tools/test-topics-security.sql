-- Transactional checks for topic feeds (20261006200000_post_topics, 20261006210000_topic_feed_sync)
-- and the pre-post text filter (20261006220000_post_text_filter). Run as the database owner with
-- psql; everything rolls back and nothing outside the transaction changes. Gateway calls run as
-- service_role (the edge function's role); operator commands run as the owner. The query-plan
-- checks, which need ANALYZE, are in tools/test-topics-plan.sql (local stack only).
-- Inside one transaction now() is constant, so the 5-posts-per-15-minutes limit is stepped over by
-- ageing a member's earlier fixture posts (created_at moves no change marker).
begin;

-- Privileges -------------------------------------------------------------------------------------
do $$
declare fn text;
begin
 foreach fn in array array['social_private.topic_available(text,text)','social_private.topic_list(uuid,text)','social_private.post_set_topic(uuid,jsonb)',
  'social_private.feed_page(uuid,text,timestamptz,uuid,integer,text)','social_private.feed_delta(uuid,text,timestamptz,uuid[],text)','social_private.feed_posts(uuid,text,uuid[],text)',
  'social_private.text_filter_words(text)','social_private.text_filter_hit(text)','social_private.topic_backfill()','social_private.operator(text,jsonb,text)'] loop
  if has_function_privilege('anon',fn,'EXECUTE') or has_function_privilege('authenticated',fn,'EXECUTE') then raise exception 'Exposed to clients: %',fn;end if;
 end loop;
 if has_function_privilege('service_role','social_private.operator(text,jsonb,text)','EXECUTE') or has_function_privilege('service_role','social_private.topic_backfill()','EXECUTE') then raise exception 'Operator functions reachable by the app role';end if;
 if not has_function_privilege('service_role','social_private.topic_list(uuid,text)','EXECUTE') then raise exception 'Gateway cannot list topics';end if;
 if has_table_privilege('anon','social_private.topics','SELECT') or has_table_privilege('authenticated','social_private.topics','SELECT')
  or has_table_privilege('anon','social_private.text_filter_terms','SELECT') or has_table_privilege('authenticated','social_private.text_filter_terms','SELECT')
  or has_table_privilege('service_role','social_private.topics','UPDATE') or has_table_privilege('service_role','social_private.text_filter_terms','INSERT') then raise exception 'Topic or filter tables exposed';end if;
 if not (select relrowsecurity from pg_class where oid='social_private.topics'::regclass) or not (select relrowsecurity from pg_class where oid='social_private.text_filter_terms'::regclass) then raise exception 'RLS off on topic tables';end if;
 -- The catalog: 14 rows, the 8 launch topics active in order, uppercase hex.
 if (select count(*) from social_private.topics)<>14 or (select string_agg(slug,',' order by sort_order) from social_private.topics where active)<>'academics,aggie_life,questions,housing,sports,relationships,confessions,memes'
  or (select string_agg(slug,',' order by sort_order) from social_private.topics where not active)<>'food,events,careers,greek_life,mental_health,lost_found'
  or exists(select 1 from social_private.topics where text_hex!~'^#[0-9A-F]{6}$' or fill_hex!~'^#[0-9A-F]{6}$' or adult_only) then raise exception 'Topic catalog seed differs';end if;
 if (select count(*) from social_private.text_filter_terms)<5 or exists(select 1 from social_private.text_filter_terms where hash!~'^[0-9a-f]{64}$') then raise exception 'Filter seed missing or not hashed';end if;
 if not exists(select 1 from pg_indexes where schemaname='social_private' and indexname='posts_topic_feed') then raise exception 'posts_topic_feed missing';end if;
 raise notice 'PASS privileges, catalog seed and filter seed';
end $$;

-- An adult-only topic for the NSFW rule (rolled back).
insert into social_private.topics(slug,title,emoji,text_hex,fill_hex,sort_order,active,adult_only)values('qa_adult','QA Adult','🔞','#FFFFFF','#000000',99,true,true);

set local role service_role;
create temporary table qa(k text primary key,v text) on commit drop;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');hd text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;d uuid;out jsonb;page jsonb;cursor jsonb:='{}';obj jsonb;nonce uuid:=gen_random_uuid();i int;since double precision;he text;
 sports uuid[]:='{}';seen uuid[]:='{}';p_plain uuid;p_null uuid;p_house uuid;p_mov uuid;p_del uuid;p_hidden uuid;p_blocked uuid;p_old uuid;p_other uuid;p_adult uuid;stamp timestamptz;
 base jsonb;after jsonb;n int;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'topic_a_'||substr(ha,1,8),true,ha)returning id into a;insert into social_private.guidelines_acceptances(member,version)select a,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'topic_b_'||substr(hb,1,8),true,hb)returning id into b;insert into social_private.guidelines_acceptances(member,version)select b,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'topic_c_'||substr(hc,1,8),true,hc)returning id into c;insert into social_private.guidelines_acceptances(member,version)select c,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash,nsfw_enabled)values(hd,'topic_d_'||substr(hd,1,8),true,hd,true)returning id into d;insert into social_private.guidelines_acceptances(member,version)select d,required_version from social_private.guidelines_settings;
 insert into qa values('a',a),('b',b),('c',c),('d',d),('ha',ha),('hb',hb),('hc',hc),('hd',hd);
 base:=public.social_gateway('topics.list',hb,'{"community":"Juniors"}');
 if base?'error' then raise exception 'topics.list failed %',base;end if;

 -- post.create: unknown, inactive, non-string and adult-only-outside-NSFW topics are rejected.
 foreach obj in array array['{"topic":"nope"}','{"topic":"food"}','{"topic":5}','{"topic":["sports"]}','{"topic":"Sports"}','{"topic":"qa_adult"}']::jsonb[] loop
  out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Topic QA','community','Juniors')||obj);
  if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'Choose an available topic.' then raise exception 'Bad topic accepted % %',obj,out;end if;
 end loop;
 if exists(select 1 from social_private.posts where author=a) then raise exception 'A rejected topic created a post';end if;
 out:=public.social_gateway('post.create',hd,'{"text":"Adult topic QA","community":"NSFW","topic":"qa_adult"}');
 p_adult:=(out->>'resource_id')::uuid;
 if p_adult is null or (select topic from social_private.posts where id=p_adult)<>'qa_adult' then raise exception 'Adult-only topic refused in NSFW %',out;end if;
 -- Posts without a topic (older builds) are still accepted, with "topic": null in the JSON.
 out:=public.social_gateway('post.create',ha,'{"text":"No topic QA","community":"Juniors"}');p_plain:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',ha,'{"text":"Null topic QA","community":"Juniors","topic":null}');p_null:=(out->>'resource_id')::uuid;
 if p_plain is null or p_null is null or exists(select 1 from social_private.posts where id in(p_plain,p_null) and topic is not null) then raise exception 'Topicless post refused';end if;
 obj:=social_private.post_json(b,(select p from social_private.posts p where p.id=p_plain));
 if not obj?'topic' or jsonb_typeof(obj->'topic')<>'null' then raise exception 'Topicless post JSON lacks topic:null %',obj;end if;

 -- A nonce retry with the same topic returns the post; another or no topic is a conflict.
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Housing QA','community','Juniors','topic','housing','nonce',nonce));p_house:=(out->>'resource_id')::uuid;
 if p_house is null then raise exception 'Housing post failed %',out;end if;
 if (public.social_gateway('post.create',ha,jsonb_build_object('text','Housing QA','community','Juniors','topic','housing','nonce',nonce)))->>'resource_id' is distinct from p_house::text then raise exception 'Exact retry not idempotent';end if;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Housing QA','community','Juniors','topic','sports','nonce',nonce));
 if out->>'code' is distinct from 'conflict' then raise exception 'Retry with another topic accepted %',out;end if;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Housing QA','community','Juniors','nonce',nonce));
 if out->>'code' is distinct from 'conflict' then raise exception 'Retry without the topic accepted %',out;end if;
 obj:=social_private.post_json(b,(select p from social_private.posts p where p.id=p_house));
 if obj->>'topic' is distinct from 'housing' then raise exception 'Post JSON topic missing %',obj->'topic';end if;
 -- The snapshot projection carries it too.
 if not exists(select 1 from jsonb_array_elements(social_private.snapshot(b)->'posts')e where e->>'id'=p_house::text and e->>'topic'='housing') then raise exception 'Snapshot post lacks topic';end if;
 insert into qa values('p_house',p_house),('p_plain',p_plain),('p_adult',p_adult),('house_nonce',nonce);

 -- 80 Sports posts (direct inserts: the fixture is about paging, not posting limits).
 insert into social_private.posts(author,nonce,community,body,topic)select c,gen_random_uuid(),'Juniors','Sports QA '||g,'sports' from generate_series(1,80)g;
 select array_agg(id) into sports from social_private.posts where author=c and topic='sports';
 -- feed.page with a topic returns only that topic and pages past 30 without duplicates.
 for i in 1..10 loop
  page:=public.social_gateway('feed.page',hb,jsonb_build_object('community','Juniors','topic','sports','limit',30)||cursor);
  if page?'error' then raise exception 'Topic page failed %',page;end if;
  for obj in select value from jsonb_array_elements(page->'posts') loop
   if obj->>'topic' is distinct from 'sports' then raise exception 'Topic page returned another topic %',obj->>'topic';end if;
   if (obj->>'id')::uuid=any(seen) then raise exception 'Topic page repeated a post';end if;
   seen:=seen||(obj->>'id')::uuid;
  end loop;
  exit when jsonb_typeof(page->'next') is distinct from 'object';
  cursor:=page->'next';
 end loop;
 if cardinality(seen)<>80 or not sports<@seen or i<>3 then raise exception 'Topic paging wrong: % posts in % pages',cardinality(seen),i;end if;
 -- All (absent or null topic) still mixes topics; bad topics answer invalid.
 seen:='{}';cursor:='{}';
 for i in 1..10 loop
  page:=public.social_gateway('feed.page',hb,jsonb_build_object('community','Juniors','limit',50,'topic',null)||cursor);
  select seen||coalesce(array_agg((value->>'id')::uuid),'{}') into seen from jsonb_array_elements(page->'posts');
  exit when jsonb_typeof(page->'next') is distinct from 'object';
  cursor:=page->'next';
 end loop;
 if not(p_house=any(seen) and p_plain=any(seen) and sports<@seen) then raise exception 'All page filtered by topic';end if;
 foreach obj in array array['{"topic":"nope"}','{"topic":"food"}','{"topic":7}','{"topic":""}']::jsonb[] loop
  foreach out in array array[jsonb_build_object('a','feed.page'),jsonb_build_object('a','feed.delta','since',0),jsonb_build_object('a','feed.posts','ids',jsonb_build_array(p_house))] loop
   page:=public.social_gateway(out->>'a',hb,(out-'a')||jsonb_build_object('community','Juniors')||obj);
   if page->>'code' is distinct from 'invalid' or page->>'error' is distinct from 'Choose an available topic.' then raise exception '% accepted topic % %',out->>'a',obj,page;end if;
  end loop;
 end loop;
 raise notice 'PASS topic validation, nonce conflicts, JSON topic, topic paging (80 posts, 3 pages, no duplicates)';

 -- Deleting a post clears its stored topic (with its tags), so no topic-filtered read can reveal
 -- what it was about: the topic page drops it, a topic tab holding it gets it in "removed", and
 -- All still returns the deleted placeholder with topic:null.
 update social_private.posts set created_at=created_at-interval '15 minutes' where author=a;
 out:=public.social_gateway('post.create',ha,'{"text":"Delete me QA","community":"Juniors","topic":"memes","anonymous":true}');p_del:=(out->>'resource_id')::uuid;
 since:=extract(epoch from now())-60;
 out:=public.social_gateway('post.delete',ha,jsonb_build_object('post_id',p_del));
 if out?'error' then raise exception 'Delete failed %',out;end if;
 if (select topic from social_private.posts where id=p_del) is not null then raise exception 'post.delete kept the stored topic';end if;
 page:=public.social_gateway('feed.page',hb,'{"community":"Juniors","topic":"memes","limit":50}');
 if exists(select 1 from jsonb_array_elements(page->'posts')e where e->>'id'=p_del::text) then raise exception 'Deleted post still on its former topic page';end if;
 foreach obj in array array['"academics"','"aggie_life"','"questions"','"housing"','"sports"','"relationships"','"confessions"','"memes"']::jsonb[] loop
  page:=public.social_gateway('feed.posts',hb,jsonb_build_object('community','Juniors','topic',obj,'ids',jsonb_build_array(p_del)));
  if jsonb_array_length(page->'posts')<>0 then raise exception 'Topic % still returns the deleted post',obj;end if;
 end loop;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Juniors','topic','memes','since',since,'known_ids',jsonb_build_array(p_del)));
 if not page->'removed' ? p_del::text then raise exception 'Topic delta kept the deleted post %',page;end if;
 page:=public.social_gateway('feed.posts',hb,jsonb_build_object('community','Juniors','ids',jsonb_build_array(p_del)));
 obj:=page->'posts'->0;
 if obj is null or not (obj->>'deleted')::boolean or jsonb_typeof(obj->'topic')<>'null' then raise exception 'Deleted post topic not null in All %',obj;end if;
 -- Account deletion clears the topic of every one of the member's posts.
 he:=encode(extensions.gen_random_bytes(32),'hex');
 insert into social_private.members(token_hash,username,adult,network_hash)values(he,'topic_e_'||substr(he,1,8),true,he);insert into social_private.guidelines_acceptances(member,version)select (select id from social_private.members where token_hash=he),required_version from social_private.guidelines_settings;
 out:=public.social_gateway('post.create',he,'{"text":"Leaving QA","community":"Juniors","topic":"relationships"}');
 if out?'error' then raise exception 'Leaving member post failed %',out;end if;
 p_mov:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('account.delete',he);
 if out?'error' then raise exception 'Account delete failed %',out;end if;
 if (select topic from social_private.posts where id=p_mov) is not null then raise exception 'Account deletion kept a post topic';end if;
 -- No later write can put a topic back on a deleted post.
 update social_private.posts set topic='memes' where id=p_del;
 if (select topic from social_private.posts where id=p_del) is not null then raise exception 'A deleted post took a topic';end if;

 -- post.topic: only the author, only live posts, only available topics; clearing works.
 out:=public.social_gateway('post.topic',hb,jsonb_build_object('post_id',p_house,'topic','sports'));
 if out->>'code' is distinct from 'forbidden' then raise exception 'Another member retagged %',out;end if;
 out:=public.social_gateway('post.topic',ha,jsonb_build_object('post_id',p_del,'topic','sports'));
 if out->>'code' is distinct from 'forbidden' then raise exception 'Deleted post retagged %',out;end if;
 foreach obj in array array['{"topic":"food"}','{"topic":"nope"}','{"topic":3}','{"topic":"qa_adult"}','{}']::jsonb[] loop
  out:=public.social_gateway('post.topic',ha,jsonb_build_object('post_id',p_house)||obj);
  if out->>'code' is distinct from 'invalid' then raise exception 'post.topic accepted %: %',obj,out;end if;
 end loop;
 if (public.social_gateway('post.topic',ha,'{"post_id":"not-a-uuid","topic":"sports"}'))->>'code' is distinct from 'invalid' then raise exception 'Malformed post id accepted';end if;
 if (select topic from social_private.posts where id=p_house)<>'housing' then raise exception 'A rejected retag changed the post';end if;

 -- feed.delta and feed.posts with a topic report a post retagged away; the new tab gets it.
 page:=public.social_gateway('feed.page',hb,'{"community":"Juniors","topic":"sports","limit":50}');
 if exists(select 1 from jsonb_array_elements(page->'posts')e where e->>'id'=p_house::text) then raise exception 'Housing post on the Sports page';end if;
 update social_private.posts set changed_at=clock_timestamp()-interval '1 hour' where author in(a,c);
 since:=extract(epoch from now())-60;
 select changed_at into stamp from social_private.posts where id=p_house;
 out:=public.social_gateway('post.topic',ha,jsonb_build_object('post_id',p_house,'topic','sports'));
 if out?'error' or out->>'resource_id' is distinct from p_house::text then raise exception 'Author retag failed %',out;end if;
 if (select changed_at from social_private.posts where id=p_house)<=stamp then raise exception 'Retag did not move the change marker';end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Juniors','topic','housing','since',since,'known_ids',jsonb_build_array(p_house,p_plain)));
 if not page->'removed' ? p_house::text then raise exception 'Delta kept a retagged-away post %',page;end if;
 if page->'removed' ? p_plain::text then null;else raise exception 'Delta kept a topicless post in a topic tab';end if;
 if exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'topic' is distinct from 'housing') then raise exception 'Topic delta returned another topic';end if;
 -- Like All, a delta returns held or newer posts; an older post retagged in shows on the tab's next page.
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Juniors','topic','sports','since',since,'known_ids',jsonb_build_array(p_house)));
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=p_house::text and e->>'topic'='sports') then raise exception 'Retagged post missing from its new tab %',page;end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Juniors','since',since,'known_ids',jsonb_build_array(p_house)));
 if page->'removed' ? p_house::text or not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=p_house::text) then raise exception 'All delta mishandled a retag %',page;end if;
 page:=public.social_gateway('feed.posts',hb,jsonb_build_object('community','Juniors','topic','housing','ids',jsonb_build_array(p_house,sports[1])));
 if not(page->'removed' ? p_house::text and page->'removed' ? sports[1]::text) or jsonb_array_length(page->'posts')<>0 then raise exception 'Resync kept posts outside the topic %',page;end if;
 page:=public.social_gateway('feed.posts',hb,jsonb_build_object('community','Juniors','topic','sports','ids',jsonb_build_array(p_house,sports[1],p_plain)));
 if jsonb_array_length(page->'posts')<>2 or not page->'removed' ? p_plain::text or exists(select 1 from jsonb_array_elements(page->'posts')e where e->>'topic'<>'sports') then raise exception 'Topic resync wrong %',page;end if;
 -- Clearing the topic removes it from the topic tab too.
 out:=public.social_gateway('post.topic',ha,jsonb_build_object('post_id',p_house,'topic',null));
 if out?'error' or (select topic from social_private.posts where id=p_house) is not null then raise exception 'Clearing the topic failed %',out;end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Juniors','topic','sports','since',since,'known_ids',jsonb_build_array(p_house)));
 if not page->'removed' ? p_house::text then raise exception 'Cleared post kept in the topic tab';end if;
 out:=public.social_gateway('post.topic',ha,jsonb_build_object('post_id',p_house,'topic','housing'));
 raise notice 'PASS deleting a post or an account clears its topic, post.topic rules, delta and resync report retagged-away posts';

 -- topics.list: active topics in sort_order, counts of readable, live, recent posts only.
 update social_private.posts set created_at=created_at-interval '15 minutes' where author=a;
 out:=public.social_gateway('post.create',ha,'{"text":"Hidden QA","community":"Juniors","topic":"questions"}');p_hidden:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',ha,'{"text":"Visible QA","community":"Juniors","topic":"questions"}');
 out:=public.social_gateway('post.create',ha,'{"text":"Old QA","community":"Juniors","topic":"questions"}');p_old:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',ha,'{"text":"Other community QA","community":"Seniors","topic":"questions"}');p_other:=(out->>'resource_id')::uuid;
 update social_private.posts set created_at=now()-interval '8 days' where id=p_old;
 out:=public.social_gateway('report',hb,jsonb_build_object('target_type','post','target_id',p_hidden,'reason','Wrong topic'));
 if out?'error' then raise exception 'Report failed %',out;end if;
 if (select evidence->>'topic' from social_private.reports where target_id=p_hidden::text)<>'questions' then raise exception 'Report evidence lacks the topic';end if;
 insert into social_private.posts(author,nonce,community,body,topic)values(d,gen_random_uuid(),'Juniors','Blocked author QA','questions')returning id into p_blocked;
 out:=public.social_gateway('block',hb,jsonb_build_object('target_type','post','target_id',p_blocked));
 if out?'error' then raise exception 'Block failed %',out;end if;
 after:=public.social_gateway('topics.list',hb,'{"community":"Juniors"}');
 if jsonb_array_length(after->'topics')<>8 or (select string_agg(e->>'slug',',' order by o) from jsonb_array_elements(after->'topics')with ordinality x(e,o))<>'academics,aggie_life,questions,housing,sports,relationships,confessions,memes' then raise exception 'topics.list catalog wrong %',after;end if;
 obj:=after->'topics'->0;
 if not(obj?'slug' and obj?'title' and obj?'emoji' and obj?'text_hex' and obj?'fill_hex' and obj?'sort_order' and obj?'recent_count') or obj?'active' or obj?'adult_only' then raise exception 'topics.list shape %',obj;end if;
 -- questions: +1 (the visible one); hidden, blocked, old and other-community posts are not counted.
 select (x->>'recent_count')::int-(y->>'recent_count')::int into n from jsonb_array_elements(after->'topics')x,jsonb_array_elements(base->'topics')y where x->>'slug'='questions' and y->>'slug'='questions';
 if n<>1 then raise exception 'questions count moved by % (expected 1)',n;end if;
 -- sports: +80 (the fixtures; the retagged post went back to housing); memes: the deleted post is not counted.
 select (x->>'recent_count')::int-(y->>'recent_count')::int into n from jsonb_array_elements(after->'topics')x,jsonb_array_elements(base->'topics')y where x->>'slug'='sports' and y->>'slug'='sports';
 if n<>80 then raise exception 'sports count moved by % (expected 80)',n;end if;
 select (x->>'recent_count')::int-(y->>'recent_count')::int into n from jsonb_array_elements(after->'topics')x,jsonb_array_elements(base->'topics')y where x->>'slug'='memes' and y->>'slug'='memes';
 if n<>0 then raise exception 'A deleted post was counted';end if;
 -- The author counts the post someone else hid and the post of a member only that reader blocked: +3.
 if (select (x->>'recent_count')::int from jsonb_array_elements(public.social_gateway('topics.list',ha,'{"community":"Juniors"}')->'topics')x where x->>'slug'='questions')
   -(select (y->>'recent_count')::int from jsonb_array_elements(base->'topics')y where y->>'slug'='questions')<>3 then raise exception 'Author count wrong';end if;
 -- NSFW: adult-only topics are listed only there, and an unjoined member counts nothing there.
 if exists(select 1 from jsonb_array_elements(after->'topics')e where e->>'slug'='qa_adult') then raise exception 'Adult topic listed outside NSFW';end if;
 out:=public.social_gateway('topics.list',hb,'{"community":"NSFW"}');
 if not exists(select 1 from jsonb_array_elements(out->'topics')e where e->>'slug'='qa_adult' and (e->>'recent_count')::int=0) then raise exception 'Unjoined member counted adult posts %',out;end if;
 out:=public.social_gateway('topics.list',hd,'{"community":"NSFW"}');
 if not exists(select 1 from jsonb_array_elements(out->'topics')e where e->>'slug'='qa_adult' and (e->>'recent_count')::int>=1) then raise exception 'Joined member adult count missing %',out;end if;
 if (public.social_gateway('topics.list',hb,'{"community":"Elsewhere"}'))->>'code' is distinct from 'invalid' then raise exception 'topics.list accepted an unknown community';end if;
 raise notice 'PASS topics.list order, shape and counts (hidden, blocked, deleted, old, other-community and unjoined NSFW excluded), report evidence';

 -- 5 posts per 15 minutes, on top of the 10-per-minute burst, with the same copy.
 update social_private.posts set created_at=created_at-interval '15 minutes' where author=b;
 for i in 1..5 loop
  out:=public.social_gateway('post.create',hb,jsonb_build_object('text','Rate QA '||i,'community','Juniors','topic','memes'));
  if out?'error' then raise exception 'Post % of 5 refused %',i,out;end if;
 end loop;
 out:=public.social_gateway('post.create',hb,'{"text":"Rate QA 6","community":"Juniors","topic":"memes"}');
 if out->>'code' is distinct from 'rate_limit' or out->>'error' is distinct from 'Take a moment before posting again.' then raise exception 'Sixth post in 15 minutes accepted %',out;end if;
 update social_private.posts set created_at=created_at-interval '16 minutes' where author=b;
 out:=public.social_gateway('post.create',hb,'{"text":"Rate QA later","community":"Juniors","topic":"memes"}');
 if out?'error' then raise exception 'Post after the window refused %',out;end if;
 raise notice 'PASS 5 posts per 15 minutes';
 insert into qa values('since',since::text);
end $$;

-- Operator commands (owner only) ------------------------------------------------------------------
reset role;
do $$
declare a uuid:=(select v from qa where k='a');p_house uuid:=(select v from qa where k='p_house');out jsonb;
begin
 begin perform social_private.operator('topic.set',jsonb_build_object('post_id',p_house,'topic','memes','note','x'),'qa');raise exception 'unreviewed';
 exception when raise_exception then if sqlerrm='unreviewed' then raise exception 'Operator retag without review note accepted';end if;end;
 begin perform social_private.operator('topic.set',jsonb_build_object('post_id',p_house,'topic','food','note','Inactive topic check'),'topic-qa');raise exception 'inactive';
 exception when raise_exception then if sqlerrm='inactive' then raise exception 'Operator set an inactive topic';end if;end;
 out:=social_private.operator('topic.set',jsonb_build_object('post_id',p_house,'topic','memes','note','Moved by QA review'),'topic-qa');
 if not (out->>'applied')::boolean or (select topic from social_private.posts where id=p_house)<>'memes' then raise exception 'Operator retag failed %',out;end if;
 out:=social_private.operator('topic.set',jsonb_build_object('post_id',p_house,'topic',null,'note','Cleared by QA review'),'topic-qa');
 if (select topic from social_private.posts where id=p_house) is not null then raise exception 'Operator clear failed';end if;
 out:=social_private.operator('topic.set',jsonb_build_object('post_id',p_house,'topic','housing','note','Restored by QA review'),'topic-qa');
 out:=social_private.operator('topic.disable',jsonb_build_object('slug','housing','note','Disable for QA'),'topic-qa');
 if (select active from social_private.topics where slug='housing') then raise exception 'topic.disable failed';end if;
 if (select count(*) from social_private.operator_audit where reviewer='topic-qa' and target=p_house::text and action like 'topic.set:%')<>3
  or not exists(select 1 from social_private.operator_audit where reviewer='topic-qa' and action='topic.disable' and target='housing') then raise exception 'Operator topic commands not audited';end if;
 begin perform social_private.operator('topic.enable',jsonb_build_object('slug','nope','note','Unknown topic check'),'topic-qa');raise exception 'unknown';
 exception when raise_exception then if sqlerrm='unknown' then raise exception 'Unknown topic enabled';end if;end;
 -- A synthetic denylist word (only its hash goes in).
 out:=social_private.operator('filter.add',jsonb_build_object('hash',encode(sha256(convert_to('zqxfilterword','UTF8')),'hex'),'note','QA filter term'),'topic-qa');
 if not exists(select 1 from social_private.operator_audit where action='filter.add' and target=encode(sha256(convert_to('zqxfilterword','UTF8')),'hex')) then raise exception 'filter.add not audited by hash';end if;
 begin perform social_private.operator('filter.add',jsonb_build_object('hash','zqxfilterword','note','Plain words are refused'),'topic-qa');raise exception 'plain';
 exception when raise_exception then if sqlerrm='plain' then raise exception 'A plain denylist word was stored';end if;end;
 if exists(select 1 from social_private.operator_audit where reason like '%zqxfilterword%' or target like '%zqxfilterword%') then raise exception 'Plain word reached the audit';end if;
 raise notice 'PASS operator topic.set/disable/enable and filter.add are audited and need a review note';
end $$;

set local role service_role;
do $$
declare ha text:=(select v from qa where k='ha');hb text:=(select v from qa where k='hb');a uuid:=(select v from qa where k='a');b uuid:=(select v from qa where k='b');
 p_house uuid:=(select v from qa where k='p_house');p_plain uuid:=(select v from qa where k='p_plain');out jsonb;page jsonb;obj jsonb;nonce uuid:=gen_random_uuid();
begin
 -- A disabled topic is refused for posting, reading and retagging, and leaves topics.list.
 if (public.social_gateway('post.create',ha,'{"text":"Disabled QA","community":"Juniors","topic":"housing"}'))->>'code' is distinct from 'invalid' then raise exception 'Disabled topic accepted for posts';end if;
 if (public.social_gateway('feed.page',hb,'{"community":"Juniors","topic":"housing"}'))->>'code' is distinct from 'invalid' then raise exception 'Disabled topic page served';end if;
 if exists(select 1 from jsonb_array_elements(public.social_gateway('topics.list',hb,'{"community":"Juniors"}')->'topics')e where e->>'slug'='housing') then raise exception 'Disabled topic listed';end if;
 -- Its posts keep their topic and still show it.
 if (social_private.post_json(b,(select p from social_private.posts p where p.id=p_house)))->>'topic'<>'housing' then raise exception 'Disabling dropped the post topic';end if;
 -- A nonce retry of a post created before the topic was disabled returns that post (the client
 -- would otherwise make the member pick another topic and post a duplicate).
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Housing QA','community','Juniors','topic','housing','nonce',(select v from qa where k='house_nonce')));
 if out->>'resource_id' is distinct from p_house::text then raise exception 'Retry after topic.disable refused %',out;end if;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Housing QA','community','Juniors','topic','sports','nonce',(select v from qa where k='house_nonce')));
 if out->>'code' is distinct from 'conflict' then raise exception 'Retry with another topic after topic.disable accepted %',out;end if;

 -- Text filter: whole normalized words only, in posts (text, poll, tags) and replies.
 update social_private.posts set created_at=created_at-interval '15 minutes' where author=a;
 foreach obj in array array['{"text":"this has zqxfilterword in it"}','{"text":"ZQXFilterWord!"}','{"text":"well...zqxfilterword,ok"}','{"text":"Poll QA","poll":{"question":"Is zqxfilterword ok?","options":["yes","no"],"duration_hours":24}}',
  '{"text":"Poll QA","poll":{"question":"Pick one","options":["fine","zqxfilterword"],"duration_hours":24}}','{"text":"Tag QA","tags":["zqxfilterword"]}']::jsonb[] loop
  out:=public.social_gateway('post.create',ha,jsonb_build_object('community','Juniors','topic','memes')||obj);
  if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'This post includes language that isn''t allowed here.' then raise exception 'Filtered post accepted % %',obj,out;end if;
 end loop;
 if exists(select 1 from social_private.posts where author=a and body ilike '%zqxfilterword%') then raise exception 'Filtered post stored';end if;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('community','Juniors','topic','memes','text','prezqxfilterword and zqxfilterwords are different words','nonce',nonce));
 if out?'error' then raise exception 'Substring triggered the filter %',out;end if;
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',p_plain,'text','reply with Zqxfilterword.'));
 if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'This reply includes language that isn''t allowed here.' then raise exception 'Filtered reply accepted %',out;end if;
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',p_plain,'text','reply with zqxfilterwordy'));
 if out?'error' then raise exception 'Substring triggered the reply filter %',out;end if;
 if not social_private.text_filter_words('A-b_c d1 D1')@>array['a','b','c','d1'] or cardinality(social_private.text_filter_words('A-b_c d1 D1'))<>4 then raise exception 'Normalization changed';end if;
 insert into qa values('nonce',nonce);
 raise notice 'PASS disabled topic refused and unlisted (an existing post''s retry still returns it), text filter on whole words in posts, polls, tags and replies';
end $$;

reset role;
do $$
declare out jsonb;
begin
 out:=social_private.operator('filter.remove',jsonb_build_object('hash',encode(sha256(convert_to('zqxfilterword','UTF8')),'hex'),'note','QA filter cleanup'),'topic-qa');
 if exists(select 1 from social_private.text_filter_terms where hash=encode(sha256(convert_to('zqxfilterword','UTF8')),'hex')) then raise exception 'filter.remove failed';end if;
 out:=social_private.operator('topic.enable',jsonb_build_object('slug','housing','note','Enable after QA'),'topic-qa');
end $$;

set local role service_role;
do $$
declare ha text:=(select v from qa where k='ha');a uuid:=(select v from qa where k='a');out jsonb;
begin
 update social_private.posts set created_at=created_at-interval '15 minutes' where author=a;
 out:=public.social_gateway('post.create',ha,'{"text":"zqxfilterword is allowed again","community":"Juniors","topic":"housing"}');
 if out?'error' then raise exception 'Removed term still filtered or enabled topic refused %',out;end if;
end $$;

-- Backfill: only active slugs or approved aliases, first match in tag order, live posts only.
reset role;
do $$
declare c uuid:=(select v from qa where k='c');p1 uuid;p2 uuid;p3 uuid;p4 uuid;p5 uuid;p6 uuid;p7 uuid;
begin
 insert into social_private.posts(author,nonce,community,body,tags)values(c,gen_random_uuid(),'Juniors','bf1',array['random','roommates','sports'])returning id into p1;
 insert into social_private.posts(author,nonce,community,body,tags)values(c,gen_random_uuid(),'Juniors','bf2',array['food','memes'])returning id into p2;
 insert into social_private.posts(author,nonce,community,body,tags)values(c,gen_random_uuid(),'Juniors','bf3',array['food','studying'])returning id into p3;
 insert into social_private.posts(author,nonce,community,body,tags,deleted)values(c,gen_random_uuid(),'Juniors','',array['housing'],true)returning id into p4;
 insert into social_private.posts(author,nonce,community,body,tags,topic)values(c,gen_random_uuid(),'Juniors','bf5',array['sports'],'memes')returning id into p5;
 insert into social_private.posts(author,nonce,community,body,tags)values(c,gen_random_uuid(),'Juniors','bf6',array['gameday'])returning id into p6;
 insert into social_private.posts(author,nonce,community,body,tags)values(c,gen_random_uuid(),'Juniors','bf7',array['qa_adult'])returning id into p7;
 perform social_private.topic_backfill();
 if (select topic from social_private.posts where id=p1) is distinct from 'housing' or (select topic from social_private.posts where id=p2) is distinct from 'memes'
  or (select topic from social_private.posts where id=p3) is not null or (select topic from social_private.posts where id=p4) is not null
  or (select topic from social_private.posts where id=p5) is distinct from 'memes' or (select topic from social_private.posts where id=p6) is distinct from 'sports'
  or (select topic from social_private.posts where id=p7) is not null then raise exception 'Backfill rule wrong';end if;
 raise notice 'PASS backfill uses active slugs and approved aliases only, first match, live untagged posts only';
end $$;

rollback;
