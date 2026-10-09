-- Transactional checks for server search (20261008100000_post_search, gateway action posts.search).
-- Run as the database owner with psql; everything rolls back. Fixture posts are inserted as the owner
-- (no post rate limit); searches run as service_role (the edge function's role) through the gateway.
-- Every fixture post carries a word unique to this run, so existing rows never match.
begin;

do $$
declare fn text;
begin
 foreach fn in array array['social_private.post_search_document(text,text[])','social_private.post_search_query(text)','social_private.feed_scope(jsonb)',
  'social_private.page_cursor_stamp(timestamptz)','social_private.page_cursor_time(jsonb)','social_private.page_cursor_id(jsonb)','social_private.page_cursor_int(jsonb)',
  'social_private.posts_search(uuid,jsonb)'] loop
  if has_function_privilege('anon',fn,'EXECUTE') or has_function_privilege('authenticated',fn,'EXECUTE') then raise exception 'Exposed to clients: %',fn;end if;
  if not has_function_privilege('service_role',fn,'EXECUTE') then raise exception 'Gateway role cannot run %',fn;end if;
 end loop;
 if has_table_privilege('anon','social_private.search_requests','SELECT') or has_table_privilege('authenticated','social_private.search_requests','SELECT')
  or has_table_privilege('service_role','social_private.search_requests','UPDATE') then raise exception 'search_requests exposed';end if;
 if not (select relrowsecurity from pg_class where oid='social_private.search_requests'::regclass) then raise exception 'RLS off on search_requests';end if;
 if not exists(select 1 from pg_indexes where schemaname='social_private' and indexname='posts_search' and indexdef like '%gin%post_search_document(body, tags)%WHERE (NOT deleted)%') then raise exception 'posts_search index missing or different';end if;
 -- The document holds the post's own words only: no author, username or anonymity column.
 if (select pg_get_function_identity_arguments('social_private.post_search_document(text,text[])'::regprocedure))<>'p_body text, p_tags text[]' then raise exception 'Search document takes more than body and tags';end if;
 raise notice 'PASS privileges, RLS and the body-and-tags index';
end $$;

create temporary table qa(k text primary key,v text) on commit drop;
grant all on qa to service_role;
do $$
declare
 tok text:='qs'||substr(md5(random()::text),1,10);
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 hd text:=encode(extensions.gen_random_bytes(32),'hex');he text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;d uuid;e uuid;i int;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'srch_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'srch_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'srch_c_'||substr(hc,1,8),true,hc)returning id into c;
 insert into social_private.members(token_hash,username,adult,network_hash,nsfw_enabled)values(hd,'srch_d_'||substr(hd,1,8),true,hd,true)returning id into d;
 insert into social_private.members(token_hash,username,adult,network_hash)values(he,'srch_e_'||substr(he,1,8),true,he)returning id into e;
 insert into qa values('tok',tok),('a',a),('b',b),('c',c),('d',d),('e',e),('ha',ha),('hb',hb),('hc',hc),('hd',hd),('he',he),('ua','srch_a_'||substr(ha,1,8));
 -- a's posts in Juniors: anonymous and named, a prefix word, a stemmed word, a tag-only match, a topic.
 with x as(insert into social_private.posts(author,nonce,community,body,anonymous,topic,created_at)values(a,gen_random_uuid(),'Juniors','Notes on '||tok||' calculus midterm, studying all night',true,'academics',now()-interval '1 hour')returning id) insert into qa select 'anon',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body,anonymous,created_at)values(a,gen_random_uuid(),'Juniors','Named '||tok||' post about dorms',false,now()-interval '2 hours')returning id) insert into qa select 'named',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body,tags,created_at)values(a,gen_random_uuid(),'Juniors','Only the tag matches here',array[tok||'tag'],now()-interval '3 hours')returning id) insert into qa select 'tagged',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body,topic,created_at)values(a,gen_random_uuid(),'Juniors',tok||' tailgate plans','sports',now()-interval '4 hours')returning id) insert into qa select 'sports',id::text from x;
 -- Repeating the word ranks a post above the others.
 with x as(insert into social_private.posts(author,nonce,community,body,created_at)values(a,gen_random_uuid(),'Juniors',tok||' '||tok||' '||tok||' everything about it',now()-interval '30 days')returning id) insert into qa select 'strong',id::text from x;
 -- Excluded for b: blocked author, hidden by b, deleted (body kept on purpose), NSFW, another community.
 with x as(insert into social_private.posts(author,nonce,community,body)values(c,gen_random_uuid(),'Juniors','Blocked author '||tok)returning id) insert into qa select 'blocked',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body)values(a,gen_random_uuid(),'Juniors','Hidden by the reader '||tok)returning id) insert into qa select 'hidden',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body,deleted)values(a,gen_random_uuid(),'Juniors','Deleted '||tok,true)returning id) insert into qa select 'deleted',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body)values(d,gen_random_uuid(),'NSFW','Adult '||tok)returning id) insert into qa select 'nsfw',id::text from x;
 with x as(insert into social_private.posts(author,nonce,community,body)values(a,gen_random_uuid(),'Seniors','Seniors '||tok)returning id) insert into qa select 'seniors',id::text from x;
 insert into social_private.blocks values(b,c);
 insert into social_private.hidden(member,post)values(b,(select v::uuid from qa where k='hidden'));
 -- 45 equal-rank posts for paging (Freshmen), with distinct and with equal timestamps.
 for i in 1..45 loop
  insert into social_private.posts(author,nonce,community,body,created_at)values(a,gen_random_uuid(),'Freshmen','Paging '||tok||' row',now()-make_interval(mins=>i/3));
 end loop;
end $$;

set local role service_role;
do $$
declare
 tok text:=(select v from qa where k='tok');ha text:=(select v from qa where k='ha');hb text:=(select v from qa where k='hb');hd text:=(select v from qa where k='hd');he text:=(select v from qa where k='he');
 b uuid:=(select v::uuid from qa where k='b');e uuid:=(select v::uuid from qa where k='e');
 out jsonb;ids text[];feed text[];cursor jsonb;seen text[]:='{}';pages int:=0;n int;bad jsonb;
begin
 -- b in Juniors: the strong post first, then newest-first among equal ranks; nothing excluded leaks.
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok));
 if out?'error' then raise exception 'search failed %',out;end if;
 select array_agg(x->>'id' order by o) into ids from jsonb_array_elements(out->'posts')with ordinality t(x,o);
 if ids[1] is distinct from (select v from qa where k='strong') then raise exception 'Relevance order wrong %',ids;end if;
 if not ids@>array[(select v from qa where k='anon'),(select v from qa where k='named'),(select v from qa where k='tagged'),(select v from qa where k='sports')] then raise exception 'Expected matches missing %',ids;end if;
 if ids&&array(select v from qa where k in('blocked','hidden','deleted','nsfw','seniors')) then raise exception 'Excluded post returned %',ids;end if;
 if (out->>'more')::boolean or jsonb_typeof(out->'cursor')<>'null' or cardinality(ids)<>5 then raise exception 'Single page shape wrong %',out-'posts';end if;
 if array_position(ids,(select v from qa where k='anon'))>array_position(ids,(select v from qa where k='named')) then raise exception 'Equal ranks not newest first %',ids;end if;
 -- Results are built by post_json: the anonymous post shows "Anonymous", with the documented keys.
 if (select x from jsonb_array_elements(out->'posts')x where x->>'id'=(select v from qa where k='anon'))->>'author'<>'Anonymous'
  or not (out->'posts'->0)?&array['id','author','anonymous','community','text','score','vote','created','topic','comments','commentCount'] then raise exception 'Not post_json %',out->'posts'->0;end if;
 -- Feed parity: every live Juniors post with the word that b's feed shows is found, and nothing else.
 select array_agg(x->>'id') into feed from jsonb_array_elements(public.social_gateway('feed.page',hb,'{"community":"Juniors","limit":50}')->'posts')x
  where not (x->>'deleted')::boolean and x->>'id' in(select v from qa where k in('anon','named','tagged','sports','strong','blocked','hidden','deleted','nsfw','seniors'));
 if not (feed@>ids and ids@>feed) then raise exception 'Search visibility differs from the feed: search % feed %',ids,feed;end if;
 -- The blocked author's post is found by its author's other readers.
 if not exists(select 1 from jsonb_array_elements(public.social_gateway('posts.search',ha,jsonb_build_object('community','Juniors','query',tok))->'posts')x where x->>'id'=(select v from qa where k='blocked')) then raise exception 'Unblocked reader misses the post';end if;
 raise notice 'PASS relevance then newest, feed visibility (blocked, hidden, deleted, NSFW, other community), post_json results';

 -- Author identity is never matched: a's username finds neither the anonymous nor the named post.
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',(select v from qa where k='ua')));
 if out?'error' or jsonb_array_length(out->'posts')<>0 then raise exception 'Username matched a post %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok||' Anonymous'));
 if jsonb_array_length(out->'posts')<>0 then raise exception 'Anonymity flag matched %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query','Aggie '||tok));
 if jsonb_array_length(out->'posts')<>0 then raise exception 'Alias word matched %',out;end if;
 raise notice 'PASS usernames, anonymity and aliases are never matched';

 -- Prefix, stems, tags, topic, case and whitespace.
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok||' calc'));
 if (select array_agg(x->>'id') from jsonb_array_elements(out->'posts')x)<>array[(select v from qa where k='anon')] then raise exception 'Prefix search wrong %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',E'\t  '||upper(tok)||' STUDIES \n'));
 if (select array_agg(x->>'id') from jsonb_array_elements(out->'posts')x)<>array[(select v from qa where k='anon')] then raise exception 'Stem search wrong %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok||'tag'));
 if (select array_agg(x->>'id') from jsonb_array_elements(out->'posts')x)<>array[(select v from qa where k='tagged')] then raise exception 'Tag search wrong %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok,'topic','sports'));
 if (select array_agg(x->>'id') from jsonb_array_elements(out->'posts')x)<>array[(select v from qa where k='sports')] then raise exception 'Topic filter wrong %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query','?!'));
 if out?'error' or jsonb_array_length(out->'posts')<>0 or (out->>'more')::boolean then raise exception 'Punctuation-only search wrong %',out;end if;
 raise notice 'PASS prefix, stem, tag, topic, case and whitespace';

 -- Community scope: absent community searches every readable community; NSFW only for the opted-in.
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('query',tok||' seniors'));
 if (select array_agg(x->>'id') from jsonb_array_elements(out->'posts')x)<>array[(select v from qa where k='seniors')] then raise exception 'All-communities scope wrong %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok||' seniors'));
 if jsonb_array_length(out->'posts')<>0 then raise exception 'Another community leaked %',out;end if;
 foreach bad in array array['{}','{"community":null}','{"community":"NSFW"}']::jsonb[] loop
  out:=public.social_gateway('posts.search',hb,bad||jsonb_build_object('query',tok||' adult'));
  if out?'error' or jsonb_array_length(out->'posts')<>0 then raise exception 'NSFW post found without the opt-in % %',bad,out;end if;
 end loop;
 out:=public.social_gateway('posts.search',hd,jsonb_build_object('query',tok||' adult'));
 if (select array_agg(x->>'id') from jsonb_array_elements(out->'posts')x)<>array[(select v from qa where k='nsfw')] then raise exception 'NSFW member cannot find the NSFW post %',out;end if;
 raise notice 'PASS community scope and NSFW gating';

 -- Paging: 45 equal-rank posts, 20 + 20 + 5, no duplicates, newest first, cursor only while more.
 cursor:=null;
 loop
  out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Freshmen','query',tok,'limit',20)||case when cursor is null then '{}'::jsonb else jsonb_build_object('cursor',cursor)end);
  if out?'error' then raise exception 'page failed %',out;end if;
  pages:=pages+1;n:=jsonb_array_length(out->'posts');
  if (select bool_or(x->>'id'=any(seen)) from jsonb_array_elements(out->'posts')x) then raise exception 'Duplicate across pages on page %',pages;end if;
  seen:=seen||array(select x->>'id' from jsonb_array_elements(out->'posts')x);
  if (out->>'more')::boolean<>(jsonb_typeof(out->'cursor')='object') then raise exception 'more and cursor disagree %',out-'posts';end if;
  if not (out->>'more')::boolean then exit;end if;
  if n<>20 or not (out->'cursor')?&array['rank','created','id'] then raise exception 'Page shape wrong %',out->'cursor';end if;
  cursor:=out->'cursor';
  exit when pages>5;
 end loop;
 if pages<>3 or cardinality(seen)<>45 or n<>5 then raise exception 'Paging wrong pages % rows % last %',pages,cardinality(seen),n;end if;
 if exists(select 1 from unnest(seen)with ordinality s(id,o) join social_private.posts p on p.id=s.id::uuid join unnest(seen)with ordinality s2(id,o) on s2.o=s.o+1 join social_private.posts q on q.id=s2.id::uuid
  where (p.created_at,p.id)<(q.created_at,q.id)) then raise exception 'Pages not newest first';end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Freshmen','query',tok,'limit',500));
 if jsonb_array_length(out->'posts')<>30 then raise exception 'Limit not clamped to 30 (%)',jsonb_array_length(out->'posts');end if;
 raise notice 'PASS paging without duplicates and the 30-post page cap';

 -- Input validation.
 foreach bad in array array['{"community":"Juniors"}','{"community":"Juniors","query":5}','{"community":"Juniors","query":null}','{"community":"Juniors","query":"a"}',
  '{"community":"Juniors","query":"   a   "}','{"community":"Juniors","query":["ab"]}']::jsonb[] loop
  out:=public.social_gateway('posts.search',hb,bad);
  if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'Search for 2 to 80 characters.' then raise exception 'Bad query accepted % %',bad,out;end if;
 end loop;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',repeat('x',81)));
 if out->>'error' is distinct from 'Search for 2 to 80 characters.' then raise exception '81 characters accepted %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',repeat('x',80)));
 if out?'error' then raise exception '80 characters refused %',out;end if;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Elsewhere','query',tok));
 if out->>'error' is distinct from 'Choose an available community.' then raise exception 'Bad community accepted %',out;end if;
 foreach bad in array array['"nope"','"food"','5']::jsonb[] loop
  out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok,'topic',bad));
  if out->>'error' is distinct from 'Choose an available topic.' then raise exception 'Bad topic accepted % %',bad,out;end if;
 end loop;
 foreach bad in array array['"x"','[1]','{"rank":"1","created":"2026-01-01T00:00:00.000000Z","id":"00000000-0000-0000-0000-000000000000"}',
  '{"rank":1.5,"created":"2026-01-01T00:00:00.000000Z","id":"00000000-0000-0000-0000-000000000000"}','{"rank":1,"created":"yesterday","id":"00000000-0000-0000-0000-000000000000"}',
  '{"rank":1,"created":"2026-13-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000"}','{"rank":1,"created":"2026-01-01T00:00:00Z","id":"nope"}','{"rank":1,"created":"2026-01-01T00:00:00Z"}',
  '{"rank":1e30,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000"}']::jsonb[] loop
  out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok,'cursor',bad));
  if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'Use a valid page cursor.' then raise exception 'Bad cursor accepted % %',bad,out;end if;
 end loop;
 out:=public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok,'limit','x'));
 if out->>'code' is distinct from 'invalid' then raise exception 'Bad limit accepted %',out;end if;
 raise notice 'PASS query, community, topic, cursor and limit validation';

 -- Rate limit: 30 searches a minute per member; the 31st is refused and not recorded; others unaffected.
 for n in 1..30 loop
  out:=public.social_gateway('posts.search',he,jsonb_build_object('community','Juniors','query',tok));
  if out?'error' then raise exception 'Search % refused early %',n,out;end if;
 end loop;
 out:=public.social_gateway('posts.search',he,jsonb_build_object('community','Juniors','query',tok));
 if out->>'code' is distinct from 'rate_limit' or out->>'error' is distinct from 'Too many searches. Try again in a minute.' then raise exception 'Rate limit missing %',out;end if;
 if (select count(*) from social_private.search_requests where member=e)<>30 then raise exception 'Refused search was recorded';end if;
end $$;
reset role;
-- Rows older than a minute stop counting, and the next search by anyone prunes every member's.
update social_private.search_requests set at=now()-interval '61 seconds' where member=(select v::uuid from qa where k='e');
insert into social_private.search_requests(member,at) select v::uuid,now()-interval '5 minutes' from qa where k='b';
set local role service_role;
do $$
declare tok text:=(select v from qa where k='tok');hb text:=(select v from qa where k='hb');he text:=(select v from qa where k='he');e uuid:=(select v::uuid from qa where k='e');out jsonb;
begin
 out:=public.social_gateway('posts.search',he,jsonb_build_object('community','Juniors','query',tok));
 if out?'error' or (select count(*) from social_private.search_requests where member=e)<>1 then raise exception 'Old searches still count %',out;end if;
 if exists(select 1 from social_private.search_requests where at<=now()-interval '1 minute') then raise exception 'Another member''s old searches were kept';end if;
 if public.social_gateway('posts.search',hb,jsonb_build_object('community','Juniors','query',tok))?'error' then raise exception 'Another member was limited';end if;
 raise notice 'PASS 30 searches per minute per member';
end $$;
reset role;

do $$
declare e uuid:=(select v::uuid from qa where k='e');
begin
 delete from social_private.members where id=e;
 if exists(select 1 from social_private.search_requests where member=e) then raise exception 'Search records outlived the account';end if;
 if (select count(*) from social_private.search_requests where member=(select v::uuid from qa where k='b'))=0 then raise exception 'Fixture lost other members'' records';end if;
 if not exists(select 1 from cron.job where jobname='search-requests-cleanup' and command like '%search_requests%') then raise exception 'No sweep for search records';end if;
 raise notice 'PASS search records go with the account (and a sweep clears old ones)';
end $$;

rollback;
