-- Account activity stays private; clients use the credential-checked gateway.
create table social_private.notifications (
 id uuid primary key default gen_random_uuid(),
 recipient uuid not null references social_private.members on delete cascade,
 kind text not null check(kind in('comment','reply','upvotes')),
 post uuid not null references social_private.posts on delete cascade,
 comment uuid references social_private.comments on delete cascade,
 milestone integer,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 check((kind='upvotes'and milestone>0 and comment is null)or(kind in('comment','reply')and comment is not null and milestone is null))
);
create unique index social_notification_comment_once on social_private.notifications(recipient,comment)where comment is not null;
create unique index social_notification_milestone_once on social_private.notifications(recipient,post,milestone)where kind='upvotes';
create index social_notification_recipient_date on social_private.notifications(recipient,created_at desc);
create index social_notification_post on social_private.notifications(post);
create index social_notification_comment on social_private.notifications(comment)where comment is not null;
create table social_private.announcements (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(title)between 3 and 120),
 body text not null check(char_length(body)between 3 and 2000),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '90 days',
 withdrawn boolean not null default false
);
create table social_private.announcement_reads (
 member uuid not null references social_private.members on delete cascade,
 announcement uuid not null references social_private.announcements on delete cascade,
 read_at timestamptz not null default now(),primary key(member,announcement)
);
create index social_announcement_reads_announcement on social_private.announcement_reads(announcement);
alter table social_private.notifications enable row level security;
alter table social_private.announcements enable row level security;
alter table social_private.announcement_reads enable row level security;
create policy server_notifications on social_private.notifications to service_role using(true)with check(true);
create policy server_announcements on social_private.announcements for select to service_role using(true);
create policy server_announcement_reads on social_private.announcement_reads to service_role using(true)with check(true);
revoke all on social_private.notifications,social_private.announcements,social_private.announcement_reads from public,anon,authenticated;
grant all on social_private.notifications,social_private.announcement_reads to service_role;
grant select on social_private.announcements to service_role;

create function social_private.notify_comment()returns trigger language plpgsql security invoker set search_path=''as $$
declare post_author uuid;parent_author uuid;
begin
 if new.deleted or new.author is null then return new;end if;
 select author into post_author from social_private.posts where id=new.post and not deleted;
 if post_author is not null and post_author<>new.author and not social_private.blocked(post_author,new.author)then
  insert into social_private.notifications(recipient,kind,post,comment,created_at)values(post_author,'comment',new.post,new.id,new.created_at)on conflict do nothing;
 end if;
 if new.parent_id is not null then
  select author into parent_author from social_private.comments where id=new.parent_id and not deleted;
  if parent_author is not null and parent_author<>new.author and parent_author is distinct from post_author and not social_private.blocked(parent_author,new.author)then
   insert into social_private.notifications(recipient,kind,post,comment,created_at)values(parent_author,'reply',new.post,new.id,new.created_at)on conflict do nothing;
  end if;
 end if;
 return new;
end $$;
create trigger social_comment_notification after insert on social_private.comments for each row execute function social_private.notify_comment();
create function social_private.notify_post_milestone()returns trigger language plpgsql security invoker set search_path=''as $$
declare recipient_id uuid;score_value bigint;threshold integer;
begin
 if new.value<>1 then return new;end if;
 select author into recipient_id from social_private.posts where id=new.post and not deleted for update;
 if recipient_id is null or recipient_id=new.member then return new;end if;
 score_value:=social_private.post_score(new.post);
 foreach threshold in array array[1,10,25,50,100,250,500,1000]loop
  if score_value>=threshold then
   insert into social_private.notifications(recipient,kind,post,milestone)values(recipient_id,'upvotes',new.post,threshold)on conflict do nothing;
  end if;
 end loop;
 return new;
end $$;
create trigger social_post_milestone after insert or update on social_private.votes for each row execute function social_private.notify_post_milestone();

create function social_private.notification_items(p_me uuid)returns table(id uuid,kind text,title text,body text,post_id uuid,created_at timestamptz,is_read boolean)language sql stable security invoker set search_path=''as $$
 select n.id,n.kind,case n.kind when 'comment'then 'New comment on your post'when 'reply'then 'New reply to your comment'else case when n.milestone=1 then 'Your first upvote!'else n.milestone||' upvotes!'end end,
 case when n.kind in('comment','reply')then left(c.body,240)else 'Your post reached '||n.milestone||case when n.milestone=1 then ' upvote.'else ' upvotes.'end end,
 n.post,n.created_at,n.read_at is not null
 from social_private.notifications n join social_private.posts p on p.id=n.post
 join social_private.members author_account on author_account.id=p.author
 left join social_private.comments c on c.id=n.comment left join social_private.members commenter on commenter.id=c.author
 where n.recipient=p_me and not p.deleted and not author_account.banned and social_private.can_read_post(p_me,p.id)
 and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id)
 and(n.kind='upvotes'or(not c.deleted and c.author is not null and not commenter.banned and not social_private.blocked(p_me,c.author)))
 union all
 select a.id,'announcement','Announcement · Maroon Social',a.title||E'\n'||a.body,null::uuid,a.created_at,r.read_at is not null
 from social_private.announcements a left join social_private.announcement_reads r on r.announcement=a.id and r.member=p_me
 where not a.withdrawn and a.expires_at>now()
$$;

-- Share the deployed projection (anonymous bylines, votes, polls and links) with
-- collections and single-post destinations; never widen the homepage feed.
do $projection$
declare body_sql text;
begin
 select prosrc into body_sql from pg_proc where oid='social_private.visible_posts(uuid,text,text,integer)'::regprocedure;
 if position('where social_private.can_read_post(p_me,p.id)'in body_sql)=0 then raise exception 'Post visibility boundary not found';end if;
 body_sql:=replace(body_sql,'where social_private.can_read_post(p_me,p.id)','where p.id=any(p_ids) and social_private.can_read_post(p_me,p.id)');
 body_sql:=replace(replace(replace(body_sql,'p_tag','null::text'),'p_community','null::text'),'p_limit','50');
 execute 'create function social_private.post_documents(p_me uuid,p_ids uuid[])returns jsonb language sql stable security invoker set search_path=''''as $body$'||body_sql||'$body$';
end $projection$;
create index social_posts_author_date on social_private.posts(author,created_at desc,id)where not deleted;
create index social_comments_author_date on social_private.comments(author,created_at desc,id)where not deleted;

create function public.social_activity(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;items jsonb;ids uuid[];comments jsonb:='[]';kind_value text;offset_value integer;more boolean:=false;notice_id uuid;message_value text;code_value text;
begin
 me:=social_private.require_member(p_hash);
 if p_action='notifications'then
  select coalesce(jsonb_agg(jsonb_build_object('id',n.id,'kind',n.kind,'title',n.title,'body',n.body,'postID',n.post_id,'created',extract(epoch from n.created_at),'read',n.is_read)order by n.created_at desc,n.id),'[]')into items from(select *from social_private.notification_items(me)order by created_at desc,id limit 100)n;
  return jsonb_build_object('items',items,'unreadCount',(select count(*)from social_private.notification_items(me)where not is_read));
 elsif p_action='notification.read'then
  notice_id:=(p_input->>'id')::uuid;
  if not exists(select 1 from social_private.notification_items(me)where id=notice_id)then raise exception 'forbidden:This notification is unavailable.';end if;
  update social_private.notifications set read_at=coalesce(read_at,now())where id=notice_id and recipient=me;
  insert into social_private.announcement_reads(member,announcement)select me,id from social_private.announcements where id=notice_id and not withdrawn and expires_at>now()on conflict do nothing;
  return jsonb_build_object('read',true);
 elsif p_action='notifications.read_all'then
  -- Only the displayed IDs are acknowledged; a concurrently arriving event stays unread.
  if jsonb_typeof(p_input->'ids')is distinct from 'array'or jsonb_array_length(p_input->'ids')>100 then raise exception 'invalid:Choose up to 100 notifications.';end if;
  select coalesce(array_agg(value::uuid),'{}')into ids from jsonb_array_elements_text(p_input->'ids');
  update social_private.notifications set read_at=coalesce(read_at,now())where recipient=me and id=any(ids);
  insert into social_private.announcement_reads(member,announcement)select me,id from social_private.announcements where id=any(ids)and not withdrawn and expires_at>now()on conflict do nothing;
  return jsonb_build_object('read',true);
 elsif p_action='library'then
  kind_value:=p_input->>'kind';offset_value:=coalesce((p_input->>'offset')::integer,0);
  if offset_value<0 then raise exception 'invalid:Invalid collection page.';end if;
  if kind_value='post'then
   ids:=array[(p_input->>'post_id')::uuid];
  elsif kind_value='comments'then
   select coalesce(jsonb_agg(j order by created_at desc,id),'[]'),coalesce(array_agg(post order by created_at desc,id),'{}')into comments,ids from(
    select c.id,c.post,c.created_at,jsonb_build_object('id',c.id,'postID',c.post,'text',c.body,'created',extract(epoch from c.created_at),'score',social_private.comment_score(c.id),'anonymous',c.anonymous,'postText',left(p.body,240))j
    from social_private.comments c join social_private.posts p on p.id=c.post join social_private.members author_account on author_account.id=p.author
    where c.author=me and not c.deleted and not p.deleted and not author_account.banned and social_private.can_read_post(me,p.id)
    and not exists(select 1 from social_private.hidden h where h.member=me and h.post=p.id)
    order by c.created_at desc,c.id offset offset_value limit 51)x;
   more:=jsonb_array_length(comments)>50;
   if more then comments:=comments-50;ids:=ids[1:50];end if;
  elsif kind_value in('posts','saved')then
   select coalesce(array_agg(id order by created_at desc,id),'{}')into ids from(
    select p.id,p.created_at from social_private.posts p join social_private.members author_account on author_account.id=p.author
    where not p.deleted and not author_account.banned and social_private.can_read_post(me,p.id)
    and not exists(select 1 from social_private.hidden h where h.member=me and h.post=p.id)
    and((kind_value='posts'and p.author=me)or(kind_value='saved'and exists(select 1 from social_private.bookmarks b where b.post=p.id and b.member=me)))
    order by p.created_at desc,p.id offset offset_value limit 51)x;
   more:=cardinality(ids)>50;ids:=ids[1:50];
  else raise exception 'invalid:Choose a collection.';end if;
  return jsonb_build_object('posts',social_private.post_documents(me,ids),'comments',comments,'hasMore',more);
 else raise exception 'invalid:Unknown activity action.';end if;
exception when others then
 message_value:=sqlerrm;code_value:=split_part(message_value,':',1);
 if code_value in('invalid','forbidden','unauthorized','rate_limit','verification_required')then return jsonb_build_object('error',substr(message_value,length(code_value)+2),'code',code_value);end if;
 if sqlstate in('22P02','22003')then return jsonb_build_object('error','Invalid activity request.','code','invalid');end if;
 raise;
end $$;
revoke all on function public.social_activity(text,text,jsonb),social_private.notify_comment(),social_private.notify_post_milestone(),social_private.notification_items(uuid),social_private.post_documents(uuid,uuid[])from public,anon,authenticated;
grant execute on function public.social_activity(text,text,jsonb),social_private.notify_comment(),social_private.notify_post_milestone(),social_private.notification_items(uuid),social_private.post_documents(uuid,uuid[])to service_role;

-- Announcements are published only by the existing database operator, never
-- by a client claiming an admin/owner role. The audit includes the reviewer.
alter function social_private.operator(text,jsonb,text)rename to operator_before_notifications;
create function social_private.operator(p_action text,p_input jsonb default '{}',p_reviewer text default '')returns jsonb language plpgsql security invoker set search_path=''as $$
declare target uuid;note_value text:=btrim(coalesce(p_input->>'note',''));title_value text:=btrim(coalesce(p_input->>'title',''));body_value text:=btrim(coalesce(p_input->>'body',''));result jsonb;
begin
 if p_action='announcements.list'then
  select coalesce(jsonb_agg(to_jsonb(a)order by created_at desc),'[]')into result from(select *from social_private.announcements order by created_at desc limit 100)a;return result;
 elsif p_action in('announcements.publish','announcements.withdraw')then
  if char_length(btrim(p_reviewer))not between 3 and 100 or char_length(note_value)not between 5 and 2000 then raise exception 'Provide a reviewer label and review note.';end if;
  if p_action='announcements.publish'then
   if char_length(title_value)not between 3 and 120 or char_length(body_value)not between 3 and 2000 then raise exception 'Use a title of 3–120 and body of 3–2,000 characters.';end if;
   insert into social_private.announcements(title,body)values(title_value,body_value)returning id into target;
  else
   update social_private.announcements set withdrawn=true where id=(p_input->>'id')::uuid returning id into target;
   if target is null then raise exception 'Unknown announcement';end if;
  end if;
  insert into social_private.operator_audit(reviewer,action,target,reason)values(btrim(p_reviewer),p_action,target::text,note_value);
  return jsonb_build_object('applied',true,'id',target);
 end if;
 return social_private.operator_before_notifications(p_action,p_input,p_reviewer);
end $$;
revoke all on function social_private.operator(text,jsonb,text),social_private.operator_before_notifications(text,jsonb,text)from public,anon,authenticated,service_role;
