-- Post extras remain under the existing authenticated community gateway. Poll
-- choices never expose voter identities; only aggregate counts and one's own
-- current choice are projected. All objects are private and service-role-only.
alter table social_private.posts add column link_url text;
alter table social_private.posts add column tags text[] not null default '{}';

create table social_private.polls (
 id uuid primary key default gen_random_uuid(),
 post uuid not null unique references social_private.posts(id) on delete cascade,
 question text not null check(char_length(question) between 1 and 180),
 duration_hours smallint not null check(duration_hours in(24,72,168)),
 ends_at timestamptz not null,
 created_at timestamptz not null default now()
);
create table social_private.poll_options (
 id uuid primary key default gen_random_uuid(),
 poll uuid not null references social_private.polls(id) on delete cascade,
 position smallint not null check(position between 1 and 4),
 body text not null check(char_length(body) between 1 and 80),
 unique(poll,position),unique(poll,id)
);
create table social_private.poll_votes (
 poll uuid not null references social_private.polls(id) on delete cascade,
 member uuid not null references social_private.members(id) on delete cascade,
 option_id uuid not null,
 updated_at timestamptz not null default now(),
 primary key(poll,member),
 foreign key(poll,option_id) references social_private.poll_options(poll,id) on delete cascade
);
create unique index poll_options_distinct_text on social_private.poll_options(poll,lower(body));
create index poll_votes_member on social_private.poll_votes(member);
create index poll_votes_option on social_private.poll_votes(poll,option_id);
alter table social_private.polls enable row level security;
alter table social_private.poll_options enable row level security;
alter table social_private.poll_votes enable row level security;
create policy "Server access" on social_private.polls for all to service_role using(true)with check(true);
create policy "Server access" on social_private.poll_options for all to service_role using(true)with check(true);
create policy "Server access" on social_private.poll_votes for all to service_role using(true)with check(true);
revoke all on social_private.polls,social_private.poll_options,social_private.poll_votes from public,anon,authenticated;
grant all on social_private.polls,social_private.poll_options,social_private.poll_votes to service_role;

create function social_private.post_link(p_value text)returns text language plpgsql immutable security invoker set search_path='' as $$
declare value text:=nullif(btrim(p_value),'');parts text[];authority text;host text;port_value text;ending text;parsed_ip inet;
begin
 if value is null then return null;end if;
 if char_length(value)>2048 or value~'[[:space:][:cntrl:]]' or position(chr(92)in value)>0 then raise exception 'invalid:Use an HTTP or HTTPS link up to 2,048 characters without spaces.';end if;
 parts:=regexp_match(value,'^(https?)://([^/?#]+)(.*)$','i');
 if parts is null then raise exception 'invalid:Use a complete HTTP or HTTPS link.';end if;
 authority:=parts[2];
 if authority like '%@%'then raise exception 'invalid:Links cannot contain a username or password.';end if;
 if left(authority,1)='['then
  host:=substring(authority from '^\[([^]]+)\]');ending:=substring(authority from '^\[[^]]+\](.*)$');
  if host is null or ending is null or ending!~'^(:[0-9]{1,5})?$'then raise exception 'invalid:This link address is invalid.';end if;
  begin parsed_ip:=host::inet;exception when invalid_text_representation then raise exception 'invalid:This link address is invalid.';end;
  if family(parsed_ip)<>6 or position('/'in host)>0 then raise exception 'invalid:This link address is invalid.';end if;
  port_value:=nullif(ltrim(ending,':'),'');
 else
  host:=split_part(authority,':',1);port_value:=nullif(split_part(authority,':',2),'');
  if char_length(host)>253 or host!~'^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$'
   or (position(':'in authority)>0 and authority!~'^[^:]+:[0-9]{1,5}$')then raise exception 'invalid:This link address is invalid.';end if;
 end if;
 if port_value is not null and port_value::int not between 1 and 65535 then raise exception 'invalid:This link port is invalid.';end if;
 return lower(parts[1])||'://'||lower(authority)||parts[3];
end $$;

create function social_private.rich_post_create(p_me uuid,p_nonce uuid,p_input jsonb)returns uuid language plpgsql security invoker set search_path='' as $$
declare p social_private.posts;poll_value social_private.polls;body_value text:=btrim(coalesce(p_input->>'text',''));link_value text;tag_value text;tags_value text[]:='{}';
 community_value text:=coalesce(p_input->>'community','Texas A&M');anonymous_value boolean:=coalesce((p_input->>'anonymous')::boolean,true);dm_value boolean:=coalesce((p_input->>'acceptsDM')::boolean,true);
 poll_input jsonb:=nullif(p_input->'poll','null'::jsonb);question_value text;options_value text[];duration_value int;item jsonb;position_value int;post_value uuid;poll_id uuid;
begin
 if (p_input?'text'and jsonb_typeof(p_input->'text')not in('string','null'))or(p_input?'link_url'and jsonb_typeof(p_input->'link_url')not in('string','null'))then raise exception 'invalid:Post text and link must be text.';end if;
 link_value:=social_private.post_link(p_input->>'link_url');
 if community_value not in('Texas A&M','NSFW')then raise exception 'invalid:Choose an available community.';end if;
 if community_value='NSFW'and not exists(select 1 from social_private.members where id=p_me and adult and nsfw_enabled)then raise exception 'forbidden:Join the adult discussion community first.';end if;
 if p_input?'tags'and p_input->'tags'<>'null'::jsonb then
  if jsonb_typeof(p_input->'tags')<>'array'then raise exception 'invalid:Tags must be a list.';end if;
  if jsonb_array_length(p_input->'tags')>5 then raise exception 'invalid:Add up to five tags.';end if;
  for item in select value from jsonb_array_elements(p_input->'tags')loop
   if jsonb_typeof(item)<>'string'then raise exception 'invalid:Use text tags.';end if;
   tag_value:=lower(regexp_replace(btrim(item#>>'{}'),'^#',''));
   if tag_value!~'^[a-z0-9_]{1,24}$'then raise exception 'invalid:Tags need 1–24 letters, numbers or underscores.';end if;
   if not tag_value=any(tags_value)then tags_value:=array_append(tags_value,tag_value);end if;
  end loop;
 end if;
 if poll_input is not null then
  if jsonb_typeof(poll_input)<>'object'or jsonb_typeof(poll_input->'question')is distinct from 'string'or jsonb_typeof(poll_input->'options')is distinct from 'array'then raise exception 'invalid:Enter a poll question and two to four options.';end if;
  question_value:=btrim(poll_input->>'question');
  if char_length(question_value)not between 1 and 180 or jsonb_array_length(poll_input->'options')not between 2 and 4 then raise exception 'invalid:Use a question up to 180 characters and two to four options.';end if;
  options_value:='{}';
  for item in select value from jsonb_array_elements(poll_input->'options')loop
   if jsonb_typeof(item)<>'string'or char_length(btrim(item#>>'{}'))not between 1 and 80 then raise exception 'invalid:Each poll option needs 1–80 characters.';end if;
   if exists(select 1 from unnest(options_value)option_text where lower(option_text)=lower(btrim(item#>>'{}')))then raise exception 'invalid:Use different poll options.';end if;
   options_value:=array_append(options_value,btrim(item#>>'{}'));
  end loop;
  if jsonb_typeof(poll_input->'duration_hours')is distinct from 'number'or coalesce(poll_input->>'duration_hours','')not in('24','72','168')then raise exception 'invalid:Polls can run for 24 hours, 3 days or 7 days.';end if;
  duration_value:=(poll_input->>'duration_hours')::int;
 end if;
 if char_length(body_value)>1000 or(body_value=''and link_value is null and poll_input is null)then raise exception 'invalid:Write up to 1,000 characters, add a link or create a poll.';end if;
 -- require_member already holds this account's row lock. All creation and nonce
 -- retries therefore serialize per member, including an initially empty draft.
 select *into p from social_private.posts where author=p_me and nonce=p_nonce for update;
 if p.id is not null then
  select *into poll_value from social_private.polls where post=p.id;
  if p.deleted or p.body<>body_value or p.community<>community_value or p.anonymous<>anonymous_value or p.accepts_dm<>dm_value or p.link_url is distinct from link_value or p.tags is distinct from tags_value
   or(poll_value.id is null)<>(poll_input is null)or(poll_input is not null and(poll_value.question<>question_value or poll_value.duration_hours<>duration_value or(select array_agg(body order by position)from social_private.poll_options where poll=poll_value.id)is distinct from options_value))then
   raise exception 'conflict:This post identifier was already used. Retry the original post.';
  end if;
  return p.id;
 end if;
 if(select count(*)from social_private.posts where author=p_me and created_at>now()-interval '1 minute')>=10 then raise exception 'rate_limit:Take a moment before posting again.';end if;
 insert into social_private.posts(author,nonce,body,anonymous,community,accepts_dm,link_url,tags)values(p_me,p_nonce,body_value,anonymous_value,community_value,dm_value,link_value,tags_value)returning id into post_value;
 if poll_input is not null then
  insert into social_private.polls(post,question,duration_hours,ends_at)values(post_value,question_value,duration_value,clock_timestamp()+make_interval(hours=>duration_value))returning id into poll_id;
  for position_value in 1..array_length(options_value,1)loop
   insert into social_private.poll_options(poll,position,body)values(poll_id,position_value,options_value[position_value]);
  end loop;
 end if;
 return post_value;
end $$;

create function social_private.poll_view(p_me uuid,p_post uuid)returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('id',q.id,'question',q.question,'endsAt',extract(epoch from q.ends_at),
 'options',(select jsonb_agg(jsonb_build_object('id',o.id,'text',o.body,'votes',coalesce(v.votes,0))order by o.position)from social_private.poll_options o left join lateral(
  select count(*)votes from social_private.poll_votes pv join social_private.members voter on voter.id=pv.member where pv.poll=q.id and pv.option_id=o.id and not voter.banned and not social_private.blocked(pv.member,p.author)
 )v on true where o.poll=q.id),
 'totalVotes',(select count(*)from social_private.poll_votes pv join social_private.members voter on voter.id=pv.member where pv.poll=q.id and not voter.banned and not social_private.blocked(pv.member,p.author)),
 'myOptionID',(select option_id from social_private.poll_votes where poll=q.id and member=p_me))
 from social_private.polls q join social_private.posts p on p.id=q.post join social_private.members author_account on author_account.id=p.author
 where q.post=p_post and not p.deleted and not author_account.banned and social_private.can_read_post(p_me,p.id)
$$;

create function social_private.poll_vote(p_me uuid,p_post uuid,p_option uuid)returns void language plpgsql security invoker set search_path='' as $$
declare p social_private.posts;q social_private.polls;
begin
 -- Same member → post lock ordering as reply/vote/delete; expiry is checked
 -- after acquiring the post lock so time spent waiting cannot extend a poll.
 select *into p from social_private.posts where id=p_post for update;
 if p.id is null or p.deleted or p.author is null or not social_private.can_read_post(p_me,p.id)or exists(select 1 from social_private.members where id=p.author and banned)then raise exception 'forbidden:This poll is unavailable.';end if;
 select *into q from social_private.polls where post=p.id;
 if q.id is null then raise exception 'invalid:This post has no poll.';end if;
 if q.ends_at<=clock_timestamp()then raise exception 'closed:This poll has ended.';end if;
 if p_option is null or not exists(select 1 from social_private.poll_options where poll=q.id and id=p_option)then raise exception 'invalid:Choose an option from this poll.';end if;
 insert into social_private.poll_votes(poll,member,option_id)values(q.id,p_me,p_option)on conflict(poll,member)do update set option_id=excluded.option_id,updated_at=clock_timestamp();
end $$;

create function social_private.clear_deleted_post_extras()returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.deleted or new.author is null then
  new.link_url:=null;new.tags:='{}';
  delete from social_private.polls where post=new.id;
 end if;
 return new;
end $$;
create trigger clear_deleted_post_extras before update of deleted,author on social_private.posts for each row execute function social_private.clear_deleted_post_extras();

revoke all on function social_private.post_link(text),social_private.rich_post_create(uuid,uuid,jsonb),social_private.poll_view(uuid,uuid),social_private.poll_vote(uuid,uuid,uuid),social_private.clear_deleted_post_extras()from public,anon,authenticated;
grant execute on function social_private.post_link(text),social_private.rich_post_create(uuid,uuid,jsonb),social_private.poll_view(uuid,uuid),social_private.poll_vote(uuid,uuid,uuid),social_private.clear_deleted_post_extras()to service_role;

-- Guarded edits to current deployed definitions preserve course retention,
-- account verification, anonymous replies, media, and every unrelated route.
do $patch$
declare definition text;old_text text;new_text text;start_at int;end_at int;
begin
 definition:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old_text:=' elsif p_action=''post.create'' then';start_at:=position(old_text in definition);
 end_at:=position(' elsif p_action in(''post.delete'',''post.vote'',''post.save'',''comment.create'',''post.attach'') then'in definition);
 if start_at=0 or end_at<=start_at then raise exception 'Expected post creation branch not found';end if;
 new_text:=E' elsif p_action=''post.create'' then\n  resource:=social_private.rich_post_create(me,nonce_value,p_input)::text;\n elsif p_action=''poll.vote'' then\n  perform social_private.poll_vote(me,(p_input->>''post_id'')::uuid,(p_input->>''option_id'')::uuid);\n';
 definition:=substring(definition from 1 for start_at-1)||new_text||substring(definition from end_at);
 old_text:='evidence:=jsonb_build_object(''text'',p.body,''anonymous'',p.anonymous);';
 if position(old_text in definition)=0 then raise exception 'Expected post report evidence not found';end if;
 definition:=replace(definition,old_text,'evidence:=jsonb_build_object(''text'',p.body,''anonymous'',p.anonymous,''linkURL'',p.link_url,''tags'',p.tags,''poll'',social_private.poll_view(me,p.id)-''myOptionID'');');
 execute definition;

 definition:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 old_text:=E'\n ''comments'',coalesce((select jsonb_agg(cj order by ct)';
 if position(old_text in definition)=0 then raise exception 'Expected post snapshot fields not found';end if;
 new_text:=E'\n ''linkURL'',case when p.deleted then null else p.link_url end,''tags'',case when p.deleted then ''[]''::jsonb else to_jsonb(p.tags)end,''poll'',social_private.poll_view(p_me,p.id),\n ''comments'',coalesce((select jsonb_agg(cj order by ct)';
 execute replace(definition,old_text,new_text);

 definition:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 old_text:='select id,body,anonymous,community,accepts_dm,deleted,created_at from social_private.posts where author=me';
 if position(old_text in definition)=0 then raise exception 'Expected own-post export not found';end if;
 definition:=replace(definition,old_text,'select id,body,anonymous,community,accepts_dm,deleted,created_at,link_url,tags,social_private.poll_view(me,id)as poll from social_private.posts where author=me');
 old_text:='''connections'',social_private.connection_list(me),''blocks'',social_private.block_list(me))';
 if position(old_text in definition)=0 then raise exception 'Expected own-preferences export not found';end if;
 definition:=replace(definition,old_text,'''poll_votes'',(select coalesce(jsonb_agg(jsonb_build_object(''post_id'',p.post,''option_id'',v.option_id,''updated_at'',v.updated_at)),''[]'')from social_private.poll_votes v join social_private.polls p on p.id=v.poll where v.member=me),''connections'',social_private.connection_list(me),''blocks'',social_private.block_list(me))');
 execute definition;
end $patch$;
