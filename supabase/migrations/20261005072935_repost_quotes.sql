-- Reposts: a post may quote one other post. The quote is projected by quote_view with
-- the feed's anonymity rule and collapses to {"unavailable":true} once the source is
-- deleted, banned, blocked or otherwise unreadable, so the quoting post keeps standing.
-- Only one level is projected: a quote of a quote shows the quoted post's own body.
alter table social_private.posts add column quoted_post uuid references social_private.posts(id) on delete set null;
create index posts_quoted_post_idx on social_private.posts(quoted_post) where quoted_post is not null;

create function social_private.quote_view(p_me uuid,p_post uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 select case when p.id is null or p.deleted or u.id is null or u.banned or not social_private.can_read_post(p_me,p.id) or social_private.blocked(p_me,p.author)
  then jsonb_build_object('id',p_post,'unavailable',true)
  else jsonb_build_object('id',p.id,'author',case when p.author=p_me then u.username when p.anonymous then 'Anonymous' else u.username end,'anonymous',p.anonymous,'community',p.community,'text',left(p.body,280),'created',extract(epoch from p.created_at),'attachmentID',(select id from social_private.attachments where post=p.id and ready limit 1),'unavailable',false)end
 from (select p_post as id)target left join social_private.posts p on p.id=target.id left join social_private.members u on u.id=p.author
$$;
revoke all on function social_private.quote_view(uuid,uuid) from public,anon,authenticated;
grant execute on function social_private.quote_view(uuid,uuid) to service_role;

do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('social_private.rich_post_create(uuid,uuid,jsonb)'::regprocedure);
 old:='post_value uuid;poll_id uuid;';
 replacement:='post_value uuid;poll_id uuid;quoted_value uuid;quoted social_private.posts;';
 if strpos(def,old)=0 then raise exception 'rich_post_create declare anchor missing';end if;def:=replace(def,old,replacement);
 old:='if char_length(body_value)>1000 or(body_value=''''and link_value is null and poll_input is null)then raise exception ''invalid:Write up to 1,000 characters, add a link or create a poll.'';end if;';
 replacement:=E'if p_input?\'quoted_post_id\'and jsonb_typeof(p_input->\'quoted_post_id\')<>\'null\'then\n  if jsonb_typeof(p_input->\'quoted_post_id\')<>\'string\'or(p_input->>\'quoted_post_id\')!~\'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$\'then raise exception \'invalid:Choose a post to quote.\';end if;\n  quoted_value:=(p_input->>\'quoted_post_id\')::uuid;\n end if;\n if char_length(body_value)>1000 or(body_value=\'\'and link_value is null and poll_input is null and quoted_value is null)then raise exception \'invalid:Write up to 1,000 characters, add a link, quote a post or create a poll.\';end if;';
 if strpos(def,old)=0 then raise exception 'rich_post_create body anchor missing';end if;def:=replace(def,old,replacement);
 old:='p.link_url is distinct from link_value or p.tags is distinct from tags_value';
 replacement:='p.link_url is distinct from link_value or p.tags is distinct from tags_value or p.quoted_post is distinct from quoted_value';
 if strpos(def,old)=0 then raise exception 'rich_post_create retry anchor missing';end if;def:=replace(def,old,replacement);
 old:='insert into social_private.posts(author,nonce,body,anonymous,community,accepts_dm,link_url,tags)values(p_me,p_nonce,body_value,anonymous_value,community_value,dm_value,link_value,tags_value)returning id into post_value;';
 replacement:=E'if quoted_value is not null then\n  select *into quoted from social_private.posts where id=quoted_value;\n  if quoted.id is null or quoted.deleted or quoted.author is null or exists(select 1 from social_private.members where id=quoted.author and banned)or not social_private.can_read_post(p_me,quoted.id)or social_private.blocked(p_me,quoted.author)then raise exception \'invalid:That post is no longer available to quote.\';end if;\n  if quoted.community=\'NSFW\'and community_value<>\'NSFW\'then raise exception \'invalid:Keep adult discussions in the adult community.\';end if;\n end if;\n insert into social_private.posts(author,nonce,body,anonymous,community,accepts_dm,link_url,tags,quoted_post)values(p_me,p_nonce,body_value,anonymous_value,community_value,dm_value,link_value,tags_value,quoted_value)returning id into post_value;';
 if strpos(def,old)=0 then raise exception 'rich_post_create insert anchor missing';end if;def:=replace(def,old,replacement);
 execute def;

 old:='''linkURL'',case when p.deleted then null else p.link_url end,';
 replacement:='''linkURL'',case when p.deleted then null else p.link_url end,''repostCount'',(select count(*)from social_private.posts q where q.quoted_post=p.id and not q.deleted),''quote'',case when p.deleted or p.quoted_post is null then null else social_private.quote_view(p_me,p.quoted_post)end,';
 def:=pg_get_functiondef('social_private.visible_posts(uuid,text,text,integer)'::regprocedure);
 if strpos(def,old)=0 then raise exception 'visible_posts projection anchor missing';end if;execute replace(def,old,replacement);
 def:=pg_get_functiondef('social_private.post_documents(uuid,uuid[])'::regprocedure);
 if strpos(def,old)=0 then raise exception 'post_documents projection anchor missing';end if;execute replace(def,old,replacement);

 def:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 old:='select id,body,anonymous,community,accepts_dm,deleted,created_at,link_url,tags,social_private.poll_view(me,id)as poll from social_private.posts where author=me';
 replacement:='select id,body,anonymous,community,accepts_dm,deleted,created_at,link_url,tags,quoted_post,social_private.poll_view(me,id)as poll from social_private.posts where author=me';
 if strpos(def,old)=0 then raise exception 'account_controls post export anchor missing';end if;execute replace(def,old,replacement);
end $patch$;
