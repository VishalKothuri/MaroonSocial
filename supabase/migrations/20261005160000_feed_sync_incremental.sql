-- Caching phase 1: incremental feed/comment/message reads.
-- * posts.changed_at is bumped whenever anything a post card projects may change (its own
--   columns, votes, replies, reply votes, poll votes, bookmarks, ready attachments, reposts,
--   blocks between members and suspensions/renames). Deltas compare against it.
-- * post_tombstones remembers physically deleted posts (moderation deletes); account deletion
--   soft-deletes posts, which is an ordinary change the delta returns with deleted=true.
-- * One projection: post_json/comment_json now back visible_posts, post_documents and the new
--   paged reads, so the JSON shape (including repost quote/repostCount) cannot fork.
-- * message_page backs message_list (now the newest 50) and room.messages; conversation
--   metadata is one function shared by the snapshot and room.messages.
alter table social_private.posts add column if not exists changed_at timestamptz not null default now();
create index if not exists posts_changed_at on social_private.posts(changed_at desc);
create index if not exists posts_created_id on social_private.posts(created_at desc,id desc);
-- social_messages_room (room, seq) already serves both seq directions; no (room, seq desc) copy is needed.

create table if not exists social_private.post_tombstones(id uuid primary key,removed_at timestamptz not null default now());
create index if not exists post_tombstones_removed on social_private.post_tombstones(removed_at);
alter table social_private.post_tombstones enable row level security;
revoke all on social_private.post_tombstones from public,anon,authenticated;
grant select,insert,update,delete on social_private.post_tombstones to service_role;

-- Change tracking -------------------------------------------------------------------------
create or replace function social_private.touch_posts(p_ids uuid[]) returns void language sql set search_path='' as $$
 update social_private.posts set changed_at=clock_timestamp() where id=any(p_ids)
$$;
create or replace function social_private.posts_touch_self() returns trigger language plpgsql set search_path='' as $$
begin new.changed_at:=clock_timestamp();return new;end $$;
create or replace function social_private.posts_touch_related() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.quoted_post is not null then perform social_private.touch_posts(array[new.quoted_post]);end if;
 else
  -- Reposts project the quoted post and count the quoting ones.
  perform social_private.touch_posts(array(select id from social_private.posts where quoted_post=new.id));
  if new.quoted_post is not null then perform social_private.touch_posts(array[new.quoted_post]);end if;
  if old.quoted_post is distinct from new.quoted_post and old.quoted_post is not null then perform social_private.touch_posts(array[old.quoted_post]);end if;
 end if;
 return null;
end $$;
create or replace function social_private.posts_tombstone() returns trigger language plpgsql set search_path='' as $$
begin
 insert into social_private.post_tombstones(id,removed_at)values(old.id,clock_timestamp())on conflict(id)do update set removed_at=excluded.removed_at;
 return old;
end $$;
create or replace function social_private.touch_post_from_row() returns trigger language plpgsql set search_path='' as $$
declare ids uuid[]:='{}'; keys uuid[]:='{}';
begin
 if tg_table_name='attachments' then
  if new.post is null or not new.ready then return null;end if;
  perform social_private.touch_posts(array[new.post]);return null;
 end if;
 if tg_op in('INSERT','UPDATE') then
  if tg_table_name='comment_votes' then keys:=keys||new.comment;elsif tg_table_name='poll_votes' then keys:=keys||new.poll;else ids:=ids||new.post;end if;
 end if;
 if tg_op in('UPDATE','DELETE') then
  if tg_table_name='comment_votes' then keys:=keys||old.comment;elsif tg_table_name='poll_votes' then keys:=keys||old.poll;else ids:=ids||old.post;end if;
 end if;
 if tg_table_name='comment_votes' then ids:=array(select post from social_private.comments where id=any(keys));
 elsif tg_table_name='poll_votes' then ids:=array(select post from social_private.polls where id=any(keys));
 end if;
 if cardinality(ids)>0 then perform social_private.touch_posts(ids);end if;
 return null;
end $$;
create or replace function social_private.touch_posts_for_members() returns trigger language plpgsql set search_path='' as $$
declare people uuid[];
begin
 if tg_table_name='blocks' then
  if tg_op='DELETE' then people:=array[old.blocker,old.blocked];else people:=array[new.blocker,new.blocked];end if;
 else
  people:=array[new.id];
 end if;
 -- Blocks hide replies and scores both ways; suspensions and renames change projected names and scores.
 perform social_private.touch_posts(array(
  select id from social_private.posts where author=any(people)
  union select post from social_private.comments where author=any(people)));
 return null;
end $$;

drop trigger if exists posts_touch_self on social_private.posts;
create trigger posts_touch_self before update of body,deleted,accepts_dm,link_url,tags,author,anonymous,community,quoted_post on social_private.posts for each row execute function social_private.posts_touch_self();
drop trigger if exists posts_touch_related_insert on social_private.posts;
create trigger posts_touch_related_insert after insert on social_private.posts for each row when (new.quoted_post is not null) execute function social_private.posts_touch_related();
drop trigger if exists posts_touch_related_update on social_private.posts;
create trigger posts_touch_related_update after update of body,deleted,author,anonymous,quoted_post on social_private.posts for each row execute function social_private.posts_touch_related();
drop trigger if exists posts_tombstone on social_private.posts;
create trigger posts_tombstone before delete on social_private.posts for each row execute function social_private.posts_tombstone();
drop trigger if exists votes_touch_post on social_private.votes;
create trigger votes_touch_post after insert or update or delete on social_private.votes for each row execute function social_private.touch_post_from_row();
drop trigger if exists comments_touch_post on social_private.comments;
create trigger comments_touch_post after insert or update on social_private.comments for each row execute function social_private.touch_post_from_row();
drop trigger if exists comment_votes_touch_post on social_private.comment_votes;
create trigger comment_votes_touch_post after insert or update or delete on social_private.comment_votes for each row execute function social_private.touch_post_from_row();
drop trigger if exists poll_votes_touch_post on social_private.poll_votes;
create trigger poll_votes_touch_post after insert or update or delete on social_private.poll_votes for each row execute function social_private.touch_post_from_row();
drop trigger if exists bookmarks_touch_post on social_private.bookmarks;
create trigger bookmarks_touch_post after insert or delete on social_private.bookmarks for each row execute function social_private.touch_post_from_row();
drop trigger if exists attachments_touch_post on social_private.attachments;
create trigger attachments_touch_post after insert or update of ready,post on social_private.attachments for each row execute function social_private.touch_post_from_row();
drop trigger if exists blocks_touch_posts on social_private.blocks;
create trigger blocks_touch_posts after insert or delete on social_private.blocks for each row execute function social_private.touch_posts_for_members();
drop trigger if exists members_touch_posts on social_private.members;
create trigger members_touch_posts after update of banned,username on social_private.members for each row when (old.banned is distinct from new.banned or old.username is distinct from new.username) execute function social_private.touch_posts_for_members();

-- One post/reply projection ---------------------------------------------------------------
create or replace function social_private.comment_json(p_me uuid,p social_private.posts,c social_private.comments) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',c.id,'author',case when c.deleted or cu.id is null then '[deleted]' when c.author=p_me then cu.username when c.anonymous then case when c.author=p.author then 'OP' else 'Aggie '||substr(md5(p.id::text||c.author::text),1,4) end else cu.username end,'text',case when c.deleted then '[Reply deleted]' else c.body end,'anonymous',c.anonymous,'created',extract(epoch from c.created_at),'isOP',c.author=p.author,'deleted',c.deleted,'parentID',c.parent_id,'score',social_private.comment_score(c.id),'vote',case when c.deleted or p.deleted then 0 else coalesce((select value from social_private.comment_votes where comment=c.id and member=p_me),0)end)
 from (select 1)one left join social_private.members cu on cu.id=c.author
$$;
-- p_comment_limit keeps the newest replies (returned oldest first). Posts accept at most 200.
create or replace function social_private.post_json(p_me uuid,p social_private.posts,p_comment_limit integer default 200) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',p.id,'author',case when p.deleted or u.id is null then '[deleted]' when p.author=p_me then u.username when p.anonymous then 'Anonymous' else u.username end,'anonymous',p.anonymous,'community',p.community,'text',case when p.deleted then '[Post deleted]' else p.body end,'score',social_private.post_score(p.id),'vote',case when p.deleted then 0 else coalesce((select value from social_private.votes where post=p.id and member=p_me),0)end,'created',extract(epoch from p.created_at),'saved',exists(select 1 from social_private.bookmarks where post=p.id and member=p_me),'acceptsDM',p.accepts_dm and not p.deleted,'deleted',p.deleted,'attachmentID',case when p.deleted then null else(select id from social_private.attachments where post=p.id and ready limit 1)end,
 'linkURL',case when p.deleted then null else p.link_url end,'repostCount',(select count(*)from social_private.posts q where q.quoted_post=p.id and not q.deleted),'quote',case when p.deleted or p.quoted_post is null then null else social_private.quote_view(p_me,p.quoted_post)end,'tags',case when p.deleted then '[]'::jsonb else to_jsonb(p.tags)end,'poll',social_private.poll_view(p_me,p.id),
 'comments',coalesce((select jsonb_agg(w.cj order by w.ct,w.cid)from(select c.created_at ct,c.id cid,social_private.comment_json(p_me,p,c)cj from social_private.comments c where c.post=p.id and not social_private.blocked(p_me,c.author)order by c.created_at desc,c.id desc limit greatest(0,coalesce(p_comment_limit,200)))w),'[]'),
 'commentCount',(select count(*)from social_private.comments c where c.post=p.id and not social_private.blocked(p_me,c.author)),
 'changedAt',extract(epoch from p.changed_at))
 from (select 1)one left join social_private.members u on u.id=p.author
$$;
create or replace function social_private.visible_posts(p_me uuid,p_tag text default null,p_community text default null,p_limit integer default 150) returns jsonb language sql stable set search_path='' as $$
 select coalesce((select jsonb_agg(social_private.post_json(p_me,x.p)order by (x.p).created_at desc,(x.p).id desc)from(
  select p from social_private.posts p left join social_private.members u on u.id=p.author where social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community) and (p_tag is null or (not p.deleted and p.author is not null and not coalesce(u.banned,true) and p.tags @> array[p_tag])) and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id) order by p.created_at desc,p.id desc limit least(150,greatest(1,coalesce(p_limit,150))))x),'[]')
$$;
create or replace function social_private.post_documents(p_me uuid,p_ids uuid[]) returns jsonb language sql stable set search_path='' as $$
 select coalesce((select jsonb_agg(social_private.post_json(p_me,x.p)order by (x.p).created_at desc,(x.p).id desc)from(
  select p from social_private.posts p where p.id=any(p_ids) and social_private.can_read_post(p_me,p.id) and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id) order by p.created_at desc,p.id desc limit 50)x),'[]')
$$;

-- Keyset pages ------------------------------------------------------------------------------
create or replace function social_private.sync_time(p_value jsonb) returns timestamptz language plpgsql stable set search_path='' as $$
begin
 if p_value is null or jsonb_typeof(p_value)='null' then return null;end if;
 if jsonb_typeof(p_value)='number' then return to_timestamp((p_value#>>'{}')::double precision);end if;
 if jsonb_typeof(p_value)='string' then return (p_value#>>'{}')::timestamptz;end if;
 raise exception 'invalid:Use a valid page cursor.';
end $$;
create or replace function social_private.sync_limit(p_value jsonb,p_default integer) returns integer language plpgsql immutable set search_path='' as $$
begin
 if p_value is null or jsonb_typeof(p_value)='null' then return p_default;end if;
 if jsonb_typeof(p_value)<>'number' then raise exception 'invalid:Use a numeric page size.';end if;
 return least(50,greatest(1,floor((p_value#>>'{}')::numeric)::integer));
end $$;
create or replace function social_private.feed_page(p_me uuid,p_community text,p_before_created timestamptz,p_before_id uuid,p_limit integer) returns jsonb language sql stable set search_path='' as $$
 with page as(
  select x.p,row_number()over(order by (x.p).created_at desc,(x.p).id desc)n from(
   select p from social_private.posts p where social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
    and (p_before_created is null or (p_before_id is null and p.created_at<p_before_created) or (p_before_id is not null and (p.created_at,p.id)<(p_before_created,p_before_id)))
   order by p.created_at desc,p.id desc limit p_limit+1)x)
 select jsonb_build_object('posts',coalesce((select jsonb_agg(social_private.post_json(p_me,page.p,50)order by n)from page where n<=p_limit),'[]'),
  'next',(select jsonb_build_object('before_created',extract(epoch from (page.p).created_at),'before_id',(page.p).id)from page where n=p_limit and exists(select 1 from page later where later.n>p_limit)))
$$;
create or replace function social_private.feed_delta(p_me uuid,p_community text,p_since timestamptz,p_known uuid[]) returns jsonb language sql stable set search_path='' as $$
 with changed as(
  select x.p,row_number()over(order by (x.p).changed_at desc,(x.p).id)n from(
   select p from social_private.posts p where p.changed_at>p_since and (p.id=any(p_known) or p.created_at>p_since)
    and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community)
    and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
   order by p.changed_at desc,p.id limit 101)x)
 select jsonb_build_object(
  'changed',coalesce((select jsonb_agg(social_private.post_json(p_me,changed.p,50)order by (changed.p).created_at desc,(changed.p).id desc)from changed where n<=100),'[]'),
  'truncated',exists(select 1 from changed where n>100),
  -- Only ids the caller already holds are reported, so the answer reveals nothing new.
  'removed',coalesce((select jsonb_agg(distinct k)from unnest(p_known)k where
    exists(select 1 from social_private.post_tombstones t where t.id=k and t.removed_at>p_since)
    or not exists(select 1 from social_private.posts p where p.id=k and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community))
    or exists(select 1 from social_private.hidden h where h.member=p_me and h.post=k)),'[]'),
  -- Five seconds of overlap absorb writers that commit after this read started.
  'now',extract(epoch from now())-5)
$$;
create or replace function social_private.comments_page(p_me uuid,p social_private.posts,p_before_created timestamptz,p_before_id uuid,p_limit integer) returns jsonb language sql stable set search_path='' as $$
 with page as(
  select x.c,row_number()over(order by (x.c).created_at desc,(x.c).id desc)n from(
   select c from social_private.comments c where c.post=p.id and not social_private.blocked(p_me,c.author)
    and (p_before_created is null or (p_before_id is null and c.created_at<p_before_created) or (p_before_id is not null and (c.created_at,c.id)<(p_before_created,p_before_id)))
   order by c.created_at desc,c.id desc limit p_limit+1)x)
 select jsonb_build_object('post_id',p.id,
  'comments',coalesce((select jsonb_agg(social_private.comment_json(p_me,p,page.c)order by (page.c).created_at,(page.c).id)from page where n<=p_limit),'[]'),
  'next',(select jsonb_build_object('before_created',extract(epoch from (page.c).created_at),'before_id',(page.c).id)from page where n=p_limit and exists(select 1 from page later where later.n>p_limit)),
  'commentCount',(select count(*)from social_private.comments c where c.post=p.id and not social_private.blocked(p_me,c.author)))
$$;

-- Messages and conversation metadata (generated from the live definitions) -----------------
do $patch$
declare def text; old text; replacement text; start_at integer; end_at integer; tail text; meta_expr text;
begin
 def:=pg_get_functiondef('social_private.message_list(uuid,text)'::regprocedure);
 old:='social_private.message_list(p_me uuid, p_room text)';
 if strpos(def,old)=0 then raise exception 'message_list header anchor missing';end if;
 def:=replace(def,old,'social_private.message_page(p_me uuid, p_room text, p_after bigint, p_before bigint, p_limit integer)');
 old:='where m.room=p_room and social_private.can_read_room(p_me,p_room) and not social_private.blocked(p_me,m.author) order by m.seq desc limit 100) visible';
 replacement:='where m.room=p_room and (p_after is null or m.seq>p_after) and (p_before is null or m.seq<p_before) and social_private.can_read_room(p_me,p_room) and not social_private.blocked(p_me,m.author) order by case when p_after is not null then m.seq end asc,m.seq desc limit least(100,greatest(1,coalesce(p_limit,50)))) visible';
 if strpos(def,old)=0 then raise exception 'message_list window anchor missing';end if;
 execute replace(def,old,replacement);
 execute $sql$create or replace function social_private.message_list(p_me uuid,p_room text) returns jsonb language sql stable set search_path='' as $f$ select social_private.message_page(p_me,p_room,null,null,50) $f$$sql$;

 -- Report evidence keeps its previous 100-message window.
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='evidence:=social_private.message_list(me,room_id);';
 if strpos(def,old)=0 then raise exception 'gateway report evidence anchor missing';end if;
 def:=replace(def,old,'evidence:=social_private.message_page(me,room_id,null,null,100);');
 old:=E'if p_action=\'snapshot\' then null;';
 if strpos(def,old)=0 then raise exception 'gateway snapshot anchor missing';end if;
 def:=replace(def,old,E'if p_action=\'snapshot\' then null;\n elsif p_action in(\'feed.page\',\'feed.delta\',\'comments.page\',\'room.messages\') then\n  return social_private.feed_sync(me,p_action,p_input);');
 execute def;

 def:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 old:=E'\'conversationMeta\',coalesce((select jsonb_agg(';
 start_at:=strpos(def,old);
 if start_at=0 then raise exception 'snapshot conversationMeta anchor missing';end if;
 tail:=E') from social_private.rooms r join social_private.room_members rm on rm.room=r.id where (r.kind<>\'course\' or course_private.term_open(r.meta->>\'term\')) and rm.member=p_me and rm.status in(\'accepted\',\'invited\')),\'[]\'),';
 end_at:=strpos(substr(def,start_at),tail);
 if end_at=0 then raise exception 'snapshot conversationMeta tail anchor missing';end if;
 meta_expr:=substr(def,start_at+length(old),end_at-1-length(old));
 execute format($sql$create or replace function social_private.conversation_meta_list(p_me uuid,p_room text) returns jsonb language sql stable set search_path='' as $f$
  select coalesce((select jsonb_agg(%s) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where (p_room is null or r.id=p_room) and (r.kind<>'course' or course_private.term_open(r.meta->>'term')) and rm.member=p_me and rm.status in('accepted','invited')),'[]')
 $f$$sql$,meta_expr);
 def:=substr(def,1,start_at-1)||E'\'conversationMeta\',social_private.conversation_meta_list(p_me,null),'||substr(def,start_at+end_at-1+length(tail));
 -- The snapshot carries the first feed page (30 posts, newest 50 replies each) and its cursor.
 old:=E'\'posts\',social_private.visible_posts(p_me,null,nullif(current_setting(\'maroon.feed_community\',true),\'\')),';
 if strpos(def,old)=0 then raise exception 'snapshot posts anchor missing';end if;
 def:=replace(def,old,E'\'posts\',feed->\'posts\',\'feedNext\',feed->\'next\',\'serverNow\',extract(epoch from now())-5,');
 old:='declare result jsonb; begin';
 if strpos(def,old)=0 then raise exception 'snapshot declare anchor missing';end if;
 def:=replace(def,old,'declare result jsonb; feed jsonb; begin');
 old:=E'\n select jsonb_build_object(\'username\',me.username,';
 if strpos(def,old)=0 then raise exception 'snapshot select anchor missing';end if;
 def:=replace(def,old,E'\n feed:=social_private.feed_page(p_me,nullif(current_setting(\'maroon.feed_community\',true),\'\'),null,null,30);\n select jsonb_build_object(\'username\',me.username,');
 execute def;
end $patch$;

create or replace function social_private.feed_sync(p_me uuid,p_action text,p_input jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare community_value text; target social_private.posts; room_value text; after_value bigint; before_value bigint; limit_value integer; messages jsonb; known uuid[];
begin
 if p_action in('feed.page','feed.delta') then
  if p_input?'community' and jsonb_typeof(p_input->'community')<>'null' and (jsonb_typeof(p_input->'community')<>'string' or p_input->>'community' not in('Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates','NSFW')) then raise exception 'invalid:Choose an available community.';end if;
  community_value:=coalesce(nullif(p_input->>'community',''),nullif(current_setting('maroon.feed_community',true),''));
 end if;
 if p_action='feed.page' then
  if p_input?'before_id' and jsonb_typeof(p_input->'before_id')<>'null' and jsonb_typeof(p_input->'before_id')<>'string' then raise exception 'invalid:Use a valid page cursor.';end if;
  return social_private.feed_page(p_me,community_value,social_private.sync_time(p_input->'before_created'),(p_input->>'before_id')::uuid,social_private.sync_limit(p_input->'limit',30));
 elsif p_action='feed.delta' then
  if jsonb_typeof(p_input->'since') is distinct from 'number' then raise exception 'invalid:Use a numeric sync time.';end if;
  if p_input?'known_ids' and jsonb_typeof(p_input->'known_ids')<>'array' then raise exception 'invalid:Use a list of post ids.';end if;
  -- At most 300 known ids are considered; extra ids are ignored.
  select coalesce(array_agg(value::uuid),'{}') into known from(select value from jsonb_array_elements_text(coalesce(p_input->'known_ids','[]'))with ordinality e(value,i) order by i limit 300)ids;
  return social_private.feed_delta(p_me,community_value,social_private.sync_time(p_input->'since'),known);
 elsif p_action='comments.page' then
  select * into target from social_private.posts where id=(p_input->>'post_id')::uuid;
  if target.id is null or not social_private.can_read_post(p_me,target.id) or exists(select 1 from social_private.hidden h where h.member=p_me and h.post=target.id) then raise exception 'forbidden:This post is not available.';end if;
  if p_input?'before_id' and jsonb_typeof(p_input->'before_id')<>'null' and jsonb_typeof(p_input->'before_id')<>'string' then raise exception 'invalid:Use a valid page cursor.';end if;
  return social_private.comments_page(p_me,target,social_private.sync_time(p_input->'before_created'),(p_input->>'before_id')::uuid,social_private.sync_limit(p_input->'limit',50));
 elsif p_action='room.messages' then
  room_value:=p_input->>'room_id';
  if room_value is null or not social_private.can_read_room(p_me,room_value) then raise exception 'forbidden:This conversation is not available.';end if;
  if (p_input?'after_seq' and jsonb_typeof(p_input->'after_seq')<>'null' and jsonb_typeof(p_input->'after_seq')<>'number')
   or (p_input?'before_seq' and jsonb_typeof(p_input->'before_seq')<>'null' and jsonb_typeof(p_input->'before_seq')<>'number') then raise exception 'invalid:Use a numeric message cursor.';end if;
  after_value:=floor((p_input->>'after_seq')::numeric)::bigint;before_value:=floor((p_input->>'before_seq')::numeric)::bigint;
  if after_value is not null and before_value is not null then raise exception 'invalid:Choose newer or older messages, not both.';end if;
  limit_value:=social_private.sync_limit(p_input->'limit',50);
  messages:=social_private.message_page(p_me,room_value,after_value,before_value,limit_value);
  return jsonb_build_object('room_id',room_value,'messages',messages,'more',jsonb_array_length(messages)>=limit_value,
   'meta',community_private.decorate_snapshot(p_me,jsonb_build_object('conversationMeta',social_private.conversation_meta_list(p_me,room_value)))->'conversationMeta'->0);
 end if;
 raise exception 'invalid:Unknown social action.';
end $$;

do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.touch_posts(uuid[])','social_private.posts_touch_self()','social_private.posts_touch_related()','social_private.posts_tombstone()','social_private.touch_post_from_row()','social_private.touch_posts_for_members()',
  'social_private.comment_json(uuid,social_private.posts,social_private.comments)','social_private.post_json(uuid,social_private.posts,integer)','social_private.visible_posts(uuid,text,text,integer)','social_private.post_documents(uuid,uuid[])',
  'social_private.sync_time(jsonb)','social_private.sync_limit(jsonb,integer)','social_private.feed_page(uuid,text,timestamptz,uuid,integer)','social_private.feed_delta(uuid,text,timestamptz,uuid[])',
  'social_private.comments_page(uuid,social_private.posts,timestamptz,uuid,integer)','social_private.message_page(uuid,text,bigint,bigint,integer)','social_private.message_list(uuid,text)',
  'social_private.conversation_meta_list(uuid,text)','social_private.feed_sync(uuid,text,jsonb)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end $grants$;
