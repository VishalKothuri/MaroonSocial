-- Review fixes for reposts:
-- 1. A post the viewer reported is in social_private.hidden and is withheld by every
--    other reader; quote cards must collapse it to unavailable too.
-- 2. quote_view says whether the quoted post itself quotes another, so a quote of a
--    quote-only post can show a placeholder instead of an empty card.
-- 3. Report evidence for a post records what it quoted, so moderation can act on a
--    quote-only post after either side is deleted.
create or replace function social_private.quote_view(p_me uuid,p_post uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 select case when p.id is null or p.deleted or u.id is null or u.banned or not social_private.can_read_post(p_me,p.id) or social_private.blocked(p_me,p.author)
   or exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
  then jsonb_build_object('id',p_post,'unavailable',true)
  else jsonb_build_object('id',p.id,'author',case when p.author=p_me then u.username when p.anonymous then 'Anonymous' else u.username end,'anonymous',p.anonymous,'community',p.community,'text',left(p.body,280),'created',extract(epoch from p.created_at),'attachmentID',(select id from social_private.attachments where post=p.id and ready limit 1),'quotes',p.quoted_post is not null,'unavailable',false)end
 from (select p_post as id)target left join social_private.posts p on p.id=target.id left join social_private.members u on u.id=p.author
$$;
revoke all on function social_private.quote_view(uuid,uuid) from public,anon,authenticated;
grant execute on function social_private.quote_view(uuid,uuid) to service_role;

do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='evidence:=jsonb_build_object(''text'',p.body,''anonymous'',p.anonymous,''linkURL'',p.link_url,''tags'',p.tags,''poll'',social_private.poll_view(me,p.id)-''myOptionID'');';
 replacement:='evidence:=jsonb_build_object(''text'',p.body,''anonymous'',p.anonymous,''linkURL'',p.link_url,''tags'',p.tags,''poll'',social_private.poll_view(me,p.id)-''myOptionID'',''quotedPost'',p.quoted_post,''quotedText'',(select left(q.body,280) from social_private.posts q where q.id=p.quoted_post));';
 if strpos(def,old)=0 then raise exception 'report evidence anchor missing';end if;
 execute replace(def,old,replacement);
end $patch$;
