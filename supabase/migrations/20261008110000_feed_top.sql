-- Top sort: gateway action feed.top over a cached post score.
-- * posts.score caches social_private.post_score (the number the app shows: every counted vote,
--   including the author's own starting upvote; nothing from banned voters or authors, from voters
--   blocked either way with the author, or on deleted posts). Triggers keep it equal to post_score:
--   votes (insert, change, delete), a post's deleted flag or author, a member's ban, and a block
--   added or removed (which locks every live post of both members, so a vote racing the block
--   waits for it). Each refresh first takes the post rows' FOR NO KEY UPDATE locks (sorted by id;
--   compatible with the KEY SHARE lock a new vote's foreign key holds) and then recounts in a new
--   statement, whose snapshot includes every vote committed before the lock was granted, so two
--   concurrent votes can never leave a stale total. Adding the column with a constant default does
--   not rewrite the table; the backfill below touches only posts whose score is not 0 and fires no
--   change-marker triggers (they all name their columns, and score is not one of them).
-- * Input {"community", "topic"?, "window": "day"|"week"|"all", "cursor"?, "limit"?}; community and
--   topic as feed.page; an unknown window is "invalid:Choose Today, This week or All time.". limit
--   1-30 (default 20, clamped).
-- * Answer {"posts": [post_json, ...], "more": bool, "cursor": object|null}; send "cursor" back
--   unchanged. Order: score, then newest, then id. Visibility is the feed's (can_read_post, nothing
--   hidden) without deleted posts, filtered by topic like feed.page.
-- * Paging while scores move (the choice): keyset on (score, created_at, id) plus two things the
--   cursor carries. "since" pins the window's start at the first page, so Today does not slide
--   while someone scrolls. "seen" lists the ids already returned (the most recent 300), which the
--   next pages exclude, so a post whose score fell below the cursor is not returned twice. A post
--   whose score rose above the cursor after its page was read is not returned again on later pages
--   (it shows on the next refresh). Past 300 results the client drops repeated ids itself.

alter table social_private.posts add column if not exists score bigint not null default 0;

-- Recount the given posts' scores (locks first, then a fresh statement).
create or replace function social_private.refresh_post_scores(p_posts uuid[]) returns void language plpgsql set search_path='' as $$
begin
 if p_posts is null or cardinality(p_posts)=0 then return;end if;
 perform 1 from social_private.posts where id=any(p_posts) order by id for no key update;
 update social_private.posts p set score=s.v from(select x id,social_private.post_score(x) v from unnest(p_posts)x)s
  where p.id=s.id and p.score is distinct from s.v;
end $$;

create or replace function social_private.votes_refresh_score() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then perform social_private.refresh_post_scores(array[new.post]);
 elsif tg_op='DELETE' then perform social_private.refresh_post_scores(array[old.post]);
 elsif new.post is distinct from old.post then perform social_private.refresh_post_scores(array[old.post,new.post]);
 else perform social_private.refresh_post_scores(array[new.post]);
 end if;
 return null;
end $$;
drop trigger if exists votes_refresh_score on social_private.votes;
create trigger votes_refresh_score after insert or update or delete on social_private.votes for each row execute function social_private.votes_refresh_score();

create or replace function social_private.posts_refresh_score() returns trigger language plpgsql set search_path='' as $$
begin
 perform social_private.refresh_post_scores(array[new.id]);
 return null;
end $$;
drop trigger if exists posts_refresh_score on social_private.posts;
create trigger posts_refresh_score after update of deleted,author on social_private.posts for each row
 when(old.deleted is distinct from new.deleted or old.author is distinct from new.author) execute function social_private.posts_refresh_score();

create or replace function social_private.members_refresh_scores() returns trigger language plpgsql set search_path='' as $$
begin
 perform social_private.refresh_post_scores(array(select id from social_private.posts where author=new.id union select post from social_private.votes where member=new.id));
 return null;
end $$;
drop trigger if exists members_refresh_scores on social_private.members;
create trigger members_refresh_scores after update of banned on social_private.members for each row
 when(old.banned is distinct from new.banned) execute function social_private.members_refresh_scores();

-- A block (or unblock) changes which votes count on every post either member wrote. All of those
-- posts are locked first, not only those with a vote between the two already visible: a vote that
-- is still uncommitted while the block is added has its own refresh wait for this lock, and then
-- recounts with the block visible (and the gateway's post.vote, which locks the post FOR UPDATE
-- before can_read_post, waits the same way and is refused). Only posts with a vote between the
-- two are recounted, in a statement after the locks, so votes committed before them are counted.
create or replace function social_private.blocks_refresh_scores() returns trigger language plpgsql set search_path='' as $$
declare a uuid:=coalesce(new.blocker,old.blocker); b uuid:=coalesce(new.blocked,old.blocked);
begin
 perform 1 from social_private.posts p where p.author in(a,b) and not p.deleted order by p.id for no key update;
 perform social_private.refresh_post_scores(array(
  select p.id from social_private.posts p join social_private.votes v on v.post=p.id where (p.author=a and v.member=b) or (p.author=b and v.member=a)));
 return null;
end $$;
drop trigger if exists blocks_refresh_scores on social_private.blocks;
create trigger blocks_refresh_scores after insert or delete on social_private.blocks for each row execute function social_private.blocks_refresh_scores();

-- Backfill (posts with no counted votes stay at the default 0).
update social_private.posts p set score=social_private.post_score(p.id) where social_private.post_score(p.id)<>p.score;

create index if not exists posts_top on social_private.posts(community,score desc,created_at desc,id desc) where not deleted;
create index if not exists posts_top_topic on social_private.posts(community,topic,score desc,created_at desc,id desc) where not deleted and topic is not null;

create or replace function social_private.feed_top(p_me uuid,p_input jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare scope record; window_value text; since_value timestamptz; limit_value integer; c_score bigint; c_created timestamptz; c_id uuid; seen uuid[]:='{}'; result jsonb;
begin
 select * into scope from social_private.feed_scope(p_input);
 if jsonb_typeof(p_input->'window') is distinct from 'string' or p_input->>'window' not in('day','week','all') then raise exception 'invalid:Choose Today, This week or All time.';end if;
 window_value:=p_input->>'window';
 limit_value:=least(30,social_private.sync_limit(p_input->'limit',20));
 if p_input?'cursor' and jsonb_typeof(p_input->'cursor')<>'null' then
  if jsonb_typeof(p_input->'cursor')<>'object' then raise exception 'invalid:Use a valid page cursor.';end if;
  c_score:=social_private.page_cursor_int(p_input->'cursor'->'score');
  c_created:=social_private.page_cursor_time(p_input->'cursor'->'created');
  c_id:=social_private.page_cursor_id(p_input->'cursor'->'id');
  -- The window's start from the first page: required for Today and This week, absent for All time.
  if window_value='all' then
   if p_input->'cursor'?'since' and jsonb_typeof(p_input->'cursor'->'since')<>'null' then raise exception 'invalid:Use a valid page cursor.';end if;
  else
   since_value:=social_private.page_cursor_time(p_input->'cursor'->'since');
  end if;
  if p_input->'cursor'?'seen' and jsonb_typeof(p_input->'cursor'->'seen')<>'null' then
   if jsonb_typeof(p_input->'cursor'->'seen')<>'array' or jsonb_array_length(p_input->'cursor'->'seen')>300
    or exists(select 1 from jsonb_array_elements(p_input->'cursor'->'seen')e where jsonb_typeof(e)<>'string' or e#>>'{}'!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
   then raise exception 'invalid:Use a valid page cursor.';end if;
   select coalesce(array_agg(value::uuid),'{}') into seen from jsonb_array_elements_text(p_input->'cursor'->'seen');
  end if;
 elsif window_value<>'all' then
  since_value:=now()-case window_value when 'day' then interval '1 day' else interval '7 days' end;
 end if;
 with page as(
  select p from social_private.posts p
  where not p.deleted and (scope.community_value is null or p.community=scope.community_value) and (scope.topic_value is null or p.topic=scope.topic_value)
   and (since_value is null or p.created_at>=since_value)
   and (c_id is null or (p.score,p.created_at,p.id)<(c_score,c_created,c_id)) and not p.id=any(seen)
   and social_private.can_read_post(p_me,p.id) and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
  order by p.score desc,p.created_at desc,p.id desc limit limit_value+1),
 numbered as(select page.p,row_number()over(order by (page.p).score desc,(page.p).created_at desc,(page.p).id desc)n from page)
 select jsonb_build_object(
  'posts',coalesce((select jsonb_agg(social_private.post_json(p_me,numbered.p,50)order by n)from numbered where n<=limit_value),'[]'),
  'more',exists(select 1 from numbered where n>limit_value),
  'cursor',(select jsonb_build_object('score',(numbered.p).score,'created',social_private.page_cursor_stamp((numbered.p).created_at),'id',(numbered.p).id,
    'since',case when since_value is null then null else social_private.page_cursor_stamp(since_value)end,
    -- The ids returned so far, newest page last, at most 300.
    'seen',(select coalesce(jsonb_agg(to_jsonb(x.id)order by x.i),'[]') from(select id,i from(
      select s.id,s.i from unnest(seen)with ordinality s(id,i)
      union all select (q.p).id,cardinality(seen)+q.n from numbered q where q.n<=limit_value)all_ids order by i desc limit 300)x))
   from numbered where n=limit_value and exists(select 1 from numbered later where later.n>limit_value)))
 into result;
 return result;
end $$;

-- Routing (patched from the current gateway; the anchor must occur exactly once).
do $patch$
declare def text; old text;
begin
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:=E' elsif p_action=\'posts.search\' then';
 if (length(def)-length(replace(def,old,'')))/length(old)<>1 then raise exception 'gateway posts.search anchor must occur once';end if;
 def:=replace(def,old,E' elsif p_action=\'feed.top\' then\n  return social_private.feed_top(me,p_input);\n'||old);
 execute def;
end $patch$;

do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.refresh_post_scores(uuid[])','social_private.feed_top(uuid,jsonb)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
 foreach fn in array array['social_private.votes_refresh_score()','social_private.posts_refresh_score()','social_private.members_refresh_scores()','social_private.blocks_refresh_scores()'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
 end loop;
end $grants$;
