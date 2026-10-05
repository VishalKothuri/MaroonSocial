-- A direct message that started from a post (or from a reply on a post) keeps that
-- origin in room meta. context_post is nulled when the post row is hard-deleted on
-- account deletion, so meta.source_post is what lets the "From this post" tag stay
-- after the post is gone. The snapshot projects the tag without ever naming the author.
update social_private.rooms set meta=meta||jsonb_build_object('source_post',context_post::text) where kind='dm' and context_post is not null and not(meta?'source_post');
do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='insert into social_private.rooms(kind,title,status,anonymous,requester,context_post,meta)values(''dm'',''Conversation'',''pending'',p.id is not null,me,p.id,case when c.id is not null then jsonb_build_object(''source_comment'',c.id)else ''{}''::jsonb end)returning id into resource;';
 replacement:='insert into social_private.rooms(kind,title,status,anonymous,requester,context_post,meta)values(''dm'',''Conversation'',''pending'',p.id is not null,me,p.id,(case when p.id is not null then jsonb_build_object(''source_post'',p.id::text)else ''{}''::jsonb end)||(case when c.id is not null then jsonb_build_object(''source_comment'',c.id)else ''{}''::jsonb end))returning id into resource;';
 if strpos(def,old)=0 then raise exception 'dm.request insert anchor missing';end if;def:=replace(def,old,replacement);
 -- A named request never merges into an anonymous post room whose post row is gone.
 old:='rooms.kind=''dm'' and rooms.context_post is not distinct from p.id and rooms.meta->>''source_comment'' is not distinct from c.id::text';
 replacement:='rooms.kind=''dm'' and rooms.context_post is not distinct from p.id and rooms.meta->>''source_post'' is not distinct from p.id::text and rooms.meta->>''source_comment'' is not distinct from c.id::text';
 if strpos(def,old)=0 then raise exception 'dm.request lookup anchor missing';end if;def:=replace(def,old,replacement);
 execute def;
 def:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 old:='''pendingOutgoing'',r.status=''pending'' and r.requester=p_me,';
 replacement:=old||'''sourcePost'',case when r.kind=''dm'' and(r.context_post is not null or r.meta?''source_post'')then(select jsonb_build_object(''postID'',coalesce(r.context_post::text,r.meta->>''source_post''),''excerpt'',case when sp.id is not null and not sp.deleted and social_private.can_read_post(p_me,sp.id)then left(sp.body,140)else null end,''deleted'',sp.id is null or sp.deleted,''fromReply'',r.meta?''source_comment'')from(select 1)origin left join social_private.posts sp on sp.id=coalesce(r.context_post,case when r.meta->>''source_post''~''^[0-9a-fA-F-]{36}$''then(r.meta->>''source_post'')::uuid end))else null end,';
 if strpos(def,old)=0 then raise exception 'snapshot conversationMeta anchor missing';end if;def:=replace(def,old,replacement);
 execute def;
end $patch$;
