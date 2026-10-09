-- Follow-up to author_upvotes_named_replies: the feed and library projections
-- zeroed the author's own vote, so the starting upvote scored but never showed.
-- Karma now mirrors the score rules while skipping the author's own vote, so a
-- deleted post or reply never leaves a stray self-vote in the total.
do $patch$
declare def text; old text; replacement text; fn text;
begin
 foreach fn in array array['social_private.visible_posts(uuid,text,text,integer)','social_private.post_documents(uuid,uuid[])'] loop
  def:=pg_get_functiondef(fn::regprocedure);
  old:='''vote'',case when p.deleted or p.author=p_me then 0 else';
  replacement:='''vote'',case when p.deleted then 0 else';
  if strpos(def,old)=0 then raise exception '% post vote anchor missing',fn;end if;def:=replace(def,old,replacement);
  old:='''vote'',case when c.deleted or p.deleted or c.author=p_me then 0 else';
  replacement:='''vote'',case when c.deleted or p.deleted then 0 else';
  if strpos(def,old)=0 then raise exception '% reply vote anchor missing',fn;end if;def:=replace(def,old,replacement);
  execute def;
 end loop;
end $patch$;

create or replace function social_private.karma(p_me uuid) returns bigint language sql stable security invoker set search_path='' as $$
 select case when coalesce((select banned from social_private.members where id=p_me),true) then 0 else
  coalesce((select sum(v.value) from social_private.votes v join social_private.posts p on p.id=v.post join social_private.members voter on voter.id=v.member
   where p.author=p_me and not p.deleted and v.member<>p.author and not voter.banned and not social_private.blocked(v.member,p.author)),0)::bigint
  + coalesce((select sum(v.value) from social_private.comment_votes v join social_private.comments c on c.id=v.comment join social_private.posts p on p.id=c.post join social_private.members voter on voter.id=v.member
   where c.author=p_me and not c.deleted and not p.deleted and v.member<>c.author and not voter.banned and not social_private.blocked(v.member,c.author)),0)::bigint
 end
$$;
