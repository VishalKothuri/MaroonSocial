-- Discoverable campus chats reuse the same private room and message boundary.
create schema community_private;
revoke all on schema community_private from public,anon,authenticated;
grant usage on schema community_private to service_role;
create table community_private.communities (
 room text primary key references social_private.rooms(id) on delete cascade,
 creator uuid references social_private.members(id) on delete set null,
 nonce uuid not null,
 is_public boolean not null default true,
 invite_code text unique not null default upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,10)),
 description text not null check(length(description) between 10 and 500),
 category text not null check(category in('General','Academics','Hobbies','Sports','Campus life')),
 capacity integer not null default 200 check(capacity between 2 and 200),
 created_at timestamptz not null default now(),
 unique(creator,nonce)
);
create index communities_creator on community_private.communities(creator,created_at);
create table community_private.bans (
 room text references community_private.communities(room) on delete cascade,
 member uuid references social_private.members(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(room,member)
);
create index community_bans_member on community_private.bans(member);
create table community_private.join_limits(member uuid primary key references social_private.members on delete cascade,window_at timestamptz not null default now(),attempts integer not null default 0);
do $$ declare t text;begin foreach t in array array['communities','bans','join_limits']loop
 execute format('alter table community_private.%I enable row level security',t);
 execute format('create policy "Server only" on community_private.%I to service_role using(true) with check(true)',t);
 execute format('revoke all on community_private.%I from public,anon,authenticated',t);
 execute format('grant select,insert,update,delete on community_private.%I to service_role',t);
end loop;end $$;

-- Generic group invitations and accept endpoints must obey community bans/caps
-- too; this is enforced below the new endpoint, not just in its UI.
create function community_private.membership_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare cap integer;state text;
begin
 select c.capacity into cap from community_private.communities c where c.room=new.room;
 if cap is null then return new;end if;
 if new.status not in('accepted','invited')then return new;end if;
 select status into state from social_private.rooms where id=new.room for update;
 if state<>'active' then raise exception 'forbidden:This community is closed.';end if;
 if exists(select 1 from community_private.bans where room=new.room and member=new.member)
 or exists(select 1 from social_private.members where id=new.member and banned)then raise exception 'forbidden:This community is unavailable.';end if;
 if exists(select 1 from social_private.room_members o join social_private.members m on m.id=o.member where o.room=new.room and o.role='owner'and m.banned)then raise exception 'forbidden:This community is unavailable.';end if;
 if exists(select 1 from social_private.room_members o where o.room=new.room and o.role='owner' and o.status='accepted' and social_private.blocked(o.member,new.member))then raise exception 'forbidden:This community is unavailable.';end if;
 if new.status='accepted' and (tg_op='INSERT' or old.status<>'accepted') and
 (select count(*)from social_private.room_members rm join community_private.communities c on c.room=rm.room where rm.member=new.member and rm.status='accepted')>=30 then raise exception 'full:Join up to 30 campus communities.';end if;
 if new.status='accepted' and (tg_op='INSERT' or old.status<>'accepted') and
 (select count(*)from social_private.room_members where room=new.room and status='accepted')>=cap then raise exception 'full:This community is full.';end if;
 return new;
end $$;
create trigger campus_community_membership_guard before insert or update of status,role on social_private.room_members for each row execute function community_private.membership_guard();
create function community_private.owner_leaving() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if old.role='owner' and exists(select 1 from community_private.communities where room=old.room)then
  update social_private.rooms set status='closed'where id=old.room;
 end if;return old;
end $$;
create trigger campus_community_owner_leaving before delete on social_private.room_members for each row execute function community_private.owner_leaving();

create function community_private.owner_suspended() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.banned and not old.banned then
  update social_private.rooms r set status='closed'where exists(select 1 from community_private.communities c join social_private.room_members rm on rm.room=c.room where c.room=r.id and rm.member=new.id and rm.role='owner');
 end if;return new;
end $$;
create trigger campus_community_owner_suspended after update of banned on social_private.members for each row execute function community_private.owner_suspended();

create function community_private.owner_blocked() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 delete from social_private.room_members victim using community_private.communities c,social_private.room_members owner
 where victim.room=c.room and owner.room=c.room and owner.role='owner'and owner.status='accepted'and victim.role<>'owner'
 and ((owner.member=new.blocker and victim.member=new.blocked)or(owner.member=new.blocked and victim.member=new.blocker));
 return new;
end $$;
create trigger campus_community_owner_blocked after insert on social_private.blocks for each row execute function community_private.owner_blocked();

create function community_private.summary(p_me uuid,p_room text) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('id',r.id,'title',r.title,'description',c.description,'category',c.category,'capacity',c.capacity,
 'member_count',(select count(*)from social_private.room_members where room=r.id and status='accepted'),
 'joined',exists(select 1 from social_private.room_members where room=r.id and member=p_me and status='accepted'),
 'owner',exists(select 1 from social_private.room_members where room=r.id and member=p_me and status='accepted' and role='owner'),
 'closed',r.status<>'active','is_public',c.is_public,'invite_code',case when exists(select 1 from social_private.room_members where room=r.id and member=p_me and role='owner'and status='accepted')then c.invite_code else null end,'created_at',extract(epoch from c.created_at))
 from community_private.communities c join social_private.rooms r on r.id=c.room where c.room=p_room
$$;
create function public.communities_gateway(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
declare me uuid;rid text;other uuid;owner_id uuid;is_owner boolean;joined boolean;value_name text;value_description text;value_category text;reason text;n uuid;result jsonb;page jsonb;query_value text;offset_value integer;attempt_count integer;public_value boolean;resources text[];raw_error text;code text;
begin
 me:=social_private.require_member(p_hash);
 if p_action='list' then
  query_value:=left(btrim(coalesce(p_input->>'search','')),80);offset_value:=least(10000,greatest(0,coalesce((p_input->>'offset')::integer,0)));
  select coalesce(jsonb_agg(value order by joined_order desc,sort_name,id),'[]')into page from(
   select community_private.summary(me,c.room)value,
    exists(select 1 from social_private.room_members mine where mine.room=c.room and mine.member=me and mine.status='accepted')joined_order,
    lower(r.title)sort_name,r.id
   from community_private.communities c join social_private.rooms r on r.id=c.room
   where r.kind='group'and r.status='active'
    and exists(select 1 from social_private.room_members own join social_private.members m on m.id=own.member where own.room=c.room and own.role='owner'and own.status='accepted'and not m.banned and not social_private.blocked(me,own.member))
    and (c.is_public or exists(select 1 from social_private.room_members mine where mine.room=c.room and mine.member=me and mine.status='accepted'))
    and not exists(select 1 from community_private.bans where room=c.room and member=me)
    and (query_value=''or strpos(lower(r.title||' '||c.description),lower(query_value))>0)
    and (coalesce(p_input->>'category','All')='All'or c.category=p_input->>'category')
    and (coalesce((p_input->>'joined_only')::boolean,false)=false or exists(select 1 from social_private.room_members mine where mine.room=c.room and mine.member=me and mine.status='accepted'))
   order by joined_order desc,sort_name,r.id offset offset_value limit 51
  ) rows;
  return jsonb_build_object('communities',case when jsonb_array_length(page)>50 then page-50 else page end,'has_more',jsonb_array_length(page)>50);
 end if;
 if p_action='create' then
  n:=(p_input->>'nonce')::uuid;
  if n is null then raise exception 'invalid:Missing request identifier.';end if;
  select room into rid from community_private.communities where creator=me and nonce=n;
  if rid is not null then
   if not exists(select 1 from social_private.room_members where room=rid and member=me and status='accepted')then raise exception 'forbidden:You no longer have access to this community.';end if;
   return jsonb_build_object('community',community_private.summary(me,rid),'room_id',rid);
  end if;
  value_name:=btrim(coalesce(p_input->>'title',''));value_description:=btrim(coalesce(p_input->>'description',''));value_category:=p_input->>'category';public_value:=coalesce((p_input->>'is_public')::boolean,true);
  if length(value_name)not between 3 and 60 or length(value_description)not between 10 and 500 or value_category not in('General','Academics','Hobbies','Sports','Campus life')then raise exception 'invalid:Choose a 3–60 character name, a 10–500 character description and a category.';end if;
  perform pg_advisory_xact_lock(hashtextextended(lower(value_name),710912));
  if public_value and exists(select 1 from community_private.communities c join social_private.rooms r on r.id=c.room where c.is_public and lower(r.title)=lower(value_name) and r.status='active')then raise exception 'conflict:A community with that name already exists.';end if;
  if (select count(*)from social_private.room_members rm join community_private.communities c on c.room=rm.room where rm.member=me and rm.status='accepted')>=30 then raise exception 'full:Join up to 30 campus communities.';end if;
  if (select count(*)from community_private.communities where creator=me and created_at>now()-interval '1 day')>=3 then raise exception 'rate_limit:Create up to three communities per day.';end if;
  insert into social_private.rooms(kind,title,meta)values('group',value_name,'{"campusCommunity":true}')returning id into rid;
  insert into community_private.communities(room,creator,nonce,description,category,is_public)values(rid,me,n,value_description,value_category,public_value);
  insert into social_private.room_members(room,member,role,status)values(rid,me,'owner','accepted');
  return jsonb_build_object('community',community_private.summary(me,rid),'room_id',rid);
 end if;
 rid:=p_input->>'room_id';
 if p_action='join_code'then
  insert into community_private.join_limits(member)values(me)on conflict do nothing;
  update community_private.join_limits set attempts=case when window_at<now()-interval '1 minute'then 1 else attempts+1 end,window_at=case when window_at<now()-interval '1 minute'then now()else window_at end where member=me returning attempts into attempt_count;
  if attempt_count>12 then return jsonb_build_object('error','Too many invite-code attempts. Try again in a minute.','code','rate_limit');end if;
  if coalesce(p_input->>'invite_code','') !~ '^[A-Fa-f0-9]{10}$'then return jsonb_build_object('error','Enter the 10-character invitation code.','code','invalid');end if;
  select room into rid from community_private.communities where invite_code=upper(p_input->>'invite_code');
  if rid is null then return jsonb_build_object('error','That invitation is unavailable. Check the code with its owner.','code','unavailable');end if;
 end if;
 perform 1 from social_private.rooms r join community_private.communities c on c.room=r.id where r.id=rid for update of r;
 if not found then raise exception 'unavailable:This community is unavailable.';end if;
 select member into owner_id from social_private.room_members where room=rid and role='owner'and status='accepted'limit 1;
 is_owner:=owner_id=me;joined:=exists(select 1 from social_private.room_members where room=rid and member=me and status='accepted');
 if exists(select 1 from community_private.bans where room=rid and member=me) or social_private.blocked(me,owner_id) then raise exception 'forbidden:This community is unavailable.';end if;
 if not joined and exists(select 1 from community_private.communities where room=rid and not is_public)and p_action<>'join_code' then raise exception 'unavailable:Use an invitation code to join this private community.';end if;
 if p_action='detail' then
  if not joined and (owner_id is null or exists(select 1 from social_private.rooms where id=rid and status<>'active'))then raise exception 'unavailable:This community is unavailable.';end if;
 elsif p_action in('join','join_code') then
  if not coalesce((p_input->>'named_consent')::boolean,false)then raise exception 'invalid:Confirm that your username will be visible to community members.';end if;
  if owner_id is null or exists(select 1 from social_private.rooms where id=rid and status<>'active')then raise exception 'unavailable:This community is closed.';end if;
  if not joined and (select count(*)from social_private.room_members rm join community_private.communities c on c.room=rm.room where rm.member=me and rm.status='accepted')>=30 then raise exception 'full:Join up to 30 campus communities.';end if;
  insert into social_private.room_members(room,member,status)values(rid,me,'accepted')on conflict(room,member)do update set status='accepted';
 elsif p_action='leave' then
  if is_owner and exists(select 1 from social_private.rooms where id=rid and status='active')and exists(select 1 from social_private.room_members where room=rid and member<>me and status='accepted')then raise exception 'invalid:Transfer ownership or close the community before leaving.';end if;
  delete from social_private.room_members where room=rid and member=me;
  return jsonb_build_object('left',true,'room_id',rid);
 elsif p_action='report' then
  reason:=btrim(coalesce(p_input->>'reason',''));
  if length(reason)not between 3 and 500 then raise exception 'invalid:Add a short reason for your report.';end if;
  if not exists(select 1 from social_private.reports where reporter=me and target_type='room'and target_id=rid and status='pending')then
   insert into social_private.reports(reporter,target_type,target_id,reason,evidence)values(me,'room',rid,reason,jsonb_build_object('community',community_private.summary(me,rid)));
  end if;
  return jsonb_build_object('reported',true);
 else
  if not coalesce(is_owner,false)then raise exception 'forbidden:Only the community owner can do that.';end if;
  if p_action='update' then
   value_name:=btrim(coalesce(p_input->>'title',''));value_description:=btrim(coalesce(p_input->>'description',''));value_category:=p_input->>'category';
   if length(value_name)not between 3 and 60 or length(value_description)not between 10 and 500 or value_category not in('General','Academics','Hobbies','Sports','Campus life')then raise exception 'invalid:Check the community name, description and category.';end if;
   perform pg_advisory_xact_lock(hashtextextended(lower(value_name),710912));
   if (select is_public from community_private.communities where room=rid)and exists(select 1 from community_private.communities c join social_private.rooms r on r.id=c.room where c.room<>rid and c.is_public and lower(r.title)=lower(value_name)and r.status='active')then raise exception 'conflict:A community with that name already exists.';end if;
   update social_private.rooms set title=value_name where id=rid;update community_private.communities set description=value_description,category=value_category where room=rid;
  elsif p_action='rotate_code'then
   update community_private.communities set invite_code=upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,10))where room=rid;
  elsif p_action='close' then
   update social_private.rooms set status='closed'where id=rid;
  elsif p_action in('remove','ban','unban','transfer')then
   select id into other from social_private.members where username=lower(ltrim(btrim(p_input->>'username'),'@'));
   if other is null or other=me then raise exception 'invalid:Choose another community member.';end if;
   if p_action='unban'then delete from community_private.bans where room=rid and member=other;
   else
    if not exists(select 1 from social_private.room_members where room=rid and member=other and status='accepted')then raise exception 'invalid:That person is not a current member.';end if;
    if p_action='transfer'then
     if exists(select 1 from social_private.members where id=other and banned)or social_private.blocked(me,other)then raise exception 'invalid:Choose an available member.';end if;
     update social_private.room_members set role=case when member=other then 'owner'else 'member'end where room=rid and member in(me,other);
    else
     if p_action='ban'then insert into community_private.bans(room,member)values(rid,other)on conflict do nothing;end if;
     delete from social_private.room_members where room=rid and member=other;
    end if;
   end if;
  else raise exception 'invalid:Unknown community action.';end if;
 end if;
 result:=jsonb_build_object('community',community_private.summary(me,rid),'room_id',rid);
 if exists(select 1 from social_private.room_members where room=rid and member=me and status='accepted')then
  result:=result||jsonb_build_object('members',coalesce((select jsonb_agg(jsonb_build_object('username',m.username,'role',rm.role)order by rm.role desc,m.username)from social_private.room_members rm join social_private.members m on m.id=rm.member where rm.room=rid and rm.status='accepted'and not social_private.blocked(me,m.id)),'[]'));
 end if;
 if exists(select 1 from social_private.room_members where room=rid and member=me and role='owner'and status='accepted')then
  result:=result||jsonb_build_object('bans',coalesce((select jsonb_agg(jsonb_build_object('username',m.username,'role','banned')order by m.username)from community_private.bans b join social_private.members m on m.id=b.member where b.room=rid),'[]'));
 end if;
 return result;
exception when raise_exception then raw_error:=sqlerrm;code:=split_part(raw_error,':',1);return jsonb_build_object('error',substr(raw_error,length(code)+2),'code',code);
 when unique_violation then return jsonb_build_object('error','This community or request already exists. Refresh and try again.','code','conflict');
 when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Check the community details and try again.','code','invalid');
end $$;
revoke all on all functions in schema community_private from public,anon,authenticated;
grant execute on all functions in schema community_private to service_role;
revoke all on function public.communities_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.communities_gateway(text,text,jsonb)to service_role;
