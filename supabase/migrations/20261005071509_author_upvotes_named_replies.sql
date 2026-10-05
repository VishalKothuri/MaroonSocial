-- A new post or reply starts with its author's own upvote (shown as "coming from
-- you"), authors may change that vote like any other, and scores count it.
-- Karma keeps excluding self votes so it still measures what others thought.
-- Replies may be named on any post; only the author of an anonymous post is held
-- anonymous in its thread so the OP cannot be unmasked by their own reply.
create or replace function social_private.post_score(p_post uuid) returns bigint language sql stable security invoker set search_path='' as $$
 select coalesce(sum(v.value),0) from social_private.votes v join social_private.posts p on p.id=v.post
 join social_private.members voter on voter.id=v.member join social_private.members author on author.id=p.author
 where p.id=p_post and not p.deleted and not voter.banned and not author.banned and not social_private.blocked(v.member,p.author)
$$;
create or replace function social_private.comment_score(p_comment uuid) returns bigint language sql stable security invoker set search_path='' as $$
 select coalesce(sum(v.value),0) from social_private.comment_votes v join social_private.comments c on c.id=v.comment
 join social_private.posts p on p.id=c.post join social_private.members voter on voter.id=v.member join social_private.members author on author.id=c.author
 where c.id=p_comment and not c.deleted and not p.deleted and not voter.banned and not author.banned and not social_private.blocked(v.member,c.author)
$$;
create or replace function social_private.karma(p_me uuid) returns bigint language sql stable security invoker set search_path='' as $$
 select coalesce((select sum(social_private.post_score(id))from social_private.posts where author=p_me and not deleted),0)::bigint
 - coalesce((select sum(v.value)from social_private.votes v join social_private.posts p on p.id=v.post where p.author=p_me and v.member=p_me and not p.deleted),0)::bigint
 + coalesce((select sum(social_private.comment_score(id))from social_private.comments where author=p_me and not deleted),0)::bigint
 - coalesce((select sum(v.value)from social_private.comment_votes v join social_private.comments c on c.id=v.comment where c.author=p_me and v.member=p_me and not c.deleted),0)::bigint
$$;

do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('social_private.rich_post_create(uuid,uuid,jsonb)'::regprocedure);
 old:=E' end if;\n return post_value;\nend $function$';
 replacement:=E' end if;\n insert into social_private.votes(member,post,value)values(p_me,post_value,1)on conflict(member,post)do nothing;\n return post_value;\nend $function$';
 if strpos(def,old)=0 then raise exception 'rich_post_create return anchor missing';end if;def:=replace(def,old,replacement);
 execute def;

 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='if p.deleted or p.author is null or p.author=me or exists(select 1 from social_private.members where id=p.author and banned)then raise exception ''forbidden:You can only vote on another active account’s post.'';end if;';
 replacement:='if p.deleted or p.author is null or exists(select 1 from social_private.members where id=p.author and banned)then raise exception ''forbidden:You can only vote on an active account’s post.'';end if;';
 if strpos(def,old)=0 then raise exception 'post.vote anchor missing';end if;def:=replace(def,old,replacement);
 old:='if c.id is null or c.deleted or p.deleted or c.author is null or c.author=me or not social_private.can_read_post(me,c.post)';
 replacement:='if c.id is null or c.deleted or p.deleted or c.author is null or not social_private.can_read_post(me,c.post)';
 if strpos(def,old)=0 then raise exception 'comment.vote anchor missing';end if;def:=replace(def,old,replacement);
 old:='c.anonymous<>(p.anonymous or coalesce((p_input->>''anonymous'')::boolean,true))';
 replacement:='c.anonymous<>((p.anonymous and p.author=me)or coalesce((p_input->>''anonymous'')::boolean,true))';
 if strpos(def,old)=0 then raise exception 'comment.create retry anchor missing';end if;def:=replace(def,old,replacement);
 old:='insert into social_private.comments(post,author,nonce,body,anonymous,parent_id)values(p.id,me,nonce_value,body_value,p.anonymous or coalesce((p_input->>''anonymous'')::boolean,true),parent_value)returning id::text into resource;';
 replacement:='insert into social_private.comments(post,author,nonce,body,anonymous,parent_id)values(p.id,me,nonce_value,body_value,(p.anonymous and p.author=me)or coalesce((p_input->>''anonymous'')::boolean,true),parent_value)returning id::text into resource;
    insert into social_private.comment_votes(member,comment,value)values(me,resource::uuid,1)on conflict(member,comment)do nothing;';
 if strpos(def,old)=0 then raise exception 'comment.create insert anchor missing';end if;def:=replace(def,old,replacement);
 execute def;
end $patch$;

-- Existing content gets the same starting upvote so older posts are not scored a point lower than new ones.
insert into social_private.votes(member,post,value)
 select p.author,p.id,1 from social_private.posts p where p.author is not null and not p.deleted on conflict(member,post)do nothing;
insert into social_private.comment_votes(member,comment,value)
 select c.author,c.id,1 from social_private.comments c where c.author is not null and not c.deleted on conflict(member,comment)do nothing;
