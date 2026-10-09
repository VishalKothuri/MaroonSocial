-- Transactional checks for the Top sort (20261008110000_feed_top, gateway action feed.top) and the
-- cached posts.score. Run as the database owner with psql; everything rolls back. Fixture posts and
-- votes are inserted as the owner (no rate limits); reads run as service_role through the gateway.
-- Expected orders are computed from post_score itself, so other rows in the database cannot break
-- the comparisons and the cache is checked against the score the app shows.
begin;

do $$
declare fn text;
begin
 foreach fn in array array['social_private.refresh_post_scores(uuid[])','social_private.feed_top(uuid,jsonb)'] loop
  if has_function_privilege('anon',fn,'EXECUTE') or has_function_privilege('authenticated',fn,'EXECUTE') then raise exception 'Exposed to clients: %',fn;end if;
  if not has_function_privilege('service_role',fn,'EXECUTE') then raise exception 'Gateway role cannot run %',fn;end if;
 end loop;
 foreach fn in array array['social_private.votes_refresh_score()','social_private.posts_refresh_score()','social_private.members_refresh_scores()','social_private.blocks_refresh_scores()'] loop
  if has_function_privilege('anon',fn,'EXECUTE') or has_function_privilege('authenticated',fn,'EXECUTE') then raise exception 'Trigger function exposed: %',fn;end if;
 end loop;
 if (select count(*) from pg_trigger where not tgisinternal and tgname in('votes_refresh_score','posts_refresh_score','members_refresh_scores','blocks_refresh_scores'))<>4 then raise exception 'Score triggers missing';end if;
 if (select count(*) from pg_indexes where schemaname='social_private' and indexname in('posts_top','posts_top_topic'))<>2 then raise exception 'Top indexes missing';end if;
 -- The backfill left every cached score equal to the score the app shows.
 if exists(select 1 from social_private.posts where score<>social_private.post_score(id)) then raise exception 'Cached scores differ after the backfill';end if;
 raise notice 'PASS privileges, triggers, indexes and the backfill';
end $$;

create temporary table qa(k text primary key,v text) on commit drop;
grant all on qa to service_role;
do $$
declare
 h text[]:='{}';m uuid[]:='{}';x uuid;i int;j int;post uuid;
begin
 -- Members 1..8: 1 author, 2 reader, 3 blocked author, 4 NSFW reader, 5..8 voters.
 for i in 1..8 loop
  h:=h||encode(extensions.gen_random_bytes(32),'hex');
  insert into social_private.members(token_hash,username,adult,network_hash,nsfw_enabled)values(h[i],'top_'||i||'_'||substr(h[i],1,8),true,h[i],i=4)returning id into x;
  insert into social_private.guidelines_acceptances(member,version)select x,required_version from social_private.guidelines_settings;
  m:=m||x;insert into qa values('h'||i,h[i]),('m'||i,x);
 end loop;
 -- Sophomores: scores 4, 3 (topic sports), 2, 1, -1, plus age variety for the windows.
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Sophomores','Top four',now()-interval '2 hours')returning id) insert into qa select 'p4',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,topic,created_at)values(m[1],gen_random_uuid(),'Sophomores','Top three','sports',now()-interval '3 days')returning id) insert into qa select 'p3',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Sophomores','Top two',now()-interval '20 days')returning id) insert into qa select 'p2',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Sophomores','Top one',now()-interval '1 hour')returning id) insert into qa select 'p1',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Sophomores','Top minus',now()-interval '5 hours')returning id) insert into qa select 'pm',id from p;
 -- Excluded for the reader: a blocked author's post, a hidden post, a deleted post (score 9 before deletion), NSFW.
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[3],gen_random_uuid(),'Sophomores','Blocked author',now()-interval '1 hour')returning id) insert into qa select 'pb',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Sophomores','Hidden',now()-interval '1 hour')returning id) insert into qa select 'ph',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Sophomores','Deleted',now()-interval '1 hour')returning id) insert into qa select 'pd',id from p;
 with p as(insert into social_private.posts(author,nonce,community,body,created_at)values(m[4],gen_random_uuid(),'NSFW','Adult top',now()-interval '1 hour')returning id) insert into qa select 'pn',id from p;
 for i in 5..8 loop insert into social_private.votes values(m[i],(select v::uuid from qa where k='p4'),1);end loop;
 for i in 5..7 loop insert into social_private.votes values(m[i],(select v::uuid from qa where k='p3'),1);end loop;
 for i in 5..6 loop insert into social_private.votes values(m[i],(select v::uuid from qa where k='p2'),1);end loop;
 insert into social_private.votes values(m[5],(select v::uuid from qa where k='p1'),1);
 insert into social_private.votes values(m[5],(select v::uuid from qa where k='pm'),-1);
 for i in 5..8 loop insert into social_private.votes values(m[i],(select v::uuid from qa where k='pb'),1),(m[i],(select v::uuid from qa where k='ph'),1),(m[i],(select v::uuid from qa where k='pd'),1),(m[i],(select v::uuid from qa where k='pn'),1);end loop;
 update social_private.posts set deleted=true,body='' where id=(select v::uuid from qa where k='pd');
 insert into social_private.blocks values(m[2],m[3]);
 insert into social_private.hidden(member,post)values(m[2],(select v::uuid from qa where k='ph'));
 -- Juniors: 45 posts within the last day with scores 0..4 (many ties) for paging.
 for i in 1..45 loop
  insert into social_private.posts(author,nonce,community,body,created_at)values(m[1],gen_random_uuid(),'Juniors','Paging top '||i,now()-make_interval(mins=>i/2))returning id into post;
  for j in 5..4+(i%5) loop insert into social_private.votes values(m[j],post,1);end loop;
 end loop;
end $$;

-- The cache follows every input of post_score.
do $$
declare
 a uuid:=(select v::uuid from qa where k='m1');v5 uuid:=(select v::uuid from qa where k='m5');v6 uuid:=(select v::uuid from qa where k='m6');
 p4 uuid:=(select v::uuid from qa where k='p4');p2 uuid:=(select v::uuid from qa where k='p2');pd uuid:=(select v::uuid from qa where k='pd');
begin
 if (select score from social_private.posts where id=p4)<>4 or (select score from social_private.posts where id=pd)<>0 then raise exception 'Vote or deletion not cached';end if;
 if exists(select 1 from social_private.posts where score<>social_private.post_score(id)) then raise exception 'Cache differs after votes';end if;
 update social_private.votes set value=-1 where member=v5 and post=p4;
 if (select score from social_private.posts where id=p4)<>2 then raise exception 'Changed vote not cached';end if;
 update social_private.votes set value=1 where member=v5 and post=p4;
 delete from social_private.votes where member=v6 and post=p2;
 if (select score from social_private.posts where id=p2)<>1 then raise exception 'Removed vote not cached';end if;
 insert into social_private.votes values(v6,p2,1);
 update social_private.members set banned=true where id=v5;
 if (select score from social_private.posts where id=p4)<>3 then raise exception 'Banned voter still counted';end if;
 update social_private.members set banned=false where id=v5;
 update social_private.members set banned=true where id=a;
 if (select score from social_private.posts where id=p4)<>0 then raise exception 'Banned author still scored';end if;
 update social_private.members set banned=false where id=a;
 insert into social_private.blocks values(a,v6);
 if (select score from social_private.posts where id=p4)<>3 then raise exception 'Blocked voter still counted';end if;
 delete from social_private.blocks where blocker=a and blocked=v6;
 insert into social_private.blocks values(v6,a);
 if (select score from social_private.posts where id=p4)<>3 then raise exception 'Voter who blocked the author still counted';end if;
 delete from social_private.blocks where blocker=v6 and blocked=a;
 if (select score from social_private.posts where id=p4)<>4 then raise exception 'Unblock not restored';end if;
 if exists(select 1 from social_private.posts where score<>social_private.post_score(id)) then raise exception 'Cache differs after bans and blocks';end if;
 raise notice 'PASS the cache follows votes, vote changes, removals, bans, blocks either way and deletion';
end $$;

-- A block locks every live post of both members, including ones with no vote between them yet, so
-- a vote still uncommitted while the block is added waits for it and recounts with the block
-- visible (two sessions; here the lock itself is checked: the row's xmax is this transaction).
do $$
declare v7 uuid:=(select v::uuid from qa where k='m7');v8 uuid:=(select v::uuid from qa where k='m8');fresh uuid;
begin
 insert into social_private.posts(author,nonce,community,body)values(v7,gen_random_uuid(),'Juniors','No votes yet')returning id into fresh;
 if (select xmax::text from social_private.posts where id=fresh)<>'0' then raise exception 'Fresh post already locked';end if;
 insert into social_private.blocks values(v8,v7);
 if (select xmax::text from social_private.posts where id=fresh)<>(pg_current_xact_id()::text::bigint%4294967296)::text then raise exception 'Block did not lock the blocked member''s posts';end if;
 delete from social_private.blocks where blocker=v8 and blocked=v7;
 delete from social_private.posts where id=fresh;
 raise notice 'PASS a block locks both members'' posts before a racing vote can count';
end $$;

set local role service_role;
do $$
declare
 h2 text:=(select v from qa where k='h2');h4 text:=(select v from qa where k='h4');h1 text:=(select v from qa where k='h1');
 b uuid:=(select v::uuid from qa where k='m2');
 out jsonb;ids text[];want text[];w text;since timestamptz;bad jsonb;
begin
 -- Sophomores, each window, compared with post_score order over the reader's visible posts.
 foreach w in array array['day','week','all'] loop
  out:=public.social_gateway('feed.top',h2,jsonb_build_object('community','Sophomores','window',w,'limit',30));
  if out?'error' then raise exception 'feed.top % failed %',w,out;end if;
  since:=case w when 'day' then now()-interval '1 day' when 'week' then now()-interval '7 days' end;
  select array_agg(p.id::text order by social_private.post_score(p.id) desc,p.created_at desc,p.id desc) into want from(
   select p.id,p.created_at from social_private.posts p where p.community='Sophomores' and not p.deleted and (since is null or p.created_at>=since)
    and social_private.can_read_post(b,p.id) and not exists(select 1 from social_private.hidden h where h.member=b and h.post=p.id)
   order by social_private.post_score(p.id) desc,p.created_at desc,p.id desc limit 30)p;
  select array_agg(x->>'id' order by o) into ids from jsonb_array_elements(out->'posts')with ordinality t(x,o);
  if ids is distinct from want then raise exception 'Window % order differs: got % want %',w,ids,want;end if;
  if ids&&array(select v from qa where k in('pb','ph','pd','pn')) then raise exception 'Excluded post in %',w;end if;
  if (select array_agg(x->>'score' order by o) from jsonb_array_elements(out->'posts')with ordinality t(x,o)) is distinct from
     (select array_agg(social_private.post_score(id::uuid)::text order by o) from unnest(ids)with ordinality s(id,o)) then raise exception 'Shown scores are not the app''s scores';end if;
 end loop;
 out:=public.social_gateway('feed.top',h2,'{"community":"Sophomores","window":"day"}');
 select array_agg(x->>'id' order by o) into ids from jsonb_array_elements(out->'posts')with ordinality t(x,o);
 if array_position(ids,(select v from qa where k='p4'))>array_position(ids,(select v from qa where k='p1')) or array_position(ids,(select v from qa where k='p1'))>array_position(ids,(select v from qa where k='pm'))
  or ids&&array(select v from qa where k in('p3','p2')) then raise exception 'Day window wrong %',ids;end if;
 out:=public.social_gateway('feed.top',h2,'{"community":"Sophomores","window":"week"}');
 select array_agg(x->>'id' order by o) into ids from jsonb_array_elements(out->'posts')with ordinality t(x,o);
 if not ids@>array[(select v from qa where k='p3')] or ids@>array[(select v from qa where k='p2')] then raise exception 'Week window wrong %',ids;end if;
 out:=public.social_gateway('feed.top',h2,'{"community":"Sophomores","window":"all","limit":30}');
 select array_agg(x->>'id' order by o) into ids from jsonb_array_elements(out->'posts')with ordinality t(x,o);
 if not ids@>array[(select v from qa where k='p2')] then raise exception 'All time misses old posts %',ids;end if;
 -- Topic filter, like feed.page.
 out:=public.social_gateway('feed.top',h2,'{"community":"Sophomores","window":"week","topic":"sports"}');
 if not exists(select 1 from jsonb_array_elements(out->'posts')x where x->>'id'=(select v from qa where k='p3')) or exists(select 1 from jsonb_array_elements(out->'posts')x where x->>'topic' is distinct from 'sports')
  then raise exception 'Topic filter wrong %',out;end if;
 -- The blocked author's post is listed for its own author's readers; NSFW only for the opted-in.
 if not exists(select 1 from jsonb_array_elements(public.social_gateway('feed.top',h1,'{"community":"Sophomores","window":"day","limit":30}')->'posts')x where x->>'id'=(select v from qa where k='pb')) then raise exception 'Unblocked reader misses the post';end if;
 if jsonb_array_length(public.social_gateway('feed.top',h2,'{"community":"NSFW","window":"day"}')->'posts')<>0 then raise exception 'NSFW without the opt-in';end if;
 if not exists(select 1 from jsonb_array_elements(public.social_gateway('feed.top',h4,'{"community":"NSFW","window":"day","limit":30}')->'posts')x where x->>'id'=(select v from qa where k='pn')) then raise exception 'NSFW member misses the NSFW post';end if;
 raise notice 'PASS score order per window, ties by newest, feed visibility, topic filter and NSFW gating';

 -- Validation.
 foreach bad in array array['{"community":"Sophomores"}','{"community":"Sophomores","window":"month"}','{"community":"Sophomores","window":null}','{"community":"Sophomores","window":1}']::jsonb[] loop
  out:=public.social_gateway('feed.top',h2,bad);
  if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'Choose Today, This week or All time.' then raise exception 'Bad window accepted % %',bad,out;end if;
 end loop;
 if public.social_gateway('feed.top',h2,'{"community":"Elsewhere","window":"day"}')->>'error' is distinct from 'Choose an available community.' then raise exception 'Bad community accepted';end if;
 if public.social_gateway('feed.top',h2,'{"community":"Sophomores","window":"day","topic":"food"}')->>'error' is distinct from 'Choose an available topic.' then raise exception 'Inactive topic accepted';end if;
 foreach bad in array array['{"window":"all","cursor":"x"}','{"window":"all","cursor":{"score":"1","created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000"}}',
  '{"window":"all","cursor":{"score":1,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000","since":"2026-01-01T00:00:00Z"}}',
  '{"window":"day","cursor":{"score":1,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000"}}',
  '{"window":"week","cursor":{"score":1,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000","since":"soon"}}',
  '{"window":"all","cursor":{"score":1,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000","seen":"x"}}',
  '{"window":"all","cursor":{"score":1,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000","seen":[5]}}',
  '{"window":"all","cursor":{"score":1,"created":"2026-01-01T00:00:00Z","id":"00000000-0000-0000-0000-000000000000","seen":["nope"]}}']::jsonb[] loop
  out:=public.social_gateway('feed.top',h2,bad||'{"community":"Sophomores"}');
  if out->>'code' is distinct from 'invalid' or out->>'error' is distinct from 'Use a valid page cursor.' then raise exception 'Bad cursor accepted % %',bad,out;end if;
 end loop;
 out:=public.social_gateway('feed.top',h2,jsonb_build_object('community','Sophomores','window','all','cursor',jsonb_build_object('score',1,'created','2026-01-01T00:00:00Z','id',gen_random_uuid(),
  'seen',(select jsonb_agg(gen_random_uuid()) from generate_series(1,301)))));
 if out->>'error' is distinct from 'Use a valid page cursor.' then raise exception 'Oversized seen list accepted';end if;
 if jsonb_array_length(public.social_gateway('feed.top',h2,'{"community":"Juniors","window":"day","limit":500}')->'posts')<>30 then raise exception 'Limit not clamped to 30';end if;
 raise notice 'PASS window, community, topic, cursor and limit validation';
end $$;

-- Paging over 45 Juniors posts (many tied scores) while scores change between pages.
do $$
declare
 h2 text:=(select v from qa where k='h2');b uuid:=(select v::uuid from qa where k='m2');
 out jsonb;cursor jsonb;seen text[]:='{}';want text[];pages int:=0;n int;dropped text;raised text;
begin
 select array_agg(p.id::text order by social_private.post_score(p.id) desc,p.created_at desc,p.id desc) into want from social_private.posts p
  where p.community='Juniors' and not p.deleted and p.created_at>=now()-interval '1 day' and social_private.can_read_post(b,p.id)
   and not exists(select 1 from social_private.hidden h where h.member=b and h.post=p.id);
 loop
  out:=public.social_gateway('feed.top',h2,jsonb_build_object('community','Juniors','window','day','limit',20)||case when cursor is null then '{}'::jsonb else jsonb_build_object('cursor',cursor)end);
  if out?'error' then raise exception 'page failed %',out;end if;
  pages:=pages+1;n:=jsonb_array_length(out->'posts');
  if (select bool_or(x->>'id'=any(seen)) from jsonb_array_elements(out->'posts')x) then raise exception 'Duplicate on page %',pages;end if;
  seen:=seen||array(select x->>'id' from jsonb_array_elements(out->'posts')with ordinality t(x,o) order by o);
  if (out->>'more')::boolean<>(jsonb_typeof(out->'cursor')='object') then raise exception 'more and cursor disagree';end if;
  if not (out->>'more')::boolean then exit;end if;
  cursor:=out->'cursor';
  if not cursor?&array['score','created','id','since','seen'] or jsonb_array_length(cursor->'seen')<>cardinality(seen) then raise exception 'Cursor shape wrong %',cursor;end if;
  if pages=1 then
   if seen is distinct from want[1:20] then raise exception 'First page not in score order';end if;
   if (cursor->>'since')::timestamptz<>now()-interval '1 day' then raise exception 'Cursor does not pin the window start %',cursor->>'since';end if;
   -- Between pages: the top post falls to the bottom, and a bottom post rises to the top.
   dropped:=seen[1];raised:=want[cardinality(want)];
   reset role;
   insert into social_private.votes select m.id,dropped::uuid,-1 from social_private.members m where m.id in(select v::uuid from qa where k in('m3','m4','m6','m7','m8')) on conflict(member,post)do update set value=-1;
   insert into social_private.votes select m.id,raised::uuid,1 from social_private.members m where m.id in(select v::uuid from qa where k in('m3','m4','m5','m6','m7','m8')) on conflict(member,post)do update set value=1;
   set local role service_role;
   if (select score from social_private.posts where id=dropped::uuid)>=0 then raise exception 'Fixture did not drop the score';end if;
  end if;
  exit when pages>5;
 end loop;
 if pages<>3 or cardinality(seen)<>cardinality(want)-1 then raise exception 'Paging shape wrong: pages % rows % of %',pages,cardinality(seen),cardinality(want);end if;
 -- The dropped post was not returned twice; the raised post was already past and is not repeated either.
 if (select count(*) from unnest(seen)s where s=dropped)<>1 then raise exception 'Dropped post repeated';end if;
 if (select count(*) from unnest(seen)s where s=raised)>1 then raise exception 'Raised post repeated';end if;
 if cardinality(seen)<>(select count(distinct s) from unnest(seen)s) then raise exception 'Duplicates across pages';end if;
 -- Every post of the window is returned except, at most, the one that rose above the cursor.
 if not (seen@>array_remove(want,raised)) then raise exception 'Posts skipped beyond the documented case';end if;
 raise notice 'PASS paging without duplicates while scores change (% rows over % pages)',cardinality(seen),pages;
end $$;
reset role;

-- The self-vote counts as the app counts it: a post made through the gateway starts at 1.
do $$
declare h1 text:=(select v from qa where k='h7');out jsonb;post uuid;
begin
 perform set_config('role','service_role',true);
 out:=public.social_gateway('post.create',h1,'{"text":"Top self vote","community":"Seniors"}');
 post:=(out->>'resource_id')::uuid;
 if post is null then raise exception 'post.create failed %',out;end if;
 if (select score from social_private.posts where id=post)<>1 then raise exception 'Self-vote not cached';end if;
 out:=public.social_gateway('post.vote',h1,jsonb_build_object('post_id',post,'value',0));
 if out?'error' or (select score from social_private.posts where id=post)<>0 then raise exception 'Withdrawn self-vote not cached %',out;end if;
 out:=public.social_gateway('post.delete',h1,jsonb_build_object('post_id',post));
 out:=public.social_gateway('feed.top',h1,'{"community":"Seniors","window":"day","limit":30}');
 if exists(select 1 from jsonb_array_elements(out->'posts')x where (x->>'id')::uuid=post) then raise exception 'Deleted post listed';end if;
 perform set_config('role','postgres',true);
 -- Account deletion: the voter's votes go and the scores they gave go with them.
 delete from social_private.members where id=(select v::uuid from qa where k='m5');
 if exists(select 1 from social_private.posts where score<>social_private.post_score(id)) then raise exception 'Cache differs after account deletion';end if;
 raise notice 'PASS self-vote, withdrawn vote, deletion and account deletion keep the cache equal to the app''s score';
end $$;

rollback;
