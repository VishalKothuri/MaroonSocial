-- Topic feeds, part 1: the topic catalog and one optional topic per post.
-- * social_private.topics holds the catalog (14 rows; the 8 launch topics start active, the
--   6 reserve topics inactive). Turning a topic on or off, renaming or recolouring it is a data
--   change that topics.list delivers (20261006210000), never an app release.
-- * posts.topic is optional: older builds and callers that leave it out keep working. post_json
--   projects it as "topic" (null for deleted posts), so the snapshot, feed reads, threads, tag
--   results and the library all carry it.
-- * rich_post_create accepts an optional "topic" (active, and adult-only topics only in NSFW).
--   It is patched from the live definition with anchors, the same way the author-upvote and
--   quote migrations patched it: the original function text is three patches behind.
-- * A retag moves the post's change marker, so feed.delta reports it.
-- * Existing posts tagged with an active topic slug or an approved alias get that topic.

create table if not exists social_private.topics(
 slug text primary key check (slug ~ '^[a-z0-9_]{1,24}$'),
 title text not null check (char_length(title) between 1 and 24),
 emoji text not null check (char_length(emoji) between 1 and 8),
 text_hex text not null check (text_hex ~ '^#[0-9A-F]{6}$'),
 fill_hex text not null check (fill_hex ~ '^#[0-9A-F]{6}$'),
 sort_order smallint not null,
 active boolean not null default true,
 -- Reserved for topics that only exist in the adult community.
 adult_only boolean not null default false
);
-- No policies: the catalog is reached only through the gateway, like the rest of social_private.
alter table social_private.topics enable row level security;
revoke all on social_private.topics from public,anon,authenticated;
grant select on social_private.topics to service_role;

insert into social_private.topics(slug,title,emoji,text_hex,fill_hex,sort_order,active)values
 ('academics','Academics','📚','#93C5FD','#21304C',1,true),
 ('aggie_life','Aggie Life','👍','#FDA4AF','#431C29',2,true),
 ('questions','Questions','❓','#67E8F9','#173B45',3,true),
 ('housing','Housing','🏠','#5EEAD4','#1A3B3C',4,true),
 ('sports','Sports','🏈','#FDBA74','#472D1F',5,true),
 ('relationships','Relationships','💘','#F9A8D4','#452539',6,true),
 ('confessions','Confessions','🤫','#F0ABFC','#41244A',7,true),
 ('memes','Memes','😂','#FDE047','#443A1C',8,true),
 ('food','Food','🌮','#FCD34D','#47361D',9,false),
 ('events','Events','🎉','#C4B5FD','#31294C',10,false),
 ('careers','Careers','💼','#6EE7B7','#193B34',11,false),
 ('greek_life','Greek Life','🏛️','#A5B4FC','#292B4B',12,false),
 ('mental_health','Mental Health','🫶','#7DD3FC','#183749',13,false),
 ('lost_found','Lost & Found','🔎','#BEF264','#303F1F',14,false)
on conflict(slug)do nothing;

alter table social_private.posts add column if not exists topic text references social_private.topics(slug) on update cascade;
-- A deleted post (or one whose author deleted their account) loses its topic along with its tags
-- and link, so topic-filtered reads cannot reveal what a deleted post was about. Topic pages
-- therefore never return deleted placeholders; a topic tab that held the post gets it in
-- feed.delta's "removed" (its topic no longer matches), and All still reports it as deleted.
-- The trigger also fires on topic updates, so no later write can put a topic on a deleted post.
create or replace function social_private.clear_deleted_post_extras()returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.deleted or new.author is null then
  new.link_url:=null;new.tags:='{}';new.topic:=null;
  delete from social_private.polls where post=new.id;
 end if;
 return new;
end $$;
drop trigger if exists clear_deleted_post_extras on social_private.posts;
create trigger clear_deleted_post_extras before update of deleted,author,topic on social_private.posts for each row execute function social_private.clear_deleted_post_extras();
-- Partial on "topic is not null"; deleted posts have no topic, so it holds live posts only.
create index if not exists posts_topic_feed on social_private.posts(community,topic,created_at desc,id desc) where topic is not null;

-- Whether a member may put this topic on a post in this community.
create or replace function social_private.topic_available(p_slug text,p_community text) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from social_private.topics t where t.slug=p_slug and t.active and (not t.adult_only or p_community='NSFW'))
$$;

do $patch$
declare def text; old text; replacement text;
begin
 -- rich_post_create: anchors are the live text after 20261005072935_repost_quotes.
 def:=pg_get_functiondef('social_private.rich_post_create(uuid,uuid,jsonb)'::regprocedure);
 old:='post_value uuid;poll_id uuid;quoted_value uuid;quoted social_private.posts;';
 if strpos(def,old)=0 then raise exception 'rich_post_create declare anchor missing';end if;
 def:=replace(def,old,old||'topic_value text;');
 -- Parse the topic before the nonce lookup so a retry is compared against the requested topic.
 old:='select *into p from social_private.posts where author=p_me and nonce=p_nonce for update;';
 replacement:=E'if p_input?\'topic\'and jsonb_typeof(p_input->\'topic\')<>\'null\'then\n  if jsonb_typeof(p_input->\'topic\')<>\'string\'then raise exception \'invalid:Choose an available topic.\';end if;\n  topic_value:=p_input->>\'topic\';\n end if;\n '||old;
 if strpos(def,old)=0 then raise exception 'rich_post_create nonce anchor missing';end if;
 def:=replace(def,old,replacement);
 -- Availability applies to new posts only: a retry of a post whose topic was disabled since
 -- returns the existing post instead of failing (and the client then creating a duplicate).
 old:='if(select count(*)from social_private.posts where author=p_me and created_at>now()-interval ''1 minute'')>=10 then';
 replacement:=E'if topic_value is not null and not social_private.topic_available(topic_value,community_value)then raise exception \'invalid:Choose an available topic.\';end if;\n '||old;
 if strpos(def,old)=0 then raise exception 'rich_post_create burst limit anchor missing';end if;
 def:=replace(def,old,replacement);
 old:='p.tags is distinct from tags_value or p.quoted_post is distinct from quoted_value';
 if strpos(def,old)=0 then raise exception 'rich_post_create retry anchor missing';end if;
 def:=replace(def,old,old||' or p.topic is distinct from topic_value');
 old:='insert into social_private.posts(author,nonce,body,anonymous,community,accepts_dm,link_url,tags,quoted_post)values(p_me,p_nonce,body_value,anonymous_value,community_value,dm_value,link_value,tags_value,quoted_value)returning id into post_value;';
 replacement:='insert into social_private.posts(author,nonce,body,anonymous,community,accepts_dm,link_url,tags,quoted_post,topic)values(p_me,p_nonce,body_value,anonymous_value,community_value,dm_value,link_value,tags_value,quoted_value,topic_value)returning id into post_value;';
 if strpos(def,old)=0 then raise exception 'rich_post_create insert anchor missing';end if;
 execute replace(def,old,replacement);

 -- post_json (20261005170000) projects the topic; a deleted post shows none.
 def:=pg_get_functiondef('social_private.post_json(uuid,social_private.posts,integer)'::regprocedure);
 old:='''tags'',case when p.deleted then ''[]''::jsonb else to_jsonb(p.tags)end,';
 if strpos(def,old)=0 then raise exception 'post_json tags anchor missing';end if;
 execute replace(def,old,old||'''topic'',case when p.deleted then null else p.topic end,');

 -- The member's data export lists each post's topic.
 def:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 old:='select id,body,anonymous,community,accepts_dm,deleted,created_at,link_url,tags,quoted_post,social_private.poll_view(me,id)as poll from social_private.posts where author=me';
 replacement:='select id,body,anonymous,community,accepts_dm,deleted,created_at,link_url,tags,quoted_post,topic,social_private.poll_view(me,id)as poll from social_private.posts where author=me';
 if strpos(def,old)=0 then raise exception 'account_controls post export anchor missing';end if;
 execute replace(def,old,replacement);

 -- Reports about a post record the topic it carried (for "Wrong topic" reviews).
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='''quotedText'',(select left(q.body,280) from social_private.posts q where q.id=p.quoted_post));';
 if strpos(def,old)=0 then raise exception 'gateway report evidence anchor missing';end if;
 execute replace(def,old,'''quotedText'',(select left(q.body,280) from social_private.posts q where q.id=p.quoted_post),''topic'',p.topic);');
end $patch$;

-- A retag of a live post moves its change marker (the definition from 20261005170000 plus topic).
drop trigger if exists posts_touch_self on social_private.posts;
create trigger posts_touch_self before update of body,deleted,accepts_dm,link_url,tags,author,anonymous,community,quoted_post,topic on social_private.posts for each row
 when (old.deleted is distinct from new.deleted or old.community is distinct from new.community
  or (not new.deleted and (old.body is distinct from new.body or old.accepts_dm is distinct from new.accepts_dm or old.link_url is distinct from new.link_url
   or old.tags is distinct from new.tags or old.author is distinct from new.author or old.anonymous is distinct from new.anonymous or old.quoted_post is distinct from new.quoted_post
   or old.topic is distinct from new.topic)))
 execute function social_private.posts_touch_self();

-- Backfill (after the trigger, so clients pick the topics up through feed.delta): a live post
-- without a topic takes the first of its tags, in tag order, that is an active topic slug or an
-- approved alias of one. Posts without such a tag stay under All only. Kept as an owner-only
-- function so the SQL suite can check the rule on its own fixtures.
create or replace function social_private.topic_backfill() returns integer language plpgsql set search_path='' as $$
declare changed integer;
begin
 with alias(tag,slug) as(values
   ('classes','academics'),('class','academics'),('study','academics'),('exam','academics'),('exams','academics'),
   ('meme','memes'),('confession','confessions'),('question','questions'),('help','questions'),
   ('roommate','housing'),('roommates','housing'),('apartment','housing'),('lease','housing'),
   ('football','sports'),('game','sports'),('gameday','sports')),
 pick as(
  select p.id,(select t.slug from unnest(p.tags)with ordinality u(tag,i)
    left join alias a on a.tag=u.tag
    join social_private.topics t on t.slug=coalesce(a.slug,u.tag) and t.active and (not t.adult_only or p.community='NSFW')
    order by u.i limit 1) slug
  from social_private.posts p where not p.deleted and p.topic is null and cardinality(p.tags)>0)
 update social_private.posts p set topic=pick.slug from pick where p.id=pick.id and pick.slug is not null;
 get diagnostics changed=row_count;
 return changed;
end $$;
revoke all on function social_private.topic_backfill() from public,anon,authenticated,service_role;
select social_private.topic_backfill();

-- create or replace keeps the privileges of the patched functions; only the new helper needs them.
revoke all on function social_private.topic_available(text,text) from public,anon,authenticated;
grant execute on function social_private.topic_available(text,text) to service_role;
