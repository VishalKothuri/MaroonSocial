-- Server search over post bodies and tags: gateway action posts.search.
-- * Input {"community", "query", "topic"?, "cursor"?, "limit"?}. community and topic follow feed.page
--   ("invalid:Choose an available community." / "invalid:Choose an available topic."; absent or null
--   community falls back to the request's feed_community, then to every community the caller can
--   read). query is a string of 2-80 characters after trimming whitespace ("invalid:Search for 2 to
--   80 characters."). limit is 1-30 (default 20; numbers outside are clamped like feed.page).
-- * Answer {"posts": [post_json, ...], "more": bool, "cursor": object|null}. Send "cursor" back
--   unchanged for the next page; it is {"rank", "created", "id"} of the last post returned (keyset
--   paging, so a page never repeats a post from an earlier one: a post's text and tags do not change
--   while it is live). Order: relevance (ts_rank, kept to six decimals so the cursor compares
--   exactly), then newest, then id.
-- * Visibility is the feed's: can_read_post (community access incl. the NSFW opt-in, blocks either
--   way), nothing the caller hid or reported, and never a deleted post. Only the post's own words
--   (body and tags) are indexed or matched: never the author, a username, an alias or anonymity.
-- * Matching: each query word (up to 8) must match the post as a prefix of either the word itself
--   (simple config: "calc" finds "calculus") or its English stem ("studying" finds "study").
--   English stop words are ignored unless the query has nothing else ("it", "the who").
-- * Index: an expression GIN index over social_private.post_search_document(body,tags), partial on
--   live posts. Chosen over a stored generated tsvector column because adding a stored column
--   rewrites the whole posts table under an ACCESS EXCLUSIVE lock (feed reads stall for the rewrite),
--   while CREATE INDEX reads the table once under a SHARE lock that lets reads continue, and the
--   tsvector is not stored twice. Search ranks only the matches in the requested community (and
--   topic): the scope applies in the matching step itself, each match's document is built once (for
--   the rank), and visibility checks run only on in-scope matches.
-- * Rate limit: 30 searches per member per rolling minute ("rate_limit:Too many searches. Try again
--   in a minute."). social_private.search_requests holds no query text, only when each member
--   searched: every search deletes every member's timestamps older than a minute, and a pg_cron
--   job every ten minutes clears what is left once nobody searches. A member's rows also go with
--   their account.

-- COST 1000: parsing a body is far dearer than the default function cost says, so the planner
-- reads the GIN index rather than parsing every post of a community to filter it.
create or replace function social_private.post_search_document(p_body text,p_tags text[]) returns tsvector
language sql immutable parallel safe cost 1000 set search_path='' as $$
 select to_tsvector('english'::regconfig,coalesce(p_body,'')||' '||array_to_string(coalesce(p_tags,'{}'::text[]),' '))
  ||to_tsvector('simple'::regconfig,coalesce(p_body,'')||' '||array_to_string(coalesce(p_tags,'{}'::text[]),' '))
$$;

create index if not exists posts_search on social_private.posts using gin(social_private.post_search_document(body,tags)) where not deleted;

-- The query: every word (prefix of the word or of its English stem), AND-ed.
create or replace function social_private.post_search_query(p_query text) returns tsquery
language plpgsql immutable set search_path='' set client_min_messages=warning as $$
declare result tsquery; term tsquery; word text; stem text; stops text[]:='{}';
begin
 for word in select w from unnest(tsvector_to_array(to_tsvector('simple'::regconfig,coalesce(p_query,''))))w where w~'^[[:alnum:]]+$' order by w limit 8 loop
  stem:=(tsvector_to_array(to_tsvector('english'::regconfig,word)))[1];
  if stem is null then stops:=stops||word;continue;end if;
  term:=to_tsquery('simple'::regconfig,''''||word||''':*');
  if stem<>word and stem~'^[[:alnum:]]+$' then term:=term||to_tsquery('simple'::regconfig,''''||stem||''':*');end if;
  result:=case when result is null then term else result&&term end;
 end loop;
 if result is null then
  foreach word in array stops loop
   term:=to_tsquery('simple'::regconfig,''''||word||''':*');
   result:=case when result is null then term else result&&term end;
  end loop;
 end if;
 return coalesce(result,''::tsquery);
end $$;

-- community and topic for the feed-style reads, validated as feed.page validates them.
create or replace function social_private.feed_scope(p_input jsonb,out community_value text,out topic_value text)
language plpgsql stable set search_path='' as $$
begin
 if p_input?'community' and jsonb_typeof(p_input->'community')<>'null' and (jsonb_typeof(p_input->'community')<>'string'
  or p_input->>'community' not in('Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates','NSFW')) then raise exception 'invalid:Choose an available community.';end if;
 community_value:=coalesce(nullif(p_input->>'community',''),nullif(current_setting('maroon.feed_community',true),''));
 if p_input?'topic' and jsonb_typeof(p_input->'topic')<>'null' then
  if jsonb_typeof(p_input->'topic')<>'string' or not exists(select 1 from social_private.topics t where t.slug=p_input->>'topic' and t.active) then raise exception 'invalid:Choose an available topic.';end if;
  topic_value:=p_input->>'topic';
 end if;
end $$;

-- Cursor timestamps travel as exact UTC text (microseconds), so keyset comparisons are exact.
create or replace function social_private.page_cursor_stamp(p_at timestamptz) returns text language sql immutable set search_path='' as $$
 select to_char(p_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
$$;
create or replace function social_private.page_cursor_time(p_value jsonb) returns timestamptz language plpgsql stable set search_path='' as $$
declare moment timestamptz;
begin
 if jsonb_typeof(p_value) is distinct from 'string' or (p_value#>>'{}')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?Z$' then raise exception 'invalid:Use a valid page cursor.';end if;
 begin moment:=(p_value#>>'{}')::timestamptz;
 exception when others then raise exception 'invalid:Use a valid page cursor.';
 end;
 if moment<'1970-01-01 00:00:00+00'::timestamptz or moment>'2100-01-01 00:00:00+00'::timestamptz then raise exception 'invalid:Use a valid page cursor.';end if;
 return moment;
end $$;
create or replace function social_private.page_cursor_id(p_value jsonb) returns uuid language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(p_value) is distinct from 'string' or (p_value#>>'{}')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'invalid:Use a valid page cursor.';end if;
 return (p_value#>>'{}')::uuid;
end $$;
create or replace function social_private.page_cursor_int(p_value jsonb) returns bigint language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(p_value) is distinct from 'number' or (p_value#>>'{}')!~'^-?[0-9]{1,15}$' then raise exception 'invalid:Use a valid page cursor.';end if;
 return (p_value#>>'{}')::bigint;
end $$;

create table if not exists social_private.search_requests(
 member uuid not null references social_private.members(id) on delete cascade,
 at timestamptz not null default now()
);
create index if not exists search_requests_member_at on social_private.search_requests(member,at);
create index if not exists search_requests_at on social_private.search_requests(at);
-- No policies: reached only through the gateway.
alter table social_private.search_requests enable row level security;
revoke all on social_private.search_requests from public,anon,authenticated;
grant select,insert,delete on social_private.search_requests to service_role;
select cron.schedule('search-requests-cleanup','*/10 * * * *',$$ delete from social_private.search_requests where at<=now()-interval '1 minute'; $$);

create or replace function social_private.posts_search(p_me uuid,p_input jsonb) returns jsonb language plpgsql set search_path='' as $$
declare scope record; query_value text; q tsquery; limit_value integer; c_rank bigint; c_created timestamptz; c_id uuid; result jsonb;
begin
 select * into scope from social_private.feed_scope(p_input);
 if jsonb_typeof(p_input->'query') is distinct from 'string' then raise exception 'invalid:Search for 2 to 80 characters.';end if;
 query_value:=regexp_replace(p_input->>'query','^\s+|\s+$','','g');
 if char_length(query_value) not between 2 and 80 then raise exception 'invalid:Search for 2 to 80 characters.';end if;
 limit_value:=least(30,social_private.sync_limit(p_input->'limit',20));
 if p_input?'cursor' and jsonb_typeof(p_input->'cursor')<>'null' then
  if jsonb_typeof(p_input->'cursor')<>'object' then raise exception 'invalid:Use a valid page cursor.';end if;
  c_rank:=social_private.page_cursor_int(p_input->'cursor'->'rank');
  c_created:=social_private.page_cursor_time(p_input->'cursor'->'created');
  c_id:=social_private.page_cursor_id(p_input->'cursor'->'id');
 end if;
 -- 30 searches per rolling minute per member; a refused search is not counted.
 perform pg_advisory_xact_lock(hashtextextended('posts-search:'||p_me::text,0));
 if (select count(*) from social_private.search_requests where member=p_me and at>now()-interval '1 minute')>=30 then raise exception 'rate_limit:Too many searches. Try again in a minute.';end if;
 -- Every member's timestamps older than a minute go (bounded by search_requests_at).
 delete from social_private.search_requests where at<=now()-interval '1 minute';
 insert into social_private.search_requests(member)values(p_me);
 q:=social_private.post_search_query(query_value);
 if numnode(q)=0 then return jsonb_build_object('posts','[]'::jsonb,'more',false,'cursor',null);end if;
 -- The matching step (materialized) applies the text match and the community and topic together, so
 -- the planner reads the text index or the scope's own index, whichever reads fewer rows, and never
 -- ranks matches from other communities. Each match's document is built once there for its rank;
 -- the visibility checks then run only on in-scope matches.
 with matched as materialized(
  select p,social_private.post_search_document(p.body,p.tags) doc from social_private.posts p
  where not p.deleted and social_private.post_search_document(p.body,p.tags)@@q
   and (scope.community_value is null or p.community=scope.community_value) and (scope.topic_value is null or p.topic=scope.topic_value)),
 hits as(
  select m.p,(ts_rank(m.doc,q)*1000000)::bigint rk from matched m
  where social_private.can_read_post(p_me,(m.p).id) and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=(m.p).id)),
 page as(select h.p,h.rk from hits h where c_id is null or (h.rk,(h.p).created_at,(h.p).id)<(c_rank,c_created,c_id)
  order by h.rk desc,(h.p).created_at desc,(h.p).id desc limit limit_value+1),
 numbered as(select page.p,page.rk,row_number()over(order by page.rk desc,(page.p).created_at desc,(page.p).id desc)n from page)
 select jsonb_build_object(
  'posts',coalesce((select jsonb_agg(social_private.post_json(p_me,numbered.p,50)order by n)from numbered where n<=limit_value),'[]'),
  'more',exists(select 1 from numbered where n>limit_value),
  'cursor',(select jsonb_build_object('rank',numbered.rk,'created',social_private.page_cursor_stamp((numbered.p).created_at),'id',(numbered.p).id)
   from numbered where n=limit_value and exists(select 1 from numbered later where later.n>limit_value)))
 into result;
 return result;
end $$;

-- Routing (patched from the current gateway; the anchor must occur exactly once).
do $patch$
declare def text; old text;
begin
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:=E' elsif p_action in(\'feed.page\',\'feed.delta\',\'feed.posts\',\'topics.list\',\'comments.page\',\'room.messages\') then';
 if (length(def)-length(replace(def,old,'')))/length(old)<>1 then raise exception 'gateway feed_sync anchor must occur once';end if;
 def:=replace(def,old,E' elsif p_action=\'posts.search\' then\n  return social_private.posts_search(me,p_input);\n'||old);
 execute def;
end $patch$;

do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.post_search_document(text,text[])','social_private.post_search_query(text)','social_private.feed_scope(jsonb)',
  'social_private.page_cursor_stamp(timestamptz)','social_private.page_cursor_time(jsonb)','social_private.page_cursor_id(jsonb)','social_private.page_cursor_int(jsonb)',
  'social_private.posts_search(uuid,jsonb)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end $grants$;
