alter table social_private.activities add column nonce uuid;
create unique index social_activities_nonce on social_private.activities(host,nonce);
create or replace function social_private.can_read_room(p_member uuid,p_room text) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from social_private.rooms r join social_private.room_members rm on rm.room=r.id where r.id=p_room and rm.member=p_member and (rm.status='accepted' or (r.kind='dm' and rm.status='invited')) and not exists(select 1 from social_private.room_members other where other.room=r.id and r.kind='dm' and social_private.blocked(p_member,other.member)))
$$;
create or replace function social_private.can_read_post(p_member uuid,p_post uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from social_private.posts p join social_private.members m on m.id=p_member where p.id=p_post and (p.community='Texas A&M' or (m.adult and m.nsfw_enabled)) and not social_private.blocked(p_member,p.author))
$$;
create or replace function social_private.message_list(p_me uuid,p_room text) returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(j order by seq),'[]') from (
 select m.seq,jsonb_build_object('id',m.id,'author',case when m.deleted or u.id is null then '[deleted]' when m.author=p_me then u.username when r.anonymous then case when m.author=p.author then 'Post author' else 'Guest' end else u.username end,'text',case when m.deleted then '[Message deleted]' else m.body end,'created',extract(epoch from m.created_at),'game',case when m.deleted then null else m.game end,'gameSessionID',case when m.deleted then null else m.game_session_id end,'replyTo',m.reply_to,'sequence',m.seq,'deleted',m.deleted,'attachmentID',case when m.deleted then null else (select id from social_private.attachments where message=m.id and ready limit 1) end,'reactions',coalesce((select jsonb_object_agg(emoji,n) from(select emoji,count(*) n from social_private.reactions where message=m.id group by emoji) reactions),'{}'),'myReactions',coalesce((select jsonb_agg(emoji) from social_private.reactions where message=m.id and member=p_me),'[]')) j
 from social_private.messages m join social_private.rooms r on r.id=m.room left join social_private.members u on u.id=m.author left join social_private.posts p on p.id=r.context_post
 where m.room=p_room and not social_private.blocked(p_me,m.author) order by m.seq desc limit 100) visible
$$;
create or replace function social_private.snapshot(p_me uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb; begin
 select jsonb_build_object('username',me.username,'nsfwEnabled',me.nsfw_enabled,
 'posts',coalesce((select jsonb_agg(j order by created_at desc) from (
 select p.created_at,jsonb_build_object('id',p.id,'author',case when p.deleted or u.id is null then '[deleted]' when p.author=p_me then u.username when p.anonymous then 'Anonymous' else u.username end,'anonymous',p.anonymous,'community',p.community,'text',case when p.deleted then '[Post deleted]' else p.body end,'score',coalesce((select sum(value) from social_private.votes where post=p.id),0),'vote',coalesce((select value from social_private.votes where post=p.id and member=p_me),0),'created',extract(epoch from p.created_at),'saved',exists(select 1 from social_private.bookmarks where post=p.id and member=p_me),'acceptsDM',p.accepts_dm and not p.deleted,'deleted',p.deleted,'attachmentID',case when p.deleted then null else(select id from social_private.attachments where post=p.id and ready limit 1)end,
 'comments',coalesce((select jsonb_agg(cj order by ct) from(select c.created_at ct,jsonb_build_object('id',c.id,'author',case when c.deleted or cu.id is null then '[deleted]' when c.author=p_me then cu.username when c.anonymous then case when c.author=p.author then 'OP' else 'Aggie '||substr(md5(p.id::text||c.author::text),1,4) end else cu.username end,'text',case when c.deleted then '[Reply deleted]' else c.body end,'anonymous',c.anonymous,'created',extract(epoch from c.created_at),'isOP',c.author=p.author,'deleted',c.deleted) cj from social_private.comments c left join social_private.members cu on cu.id=c.author where c.post=p.id and not social_private.blocked(p_me,c.author) order by c.created_at limit 200) comments),'[]'))j
 from social_private.posts p left join social_private.members u on u.id=p.author where social_private.can_read_post(p_me,p.id) and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id) order by p.created_at desc limit 150)posts),'[]'),
 'courses',coalesce((select jsonb_agg(r.meta) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where r.kind='course' and rm.member=p_me and rm.status='accepted'),'[]'),
 'activities',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'kind',a.kind,'host',case when r.meta?'organization' then (select name from social_private.organizations where id=(r.meta->>'organization')::uuid) else coalesce(u.username,'[deleted]') end,'place',a.place,'starts',extract(epoch from a.starts),'capacity',a.capacity,'details',a.details,'course',a.course,'cancelled',a.cancelled,'approvalRequired',a.approval_required,'waitlisted',exists(select 1 from social_private.room_members where room=a.room and member=p_me and status='waitlisted'),'participantCount',(select count(*) from social_private.room_members where room=a.room and status='accepted'),'participants',case when exists(select 1 from social_private.room_members where room=a.room and member=p_me and status='accepted') then coalesce((select jsonb_agg(case when r.meta?'organization' and rm.role='owner' then (select name from social_private.organizations where id=(r.meta->>'organization')::uuid) else am.username end) from social_private.room_members rm join social_private.members am on am.id=rm.member where rm.room=a.room and rm.status='accepted'),'[]') else '[]'::jsonb end) order by a.starts) from social_private.activities a join social_private.rooms r on r.id=a.room left join social_private.members u on u.id=a.host where not social_private.blocked(p_me,a.host) and (not a.cancelled or a.host=p_me)),'[]'),
 'conversations',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',case when r.kind='dm' then case when r.anonymous then 'Anonymous · post conversation' else coalesce((select u.username from social_private.room_members o join social_private.members u on u.id=o.member where o.room=r.id and o.member<>p_me limit 1),'Conversation')end else r.title end,'subtitle',case when r.status='pending' then case when r.requester=p_me then 'Request sent' else 'Message request'end else case when r.kind='course' then coalesce(r.meta->>'term','')||' · shared course room' else 'Shared '||r.kind||' conversation'end end,'messages',case when social_private.can_read_room(p_me,r.id) then social_private.message_list(p_me,r.id) else '[]'::jsonb end,'request',rm.status='invited','anonymous',r.anonymous) order by r.created_at desc) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where rm.member=p_me and rm.status in('accepted','invited') and (r.kind<>'dm' or not exists(select 1 from social_private.room_members o where o.room=r.id and social_private.blocked(p_me,o.member)))),'[]'),
 'conversationMeta',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'status',r.status,'role',rm.role,'canSend',social_private.can_message(p_me,r.id),'lastRead',rm.last_read,'pendingOutgoing',r.status='pending' and r.requester=p_me,'unread',(select count(*) from social_private.messages m where m.room=r.id and m.seq>rm.last_read and m.author<>p_me and not social_private.blocked(p_me,m.author)),'typing',coalesce((select jsonb_agg(case when r.anonymous then 'Guest' else u.username end) from social_private.room_members t join social_private.members u on u.id=t.member where t.room=r.id and t.member<>p_me and t.typing_until>now() and not social_private.blocked(p_me,t.member)),'[]'))) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where rm.member=p_me and rm.status in('accepted','invited')),'[]'),
 'ownPostIDs',coalesce((select jsonb_agg(id) from social_private.posts where author=p_me),'[]'),'ownCommentIDs',coalesce((select jsonb_agg(id) from social_private.comments where author=p_me),'[]'),'ownMessageIDs',coalesce((select jsonb_agg(id) from social_private.messages where author=p_me),'[]'),
 'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'kind',a.kind,'mime',a.mime,'size',a.size,'roomID',a.room,'messageID',a.message,'postID',a.post)) from social_private.attachments a where a.ready and ((a.post is not null and social_private.can_read_post(p_me,a.post)) or(a.message is not null and social_private.can_read_room(p_me,a.room)))),'[]'),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'about',o.about,'status',o.status,'followed',exists(select 1 from social_private.organization_follows where organization=o.id and member=p_me),'canManage',exists(select 1 from social_private.organization_admins where organization=o.id and member=p_me))) from social_private.organizations o where o.status='verified' or exists(select 1 from social_private.organization_admins where organization=o.id and member=p_me)),'[]'),
 'savedEvents',coalesce((select jsonb_agg(event_id) from social_private.saved_events where member=p_me),'[]')) into result from social_private.members me where me.id=p_me;
 return result;
end $$;

create or replace function public.social_gateway(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
declare me uuid; m social_private.members; p social_private.posts; c social_private.comments; r social_private.rooms; a social_private.activities; msg social_private.messages; att social_private.attachments; org social_private.organizations;
 other uuid; resource text; room_id text; body_value text; username_value text; nonce_value uuid; value_int integer; event jsonb; event_start double precision; event_end double precision; media uuid; evidence jsonb; role_value text;
begin
 if p_action='register' then
  if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'invalid:Invalid credential.'; end if;
  username_value:=lower(btrim(coalesce(p_input->>'username','')));
  if username_value !~ '^[a-z0-9_]{3,20}$' then raise exception 'invalid:Use 3–20 lowercase letters, numbers or underscores.'; end if;
  if coalesce((p_input->>'adult')::boolean,false) is not true then raise exception 'forbidden:You must be 18 or older to join.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(coalesce(p_input->>'network',''),778));
  if (select count(*) from social_private.members where network_hash=p_input->>'network' and created_at>now()-interval '1 hour')>=20 then raise exception 'rate_limit:Too many new accounts. Try again later.'; end if;
  insert into social_private.members(token_hash,username,adult,network_hash)values(p_hash,username_value,true,p_input->>'network') returning id into me;
  return jsonb_build_object('snapshot',social_private.snapshot(me));
 end if;
 me:=social_private.require_member(p_hash);
 select * into m from social_private.members where id=me;
 room_id:=p_input->>'room_id';
 nonce_value:=coalesce((p_input->>'nonce')::uuid,gen_random_uuid());
 if p_action='snapshot' then null;
 elsif p_action='profile.update' then
  username_value:=lower(btrim(coalesce(p_input->>'username','')));
  if username_value !~ '^[a-z0-9_]{3,20}$' then raise exception 'invalid:Use 3–20 letters, numbers or underscores.'; end if;
  update social_private.members set username=username_value where id=me;
 elsif p_action in('community.join','community.leave') then
  if p_input->>'community'<>'NSFW' then raise exception 'invalid:Unknown community.'; end if;
  if not m.adult then raise exception 'forbidden:This community is for adults.'; end if;
  update social_private.members set nsfw_enabled=p_action='community.join' where id=me;
 elsif p_action='post.create' then
  body_value:=btrim(coalesce(p_input->>'text',''));
  if char_length(body_value) not between 1 and 4000 then raise exception 'invalid:Posts must be 1–4,000 characters.'; end if;
  if coalesce(p_input->>'community','Texas A&M')='NSFW' and not m.nsfw_enabled then raise exception 'forbidden:Join the adult discussion community first.'; end if;
  if (select count(*) from social_private.posts where author=me and created_at>now()-interval '1 minute')>=10 then raise exception 'rate_limit:Take a moment before posting again.'; end if;
  insert into social_private.posts(author,nonce,body,anonymous,community,accepts_dm) values(me,nonce_value,body_value,coalesce((p_input->>'anonymous')::boolean,true),coalesce(p_input->>'community','Texas A&M'),coalesce((p_input->>'acceptsDM')::boolean,false)) on conflict(author,nonce)do update set nonce=excluded.nonce returning id::text into resource;
 elsif p_action in('post.delete','post.vote','post.save','comment.create','post.attach') then
  select * into p from social_private.posts where id=(p_input->>'post_id')::uuid;
  if p.id is null or not social_private.can_read_post(me,p.id) then raise exception 'forbidden:This post is not available.'; end if;
  if p_action='post.delete' then
   if p.author<>me then raise exception 'forbidden:Only the author can delete this post.'; end if;
   update social_private.posts set deleted=true,body='',accepts_dm=false where id=p.id;
  elsif p_action='post.vote' then
   value_int:=(p_input->>'value')::int;
   if value_int not in(-1,0,1) or value_int is null then raise exception 'invalid:Invalid vote.'; end if;
   if value_int=0 then delete from social_private.votes where member=me and post=p.id;
   else insert into social_private.votes values(me,p.id,value_int)on conflict(member,post)do update set value=excluded.value; end if;
  elsif p_action='post.save' then
   if (p_input->>'saved')::boolean then insert into social_private.bookmarks values(me,p.id)on conflict do nothing; else delete from social_private.bookmarks where member=me and post=p.id; end if;
  elsif p_action='comment.create' then
   if p.deleted then raise exception 'forbidden:This post was deleted.'; end if;
   body_value:=btrim(coalesce(p_input->>'text',''));
   if char_length(body_value) not between 1 and 2000 then raise exception 'invalid:Replies must be 1–2,000 characters.'; end if;
   insert into social_private.comments(post,author,nonce,body,anonymous)values(p.id,me,nonce_value,body_value,p.anonymous or coalesce((p_input->>'anonymous')::boolean,true))on conflict(author,nonce)do update set nonce=excluded.nonce returning id::text into resource;
  else
   if p.author<>me then raise exception 'forbidden:Only the author may add media.'; end if;
   select * into att from social_private.attachments where id=(p_input->>'attachment_id')::uuid and owner=me and post=p.id and ready;
   if att.id is null then raise exception 'invalid:That upload is not available.'; end if;
  end if;
 elsif p_action='comment.delete' then
  select * into c from social_private.comments where id=(p_input->>'comment_id')::uuid;
  if c.author is distinct from me then raise exception 'forbidden:Only the author can delete this reply.'; end if;
  update social_private.comments set deleted=true,body='' where id=c.id;
 elsif p_action='course.join' then
  if coalesce(p_input->>'code','') !~ '^[A-Z]{2,5} [0-9]{3}[A-Z]?$' or char_length(coalesce(p_input->>'term','')) not between 4 and 40 then raise exception 'invalid:Choose a valid course and term.'; end if;
  room_id:=(p_input->>'code')||'-'||(p_input->>'term');
  insert into social_private.rooms(id,kind,title,meta)values(room_id,'course',p_input->>'code',jsonb_build_object('code',p_input->>'code','title',left(coalesce(p_input->>'title','Course'),120),'term',p_input->>'term','icon',coalesce(p_input->>'icon','book.closed')))on conflict do nothing;
  insert into social_private.room_members(room,member)values(room_id,me)on conflict(room,member)do update set status='accepted'; resource:=room_id;
 elsif p_action in('activity.create','organization.publish') then
  body_value:=btrim(coalesce(p_input->>'title',''));
  if char_length(body_value) not between 1 and 100 or char_length(btrim(coalesce(p_input->>'place',''))) not between 1 and 200 or char_length(coalesce(p_input->>'details',''))>4000 then raise exception 'invalid:Enter a title, public place, and details within the limits.'; end if;
  if coalesce(p_input->>'kind','') not in('Hangouts','Study','Rec','Gaming','Organizations') then raise exception 'invalid:Unknown activity kind.'; end if;
  if to_timestamp((p_input->>'starts')::double precision)<now() or (p_input->>'capacity')::integer not between 2 and 100 then raise exception 'invalid:Choose a future time and 2–100 spots.'; end if;
  if p_input->>'kind'='Organizations' or p_action='organization.publish' then
   select * into org from social_private.organizations where id=(p_input->>'organization_id')::uuid and status='verified';
   if org.id is null or not exists(select 1 from social_private.organization_admins where organization=org.id and member=me)then raise exception 'forbidden:Only an authorized administrator of a verified organization can publish.'; end if;
  end if;
  select id::text into resource from social_private.activities where host=me and nonce=nonce_value;
  if resource is null then
   resource:=gen_random_uuid()::text;
   insert into social_private.rooms(id,kind,title,meta)values(resource,'activity',body_value,case when org.id is not null then jsonb_build_object('organization',org.id)else '{}'::jsonb end);
   insert into social_private.activities(id,room,host,nonce,title,kind,place,starts,capacity,details,course,approval_required)values(resource::uuid,resource,me,nonce_value,body_value,p_input->>'kind',p_input->>'place',to_timestamp((p_input->>'starts')::double precision),(p_input->>'capacity')::int,coalesce(p_input->>'details',''),nullif(p_input->>'course',''),coalesce((p_input->>'approval_required')::boolean,false));
   insert into social_private.room_members(room,member,role)values(resource,me,'owner');
  end if;
 elsif p_action in('activity.join','activity.leave','activity.cancel','activity.edit','activity.approve') then
  select * into a from social_private.activities where id=(p_input->>'activity_id')::uuid for update;
  if a.id is null or social_private.blocked(me,a.host) then raise exception 'forbidden:That activity is not available.'; end if;
  room_id:=a.room;resource:=a.id::text;
  if p_action='activity.join' then
   if a.cancelled or a.starts<now()-interval '1 hour' then raise exception 'forbidden:This activity is no longer accepting people.'; end if;
   if not exists(select 1 from social_private.room_members where room=a.room and member=me and status='accepted') then
    role_value:=case when a.approval_required then 'pending' when(select count(*) from social_private.room_members where room=a.room and status='accepted')>=a.capacity then 'waitlisted' else 'accepted'end;
    insert into social_private.room_members(room,member,status)values(a.room,me,role_value)on conflict(room,member)do update set status=excluded.status;
   end if;
  elsif p_action='activity.leave' then
   if a.host=me then raise exception 'invalid:The host must cancel the activity.'; end if;
   delete from social_private.room_members where room=a.room and member=me;
   update social_private.room_members set status='accepted' where room=a.room and member=(select member from social_private.room_members where room=a.room and status='waitlisted' order by joined_at limit 1) and (select count(*) from social_private.room_members where room=a.room and status='accepted')<a.capacity;
  else
   if a.host<>me then raise exception 'forbidden:Only the host can manage this activity.'; end if;
   if p_action='activity.cancel' then update social_private.activities set cancelled=true where id=a.id; update social_private.rooms set status='closed' where id=a.room;
   elsif p_action='activity.approve' then
    select id into other from social_private.members where username=p_input->>'username';
    if(select count(*) from social_private.room_members where room=a.room and status='accepted')>=a.capacity then raise exception 'full:This activity is full.'; end if;
    update social_private.room_members set status='accepted' where room=a.room and member=other and status in('pending','waitlisted');
   else
    if char_length(coalesce(p_input->>'title',a.title)) not between 1 and 100 or char_length(coalesce(p_input->>'details',a.details))>4000 then raise exception 'invalid:Activity details are too long.'; end if;
    update social_private.activities set title=coalesce(p_input->>'title',title),details=coalesce(p_input->>'details',details),place=coalesce(p_input->>'place',place),starts=coalesce(to_timestamp((p_input->>'starts')::double precision),starts)where id=a.id;
    update social_private.rooms set title=(select title from social_private.activities where id=a.id)where id=a.room;
   end if;
  end if;
 elsif p_action='dm.request' then
  if p_input?'post_id' then
   select * into p from social_private.posts where id=(p_input->>'post_id')::uuid;
   if p.id is null or not p.accepts_dm or p.deleted or not social_private.can_read_post(me,p.id) then raise exception 'forbidden:This author is not accepting message requests.'; end if;
   other:=p.author;
  else select id into other from social_private.members where username=lower(p_input->>'username');end if;
  if other is null or other=me or social_private.blocked(me,other) then raise exception 'forbidden:This person cannot receive your request.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me::text,other::text)||greatest(me::text,other::text)||coalesce(p.id::text,'named'),778));
  select rooms.* into r from social_private.rooms rooms where rooms.kind='dm' and rooms.context_post is not distinct from p.id and exists(select 1 from social_private.room_members where room=rooms.id and member=me) and exists(select 1 from social_private.room_members where room=rooms.id and member=other) limit 1;
  if r.id is not null then
   if r.status='closed' then raise exception 'forbidden:This conversation is closed.'; end if;
   resource:=r.id;
  else
   body_value:=btrim(coalesce(p_input->>'text','Hi! I’d like to chat.'));
   if char_length(body_value) not between 1 and 1000 then raise exception 'invalid:Message requests must be 1–1,000 characters.'; end if;
   if(select count(*) from social_private.rooms where requester=me and kind='dm' and created_at>now()-interval '1 hour')>=20 then raise exception 'rate_limit:Too many requests. Try again later.'; end if;
   insert into social_private.rooms(kind,title,status,anonymous,requester,context_post)values('dm','Conversation','pending',coalesce(p.anonymous,false),me,p.id)returning id into resource;
   insert into social_private.room_members(room,member,status)values(resource,me,'accepted'),(resource,other,'invited');
   insert into social_private.messages(room,author,nonce,body)values(resource,me,nonce_value,body_value);
  end if;
 elsif p_action in('dm.accept','dm.decline') then
  select * into r from social_private.rooms where id=room_id for update;
  if r.kind<>'dm' or r.status<>'pending' or r.requester=me or not exists(select 1 from social_private.room_members where room=room_id and member=me and status='invited') then raise exception 'forbidden:This message request is not available.'; end if;
  if social_private.blocked(me,r.requester)then raise exception 'forbidden:This conversation is blocked.'; end if;
  update social_private.rooms set status=case when p_action='dm.accept' then 'active' else 'closed'end where id=room_id;
  update social_private.room_members set status=case when p_action='dm.accept' then 'accepted' else 'declined'end where room=room_id and member=me;resource:=room_id;
 elsif p_action='room.send' then
  if not social_private.can_message(me,room_id)then raise exception 'forbidden:Accept the request or join this conversation before sending.'; end if;
  body_value:=btrim(coalesce(p_input->>'text',''));
  if char_length(body_value)>4000 then raise exception 'invalid:Keep messages under 4,000 characters.'; end if;
  if p_input?'attachments' then raise exception 'invalid:Send one attachment_id, not multiple attachments.'; end if;
  media:=(p_input->>'attachment_id')::uuid;
  if body_value='' and media is null then raise exception 'invalid:Write a message or add one image or GIF.'; end if;
  if p_input->>'reply_to' is not null and not exists(select 1 from social_private.messages where id=(p_input->>'reply_to')::uuid and room=room_id)then raise exception 'invalid:That reply target is not in this conversation.'; end if;
  if media is not null then
   select * into att from social_private.attachments where id=media and owner=me and room=room_id and ready for update;
   if att.id is null then raise exception 'forbidden:That attachment does not belong to this conversation.'; end if;
   if att.message is not null and not exists(select 1 from social_private.messages where id=att.message and author=me and nonce=nonce_value)then raise exception 'invalid:That attachment was already sent.'; end if;
  end if;
  insert into social_private.messages(room,author,nonce,body,reply_to)values(room_id,me,nonce_value,body_value,(p_input->>'reply_to')::uuid)on conflict(author,nonce)do update set nonce=excluded.nonce returning id::text into resource;
  if media is not null then update social_private.attachments set message=resource::uuid where id=media;end if;
  update social_private.room_members set typing_until=null where room=room_id and member=me;
 elsif p_action in('room.delete','room.react') then
  select * into msg from social_private.messages where id=(p_input->>'message_id')::uuid;
  if msg.id is null or not social_private.can_message(me,msg.room)then raise exception 'forbidden:This message is unavailable.'; end if;
  if p_action='room.delete' then
   if msg.author<>me then raise exception 'forbidden:Only the sender can delete this message.'; end if;
   update social_private.messages set deleted=true,body='' where id=msg.id;
  else
   if coalesce(p_input->>'emoji','') not in('❤️','👍','😂','🔥','👀','🙌')then raise exception 'invalid:Choose a supported reaction.';end if;
   if exists(select 1 from social_private.reactions where message=msg.id and member=me and emoji=p_input->>'emoji')then delete from social_private.reactions where message=msg.id and member=me and emoji=p_input->>'emoji';else insert into social_private.reactions values(msg.id,me,p_input->>'emoji');end if;
  end if;
 elsif p_action in('room.read','room.typing') then
  if not social_private.can_read_room(me,room_id)then raise exception 'forbidden:Join this conversation first.';end if;
  if p_action='room.read' then update social_private.room_members set last_read=coalesce((select max(seq)from social_private.messages where room=room_id),0)where room=room_id and member=me;
  else update social_private.room_members set typing_until=case when coalesce((p_input->>'typing')::boolean,true)then now()+interval '8 seconds' else null end where room=room_id and member=me;end if;
 elsif p_action='group.create' then
  body_value:=btrim(coalesce(p_input->>'title',''));
  if char_length(body_value)not between 1 and 80 then raise exception 'invalid:Name your group (1–80 characters).';end if;
  insert into social_private.rooms(kind,title)values('group',body_value)returning id into resource;
  insert into social_private.room_members(room,member,role)values(resource,me,'owner');
  for username_value in select jsonb_array_elements_text(coalesce(p_input->'usernames','[]'))loop
   select id into other from social_private.members where username=username_value and not banned;
   if other is not null and other<>me and not social_private.blocked(me,other)then insert into social_private.room_members(room,member,status)values(resource,other,'invited')on conflict do nothing;end if;
  end loop;
 elsif p_action in('group.invite','group.accept','group.decline','group.remove','group.transfer')then
  select * into r from social_private.rooms where id=room_id and kind='group' and status='active' for update;
  if r.id is null then raise exception 'forbidden:This group is unavailable.';end if;
  if p_action in('group.accept','group.decline')then
   if not exists(select 1 from social_private.room_members where room=room_id and member=me and status='invited')then raise exception 'forbidden:You have no invitation to this group.';end if;
   update social_private.room_members set status=case when p_action='group.accept' then 'accepted' else 'declined'end where room=room_id and member=me;
  else
   if not exists(select 1 from social_private.room_members where room=room_id and member=me and role='owner' and status='accepted')then raise exception 'forbidden:Only the group owner may manage members.';end if;
   select id into other from social_private.members where username=p_input->>'username' and not banned;
   if other is null or other=me or social_private.blocked(me,other)then raise exception 'invalid:Choose another available member.';end if;
   if p_action='group.invite' then insert into social_private.room_members(room,member,status)values(room_id,other,'invited')on conflict(room,member)do update set status=case when social_private.room_members.status='accepted' then 'accepted' else 'invited'end;
   elsif p_action='group.remove'then delete from social_private.room_members where room=room_id and member=other;
   else
    if not exists(select 1 from social_private.room_members where room=room_id and member=other and status='accepted')then raise exception 'invalid:The new owner must accept the invitation first.';end if;
    update social_private.room_members set role=case when member=other then 'owner'else 'member'end where room=room_id and member in(me,other);
   end if;
  end if;resource:=room_id;
 elsif p_action in('room.leave','course.leave','group.leave')then
  if room_id is null then room_id:=p_input->>'course_id';end if;
  select * into r from social_private.rooms where id=room_id;
  if r.kind='activity' then raise exception 'invalid:Leave or cancel from the activity details.';end if;
  if exists(select 1 from social_private.room_members where room=room_id and member=me and role='owner')and exists(select 1 from social_private.room_members where room=room_id and member<>me and status='accepted')then raise exception 'invalid:Transfer ownership before leaving the group.';end if;
  delete from social_private.room_members where room=room_id and member=me;
  if r.kind='dm' or not exists(select 1 from social_private.room_members where room=room_id)then update social_private.rooms set status='closed'where id=room_id and kind<>'course';end if;
 elsif p_action in('join_sports','sports.join')then
  select e into event from public.campus_cache c,jsonb_array_elements(c.payload->'events')e where c.id='current' and e->>'id'=p_input->>'event_id';
  if event is null or coalesce(event->>'category','')not ilike '%sport%' then raise exception 'forbidden:This sports event is not in the current campus schedule.';end if;
  event_start:=(event->>'starts')::double precision;event_end:=coalesce((event->>'ends')::double precision,event_start+21600);
  if extract(epoch from now())<event_start-1800 or extract(epoch from now())>event_end+7200 or coalesce((event->>'cancelled')::boolean,false) then raise exception 'forbidden:Game chat opens 30 minutes before the scheduled start.';end if;
  room_id:='sports:'||(event->>'id');insert into social_private.rooms(id,kind,title,meta)values(room_id,'sports',event->>'title',event)on conflict(id)do update set meta=excluded.meta,title=excluded.title;
  insert into social_private.room_members(room,member)values(room_id,me)on conflict(room,member)do update set status='accepted';resource:=room_id;
 elsif p_action='save_event'then
  if not exists(select 1 from public.campus_cache c,jsonb_array_elements(c.payload->'events')e where e->>'id'=p_input->>'event_id')then raise exception 'invalid:That event is no longer available.';end if;
  if coalesce((p_input->>'saved')::boolean,true)then insert into social_private.saved_events values(me,p_input->>'event_id')on conflict do nothing;else delete from social_private.saved_events where member=me and event_id=p_input->>'event_id';end if;
 elsif p_action in('organization.apply','organization.follow','organization.update')then
  if p_action='organization.apply'then
   if char_length(btrim(coalesce(p_input->>'name','')))not between 3 and 100 or char_length(coalesce(p_input->>'about',''))>2000 then raise exception 'invalid:Enter an organization name and a short description.';end if;
   insert into social_private.organizations(name,about,application)values(btrim(p_input->>'name'),coalesce(p_input->>'about',''),jsonb_build_object('contact',left(coalesce(p_input->>'contact',''),200),'evidence',left(coalesce(p_input->>'evidence',''),2000)))returning id::text into resource;
   insert into social_private.organization_admins values(resource::uuid,me,'admin');
  else
   select * into org from social_private.organizations where id=(p_input->>'organization_id')::uuid;
   if org.id is null then raise exception 'invalid:Unknown organization.';end if;
   if p_action='organization.follow'then
    if org.status<>'verified'then raise exception 'forbidden:This organization has not been verified.';end if;
    if coalesce((p_input->>'followed')::boolean,true)then insert into social_private.organization_follows values(org.id,me)on conflict do nothing;else delete from social_private.organization_follows where organization=org.id and member=me;end if;
   else
    if not exists(select 1 from social_private.organization_admins where organization=org.id and member=me)then raise exception 'forbidden:Only an organization administrator may edit it.';end if;
    if char_length(coalesce(p_input->>'about',''))>2000 then raise exception 'invalid:Description is too long.';end if;
    update social_private.organizations set about=coalesce(p_input->>'about',about)where id=org.id;
   end if;
  end if;
 elsif p_action in('attachment.authorize','attachment.reserve','attachment.commit','attachment.read')then
  if p_action in('attachment.authorize','attachment.reserve')then
   if p_input->>'post_id' is not null then
    select * into p from social_private.posts where id=(p_input->>'post_id')::uuid;
    if p.author is distinct from me or p.deleted or not social_private.can_read_post(me,p.id)then raise exception 'forbidden:Only the author may upload to this post.';end if;
    if exists(select 1 from social_private.attachments where post=p.id and ready)then raise exception 'invalid:This post already has media.';end if;
   elsif not social_private.can_message(me,room_id)then raise exception 'forbidden:Join or accept this conversation before uploading.';end if;
   if p_action='attachment.authorize'then return jsonb_build_object('authorized',true);end if;
   if(select count(*)from social_private.attachments where owner=me and created_at>now()-interval '1 hour')>=30 then raise exception 'rate_limit:Upload limit reached. Please try again later.';end if;
   insert into social_private.attachments(owner,room,post,kind,mime,size,path)values(me,room_id,p.id,p_input->>'kind',p_input->>'mime',(p_input->>'size')::integer,p_input->>'path')returning * into att;
   return jsonb_build_object('attachment_id',att.id,'path',att.path);
  else
   select * into att from social_private.attachments where id=(p_input->>'attachment_id')::uuid;
   if att.id is null then raise exception 'forbidden:This attachment is unavailable.';end if;
   if p_action='attachment.commit'then
    if att.owner<>me then raise exception 'forbidden:This upload belongs to another account.';end if;
    update social_private.attachments set ready=true where id=att.id;return jsonb_build_object('attachment_id',att.id,'snapshot',social_private.snapshot(me));
   else
    if not att.ready or not ((att.owner=me and att.message is null and att.post is null)or(att.post is not null and social_private.can_read_post(me,att.post)and not exists(select 1 from social_private.posts where id=att.post and deleted))or(att.message is not null and social_private.can_read_room(me,att.room)and not exists(select 1 from social_private.messages where id=att.message and deleted)))then raise exception 'forbidden:You do not have access to this attachment.';end if;
    return jsonb_build_object('path',att.path,'mime',att.mime,'attachment_id',att.id);
   end if;
  end if;
 elsif p_action in('report','block')then
  if p_input?'post_id' or p_input->>'target_type'='post' then
   select * into p from social_private.posts where id=coalesce(p_input->>'post_id',p_input->>'target_id')::uuid;
   if p.id is null or not social_private.can_read_post(me,p.id)then raise exception 'forbidden:This post is unavailable.';end if;other:=p.author;evidence:=jsonb_build_object('text',p.body,'anonymous',p.anonymous);
   insert into social_private.hidden values(me,p.id)on conflict do nothing;
  elsif p_input->>'target_type'='comment'then
   select * into c from social_private.comments where id=(p_input->>'target_id')::uuid;
   if c.id is null or not social_private.can_read_post(me,c.post)then raise exception 'forbidden:This reply is unavailable.';end if;other:=c.author;evidence:=jsonb_build_object('text',c.body);
  elsif p_input->>'target_type'='message'then
   select * into msg from social_private.messages where id=(p_input->>'target_id')::uuid;
   if msg.id is null or not social_private.can_read_room(me,msg.room)then raise exception 'forbidden:This message is unavailable.';end if;other:=msg.author;evidence:=jsonb_build_object('text',msg.body,'room',msg.room);
  else
   room_id:=coalesce(room_id,p_input->>'target_id');
   if not social_private.can_read_room(me,room_id)then raise exception 'forbidden:This conversation is unavailable.';end if;
   select member into other from social_private.room_members where room=room_id and member<>me limit 1;evidence:=social_private.message_list(me,room_id);
  end if;
  if p_action='report'then
   body_value:=btrim(coalesce(p_input->>'reason',''));
   if char_length(body_value)not between 1 and 500 then raise exception 'invalid:Choose a report reason.';end if;
   insert into social_private.reports(reporter,target_type,target_id,reason,evidence)values(me,coalesce(p_input->>'target_type','room'),coalesce(p_input->>'target_id',p_input->>'post_id',room_id),body_value,evidence)returning id::text into resource;
  else
   if other is null or other=me then raise exception 'invalid:Choose another person to block.';end if;
   insert into social_private.blocks values(me,other)on conflict do nothing;
   update social_private.rooms set status='closed'where kind='dm' and exists(select 1 from social_private.room_members where room=rooms.id and member=me)and exists(select 1 from social_private.room_members where room=rooms.id and member=other);
  end if;
 elsif p_action='account.delete'then
  update social_private.activities set cancelled=true where host=me;
  update social_private.rooms set status='closed'where id in(select room from social_private.room_members where member=me and role='owner');
  update social_private.posts set deleted=true,body='',accepts_dm=false where author=me;
  update social_private.comments set deleted=true,body='' where author=me;
  update social_private.messages set deleted=true,body='' where author=me;
  delete from social_private.members where id=me;
  return jsonb_build_object('deleted',true);
 else raise exception 'invalid:Unknown social action.';
 end if;
 return jsonb_build_object('snapshot',social_private.snapshot(me),'resource_id',resource);
exception when unique_violation then return jsonb_build_object('error','That username or name is already taken.','code','conflict');
 when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Some fields are invalid. Please check and try again.','code','invalid');
 when raise_exception then return jsonb_build_object('error',split_part(sqlerrm,':',2),'code',split_part(sqlerrm,':',1));
end $$;
revoke all on function social_private.can_read_room(uuid,text),social_private.can_read_post(uuid,uuid),social_private.message_list(uuid,text),social_private.snapshot(uuid) from public,anon,authenticated;
grant execute on function social_private.can_read_room(uuid,text),social_private.can_read_post(uuid,uuid),social_private.message_list(uuid,text),social_private.snapshot(uuid) to service_role;
revoke all on function public.social_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.social_gateway(text,text,jsonb)to service_role;
