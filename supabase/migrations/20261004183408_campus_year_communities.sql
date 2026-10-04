-- Class-year feeds share the same anonymity, reporting, voting and DM rules.
-- They are discussion categories, not assertions of a verified class year.
alter table social_private.posts drop constraint posts_community_check;
alter table social_private.posts add constraint posts_community_check check
 (community in ('Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates','NSFW'));
create index posts_community_created on social_private.posts(community,created_at desc,id);

create or replace function social_private.can_read_post(p_member uuid,p_post uuid)
returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from social_private.posts p join social_private.members m on m.id=p_member
 where p.id=p_post and
 (p.community in('Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates')
  or(p.community='NSFW'and m.adult and m.nsfw_enabled))
 and not social_private.blocked(p_member,p.author))
$$;

do $patch$
declare definition text;needle text;replacement text;signature regprocedure;
begin
 foreach signature in array array['social_private.rich_post_create(uuid,uuid,jsonb)'::regprocedure,'public.social_gateway(text,text,jsonb)'::regprocedure]loop
  definition:=pg_get_functiondef(signature);
  needle:='not in(''Texas A&M'',''NSFW'')';
  if position(needle in definition)=0 then raise exception 'Expected community allowlist missing in %',signature;end if;
  definition:=replace(definition,needle,'not in(''Texas A&M'',''Freshmen'',''Sophomores'',''Juniors'',''Seniors'',''Graduates'',''NSFW'')');
  if signature='public.social_gateway(text,text,jsonb)'::regprocedure then
   needle:=E'begin\n if p_action=''register'' then';
   replacement:=$scope$begin
 -- A request-local selection prevents one busy cohort from consuming another
 -- feed's 150-post window. Legacy callers may omit it; access checks still apply.
 if p_input?'feed_community'and(jsonb_typeof(p_input->'feed_community')is distinct from 'string'
  or p_input->>'feed_community'not in('Texas A&M','Freshmen','Sophomores','Juniors','Seniors','Graduates','NSFW'))then
  raise exception 'invalid:Choose an available community.';
 end if;
 perform set_config('maroon.feed_community',coalesce(p_input->>'feed_community',''),true);
 if p_action='register' then$scope$;
   if position(needle in definition)=0 then raise exception 'Expected gateway entry point missing';end if;
   definition:=replace(definition,needle,replacement);
  end if;
  execute definition;
 end loop;
 definition:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 needle:='''posts'',social_private.visible_posts(p_me)';
 if position(needle in definition)=0 then raise exception 'Expected snapshot feed projection missing';end if;
 execute replace(definition,needle,'''feedCommunity'',nullif(current_setting(''maroon.feed_community'',true),''''),''posts'',social_private.visible_posts(p_me,null,nullif(current_setting(''maroon.feed_community'',true),''''))');
end $patch$;

revoke all on function social_private.can_read_post(uuid,uuid)from public,anon,authenticated;
grant execute on function social_private.can_read_post(uuid,uuid)to service_role;
