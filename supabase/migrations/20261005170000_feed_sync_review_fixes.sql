-- Caching phase 1, after adversarial review (on top of 20261005160000_feed_sync_incremental).
-- * Post JSON no longer carries posts.changed_at. A global microsecond change time let readers
--   group posts that one statement touched (a rename touched a member's anonymous posts and
--   replies along with the named ones). Each post now carries 'syncedAt', the server time of
--   the read, which orders two copies of a post just as well and reveals nothing.
-- * changed_at only moves for changes every reader can see: a rename touches named content and
--   quotes of it; a suspension touches what visibly loses or regains a score, poll or quote,
--   including posts the member voted on; a block touches only the votes between the two members.
--   Bookmarks touch nothing (saved is per viewer), rewriting already-deleted posts, replies or
--   messages touches nothing (they show placeholders), neither do votes or poll votes on a
--   deleted post (it projects no score or poll), and attachment changes reach quoting posts.
-- * What only one member sees (a block either way, a hidden post, their own rename) sets that
--   member's feed_resyncs marker. Their own feed.delta answers resync:true and the client
--   refetches the posts it holds with the new feed.posts read.
-- * messages.changed_at moves on deletion, edits, reactions and ready attachments; room.messages
--   with changed_since returns held messages that changed, so an open chat sees them in 3 s.
-- * Page sizes, time cursors and message sequences outside their ranges answer 'invalid'.

-- Post projection: read time instead of change time ------------------------------------------
create or replace function social_private.post_json(p_me uuid,p social_private.posts,p_comment_limit integer default 200) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',p.id,'author',case when p.deleted or u.id is null then '[deleted]' when p.author=p_me then u.username when p.anonymous then 'Anonymous' else u.username end,'anonymous',p.anonymous,'community',p.community,'text',case when p.deleted then '[Post deleted]' else p.body end,'score',social_private.post_score(p.id),'vote',case when p.deleted then 0 else coalesce((select value from social_private.votes where post=p.id and member=p_me),0)end,'created',extract(epoch from p.created_at),'saved',exists(select 1 from social_private.bookmarks where post=p.id and member=p_me),'acceptsDM',p.accepts_dm and not p.deleted,'deleted',p.deleted,'attachmentID',case when p.deleted then null else(select id from social_private.attachments where post=p.id and ready limit 1)end,
 'linkURL',case when p.deleted then null else p.link_url end,'repostCount',(select count(*)from social_private.posts q where q.quoted_post=p.id and not q.deleted),'quote',case when p.deleted or p.quoted_post is null then null else social_private.quote_view(p_me,p.quoted_post)end,'tags',case when p.deleted then '[]'::jsonb else to_jsonb(p.tags)end,'poll',social_private.poll_view(p_me,p.id),
 'comments',coalesce((select jsonb_agg(w.cj order by w.ct,w.cid)from(select c.created_at ct,c.id cid,social_private.comment_json(p_me,p,c)cj from social_private.comments c where c.post=p.id and not social_private.blocked(p_me,c.author)order by c.created_at desc,c.id desc limit greatest(0,coalesce(p_comment_limit,200)))w),'[]'),
 'commentCount',(select count(*)from social_private.comments c where c.post=p.id and not social_private.blocked(p_me,c.author)),
 'syncedAt',extract(epoch from now()))
 from (select 1)one left join social_private.members u on u.id=p.author
$$;

-- Per-member resync markers ------------------------------------------------------------------
create table if not exists social_private.feed_resyncs(member uuid primary key references social_private.members(id) on delete cascade,at timestamptz not null default now());
alter table social_private.feed_resyncs enable row level security;
revoke all on social_private.feed_resyncs from public,anon,authenticated;
grant select,insert,update,delete on social_private.feed_resyncs to service_role;
create or replace function social_private.mark_feed_resync(p_members uuid[]) returns void language plpgsql set search_path='' as $$
begin
 insert into social_private.feed_resyncs(member,at)select m.id,clock_timestamp()from social_private.members m where m.id=any(p_members)
  on conflict(member)do update set at=excluded.at;
-- A member row deleted in the same statement (account deletion cascades) needs no marker.
exception when foreign_key_violation then null;
end $$;

-- Change tracking that only follows what everyone can see -------------------------------------
create or replace function social_private.touch_post_from_row() returns trigger language plpgsql set search_path='' as $$
declare ids uuid[]:='{}'; keys uuid[]:='{}';
begin
 if tg_op in('INSERT','UPDATE') then
  if tg_table_name='comment_votes' then keys:=keys||new.comment;elsif tg_table_name='poll_votes' then keys:=keys||new.poll;else ids:=ids||new.post;end if;
 end if;
 if tg_op in('UPDATE','DELETE') then
  if tg_table_name='comment_votes' then keys:=keys||old.comment;elsif tg_table_name='poll_votes' then keys:=keys||old.poll;else ids:=ids||old.post;end if;
 end if;
 if tg_table_name='comment_votes' then ids:=array(select post from social_private.comments where id=any(keys));
 elsif tg_table_name='poll_votes' then ids:=array(select post from social_private.polls where id=any(keys));
 end if;
 -- A deleted post projects score 0, vote 0 and no poll, so votes on it (account deletion
 -- removes the member's votes, including the automatic upvote on their own long-deleted
 -- posts) change nothing anyone sees.
 if tg_table_name in('votes','poll_votes') then ids:=array(select id from social_private.posts where id=any(ids) and not deleted);end if;
 if cardinality(ids)>0 then perform social_private.touch_posts(ids);end if;
 return null;
end $$;
-- Saved is projected for the saver alone; their client updates it from its own mutation.
drop trigger if exists bookmarks_touch_post on social_private.bookmarks;
-- A deleted post or reply projects placeholders, so rewriting it again (account deletion
-- rewrites every post and reply of the member, including long-deleted ones) changes nothing
-- anyone sees and must not move it alongside the member's live content.
drop trigger if exists posts_touch_self on social_private.posts;
create trigger posts_touch_self before update of body,deleted,accepts_dm,link_url,tags,author,anonymous,community,quoted_post on social_private.posts for each row
 when (old.deleted is distinct from new.deleted or old.community is distinct from new.community
  or (not new.deleted and (old.body is distinct from new.body or old.accepts_dm is distinct from new.accepts_dm or old.link_url is distinct from new.link_url
   or old.tags is distinct from new.tags or old.author is distinct from new.author or old.anonymous is distinct from new.anonymous or old.quoted_post is distinct from new.quoted_post)))
 execute function social_private.posts_touch_self();
drop trigger if exists posts_touch_related_update on social_private.posts;
create trigger posts_touch_related_update after update of body,deleted,author,anonymous,quoted_post on social_private.posts for each row
 when (old.deleted is distinct from new.deleted
  or (not new.deleted and (old.body is distinct from new.body or old.author is distinct from new.author or old.anonymous is distinct from new.anonymous or old.quoted_post is distinct from new.quoted_post)))
 execute function social_private.posts_touch_related();
drop trigger if exists comments_touch_post on social_private.comments;
drop trigger if exists comments_touch_post_insert on social_private.comments;
create trigger comments_touch_post_insert after insert on social_private.comments for each row execute function social_private.touch_post_from_row();
drop trigger if exists comments_touch_post_update on social_private.comments;
create trigger comments_touch_post_update after update on social_private.comments for each row
 when (old.deleted is distinct from new.deleted or old.post is distinct from new.post
  or (not new.deleted and (old.body is distinct from new.body or old.anonymous is distinct from new.anonymous or old.author is distinct from new.author or old.parent_id is distinct from new.parent_id)))
 execute function social_private.touch_post_from_row();

-- Message change marker (before touch_messages: a SQL function body is checked when it is created).
-- Existing rows take the migration time (a constant default, so no table rewrite).
alter table social_private.messages add column if not exists changed_at timestamptz not null default now();
create or replace function social_private.touch_messages(p_ids uuid[]) returns void language sql set search_path='' as $$
 update social_private.messages set changed_at=clock_timestamp() where id=any(p_ids)
$$;
create or replace function social_private.attachments_touch() returns trigger language plpgsql set search_path='' as $$
declare ids uuid[]:='{}'; messages uuid[]:='{}';
begin
 if tg_op in('UPDATE','DELETE') and old.ready then
  if old.post is not null then ids:=ids||old.post;end if;
  if old.message is not null then messages:=messages||old.message;end if;
 end if;
 if tg_op in('INSERT','UPDATE') and new.ready then
  if new.post is not null then ids:=ids||new.post;end if;
  if new.message is not null then messages:=messages||new.message;end if;
 end if;
 -- The post card and every quote card of that post show the attachment.
 if cardinality(ids)>0 then perform social_private.touch_posts(ids||array(select id from social_private.posts where quoted_post=any(ids)));end if;
 if cardinality(messages)>0 then perform social_private.touch_messages(messages);end if;
 return null;
end $$;
drop trigger if exists attachments_touch_post on social_private.attachments;
drop trigger if exists attachments_touch_insert on social_private.attachments;
create trigger attachments_touch_insert after insert on social_private.attachments for each row when (new.ready) execute function social_private.attachments_touch();
drop trigger if exists attachments_touch_update on social_private.attachments;
create trigger attachments_touch_update after update of ready,post,message on social_private.attachments for each row when (old.ready is distinct from new.ready or old.post is distinct from new.post or old.message is distinct from new.message) execute function social_private.attachments_touch();
drop trigger if exists attachments_touch_delete on social_private.attachments;
create trigger attachments_touch_delete after delete on social_private.attachments for each row when (old.ready) execute function social_private.attachments_touch();

-- Quote cards of a physically deleted post collapse to "unavailable". This runs after the delete:
-- a BEFORE trigger must not update rows the same statement may still delete.
create or replace function social_private.posts_touch_quoting() returns trigger language plpgsql set search_path='' as $$
begin
 perform social_private.touch_posts(array(select id from social_private.posts where quoted_post=old.id));
 return null;
end $$;
drop trigger if exists posts_touch_quoting on social_private.posts;
create trigger posts_touch_quoting after delete on social_private.posts for each row execute function social_private.posts_touch_quoting();

create or replace function social_private.blocks_touch_posts() returns trigger language plpgsql set search_path='' as $$
declare x uuid; y uuid;
begin
 if tg_op='DELETE' then x:=old.blocker;y:=old.blocked;else x:=new.blocker;y:=new.blocked;end if;
 -- Scores, reply scores and poll counts skip votes between blocked members, and every reader
 -- sees those numbers: only posts carrying such a vote move. A block in the other direction
 -- (or a suspension of either member) already hides those votes, so then nothing moves.
 if not exists(select 1 from social_private.blocks where blocker=y and blocked=x)
  and not exists(select 1 from social_private.members where id in(x,y) and banned) then
  perform social_private.touch_posts(array(
   select p.id from social_private.votes v join social_private.posts p on p.id=v.post
    where v.value<>0 and not p.deleted and ((v.member=x and p.author=y) or (v.member=y and p.author=x))
   union select p.id from social_private.comment_votes v join social_private.comments c on c.id=v.comment join social_private.posts p on p.id=c.post
    where v.value<>0 and not c.deleted and not p.deleted and ((v.member=x and c.author=y) or (v.member=y and c.author=x))
   union select p.id from social_private.poll_votes v join social_private.polls q on q.id=v.poll join social_private.posts p on p.id=q.post
    where not p.deleted and ((v.member=x and p.author=y) or (v.member=y and p.author=x))));
 end if;
 -- Each other's posts, replies and quote cards change only for the two of them.
 perform social_private.mark_feed_resync(array[x,y]);
 return null;
end $$;
drop trigger if exists blocks_touch_posts on social_private.blocks;
create trigger blocks_touch_posts after insert or delete on social_private.blocks for each row execute function social_private.blocks_touch_posts();

create or replace function social_private.members_touch_posts() returns trigger language plpgsql set search_path='' as $$
declare m uuid:=new.id;
begin
 if old.banned is distinct from new.banned then
  -- Counted as the post showed it before a suspension (or shows it after a reinstatement):
  -- the member's own vote counts while they are not suspended.
  perform social_private.touch_posts(array(
   -- Their posts lose (or regain) a non-zero score or a poll.
   select p.id from social_private.posts p where p.author=m and not p.deleted
    and (exists(select 1 from social_private.polls q where q.post=p.id)
     or coalesce((select sum(v.value)from social_private.votes v join social_private.members voter on voter.id=v.member
      where v.post=p.id and (voter.id=m or not voter.banned) and not social_private.blocked(v.member,p.author)),0)<>0)
   -- Their replies lose (or regain) a non-zero score.
   union select c.post from social_private.comments c join social_private.posts p on p.id=c.post where c.author=m and not c.deleted and not p.deleted
    and coalesce((select sum(v.value)from social_private.comment_votes v join social_private.members voter on voter.id=v.member
     where v.comment=c.id and (voter.id=m or not voter.banned) and not social_private.blocked(v.member,c.author)),0)<>0
   -- Quote cards of their posts collapse to (or return from) "unavailable".
   union select q.id from social_private.posts q join social_private.posts p on p.id=q.quoted_post where p.author=m and not p.deleted and not q.deleted
   -- Their votes stop (or start) counting wherever they counted.
   union select p.id from social_private.votes v join social_private.posts p on p.id=v.post join social_private.members author on author.id=p.author
    where v.member=m and v.value<>0 and p.author<>m and not p.deleted and not author.banned and not social_private.blocked(m,p.author)
   union select c.post from social_private.comment_votes v join social_private.comments c on c.id=v.comment join social_private.posts p on p.id=c.post join social_private.members author on author.id=c.author
    where v.member=m and v.value<>0 and c.author<>m and not c.deleted and not p.deleted and not author.banned and not social_private.blocked(m,c.author)
   union select p.id from social_private.poll_votes v join social_private.polls q on q.id=v.poll join social_private.posts p on p.id=q.post join social_private.members author on author.id=p.author
    where v.member=m and p.author<>m and not p.deleted and not author.banned and not social_private.blocked(m,p.author)));
 end if;
 if old.username is distinct from new.username then
  -- Only content that shows the name moves: named posts, named replies and quotes of named posts.
  -- Anonymous posts and replies look the same to everyone else, so they must not move with them.
  perform social_private.touch_posts(array(
   select id from social_private.posts where author=m and not anonymous and not deleted
   union select c.post from social_private.comments c where c.author=m and not c.anonymous and not c.deleted
   union select q.id from social_private.posts q join social_private.posts p on p.id=q.quoted_post where p.author=m and not p.anonymous and not p.deleted and not q.deleted));
  -- The member sees their own name on their anonymous posts and replies.
  perform social_private.mark_feed_resync(array[m]);
 end if;
 return null;
end $$;
drop trigger if exists members_touch_posts on social_private.members;
create trigger members_touch_posts after update of banned,username on social_private.members for each row when (old.banned is distinct from new.banned or old.username is distinct from new.username) execute function social_private.members_touch_posts();
drop function if exists social_private.touch_posts_for_members();

create or replace function social_private.hidden_resync() returns trigger language plpgsql set search_path='' as $$
begin
 -- A hidden post leaves that member's feed (feed.delta reports it removed) and collapses in
 -- their quote cards; nobody else sees a difference.
 if tg_op='DELETE' then perform social_private.mark_feed_resync(array[old.member]);
 else perform social_private.mark_feed_resync(array[new.member]);end if;
 return null;
end $$;
drop trigger if exists hidden_resync on social_private.hidden;
create trigger hidden_resync after insert or delete on social_private.hidden for each row execute function social_private.hidden_resync();

-- Message change marker (the column is added above, before touch_messages) ---------------------
create index if not exists messages_room_changed on social_private.messages(room,changed_at);
create or replace function social_private.messages_touch_self() returns trigger language plpgsql set search_path='' as $$
begin new.changed_at:=clock_timestamp();return new;end $$;
drop trigger if exists messages_touch_self on social_private.messages;
create trigger messages_touch_self before update of body,deleted,game,game_session_id on social_private.messages for each row
 when (old.deleted is distinct from new.deleted
  or (not new.deleted and (old.body is distinct from new.body or old.game is distinct from new.game or old.game_session_id is distinct from new.game_session_id)))
 execute function social_private.messages_touch_self();
create or replace function social_private.reactions_touch_message() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op in('INSERT','UPDATE') then perform social_private.touch_messages(array[new.message]);end if;
 if tg_op in('UPDATE','DELETE') then perform social_private.touch_messages(array[old.message]);end if;
 return null;
end $$;
drop trigger if exists reactions_touch_message on social_private.reactions;
create trigger reactions_touch_message after insert or update or delete on social_private.reactions for each row execute function social_private.reactions_touch_message();

-- message_changes: the message_page projection (generated from the live definition, so the
-- message JSON cannot fork) over held messages (seq <= p_upto) changed after p_since.
do $patch$
declare def text; old text;
begin
 def:=pg_get_functiondef('social_private.message_page(uuid,text,bigint,bigint,integer)'::regprocedure);
 old:='social_private.message_page(p_me uuid, p_room text, p_after bigint, p_before bigint, p_limit integer)';
 if strpos(def,old)=0 then raise exception 'message_page header anchor missing';end if;
 def:=replace(def,old,'social_private.message_changes(p_me uuid, p_room text, p_upto bigint, p_since timestamp with time zone)');
 old:='where m.room=p_room and (p_after is null or m.seq>p_after) and (p_before is null or m.seq<p_before) and social_private.can_read_room(p_me,p_room) and not social_private.blocked(p_me,m.author) order by case when p_after is not null then m.seq end asc,m.seq desc limit least(100,greatest(1,coalesce(p_limit,50)))) visible';
 if strpos(def,old)=0 then raise exception 'message_page window anchor missing';end if;
 execute replace(def,old,'where m.room=p_room and m.seq<=p_upto and m.changed_at>p_since and social_private.can_read_room(p_me,p_room) and not social_private.blocked(p_me,m.author) order by m.changed_at desc,m.seq desc limit 50) visible');

 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:=E'elsif p_action in(\'feed.page\',\'feed.delta\',\'comments.page\',\'room.messages\') then';
 if strpos(def,old)=0 then raise exception 'gateway feed_sync anchor missing';end if;
 execute replace(def,old,E'elsif p_action in(\'feed.page\',\'feed.delta\',\'feed.posts\',\'comments.page\',\'room.messages\') then');
end $patch$;

-- Reads -----------------------------------------------------------------------------------------
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
  -- p_since carries the five seconds of overlap below, so p_since+5 s is when the previous
  -- delta read: a marker after it has not been answered by a refetch yet.
  'resync',exists(select 1 from social_private.feed_resyncs r where r.member=p_me and r.at>p_since+interval '5 seconds'),
  -- Five seconds of overlap absorb writers that commit after this read started.
  'now',extract(epoch from now())-5)
$$;
-- Held posts by id (a resync or a truncated delta): current copies plus the ids that are gone.
create or replace function social_private.feed_posts(p_me uuid,p_community text,p_ids uuid[]) returns jsonb language sql stable set search_path='' as $$
 with found as(
  select p from social_private.posts p where p.id=any(p_ids) and social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community)
   and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id))
 select jsonb_build_object(
  'posts',coalesce((select jsonb_agg(social_private.post_json(p_me,found.p,50)order by (found.p).created_at desc,(found.p).id desc)from found),'[]'),
  'removed',coalesce((select jsonb_agg(distinct k)from unnest(p_ids)k where not exists(select 1 from found where (found.p).id=k)),'[]'))
$$;

create or replace function social_private.sync_time(p_value jsonb) returns timestamptz language plpgsql stable set search_path='' as $$
declare seconds numeric; moment timestamptz;
begin
 if p_value is null or jsonb_typeof(p_value)='null' then return null;end if;
 -- Cursors and clocks this API hands out lie between 1970 and 2100.
 if jsonb_typeof(p_value)='number' then
  seconds:=(p_value#>>'{}')::numeric;
  if seconds<0 or seconds>4102444800 then raise exception 'invalid:Use a valid time cursor.';end if;
  return to_timestamp(seconds::double precision);
 end if;
 if jsonb_typeof(p_value)='string' then
  begin moment:=(p_value#>>'{}')::timestamptz;
  exception when others then raise exception 'invalid:Use a valid time cursor.';
  end;
  if moment is null or moment<'1970-01-01 00:00:00+00'::timestamptz or moment>'2100-01-01 00:00:00+00'::timestamptz then raise exception 'invalid:Use a valid time cursor.';end if;
  return moment;
 end if;
 raise exception 'invalid:Use a valid time cursor.';
end $$;
create or replace function social_private.sync_limit(p_value jsonb,p_default integer) returns integer language plpgsql immutable set search_path='' as $$
begin
 if p_value is null or jsonb_typeof(p_value)='null' then return p_default;end if;
 if jsonb_typeof(p_value)<>'number' then raise exception 'invalid:Use a numeric page size.';end if;
 -- Clamp before the integer cast so a huge number clamps instead of overflowing.
 return least(50,greatest(1,floor((p_value#>>'{}')::numeric)))::integer;
end $$;
create or replace function social_private.sync_seq(p_value jsonb) returns bigint language plpgsql immutable set search_path='' as $$
declare sequence_value numeric;
begin
 if p_value is null or jsonb_typeof(p_value)='null' then return null;end if;
 if jsonb_typeof(p_value)<>'number' then raise exception 'invalid:Use a numeric message cursor.';end if;
 sequence_value:=floor((p_value#>>'{}')::numeric);
 if sequence_value<0 or sequence_value>9000000000000000000 then raise exception 'invalid:Use a valid message cursor.';end if;
 return sequence_value::bigint;
end $$;

create or replace function social_private.feed_sync(p_me uuid,p_action text,p_input jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare community_value text; target social_private.posts; room_value text; after_value bigint; before_value bigint; limit_value integer; messages jsonb; known uuid[]; result jsonb;
begin
 if p_action in('feed.page','feed.delta','feed.posts') then
  if p_input?'community' and jsonb_typeof(p_input->'community')<>'null' and (jsonb_typeof(p_input->'community')<>'string' or p_input->>'community' not in('Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates','NSFW')) then raise exception 'invalid:Choose an available community.';end if;
  community_value:=coalesce(nullif(p_input->>'community',''),nullif(current_setting('maroon.feed_community',true),''));
 end if;
 if p_action='feed.page' then
  if p_input?'before_id' and jsonb_typeof(p_input->'before_id')<>'null' and jsonb_typeof(p_input->'before_id')<>'string' then raise exception 'invalid:Use a valid page cursor.';end if;
  return social_private.feed_page(p_me,community_value,social_private.sync_time(p_input->'before_created'),(p_input->>'before_id')::uuid,social_private.sync_limit(p_input->'limit',30));
 elsif p_action='feed.delta' then
  if jsonb_typeof(p_input->'since') is distinct from 'number' then raise exception 'invalid:Use a numeric sync time.';end if;
  if p_input?'known_ids' and (jsonb_typeof(p_input->'known_ids')<>'array' or exists(select 1 from jsonb_array_elements(p_input->'known_ids')e where jsonb_typeof(e)<>'string')) then raise exception 'invalid:Use a list of post ids.';end if;
  -- At most 300 known ids are considered; extra ids are ignored.
  select coalesce(array_agg(value::uuid),'{}') into known from(select value from jsonb_array_elements_text(coalesce(p_input->'known_ids','[]'))with ordinality e(value,i) order by i limit 300)ids;
  return social_private.feed_delta(p_me,community_value,social_private.sync_time(p_input->'since'),known);
 elsif p_action='feed.posts' then
  if jsonb_typeof(p_input->'ids') is distinct from 'array' or exists(select 1 from jsonb_array_elements(p_input->'ids')e where jsonb_typeof(e)<>'string') then raise exception 'invalid:Use a list of post ids.';end if;
  -- At most 50 ids per read; extra ids are ignored.
  select coalesce(array_agg(value::uuid),'{}') into known from(select value from jsonb_array_elements_text(p_input->'ids')with ordinality e(value,i) order by i limit 50)ids;
  return social_private.feed_posts(p_me,community_value,known);
 elsif p_action='comments.page' then
  select * into target from social_private.posts where id=(p_input->>'post_id')::uuid;
  if target.id is null or not social_private.can_read_post(p_me,target.id) or exists(select 1 from social_private.hidden h where h.member=p_me and h.post=target.id) then raise exception 'forbidden:This post is not available.';end if;
  if p_input?'before_id' and jsonb_typeof(p_input->'before_id')<>'null' and jsonb_typeof(p_input->'before_id')<>'string' then raise exception 'invalid:Use a valid page cursor.';end if;
  return social_private.comments_page(p_me,target,social_private.sync_time(p_input->'before_created'),(p_input->>'before_id')::uuid,social_private.sync_limit(p_input->'limit',50));
 elsif p_action='room.messages' then
  room_value:=p_input->>'room_id';
  if room_value is null or not social_private.can_read_room(p_me,room_value) then raise exception 'forbidden:This conversation is not available.';end if;
  after_value:=social_private.sync_seq(p_input->'after_seq');before_value:=social_private.sync_seq(p_input->'before_seq');
  if after_value is not null and before_value is not null then raise exception 'invalid:Choose newer or older messages, not both.';end if;
  limit_value:=social_private.sync_limit(p_input->'limit',50);
  messages:=social_private.message_page(p_me,room_value,after_value,before_value,limit_value);
  result:=jsonb_build_object('room_id',room_value,'messages',messages,'more',jsonb_array_length(messages)>=limit_value,
   'meta',community_private.decorate_snapshot(p_me,jsonb_build_object('conversationMeta',social_private.conversation_meta_list(p_me,room_value)))->'conversationMeta'->0,
   -- Clock for the next changed_since, with the same five seconds of overlap as feed.delta.
   'now',extract(epoch from now())-5);
  if p_input?'changed_since' and jsonb_typeof(p_input->'changed_since')<>'null' then
   if jsonb_typeof(p_input->'changed_since')<>'number' then raise exception 'invalid:Use a numeric sync time.';end if;
   if after_value is null then raise exception 'invalid:Ask for changes together with newer messages.';end if;
   -- Held messages (up to after_seq) deleted, edited or reacted to since the previous poll.
   result:=result||jsonb_build_object('changed',social_private.message_changes(p_me,room_value,after_value,social_private.sync_time(p_input->'changed_since')));
  end if;
  return result;
 end if;
 raise exception 'invalid:Unknown social action.';
exception when numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow then
 raise exception 'invalid:Some fields are invalid. Please check and try again.';
end $$;

do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.post_json(uuid,social_private.posts,integer)','social_private.mark_feed_resync(uuid[])','social_private.touch_post_from_row()',
  'social_private.touch_messages(uuid[])','social_private.attachments_touch()','social_private.posts_touch_quoting()','social_private.blocks_touch_posts()','social_private.members_touch_posts()',
  'social_private.hidden_resync()','social_private.messages_touch_self()','social_private.reactions_touch_message()',
  'social_private.message_changes(uuid,text,bigint,timestamptz)','social_private.feed_delta(uuid,text,timestamptz,uuid[])','social_private.feed_posts(uuid,text,uuid[])',
  'social_private.sync_time(jsonb)','social_private.sync_limit(jsonb,integer)','social_private.sync_seq(jsonb)','social_private.feed_sync(uuid,text,jsonb)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end $grants$;
