create schema verification_private;
revoke all on schema verification_private from public,anon,authenticated;
grant usage on schema verification_private to service_role;
create table verification_private.settings(id boolean primary key default true check(id),require_verified boolean not null default false);
insert into verification_private.settings values(true,false);
create table verification_private.memberships(member uuid primary key references social_private.members on delete cascade,email_hash text unique not null check(email_hash~'^[a-f0-9]{64}$'),verified_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '180 days');
create table verification_private.challenges(id uuid primary key,member uuid not null references social_private.members on delete cascade,email_hash text not null check(email_hash~'^[a-f0-9]{64}$'),code_hash text check(code_hash~'^[a-f0-9]{64}$'),state text not null default 'prepared'check(state in('prepared','sent','failed','used','cancelled')),attempts integer not null default 0,created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '10 minutes');
create index verification_challenges_member on verification_private.challenges(member,created_at);
create table verification_private.sends(id uuid primary key,member uuid references social_private.members on delete set null,email_hash text not null,network_hash text not null,created_at timestamptz not null default now());
create index verification_sends_member on verification_private.sends(member,created_at);
create index verification_sends_email on verification_private.sends(email_hash,created_at);
create index verification_sends_network on verification_private.sends(network_hash,created_at);
do $$declare t text;begin for t in select tablename from pg_tables where schemaname='verification_private'loop execute format('alter table verification_private.%I enable row level security',t);execute format('create policy server_only on verification_private.%I to service_role using(true)with check(true)',t);end loop;end $$;
revoke all on all tables in schema verification_private from public,anon,authenticated;
grant select,insert,update,delete on all tables in schema verification_private to service_role;
create or replace function verification_private.status(p_me uuid)returns jsonb language sql stable security invoker set search_path=''as $$select jsonb_build_object('verified',exists(select 1 from verification_private.memberships where member=p_me and expires_at>now()),'verified_at',(select extract(epoch from verified_at)from verification_private.memberships where member=p_me),'expires_at',(select extract(epoch from expires_at)from verification_private.memberships where member=p_me),'required',(select require_verified from verification_private.settings where id))$$;
revoke all on function verification_private.status(uuid)from public,anon,authenticated;
grant execute on function verification_private.status(uuid)to service_role;
create or replace function social_private.require_account(p_hash text) returns uuid language plpgsql security invoker set search_path='' as $$
declare m social_private.members; begin
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'unauthorized:Sign in to continue.'; end if;
 select * into m from social_private.members where token_hash=p_hash for no key update;
 if m.id is null then raise exception 'unauthorized:Your account credential is unavailable.'; end if;
 if m.banned then raise exception 'forbidden:This account is suspended.'; end if;
 if m.rate_window>now()-interval '1 minute' and m.rate_count>=600 then raise exception 'rate_limit:Please slow down and try again shortly.'; end if;
 update social_private.members set seen_at=now(),rate_window=case when rate_window<now()-interval '1 minute' then now() else rate_window end,rate_count=case when rate_window<now()-interval '1 minute' then 1 else rate_count+1 end where id=m.id;
 return m.id;
end $$;

revoke all on function social_private.require_account(text)from public,anon,authenticated;
grant execute on function social_private.require_account(text)to service_role;
create or replace function social_private.require_member(p_hash text)returns uuid language plpgsql security invoker set search_path=''as $$declare me uuid;begin me:=social_private.require_account(p_hash);if(select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships where member=me and expires_at>now())then raise exception 'verification_required:Verify your TAMU mailbox to access the community.';end if;return me;end $$;
create or replace function public.verification_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;c verification_private.challenges;result jsonb;
begin
 me:=social_private.require_account(p_hash);
 if p_action='status'then return verification_private.status(me);
 elsif p_action='prepare'then
  if p_input->>'domain' is distinct from 'tamu.edu'or p_input->>'email_hash'!~'^[a-f0-9]{64}$'or p_input->>'code_hash'!~'^[a-f0-9]{64}$'then raise exception 'invalid:Use your exact @tamu.edu mailbox.';end if;
  perform pg_advisory_xact_lock(77844001);
  if exists(select 1 from verification_private.sends where member=me and created_at>now()-interval '60 seconds')then raise exception 'rate_limit:Wait one minute before requesting another code.';end if;
  if(select count(*)from verification_private.sends where member=me and created_at>now()-interval '1 hour')>=4 or(select count(*)from verification_private.sends where email_hash=p_input->>'email_hash'and created_at>now()-interval '1 day')>=8 or(select count(*)from verification_private.sends where network_hash=p_input->>'network_hash'and created_at>now()-interval '1 hour')>=15 or(select count(*)from verification_private.sends where created_at>=date_trunc('day',now()))>=250 then raise exception 'rate_limit:Verification sending limit reached. Please try again later.';end if;
  update verification_private.challenges set state='cancelled',code_hash=null where member=me and state in('prepared','sent');
  insert into verification_private.challenges(id,member,email_hash,code_hash)values((p_input->>'challenge_id')::uuid,me,p_input->>'email_hash',p_input->>'code_hash');
  insert into verification_private.sends(id,member,email_hash,network_hash)values((p_input->>'challenge_id')::uuid,me,p_input->>'email_hash',p_input->>'network_hash');
  return jsonb_build_object('prepared',true);
 elsif p_action in('sent','failed','cancel')then
  update verification_private.challenges set state=case p_action when 'sent'then 'sent'when 'failed'then 'failed'else 'cancelled'end,code_hash=case when p_action='sent'then code_hash else null end where id=(p_input->>'challenge_id')::uuid and member=me and state in('prepared','sent');
  return verification_private.status(me)||case when p_action='sent'then jsonb_build_object('challenge_id',p_input->>'challenge_id','expires_in',600,'message','Code sent. Check your TAMU mailbox and spam folder.')else '{}'::jsonb end;
 elsif p_action='confirm'then
  select *into c from verification_private.challenges where id=(p_input->>'challenge_id')::uuid and member=me for update;
  if c.id is null or c.state<>'sent'or c.expires_at<=now()or c.attempts>=5 then return jsonb_build_object('error','This code is invalid or expired. Request a new code.','code','invalid_code');end if;
  update verification_private.challenges set attempts=attempts+1 where id=c.id;
  if c.code_hash is distinct from p_input->>'code_hash'then
   if c.attempts>=4 then update verification_private.challenges set state='cancelled',code_hash=null where id=c.id;end if;
   return jsonb_build_object('error','This code is invalid or expired. Request a new code.','code','invalid_code');
  end if;
  if exists(select 1 from verification_private.memberships where email_hash=c.email_hash and member<>me)then update verification_private.challenges set state='cancelled',code_hash=null where id=c.id;return jsonb_build_object('error','This mailbox is linked to an existing account. Contact the owner for recovery.','code','account_exists');end if;
  insert into verification_private.memberships(member,email_hash)values(me,c.email_hash)on conflict(member)do update set email_hash=excluded.email_hash,verified_at=now(),expires_at=now()+interval '180 days';
  update verification_private.challenges set state='used',code_hash=null where id=c.id;
  return verification_private.status(me)||jsonb_build_object('message','TAMU mailbox verified. This confirms mailbox access, not current enrollment.');
 else raise exception 'invalid:Unknown verification action.';end if;
exception when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Invalid verification request.','code','invalid');when raise_exception then return jsonb_build_object('error',split_part(sqlerrm,':',2),'code',split_part(sqlerrm,':',1));
end $$;
revoke all on function public.verification_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.verification_gateway(text,text,jsonb)to service_role;
select cron.schedule('verification_cleanup','*/5 * * * *',$$ delete from verification_private.challenges where expires_at<now()or(state in('used','failed','cancelled')and created_at<now()-interval '10 minutes');delete from verification_private.sends where created_at<now()-interval '1 day'; $$);

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
 me:=case when p_action in('snapshot','profile.update','account.delete')then social_private.require_account(p_hash)else social_private.require_member(p_hash)end;
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
  select * into r from social_private.rooms where id=a.room;
  if r.meta?'organization' and p_action not in('activity.leave','activity.cancel') then
   select * into org from social_private.organizations where id=(r.meta->>'organization')::uuid and status='verified';
   if org.id is null or (p_action in('activity.edit','activity.approve') and not exists(select 1 from social_private.organization_admins where organization=org.id and member=me))then raise exception 'forbidden:This organization cannot publish or manage this activity.';end if;
  end if;
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
    if a.cancelled then raise exception 'forbidden:This activity has been cancelled.';end if;
    if char_length(btrim(coalesce(p_input->>'title',a.title))) not between 1 and 100 or char_length(coalesce(p_input->>'details',a.details))>4000 or char_length(btrim(coalesce(p_input->>'place',a.place)))not between 1 and 200 then raise exception 'invalid:Enter a title, public place, and details within the limits.'; end if;
    value_int:=coalesce((p_input->>'capacity')::integer,a.capacity);
    if value_int not between 2 and 100 or value_int<(select count(*)from social_private.room_members where room=a.room and status='accepted')then raise exception 'invalid:Capacity must be 2–100 and include everyone already accepted.';end if;
    if coalesce(to_timestamp((p_input->>'starts')::double precision),a.starts)<now()then raise exception 'invalid:Choose a future start time.';end if;
    update social_private.activities set capacity=value_int,approval_required=coalesce((p_input->>'approval_required')::boolean,approval_required),title=coalesce(p_input->>'title',title),details=coalesce(p_input->>'details',details),place=coalesce(p_input->>'place',place),starts=coalesce(to_timestamp((p_input->>'starts')::double precision),starts)where id=a.id;
    update social_private.rooms set title=(select title from social_private.activities where id=a.id)where id=a.room;
   end if;
  end if;
 elsif p_action='organization.message' then
  select *into org from social_private.organizations where id=(p_input->>'organization_id')::uuid and status='verified';
  if org.id is null then raise exception 'forbidden:This organization is unavailable.';end if;
  select oa.member into other from social_private.organization_admins oa join social_private.members mm on mm.id=oa.member where oa.organization=org.id and not mm.banned and oa.member<>me and not social_private.blocked(me,oa.member)order by mm.created_at limit 1;
  if other is null then raise exception 'forbidden:No organization administrator can receive this message.';end if;
  perform pg_advisory_xact_lock(hashtextextended(me::text||org.id::text,779));
  select rooms.*into r from social_private.rooms rooms where rooms.kind='dm'and rooms.meta->>'organization'=org.id::text and exists(select 1 from social_private.room_members where room=rooms.id and member=me)limit 1;
  if r.id is not null then
   if r.status='closed'then raise exception 'forbidden:This organization conversation is closed.';end if;resource:=r.id;
  else
   body_value:=btrim(coalesce(p_input->>'text','Hi! I have a question for your organization.'));
   if char_length(body_value)not between 1 and 1000 then raise exception 'invalid:Write 1–1,000 characters.';end if;
   if(select count(*)from social_private.rooms where requester=me and kind='dm'and created_at>now()-interval '1 hour')>=20 then raise exception 'rate_limit:Too many requests. Try again later.';end if;
   insert into social_private.rooms(kind,title,status,requester,meta)values('dm',org.name,'pending',me,jsonb_build_object('organization',org.id))returning id into resource;
   insert into social_private.room_members(room,member,status,role)values(resource,me,'accepted','member'),(resource,other,'invited','owner');
   insert into social_private.messages(room,author,nonce,body)values(resource,me,nonce_value,body_value);
  end if;
 elsif p_action='dm.request' then
  if p_input?'post_id' then
   select * into p from social_private.posts where id=(p_input->>'post_id')::uuid;
   if p.id is null or not p.accepts_dm or p.deleted or not social_private.can_read_post(me,p.id) then raise exception 'forbidden:This author is not accepting message requests.'; end if;
   other:=p.author;
  else select id into other from social_private.members where username=lower(p_input->>'username');end if;
  if other is null or other=me or social_private.blocked(me,other) then raise exception 'forbidden:This person cannot receive your request.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me::text,other::text)||greatest(me::text,other::text)||coalesce(p.id::text,'named'),778));
  select rooms.* into r from social_private.rooms rooms where rooms.kind='dm' and rooms.context_post is not distinct from p.id and not(rooms.meta?'organization') and exists(select 1 from social_private.room_members where room=rooms.id and member=me) and exists(select 1 from social_private.room_members where room=rooms.id and member=other) limit 1;
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
  if r.meta?'organization'and not exists(select 1 from social_private.organizations oo join social_private.organization_admins oa on oa.organization=oo.id where oo.id=(r.meta->>'organization')::uuid and oo.status='verified'and oa.member=me)then raise exception 'forbidden:You are no longer authorized to answer for this organization.';end if;
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
  select * into msg from social_private.messages where author=me and nonce=nonce_value;
  if msg.id is not null and (msg.room is distinct from room_id or msg.body is distinct from body_value or msg.reply_to is distinct from (p_input->>'reply_to')::uuid or media is distinct from (select id from social_private.attachments where message=msg.id))then raise exception 'conflict:This send identifier was already used for another message. Retry the original message.';end if;
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
  if jsonb_typeof(coalesce(p_input->'usernames','[]'))<>'array' or jsonb_array_length(coalesce(p_input->'usernames','[]'))>30 then raise exception 'invalid:Invite up to 30 people at a time.';end if;
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
   if p_action='group.invite' and (select count(*) from social_private.room_members where room=room_id and status in('accepted','invited'))>=31 then raise exception 'full:This group has reached its 31 person limit.';end if;
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
    if org.status='suspended' or not exists(select 1 from social_private.organization_admins where organization=org.id and member=me)then raise exception 'forbidden:Only an organization administrator may edit it.';end if;
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
    if not att.ready or not ((att.owner=me and att.message is null and att.post is null)or(att.post is not null and social_private.can_read_post(me,att.post)and not exists(select 1 from social_private.posts where id=att.post and deleted))or(att.message is not null and social_private.can_read_room(me,att.room)and not exists(select 1 from social_private.messages where id=att.message and (deleted or social_private.blocked(me,author)))))then raise exception 'forbidden:You do not have access to this attachment.';end if;
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
  elsif p_input->>'target_type'='activity' then
   select * into a from social_private.activities where id=(p_input->>'target_id')::uuid;
   if a.id is null or social_private.blocked(me,a.host)then raise exception 'forbidden:This activity is unavailable.';end if;
   other:=a.host;evidence:=jsonb_build_object('title',a.title,'details',a.details,'place',a.place);
  elsif p_input->>'target_type'='organization' and p_action='report' then
   select * into org from social_private.organizations where id=(p_input->>'target_id')::uuid and status='verified';
   if org.id is null then raise exception 'forbidden:This organization is unavailable.';end if;
   evidence:=jsonb_build_object('name',org.name,'about',org.about);
  else
   room_id:=coalesce(room_id,p_input->>'target_id');
   if not social_private.can_read_room(me,room_id)then raise exception 'forbidden:This conversation is unavailable.';end if;
   if p_action='block' and not exists(select 1 from social_private.rooms where id=room_id and kind='dm')then raise exception 'invalid:Block the sender of a specific message in a shared room.';end if;
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
  update social_private.rooms set status='closed'where id in(select room from social_private.room_members where member=me and (role='owner' or exists(select 1 from social_private.rooms rr where rr.id=room and rr.kind='dm')));
  update social_private.posts set deleted=true,body='',accepts_dm=false where author=me;
  update social_private.comments set deleted=true,body='' where author=me;
  update social_private.messages set deleted=true,body='' where author=me;
  select coalesce(jsonb_agg(path),'[]') into evidence from social_private.attachments where owner=me;
  insert into social_private.storage_deletions(path)select path from social_private.attachments where owner=me on conflict do nothing;
  delete from social_private.members where id=me;
  return jsonb_build_object('deleted',true,'storage_paths',evidence);
 else raise exception 'invalid:Unknown social action.';
 end if;
 return jsonb_build_object('snapshot',social_private.snapshot(me),'resource_id',resource);
exception when unique_violation then return jsonb_build_object('error','That username or name is already taken.','code','conflict');
 when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Some fields are invalid. Please check and try again.','code','invalid');
 when raise_exception then return jsonb_build_object('error',split_part(sqlerrm,':',2),'code',split_part(sqlerrm,':',1));
end $$;

create or replace function social_private.snapshot(p_me uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb; begin
 if(select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships where member=p_me and expires_at>now())then
  return jsonb_build_object('username',(select username from social_private.members where id=p_me),'nsfwEnabled',false,'posts','[]'::jsonb,'courses','[]'::jsonb,'activities','[]'::jsonb,'conversations','[]'::jsonb,'conversationMeta','[]'::jsonb,'ownPostIDs','[]'::jsonb,'ownCommentIDs','[]'::jsonb,'ownMessageIDs','[]'::jsonb,'attachments','[]'::jsonb,'organizations','[]'::jsonb,'savedEvents','[]'::jsonb);
 end if;

 select jsonb_build_object('username',me.username,'nsfwEnabled',me.nsfw_enabled,
 'posts',coalesce((select jsonb_agg(j order by created_at desc) from (
 select p.created_at,jsonb_build_object('id',p.id,'author',case when p.deleted or u.id is null then '[deleted]' when p.author=p_me then u.username when p.anonymous then 'Anonymous' else u.username end,'anonymous',p.anonymous,'community',p.community,'text',case when p.deleted then '[Post deleted]' else p.body end,'score',coalesce((select sum(value) from social_private.votes where post=p.id),0),'vote',coalesce((select value from social_private.votes where post=p.id and member=p_me),0),'created',extract(epoch from p.created_at),'saved',exists(select 1 from social_private.bookmarks where post=p.id and member=p_me),'acceptsDM',p.accepts_dm and not p.deleted,'deleted',p.deleted,'attachmentID',case when p.deleted then null else(select id from social_private.attachments where post=p.id and ready limit 1)end,
 'comments',coalesce((select jsonb_agg(cj order by ct) from(select c.created_at ct,jsonb_build_object('id',c.id,'author',case when c.deleted or cu.id is null then '[deleted]' when c.author=p_me then cu.username when c.anonymous then case when c.author=p.author then 'OP' else 'Aggie '||substr(md5(p.id::text||c.author::text),1,4) end else cu.username end,'text',case when c.deleted then '[Reply deleted]' else c.body end,'anonymous',c.anonymous,'created',extract(epoch from c.created_at),'isOP',c.author=p.author,'deleted',c.deleted) cj from social_private.comments c left join social_private.members cu on cu.id=c.author where c.post=p.id and not social_private.blocked(p_me,c.author) order by c.created_at limit 200) comments),'[]'))j
 from social_private.posts p left join social_private.members u on u.id=p.author where social_private.can_read_post(p_me,p.id) and not exists(select 1 from social_private.hidden h where h.member=p_me and h.post=p.id) order by p.created_at desc limit 150)posts),'[]'),
 'courses',coalesce((select jsonb_agg(r.meta) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where r.kind='course' and rm.member=p_me and rm.status='accepted'),'[]'),
 'activities',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'kind',a.kind,'host',case when r.meta?'organization' then (select name from social_private.organizations where id=(r.meta->>'organization')::uuid) else coalesce(u.username,'[deleted]') end,'place',a.place,'starts',extract(epoch from a.starts),'capacity',a.capacity,'details',a.details,'course',a.course,'cancelled',a.cancelled,'approvalRequired',a.approval_required,'membershipStatus',(select status from social_private.room_members where room=a.room and member=p_me),'joinRequests',case when a.host=p_me then coalesce((select jsonb_agg(mm.username) from social_private.room_members rr join social_private.members mm on mm.id=rr.member where rr.room=a.room and rr.status='pending'),'[]')else '[]'::jsonb end,'waitlisted',exists(select 1 from social_private.room_members where room=a.room and member=p_me and status='waitlisted'),'participantCount',(select count(*) from social_private.room_members where room=a.room and status='accepted'),'participants',case when exists(select 1 from social_private.room_members where room=a.room and member=p_me and status='accepted') then coalesce((select jsonb_agg(case when r.meta?'organization' and rm.role='owner' then (select name from social_private.organizations where id=(r.meta->>'organization')::uuid) else am.username end) from social_private.room_members rm join social_private.members am on am.id=rm.member where rm.room=a.room and rm.status='accepted'),'[]') else '[]'::jsonb end) order by a.starts) from social_private.activities a join social_private.rooms r on r.id=a.room left join social_private.members u on u.id=a.host where not social_private.blocked(p_me,a.host) and (not a.cancelled or a.host=p_me) and (not(r.meta?'organization') or exists(select 1 from social_private.organizations o where o.id=(r.meta->>'organization')::uuid and o.status='verified'))),'[]'),
 'conversations',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',case when r.kind='dm' then case when r.meta?'organization'then(select name from social_private.organizations where id=(r.meta->>'organization')::uuid) when r.anonymous then 'Anonymous · post conversation' else coalesce((select u.username from social_private.room_members o join social_private.members u on u.id=o.member where o.room=r.id and o.member<>p_me limit 1),'Conversation')end else r.title end,'subtitle',case when r.status='pending' then case when r.requester=p_me then 'Request sent' else 'Message request'end else case when r.kind='course' then coalesce(r.meta->>'term','')||' · shared course room' else 'Shared '||r.kind||' conversation'end end,'messages',case when social_private.can_read_room(p_me,r.id) then social_private.message_list(p_me,r.id) else '[]'::jsonb end,'request',rm.status='invited','anonymous',r.anonymous) order by r.created_at desc) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where rm.member=p_me and rm.status in('accepted','invited') and (r.kind<>'dm' or not exists(select 1 from social_private.room_members o where o.room=r.id and social_private.blocked(p_me,o.member)))),'[]'),
 'conversationMeta',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'kind',r.kind,'status',r.status,'role',rm.role,'call',case when r.kind='dm' and social_private.can_message(p_me,r.id) then(select jsonb_build_object('id',cl.id,'mode',cl.mode,'state',cl.state,'incoming',cl.callee=p_me and cl.state='ringing')from social_private.calls cl where cl.room=r.id and cl.state<>'ended'and ((cl.state='ringing'and cl.created_at>now()-interval '60 seconds')or(cl.state='connected'and least(cl.caller_seen,cl.callee_seen)>now()-interval '30 seconds'))order by cl.created_at desc limit 1)else null end,'members',case when r.kind='group' and rm.status='accepted' then coalesce((select jsonb_agg(jsonb_build_object('username',gm.username,'role',gr.role,'status',gr.status) order by gm.username) from social_private.room_members gr join social_private.members gm on gm.id=gr.member where gr.room=r.id and gr.status in('accepted','invited')),'[]')else '[]'::jsonb end,'canSend',social_private.can_message(p_me,r.id),'lastRead',rm.last_read,'pendingOutgoing',r.status='pending' and r.requester=p_me,'unread',(select count(*) from social_private.messages m where m.room=r.id and m.seq>rm.last_read and m.author<>p_me and not social_private.blocked(p_me,m.author)),'typing',coalesce((select jsonb_agg(case when r.anonymous then 'Guest' when r.meta?'organization' and t.role='owner' then(select name from social_private.organizations where id=(r.meta->>'organization')::uuid) else u.username end) from social_private.room_members t join social_private.members u on u.id=t.member where t.room=r.id and t.member<>p_me and t.typing_until>now() and not social_private.blocked(p_me,t.member)),'[]'))) from social_private.rooms r join social_private.room_members rm on rm.room=r.id where rm.member=p_me and rm.status in('accepted','invited')),'[]'),
 'ownPostIDs',coalesce((select jsonb_agg(id) from social_private.posts where author=p_me),'[]'),'ownCommentIDs',coalesce((select jsonb_agg(id) from social_private.comments where author=p_me),'[]'),'ownMessageIDs',coalesce((select jsonb_agg(id) from social_private.messages where author=p_me),'[]'),
 'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'kind',a.kind,'mime',a.mime,'size',a.size,'roomID',a.room,'messageID',a.message,'postID',a.post)) from social_private.attachments a where a.ready and ((a.post is not null and social_private.can_read_post(p_me,a.post) and exists(select 1 from social_private.posts pp where pp.id=a.post and not pp.deleted)) or(a.message is not null and social_private.can_read_room(p_me,a.room) and exists(select 1 from social_private.messages mm where mm.id=a.message and not mm.deleted and not social_private.blocked(p_me,mm.author))))),'[]'),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'about',o.about,'status',o.status,'followed',exists(select 1 from social_private.organization_follows where organization=o.id and member=p_me),'canManage',exists(select 1 from social_private.organization_admins where organization=o.id and member=p_me))) from social_private.organizations o where o.status='verified' or exists(select 1 from social_private.organization_admins where organization=o.id and member=p_me)),'[]'),
 'savedEvents',coalesce((select jsonb_agg(event_id) from social_private.saved_events where member=p_me),'[]')) into result from social_private.members me where me.id=p_me;
 return result;
end $$;

