-- Per-group identities never disclose the account username or universal member ID.
alter table community_private.communities add column avatar text not null default 'maroon';
alter table community_private.communities add constraint community_avatar check(avatar in('maroon','gold','sage','sky','violet','coral','slate','rose'));
alter table community_private.communities drop constraint communities_category_check;
update community_private.communities set category=case category when 'Academics' then 'Study Group' when 'General' then 'Other' else 'People on app' end;
alter table community_private.communities add constraint communities_category_check check(category in('Class','Major','Dorm or House','Study Group','Friends','People on app','Other'));

-- Existing private groups keep their rooms/messages but acquire the same rules.
insert into community_private.communities(room,creator,nonce,is_public,description,category)
select r.id,(select member from social_private.room_members where room=r.id and role='owner'and status='accepted'limit 1),gen_random_uuid(),false,'Private group chat.','Other'
from social_private.rooms r where r.kind='group'and not exists(select 1 from community_private.communities c where c.room=r.id);
update social_private.rooms r set meta=meta||'{"campusCommunity":true}'::jsonb where r.kind='group';
update social_private.rooms r set status='closed'where r.kind='group'and not exists(select 1 from social_private.room_members where room=r.id and role='owner'and status='accepted');
update social_private.room_members rm set status='declined',typing_until=null where status='invited'and exists(select 1 from social_private.rooms r where r.id=rm.room and r.kind='group'and r.status='closed');

create table community_private.identities(
 room text references community_private.communities(room)on delete cascade,
 member uuid references social_private.members(id)on delete cascade,
 member_key uuid not null default gen_random_uuid(),
 alias text not null check(alias~'^[A-Za-z0-9_]{3,24}$'),
 avatar text not null check(avatar in('maroon','gold','sage','sky','violet','coral','slate','rose')),
 primary key(room,member),unique(room,member_key)
);
create unique index community_alias_unique on community_private.identities(room,lower(alias));
create index community_identity_member on community_private.identities(member);
alter table community_private.identities enable row level security;
create policy "Server only"on community_private.identities to service_role using(true)with check(true);
revoke all on community_private.identities from public,anon,authenticated;
grant all on community_private.identities to service_role;
insert into community_private.identities(room,member,alias,avatar)
select rm.room,rm.member,'member_'||substr(replace(gen_random_uuid()::text,'-',''),1,16),'maroon'
from social_private.room_members rm join community_private.communities c on c.room=rm.room where rm.status='accepted';

create table community_private.invitations(
 room text references community_private.communities(room)on delete cascade,
 member uuid references social_private.members(id)on delete cascade,
 invitation_key uuid not null default gen_random_uuid(),
 primary key(room,member),unique(room,invitation_key)
);
create index community_invitation_member on community_private.invitations(member);
alter table community_private.invitations enable row level security;
create policy "Server only"on community_private.invitations to service_role using(true)with check(true);
revoke all on community_private.invitations from public,anon,authenticated;
grant all on community_private.invitations to service_role;
insert into community_private.invitations(room,member)select rm.room,rm.member from social_private.room_members rm join community_private.communities c on c.room=rm.room where rm.status='invited';

create function community_private.set_identity(p_room text,p_member uuid,p_alias text,p_avatar text)returns void language plpgsql security invoker set search_path=''as $$
declare value_alias text:=btrim(coalesce(p_alias,''));begin
 if value_alias!~'^[A-Za-z0-9_]{3,24}$'then raise exception 'invalid:Choose a group username with 3–24 letters, numbers or underscores.';end if;
 if p_avatar is null or p_avatar not in('maroon','gold','sage','sky','violet','coral','slate','rose')then raise exception 'invalid:Choose an avatar.';end if;
 if exists(select 1 from community_private.identities where room=p_room and lower(alias)=lower(value_alias)and member<>p_member)then raise exception 'alias_taken:That username is already used in this group. Choose another.';end if;
 insert into community_private.identities(room,member,alias,avatar)values(p_room,p_member,value_alias,p_avatar)
 on conflict(room,member)do update set alias=excluded.alias,avatar=excluded.avatar;
end $$;
create function community_private.display_name(p_room text,p_member uuid)returns text language sql stable security invoker set search_path=''as $$
 select coalesce((select i.alias from community_private.identities i join social_private.room_members rm on rm.room=i.room and rm.member=i.member where i.room=p_room and i.member=p_member and rm.status='accepted'),'Former member')
$$;
create function community_private.roster(p_me uuid,p_room text)returns jsonb language sql stable security invoker set search_path=''as $$
 select case when exists(select 1 from social_private.room_members where room=p_room and member=p_me and status='accepted')then
 coalesce((select jsonb_agg(jsonb_build_object('alias',i.alias,'username',i.alias,'member_key',i.member_key,'memberKey',i.member_key,'avatar',i.avatar,'is_me',i.member=p_me,'isMe',i.member=p_me,'role',rm.role,'status',rm.status)order by rm.role desc,lower(i.alias))
 from social_private.room_members rm join community_private.identities i on i.room=rm.room and i.member=rm.member join social_private.members m on m.id=rm.member
 where rm.room=p_room and rm.status='accepted'and not m.banned and not social_private.blocked(p_me,rm.member)),'[]'::jsonb)else '[]'::jsonb end
$$;
create or replace function community_private.summary(p_me uuid,p_room text)returns jsonb language sql stable security invoker set search_path=''as $$
 select jsonb_build_object('id',r.id,'title',r.title,'description',c.description,'category',c.category,'avatar',c.avatar,'capacity',c.capacity,
 'member_count',(select count(*)from social_private.room_members where room=r.id and status='accepted'),
 'joined',coalesce(mine.status='accepted',false),'invited',coalesce(mine.status='invited',false),'owner',coalesce(mine.status='accepted'and mine.role='owner',false),
 'my_alias',identity.alias,'my_avatar',identity.avatar,'closed',r.status<>'active','is_public',c.is_public,
 'invite_code',case when mine.status='accepted'and mine.role='owner'then c.invite_code else null end,'created_at',extract(epoch from c.created_at))
 from community_private.communities c join social_private.rooms r on r.id=c.room
 left join social_private.room_members mine on mine.room=r.id and mine.member=p_me
 left join community_private.identities identity on identity.room=r.id and identity.member=p_me where c.room=p_room
$$;

-- Every route, including old group.accept, must establish a chosen identity.
do $patch$declare d text;n text;begin
 d:=pg_get_functiondef('community_private.membership_guard()'::regprocedure);
 n:=' if new.status not in(''accepted'',''invited'')then return new;end if;';
 if strpos(d,n)=0 then raise exception 'Membership identity guard patch missing';end if;
 execute replace(d,n,n||E'\n if new.status=''accepted''and not exists(select 1 from community_private.identities where room=new.room and member=new.member)then raise exception ''identity_required:Choose your group username and avatar first.'';end if;');
end $patch$;
create or replace function community_private.owner_leaving()returns trigger language plpgsql security invoker set search_path=''as $$begin
 if old.role='owner'and exists(select 1 from community_private.communities where room=old.room)then
  update social_private.rooms set status='closed'where id=old.room;
  update social_private.room_members set status='declined',typing_until=null where room=old.room and status='invited';
 end if;return old;end $$;

create or replace function community_private.owner_suspended()returns trigger language plpgsql security invoker set search_path=''as $$begin
 if new.banned and not old.banned then
  update social_private.rooms r set status='closed'where exists(select 1 from community_private.communities c join social_private.room_members rm on rm.room=c.room where c.room=r.id and rm.member=new.id and rm.role='owner');
  update social_private.room_members rm set status='declined',typing_until=null,joined_at=now()where rm.status='invited'and exists(select 1 from social_private.room_members own join community_private.communities c on c.room=own.room where own.room=rm.room and own.member=new.id and own.role='owner');
 end if;return new;end $$;

-- Apply owner restrictions to groups that predate these triggers, too.
delete from social_private.room_members victim using community_private.communities c,social_private.room_members owner
where victim.room=c.room and owner.room=c.room and owner.role='owner'and owner.status='accepted'and victim.role<>'owner'and social_private.blocked(owner.member,victim.member);
update social_private.rooms r set status='closed'where exists(select 1 from community_private.communities c join social_private.room_members rm on rm.room=c.room join social_private.members m on m.id=rm.member where c.room=r.id and rm.role='owner'and m.banned);
update social_private.room_members rm set status='declined',typing_until=null,joined_at=now()where rm.status='invited'and exists(select 1 from social_private.rooms r join community_private.communities c on c.room=r.id where r.id=rm.room and r.status='closed');

create or replace function public.communities_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;rid text;other uuid;owner_id uuid;is_owner boolean;joined boolean;membership text;value_name text;value_description text;value_category text;value_avatar text;value_alias text;member_avatar text;reason text;n uuid;result jsonb;page jsonb;query_value text;offset_value integer;attempt_count integer;public_value boolean;raw_error text;code text;current_room social_private.rooms;prior community_private.communities;newly_joined boolean;
begin
 me:=social_private.require_member(p_hash);
 if p_action in('create','join','join_code','accept','profile')and(jsonb_typeof(p_input->'alias')is distinct from 'string'or jsonb_typeof(p_input->'member_avatar')is distinct from 'string')then raise exception 'invalid:Choose your group username and avatar.';end if;
 if p_action='list'then
  query_value:=left(btrim(coalesce(p_input->>'search','')),80);offset_value:=least(10000,greatest(0,coalesce((p_input->>'offset')::integer,0)));
  select coalesce(jsonb_agg(value order by joined_order desc,sort_name,id),'[]')into page from(
   select community_private.summary(me,c.room)value,exists(select 1 from social_private.room_members mine where mine.room=c.room and mine.member=me and mine.status='accepted')joined_order,lower(r.title)sort_name,r.id
   from community_private.communities c join social_private.rooms r on r.id=c.room where r.kind='group'and r.status='active'
   and exists(select 1 from social_private.room_members own join social_private.members m on m.id=own.member where own.room=c.room and own.role='owner'and own.status='accepted'and not m.banned and not social_private.blocked(me,own.member))
   and(c.is_public or exists(select 1 from social_private.room_members mine where mine.room=c.room and mine.member=me and mine.status='accepted'))
   and not exists(select 1 from community_private.bans where room=c.room and member=me)
   and(query_value=''or strpos(lower(r.title||' '||c.description),lower(query_value))>0)
   and(coalesce(p_input->>'category','All')='All'or c.category=p_input->>'category')
   and(not coalesce((p_input->>'joined_only')::boolean,false)or exists(select 1 from social_private.room_members mine where mine.room=c.room and mine.member=me and mine.status='accepted'))
   order by joined_order desc,sort_name,r.id offset offset_value limit 51)rows;
  return jsonb_build_object('communities',case when jsonb_array_length(page)>50 then page-50 else page end,'has_more',jsonb_array_length(page)>50);
 end if;
 if p_action in('create','update')then
  value_name:=btrim(coalesce(p_input->>'title',''));value_description:=btrim(coalesce(p_input->>'description',''));value_category:=p_input->>'category';value_avatar:=coalesce(p_input->>'avatar','maroon');
  if jsonb_typeof(p_input->'title')is distinct from 'string'or jsonb_typeof(p_input->'description')is distinct from 'string'or length(value_name)not between 3 and 60 or length(value_description)not between 10 and 500 or value_category is null or value_category not in('Class','Major','Dorm or House','Study Group','Friends','People on app','Other')then raise exception 'invalid:Choose a 3–60 character name, a 10–500 character description and a category.';end if;
  if value_avatar not in('maroon','gold','sage','sky','violet','coral','slate','rose')then raise exception 'invalid:Choose a group avatar.';end if;
 end if;
 if p_action='create'then
  n:=(p_input->>'nonce')::uuid;if n is null then raise exception 'invalid:Missing request identifier.';end if;
  if jsonb_typeof(p_input->'is_public')is distinct from 'boolean'then raise exception 'invalid:Choose public or private.';end if;
  public_value:=(p_input->>'is_public')::boolean;
  select *into prior from community_private.communities where creator=me and nonce=n;
  if prior.room is not null then
   select *into current_room from social_private.rooms where id=prior.room;
   if not exists(select 1 from social_private.room_members where room=prior.room and member=me and status='accepted')then raise exception 'forbidden:You no longer have access to this group.';end if;
   if current_room.title<>value_name or prior.description<>value_description or prior.category<>value_category or prior.avatar<>value_avatar or prior.is_public<>public_value then raise exception 'conflict:Retry the original group details with this request identifier.';end if;
   return jsonb_build_object('community',community_private.summary(me,prior.room),'room_id',prior.room,'members',community_private.roster(me,prior.room));
  end if;
  perform pg_advisory_xact_lock(hashtextextended(lower(value_name),710912));
  if public_value and exists(select 1 from community_private.communities c join social_private.rooms r on r.id=c.room where c.is_public and lower(r.title)=lower(value_name)and r.status='active')then raise exception 'conflict:A public group with that name already exists.';end if;
  if(select count(*)from community_private.communities where creator=me and created_at>now()-interval '1 day')>=3 then raise exception 'rate_limit:Create up to three groups per day.';end if;
  insert into social_private.rooms(kind,title,meta)values('group',value_name,'{"campusCommunity":true}')returning id into rid;
  insert into community_private.communities(room,creator,nonce,description,category,is_public,avatar)values(rid,me,n,value_description,value_category,public_value,value_avatar);
  perform community_private.set_identity(rid,me,p_input->>'alias',p_input->>'member_avatar');
  insert into social_private.room_members(room,member,role,status)values(rid,me,'owner','accepted');
 else
  rid:=p_input->>'room_id';
  if p_action='join_code'then
   insert into community_private.join_limits(member)values(me)on conflict do nothing;
   update community_private.join_limits set attempts=case when window_at<now()-interval '1 minute'then 1 else attempts+1 end,window_at=case when window_at<now()-interval '1 minute'then now()else window_at end where member=me returning attempts into attempt_count;
   if attempt_count>12 then return jsonb_build_object('error','Too many invite-code attempts. Try again in a minute.','code','rate_limit');end if;
   if coalesce(p_input->>'invite_code','')!~'^[A-Fa-f0-9]{10}$'then return jsonb_build_object('error','Enter the 10-character invitation code.','code','invalid');end if;
   select room into rid from community_private.communities where invite_code=upper(p_input->>'invite_code');
   if rid is null then return jsonb_build_object('error','That invitation is unavailable. Check the code with its owner.','code','unavailable');end if;
  end if;
  select r.*into current_room from social_private.rooms r join community_private.communities c on c.room=r.id where r.id=rid for update of r;
  if not found then raise exception 'unavailable:This group is unavailable.';end if;
  select member into owner_id from social_private.room_members where room=rid and role='owner'and status='accepted'limit 1;
  select status into membership from social_private.room_members where room=rid and member=me;
  is_owner:=coalesce(owner_id=me,false);joined:=coalesce(membership='accepted',false);
  if p_action='decline'then
   if membership='accepted'then raise exception 'conflict:Leave the group from its settings.';end if;
   if membership is null then raise exception 'unavailable:This invitation is unavailable.';end if;
   update social_private.room_members set status='declined',typing_until=null,joined_at=now()where room=rid and member=me and status='invited';
   return jsonb_build_object('declined',true,'room_id',rid);
  end if;
  if exists(select 1 from community_private.bans where room=rid and member=me)or social_private.blocked(me,owner_id)or exists(select 1 from social_private.members where id=owner_id and banned)then raise exception 'forbidden:This group is unavailable.';end if;
  if not joined and not coalesce(membership='invited',false)and exists(select 1 from community_private.communities where room=rid and not is_public)and p_action<>'join_code'then raise exception 'unavailable:Use an invitation to join this private group.';end if;
  if p_action='detail'then
   if not joined and(owner_id is null or current_room.status<>'active')then raise exception 'unavailable:This group is unavailable.';end if;
  elsif p_action in('join','join_code','accept')then
   if owner_id is null or current_room.status<>'active'then raise exception 'unavailable:This group is closed.';end if;
   if p_action='accept'and not joined and membership is distinct from 'invited'then raise exception 'forbidden:You have no invitation to this group.';end if;
   if p_action='join'and not joined and not(select is_public from community_private.communities where room=rid)then raise exception 'forbidden:Accept your invitation to join this private group.';end if;
   if not joined then perform community_private.set_identity(rid,me,p_input->>'alias',p_input->>'member_avatar');end if;
   insert into social_private.room_members(room,member,status,last_read)values(rid,me,'accepted',coalesce((select max(seq)from social_private.messages where room=rid),0))
   on conflict(room,member)do update set status='accepted',last_read=case when social_private.room_members.status='accepted'then social_private.room_members.last_read else excluded.last_read end;
  elsif p_action='profile'then
   if not joined then raise exception 'forbidden:Join this group before changing your profile.';end if;
   perform community_private.set_identity(rid,me,p_input->>'alias',p_input->>'member_avatar');
  elsif p_action='leave'then
   if is_owner and current_room.status='active'and exists(select 1 from social_private.room_members where room=rid and member<>me and status='accepted')then raise exception 'invalid:Transfer ownership or close the group before leaving.';end if;
   delete from social_private.room_members where room=rid and member=me;
   return jsonb_build_object('left',true,'room_id',rid);
  elsif p_action='report'then
   reason:=btrim(coalesce(p_input->>'reason',''));if length(reason)not between 3 and 500 then raise exception 'invalid:Add a short reason for your report.';end if;
   if not exists(select 1 from social_private.reports where reporter=me and target_type='room'and target_id=rid and status='pending')then
    insert into social_private.reports(reporter,target_type,target_id,reason,evidence)values(me,'room',rid,reason,jsonb_build_object('group',community_private.summary(me,rid)));end if;
   return jsonb_build_object('reported',true);
  else
   if not is_owner then raise exception 'forbidden:Only the group owner can do that.';end if;
   if p_action='update'then
    if current_room.status<>'active'then raise exception 'unavailable:This group is closed.';end if;
    if p_input?'is_public'and jsonb_typeof(p_input->'is_public')is distinct from 'boolean'then raise exception 'invalid:Choose public or private.';end if;
    public_value:=coalesce((p_input->>'is_public')::boolean,(select is_public from community_private.communities where room=rid));
    perform pg_advisory_xact_lock(hashtextextended(lower(value_name),710912));
    if public_value and exists(select 1 from community_private.communities c join social_private.rooms r on r.id=c.room where c.room<>rid and c.is_public and lower(r.title)=lower(value_name)and r.status='active')then raise exception 'conflict:A public group with that name already exists.';end if;
    update social_private.rooms set title=value_name where id=rid;
    update community_private.communities set description=value_description,category=value_category,avatar=value_avatar,is_public=public_value where room=rid;
   elsif p_action='rotate_code'then
    update community_private.communities set invite_code=upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,10))where room=rid;
   elsif p_action='close'then
    update social_private.rooms set status='closed'where id=rid;
    update social_private.room_members set status='declined',typing_until=null where room=rid and status='invited';
   elsif p_action='invite'then
    if current_room.status<>'active'then raise exception 'unavailable:This group is closed.';end if;
    value_name:=lower(ltrim(btrim(coalesce(p_input->>'username','')),'@'));
    if value_name!~'^[a-z0-9_]{3,20}$'then raise exception 'invalid:Enter a valid account username.';end if;
    select id into other from social_private.members where username=value_name and id<>me and not banned;
    if other is null or social_private.blocked(me,other)or exists(select 1 from community_private.bans where room=rid and member=other)then raise exception 'unavailable:That username cannot be invited. Check the username and try again.';end if;
    if not exists(select 1 from social_private.room_members where room=rid and member=other and status in('accepted','invited'))then
     if(select count(*)from social_private.room_members where room=rid and status in('accepted','invited'))>=(select capacity from community_private.communities where room=rid)then raise exception 'full:This group has no open invitation slots.';end if;
     if exists(select 1 from social_private.room_members where room=rid and member=other and status='declined'and joined_at>now()-interval '24 hours')then raise exception 'rate_limit:Wait 24 hours before inviting this person again.';end if;
     insert into community_private.invitations(room,member)values(rid,other)on conflict(room,member)do update set invitation_key=gen_random_uuid();
     insert into social_private.room_members(room,member,status)values(rid,other,'invited')on conflict(room,member)do update set status='invited',joined_at=now();
    end if;
    return jsonb_build_object('invited',true,'room_id',rid);
   elsif p_action='revoke'then
    select member into other from community_private.invitations where room=rid and invitation_key=(p_input->>'invitation_key')::uuid;
    if other is null then raise exception 'invalid:Choose a pending invitation.';end if;
    if exists(select 1 from social_private.room_members where room=rid and member=other and status='accepted')then raise exception 'conflict:That person has already joined. Use Remove member.';end if;
    update social_private.room_members set status='declined',typing_until=null,joined_at=now()where room=rid and member=other and status='invited';
   elsif p_action in('remove','ban','unban','transfer')then
    select member into other from community_private.identities where room=rid and member_key=(p_input->>'member_key')::uuid;
    if other is null or other=me then raise exception 'invalid:Choose another group member.';end if;
    if p_action='unban'then delete from community_private.bans where room=rid and member=other;
    else
     if not exists(select 1 from social_private.room_members where room=rid and member=other and status='accepted')then raise exception 'invalid:That person is not a current member.';end if;
     if p_action='transfer'then
      if exists(select 1 from social_private.members where id=other and banned)or social_private.blocked(me,other)then raise exception 'invalid:Choose an available member.';end if;
      update social_private.room_members set role=case when member=other then 'owner'else 'member'end where room=rid and member in(me,other);
      delete from social_private.room_members where room=rid and member<>other and social_private.blocked(other,member);
     else
      if p_action='ban'then insert into community_private.bans(room,member)values(rid,other)on conflict do nothing;end if;
      delete from social_private.room_members where room=rid and member=other;
     end if;
    end if;
   else raise exception 'invalid:Unknown group action.';end if;
  end if;
 end if;
 result:=jsonb_build_object('community',community_private.summary(me,rid),'room_id',rid,'members',community_private.roster(me,rid));
 if exists(select 1 from social_private.room_members where room=rid and member=me and role='owner'and status='accepted')then
  result:=result||jsonb_build_object('pending',coalesce((select jsonb_agg(jsonb_build_object('username',m.username,'invitation_key',i.invitation_key)order by rm.joined_at)from community_private.invitations i join social_private.room_members rm on rm.room=i.room and rm.member=i.member join social_private.members m on m.id=i.member where i.room=rid and rm.status='invited'),'[]'),'bans',coalesce((select jsonb_agg(jsonb_build_object('alias',i.alias,'username',i.alias,'member_key',i.member_key,'avatar',i.avatar,'is_me',false,'role','banned'))from community_private.bans b join community_private.identities i on i.room=b.room and i.member=b.member where b.room=rid),'[]'));
 end if;
 return result;
exception when raise_exception then raw_error:=sqlerrm;code:=split_part(raw_error,':',1);return jsonb_build_object('error',substr(raw_error,length(code)+2),'code',code);
 when unique_violation then return jsonb_build_object('error','That group username or name is already in use. Choose another.','code','conflict');
 when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Check the group details and try again.','code','invalid');
end $$;

-- Snapshot decoration replaces every group identity projection, leaving course,
-- activity, organization and direct-conversation behavior unchanged.
create function community_private.decorate_snapshot(p_me uuid,p_snapshot jsonb)returns jsonb language plpgsql stable security invoker set search_path=''as $$
declare result jsonb:=p_snapshot;begin
 result:=jsonb_set(result,'{conversationMeta}',coalesce((select jsonb_agg(case when entry->>'kind'='group'then entry||jsonb_build_object(
  'members',community_private.roster(p_me,entry->>'id'),
  'avatar',(select avatar from community_private.communities where room=entry->>'id'),
  'category',(select category from community_private.communities where room=entry->>'id'),
  'myAlias',(select alias from community_private.identities where room=entry->>'id'and member=p_me),
  'myAvatar',(select avatar from community_private.identities where room=entry->>'id'and member=p_me),
  'unread',case when exists(select 1 from social_private.room_members where room=entry->>'id'and member=p_me and status='accepted')then entry->'unread'else '0'::jsonb end,
  'typing',case when exists(select 1 from social_private.room_members where room=entry->>'id'and member=p_me and status='accepted')then coalesce((select jsonb_agg(i.alias)
   from social_private.room_members t join community_private.identities i on i.room=t.room and i.member=t.member join social_private.members account on account.id=t.member
   where t.room=entry->>'id'and t.member<>p_me and t.status='accepted'and t.typing_until>now()and not account.banned and not social_private.blocked(p_me,t.member)),'[]')else '[]'::jsonb end)
 else entry end order by ordinal)from jsonb_array_elements(p_snapshot->'conversationMeta')with ordinality x(entry,ordinal)),'[]'));
 return result;
end $$;
do $patch$declare d text;n text;replacement text;begin
 d:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 n:=' return result;';if strpos(d,n)=0 then raise exception 'Snapshot group projection target missing';end if;
 execute replace(d,n,' return community_private.decorate_snapshot(p_me,result);');
 d:=pg_get_functiondef('social_private.message_list(uuid,text)'::regprocedure);
 n:='when m.deleted or u.id is null then ''[deleted]''';
 if strpos(d,n)=0 then raise exception 'Message author target missing';end if;
 d:=replace(d,n,n||' when r.kind=''group''then community_private.display_name(r.id,m.author)');
 n:='''text'',case when m.deleted then ''[Message deleted]'' else m.body end';
 if strpos(d,n)=0 then raise exception 'Message game-body target missing';end if;
 d:=replace(d,n,'''text'',case when m.deleted then ''[Message deleted]'' when r.kind=''group''and m.game_session_id is not null then ''Game invitation. Open to view the players and respond.'' else m.body end');
 n:='''created'',extract(epoch from m.created_at)';
 if strpos(d,n)=0 then raise exception 'Message group avatar target missing';end if;
 execute replace(d,n,'''avatar'',case when r.kind=''group''and not m.deleted then(select i.avatar from community_private.identities i join social_private.room_members rm on rm.room=i.room and rm.member=i.member where i.room=r.id and i.member=m.author and rm.status=''accepted'')else null end,''memberKey'',case when r.kind=''group''and not m.deleted then(select i.member_key from community_private.identities i join social_private.room_members rm on rm.room=i.room and rm.member=i.member where i.room=r.id and i.member=m.author and rm.status=''accepted'')else null end,'||n);
 d:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 n:=' if p_action=''snapshot'' then null;';
 if strpos(d,n)=0 then raise exception 'Legacy group dispatch target missing';end if;
 replacement:=$route$ if p_action in('group.create','group.invite','group.accept','group.decline','group.remove','group.transfer','group.leave')or(p_action='room.leave'and exists(select 1 from social_private.rooms where id=room_id and kind='group'))then
  evidence:=public.communities_gateway(case when p_action='room.leave'then 'leave'else split_part(p_action,'.',2)end,p_hash,p_input);
  if evidence?'error'then return evidence;end if;
  return evidence||jsonb_build_object('snapshot',social_private.snapshot(me),'resource_id',evidence->>'room_id');
 end if;
 if p_action='snapshot' then null;$route$;
 execute replace(d,n,replacement);
end $patch$;

-- Preserve DM player aliases and use scoped group identities for game cards,
-- state, replay and the explicit target of an invitation.
do $patch$declare d text;n text;replacement text;begin
 d:=pg_get_functiondef('games_private.snapshot(games_private.sessions,uuid,boolean)'::regprocedure);
 n:='case when r.anonymous then ''Player 1'' else a.username end,case when r.anonymous then ''Player 2'' else b.username end';
 if strpos(d,n)=0 then raise exception 'Game player alias target missing';end if;
 execute replace(d,n,'case when r.kind=''group''then community_private.display_name(r.id,a.id)when r.anonymous then ''Player 1'' else a.username end,case when r.kind=''group''then community_private.display_name(r.id,b.id)when r.anonymous then ''Player 2'' else b.username end');
 d:=pg_get_functiondef('public.games_gateway(text,text,jsonb)'::regprocedure);
 n:='not exists(select 1 from social_private.members where id=g.opponent and username=lower(btrim(coalesce(p_input->>''opponent_username'',''''))))';
 if strpos(d,n)=0 then raise exception 'Game idempotent opponent target missing';end if;
 d:=replace(d,n,'not exists(select 1 from community_private.identities where room=g.room and member=g.opponent and member_key=(p_input->>''opponent_member_key'')::uuid)');
 n:=$old$   opponent_name:=lower(btrim(coalesce(p_input->>'opponent_username','')));
   if opponent_name !~ '^[a-z0-9_]{3,20}$' then raise exception 'invalid:Choose a current group member to invite.';end if;
   select rm.member into other from social_private.room_members rm join social_private.members m on m.id=rm.member where rm.room=room_id and rm.member<>me and rm.status='accepted'and m.username=opponent_name;$old$;
 if strpos(d,n)=0 then raise exception 'Game chosen group opponent target missing';end if;
 replacement:=$new$   select rm.member,i.alias into other,opponent_name from social_private.room_members rm join community_private.identities i on i.room=rm.room and i.member=rm.member
   where rm.room=room_id and rm.member<>me and rm.status='accepted'and i.member_key=(p_input->>'opponent_member_key')::uuid;
   if other is null then raise exception 'invalid:Choose a current group member to invite.';end if;$new$;
 execute replace(d,n,replacement);
end $patch$;

do $patch$declare d text;n text;begin
 d:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 n:='r.title,c.description,c.category,c.is_public,c.capacity,r.status,rm.role,rm.joined_at';
 if strpos(d,n)=0 then raise exception 'Group export target missing';end if;
 execute replace(d,n,n||',c.avatar,(select alias from community_private.identities where room=r.id and member=me)as my_alias,(select avatar from community_private.identities where room=r.id and member=me)as my_avatar,(select member_key from community_private.identities where room=r.id and member=me)as my_member_key');
end $patch$;

revoke all on all functions in schema community_private from public,anon,authenticated;
grant execute on all functions in schema community_private to service_role;
revoke all on function public.communities_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.communities_gateway(text,text,jsonb)to service_role;
