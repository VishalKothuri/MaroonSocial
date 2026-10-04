-- Reuse the deployed post projection so tag pages cannot drift from anonymous
-- aliases, nested replies, attachment access, polls, or score/karma privacy.
create index posts_tag_discovery on social_private.posts using gin(tags)where not deleted;
do $patch$
declare definition text;post_expression text;query_expression text;start_at int;end_at int;old_text text;new_text text;
begin
 definition:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 start_at:=position('''posts'',coalesce((select jsonb_agg(j order by created_at desc)'in definition);
 end_at:=position(E',\n ''courses'',coalesce('in definition);
 if start_at=0 or end_at<=start_at then raise exception 'Expected shared post projection not found';end if;
 post_expression:=substring(definition from start_at+length('''posts'',')for end_at-start_at-length('''posts'','));
 query_expression:=post_expression;
 old_text:='where social_private.can_read_post(p_me,p.id) and not exists';
 if position(old_text in query_expression)=0 then raise exception 'Expected post visibility predicate not found';end if;
 new_text:='where social_private.can_read_post(p_me,p.id) and (p_community is null or p.community=p_community) and (p_tag is null or (not p.deleted and p.author is not null and not coalesce(u.banned,true) and p.tags @> array[p_tag])) and not exists';
 query_expression:=replace(query_expression,old_text,new_text);
 if position('limit 150)posts'in query_expression)=0 then raise exception 'Expected post bound not found';end if;
 query_expression:=replace(query_expression,'limit 150)posts','limit least(150,greatest(1,coalesce(p_limit,150))))posts');
 execute 'create function social_private.visible_posts(p_me uuid,p_tag text default null,p_community text default null,p_limit integer default 150)returns jsonb language sql stable security invoker set search_path='''' as $body$ select '||query_expression||' $body$';
 execute substring(definition from 1 for start_at-1)||'''posts'',social_private.visible_posts(p_me)'||substring(definition from end_at);

 definition:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old_text:=' elsif p_action=''post.create'' then';
 if position(old_text in definition)=0 then raise exception 'Expected social gateway action boundary not found';end if;
 new_text:=$branch$ elsif p_action='posts.tag' then
  body_value:=lower(regexp_replace(btrim(coalesce(p_input->>'tag','')),'^#',''));
  username_value:=coalesce(p_input->>'community','Texas A&M');
  if jsonb_typeof(p_input->'tag')is distinct from 'string'or body_value!~'^[a-z0-9_]{1,24}$'or username_value not in('Texas A&M','NSFW')then raise exception 'invalid:Choose a valid tag and community.';end if;
  if username_value='NSFW'and not(m.adult and m.nsfw_enabled)then raise exception 'forbidden:Join the adult discussion community first.';end if;
  return jsonb_build_object('tag',body_value,'community',username_value,'posts',social_private.visible_posts(me,body_value,username_value,100));
 elsif p_action='post.create' then$branch$;
 execute replace(definition,old_text,new_text);
end $patch$;
revoke all on function social_private.visible_posts(uuid,text,text,integer)from public,anon,authenticated;
grant execute on function social_private.visible_posts(uuid,text,text,integer)to service_role;
