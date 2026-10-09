-- Topic feeds, part 2: topic-aware reads, the catalog read, author retags and operator commands.
-- * feed.page, feed.delta and feed.posts take an optional "topic": absent or null is All,
--   otherwise an active topic slug ("invalid:Choose an available topic." for anything else).
--   With a topic, feed.delta's "removed" and feed.posts' missing ids also report held posts
--   whose topic no longer matches, so a retagged post leaves the old tab on the next read.
--   The snapshot's first page stays All: clients ask for a topic page with feed.page.
-- * The topic page is its own statement (p.community=... and p.topic=...), so the generic plan of
--   this SQL function walks posts_topic_feed instead of filtering the whole feed. Every branch
--   starts with a one-time filter on its arguments (p_topic is null / is not null, p_community),
--   so a generic plan skips the branches that cannot match instead of scanning posts for them.
-- * topics.list: the active topics in sort_order with recent_count, the non-deleted posts with
--   that topic in the last 7 days in the requested community that the caller can read (the
--   feed's predicate: readable community, no blocked authors, nothing the caller hid).
-- * post.topic: the author sets or clears their own live post's topic (moves its change marker).
-- * Operator: topic.set <post> <slug|null>, topic.disable <slug>, topic.enable <slug>, audited.

-- Reads -------------------------------------------------------------------------------------------
-- New signatures (one optional topic argument), so the old ones are dropped. Callers: feed_sync and
-- the snapshot (feed_page with five arguments, which the default keeps working).
drop function if exists social_private.feed_page(uuid,text,timestamptz,uuid,integer);
drop function if exists social_private.feed_delta(uuid,text,timestamptz,uuid[]);
drop function if exists social_private.feed_posts(uuid,text,uuid[]);

create function social_private.feed_page(p_me uuid,p_community text,p_before_created timestamptz,p_before_id uuid,p_limit integer,p_topic text default null) returns jsonb language sql stable set search_path='' as $$
 with candidates as(
  (select p from social_private.posts p where p_topic is null and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
    and (p_before_created is null or (p_before_id is null and p.created_at<p_before_created) or (p_before_id is not null and (p.created_at,p.id)<(p_before_created,p_before_id)))
   order by p.created_at desc,p.id desc limit p_limit+1)
  union all
  -- One topic in one community: a plain equality on both, which posts_topic_feed serves in order.
  (select p from social_private.posts p where p_topic is not null and p.community=p_community and p.topic=p_topic and social_private.can_read_post(p_me,p.id)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
    and (p_before_created is null or (p_before_id is null and p.created_at<p_before_created) or (p_before_id is not null and (p.created_at,p.id)<(p_before_created,p_before_id)))
   order by p.created_at desc,p.id desc limit p_limit+1)
  union all
  -- One topic across every community the caller can read.
  (select p from social_private.posts p where p_topic is not null and p_community is null and p.topic=p_topic and social_private.can_read_post(p_me,p.id)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
    and (p_before_created is null or (p_before_id is null and p.created_at<p_before_created) or (p_before_id is not null and (p.created_at,p.id)<(p_before_created,p_before_id)))
   order by p.created_at desc,p.id desc limit p_limit+1)),
 page as(select x.p,row_number()over(order by (x.p).created_at desc,(x.p).id desc)n from candidates x)
 select jsonb_build_object('posts',coalesce((select jsonb_agg(social_private.post_json(p_me,page.p,50)order by n)from page where n<=p_limit),'[]'),
  'next',(select jsonb_build_object('before_created',extract(epoch from (page.p).created_at),'before_id',(page.p).id)from page where n=p_limit and exists(select 1 from page later where later.n>p_limit)))
$$;

-- The definition from 20261005170000 plus the topic filter, which "removed" applies as well.
create function social_private.feed_delta(p_me uuid,p_community text,p_since timestamptz,p_known uuid[],p_topic text default null) returns jsonb language sql stable set search_path='' as $$
 with changed as(
  select x.p,row_number()over(order by (x.p).changed_at desc,(x.p).id)n from(
   select p from social_private.posts p where p.changed_at>p_since and (p.id=any(p_known) or p.created_at>p_since)
    and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community) and (p_topic is null or p.topic=p_topic)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
   order by p.changed_at desc,p.id limit 101)x)
 select jsonb_build_object(
  'changed',coalesce((select jsonb_agg(social_private.post_json(p_me,changed.p,50)order by (changed.p).created_at desc,(changed.p).id desc)from changed where n<=100),'[]'),
  'truncated',exists(select 1 from changed where n>100),
  -- Only ids the caller already holds are reported, so the answer reveals nothing new. With a
  -- topic, a held post retagged away (or cleared) is reported too.
  'removed',coalesce((select jsonb_agg(distinct k)from unnest(p_known)k where
    exists(select 1 from social_private.post_tombstones t where t.id=k and t.removed_at>p_since)
    or not exists(select 1 from social_private.posts p where p.id=k and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community) and (p_topic is null or p.topic=p_topic))
    or exists(select 1 from social_private.hidden h where h.member=p_me and h.post=k)),'[]'),
  -- p_since carries the five seconds of overlap below, so p_since+5 s is when the previous
  -- delta read: a marker after it has not been answered by a refetch yet.
  'resync',exists(select 1 from social_private.feed_resyncs r where r.member=p_me and r.at>p_since+interval '5 seconds'),
  -- Five seconds of overlap absorb writers that commit after this read started.
  'now',extract(epoch from now())-5)
$$;

-- Held posts by id: current copies plus the ids that are gone (or, with a topic, no longer in it).
create function social_private.feed_posts(p_me uuid,p_community text,p_ids uuid[],p_topic text default null) returns jsonb language sql stable set search_path='' as $$
 with found as(
  select p from social_private.posts p where p.id=any(p_ids) and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community) and (p_topic is null or p.topic=p_topic)
   and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id))
 select jsonb_build_object(
  'posts',coalesce((select jsonb_agg(social_private.post_json(p_me,found.p,50)order by (found.p).created_at desc,(found.p).id desc)from found),'[]'),
  'removed',coalesce((select jsonb_agg(distinct k)from unnest(p_ids)k where not exists(select 1 from found where (found.p).id=k)),'[]'))
$$;

-- The catalog with each topic's readable posts over the last 7 days in one community (or every
-- community the caller can read). Adult-only topics are listed only in the adult community.
create function social_private.topic_list(p_me uuid,p_community text) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('topics',coalesce((select jsonb_agg(jsonb_build_object('slug',t.slug,'title',t.title,'emoji',t.emoji,'text_hex',t.text_hex,'fill_hex',t.fill_hex,
   'sort_order',t.sort_order,'recent_count',coalesce(c.n,0))order by t.sort_order,t.slug)
  from social_private.topics t left join(
   select p.topic,count(*)n from social_private.posts p where p.topic is not null and not p.deleted and p.created_at>now()-interval '7 days'
    and (p_community is null or p.community=p_community) and social_private.can_read_post(p_me,p.id)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
   group by p.topic)c on c.topic=t.slug
  where t.active and (not t.adult_only or p_community='NSFW')),'[]'))
$$;

-- Writes ------------------------------------------------------------------------------------------
-- post.topic: the author sets or clears the topic of their own live post.
create function social_private.post_set_topic(p_me uuid,p_input jsonb) returns uuid language plpgsql set search_path='' as $$
declare target social_private.posts; topic_value text;
begin
 if jsonb_typeof(p_input->'post_id') is distinct from 'string' or (p_input->>'post_id')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'invalid:Choose a post.';end if;
 select * into target from social_private.posts where id=(p_input->>'post_id')::uuid for update;
 if target.id is null or not social_private.can_read_post(p_me,target.id) then raise exception 'forbidden:This post is not available.';end if;
 if target.author is distinct from p_me then raise exception 'forbidden:Only the author can change this post''s topic.';end if;
 if target.deleted then raise exception 'forbidden:This post was deleted.';end if;
 if not p_input?'topic' then raise exception 'invalid:Choose an available topic.';end if;
 if jsonb_typeof(p_input->'topic')<>'null' then
  if jsonb_typeof(p_input->'topic')<>'string' or not social_private.topic_available(p_input->>'topic',target.community) then raise exception 'invalid:Choose an available topic.';end if;
  topic_value:=p_input->>'topic';
 end if;
 update social_private.posts set topic=topic_value where id=target.id and topic is distinct from topic_value;
 return target.id;
end $$;

-- Routing, validation and operator commands (patched from the live/pending definitions) -----------
do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('social_private.feed_sync(uuid,text,jsonb)'::regprocedure);
 old:='known uuid[]; result jsonb;';
 if strpos(def,old)=0 then raise exception 'feed_sync declare anchor missing';end if;
 def:=replace(def,old,old||' topic_value text;');
 old:=E'if p_action in(\'feed.page\',\'feed.delta\',\'feed.posts\') then';
 if strpos(def,old)=0 then raise exception 'feed_sync community anchor missing';end if;
 def:=replace(def,old,E'if p_action in(\'feed.page\',\'feed.delta\',\'feed.posts\',\'topics.list\') then');
 old:=E'community_value:=coalesce(nullif(p_input->>\'community\',\'\'),nullif(current_setting(\'maroon.feed_community\',true),\'\'));';
 replacement:=old||E'\n  if p_action<>\'topics.list\' and p_input?\'topic\' and jsonb_typeof(p_input->\'topic\')<>\'null\' then\n   if jsonb_typeof(p_input->\'topic\')<>\'string\' or not exists(select 1 from social_private.topics t where t.slug=p_input->>\'topic\' and t.active) then raise exception \'invalid:Choose an available topic.\';end if;\n   topic_value:=p_input->>\'topic\';\n  end if;';
 if strpos(def,old)=0 then raise exception 'feed_sync community value anchor missing';end if;
 def:=replace(def,old,replacement);
 old:=E'social_private.sync_limit(p_input->\'limit\',30));';
 if strpos(def,old)=0 then raise exception 'feed_sync feed_page anchor missing';end if;
 def:=replace(def,old,E'social_private.sync_limit(p_input->\'limit\',30),topic_value);');
 old:=E'social_private.feed_delta(p_me,community_value,social_private.sync_time(p_input->\'since\'),known);';
 if strpos(def,old)=0 then raise exception 'feed_sync feed_delta anchor missing';end if;
 def:=replace(def,old,E'social_private.feed_delta(p_me,community_value,social_private.sync_time(p_input->\'since\'),known,topic_value);');
 old:='return social_private.feed_posts(p_me,community_value,known);';
 if strpos(def,old)=0 then raise exception 'feed_sync feed_posts anchor missing';end if;
 def:=replace(def,old,E'return social_private.feed_posts(p_me,community_value,known,topic_value);\n elsif p_action=\'topics.list\' then\n  return social_private.topic_list(p_me,community_value);');
 execute def;

 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:=E'elsif p_action in(\'feed.page\',\'feed.delta\',\'feed.posts\',\'comments.page\',\'room.messages\') then';
 if strpos(def,old)=0 then raise exception 'gateway feed_sync anchor missing';end if;
 def:=replace(def,old,E'elsif p_action in(\'feed.page\',\'feed.delta\',\'feed.posts\',\'topics.list\',\'comments.page\',\'room.messages\') then');
 old:=E'elsif p_action=\'poll.vote\' then';
 if strpos(def,old)=0 then raise exception 'gateway poll.vote anchor missing';end if;
 def:=replace(def,old,E'elsif p_action=\'post.topic\' then\n  resource:=social_private.post_set_topic(me,p_input)::text;\n '||old);
 execute def;

 -- Operator (database owner only; see tools/social-admin.py). Each change is audited.
 def:=pg_get_functiondef('social_private.operator(text,jsonb,text)'::regprocedure);
 old:=E'body_value text:=btrim(coalesce(p_input->>\'body\',\'\'));result jsonb;';
 if strpos(def,old)=0 then raise exception 'operator declare anchor missing';end if;
 def:=replace(def,old,old||'topic_value text;');
 old:=' return social_private.operator_before_notifications(p_action,p_input,p_reviewer);';
 if strpos(def,old)=0 then raise exception 'operator delegate anchor missing';end if;
 replacement:=$r$ if p_action in('topic.set','topic.disable','topic.enable')then
  if char_length(btrim(p_reviewer))not between 3 and 100 or char_length(note_value)not between 5 and 2000 then raise exception 'Provide a reviewer label and review note.';end if;
  if p_action='topic.set'then
   if jsonb_typeof(p_input->'topic')not in('string','null')or not p_input?'topic'then raise exception 'Give a topic slug or null';end if;
   topic_value:=p_input->>'topic';
   if topic_value is not null and not exists(select 1 from social_private.topics where slug=topic_value and active)then raise exception 'Unknown or inactive topic';end if;
   update social_private.posts set topic=topic_value where id=(p_input->>'post_id')::uuid returning id into target;
   if target is null then raise exception 'Unknown post';end if;
   insert into social_private.operator_audit(reviewer,action,target,reason)values(btrim(p_reviewer),p_action||':'||coalesce(topic_value,'none'),target::text,note_value);
   return jsonb_build_object('applied',true,'action',p_action,'post_id',target,'topic',topic_value);
  end if;
  update social_private.topics set active=(p_action='topic.enable')where slug=p_input->>'slug' returning slug into topic_value;
  if topic_value is null then raise exception 'Unknown topic';end if;
  insert into social_private.operator_audit(reviewer,action,target,reason)values(btrim(p_reviewer),p_action,topic_value,note_value);
  return jsonb_build_object('applied',true,'action',p_action,'slug',topic_value);
 end if;
$r$||old;
 execute replace(def,old,replacement);
end $patch$;
-- The operator stays owner-only (topics' UPDATE is the owner's; service_role only reads them).
revoke all on function social_private.operator(text,jsonb,text) from public,anon,authenticated,service_role;

do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.feed_page(uuid,text,timestamptz,uuid,integer,text)','social_private.feed_delta(uuid,text,timestamptz,uuid[],text)',
  'social_private.feed_posts(uuid,text,uuid[],text)','social_private.topic_list(uuid,text)','social_private.post_set_topic(uuid,jsonb)','social_private.feed_sync(uuid,text,jsonb)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end $grants$;
