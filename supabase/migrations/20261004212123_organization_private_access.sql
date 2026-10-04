-- Private, explicitly accepted administrator access. Public organization cards stay unchanged.
create schema if not exists organization_private;
revoke all on schema organization_private from public,anon,authenticated;
grant usage on schema organization_private to service_role;
update social_private.organization_admins a set role='owner' where (select count(*) from social_private.organization_admins b where b.organization=a.organization)=1;
alter table social_private.organization_admins add constraint organization_admin_role check(role in('owner','admin'));
create unique index organization_one_owner on social_private.organization_admins(organization) where role='owner';
create table organization_private.identities(
 organization uuid not null,member uuid not null,member_key uuid not null default gen_random_uuid(),
 primary key(organization,member),unique(organization,member_key),
 foreign key(organization,member)references social_private.organization_admins(organization,member)on delete cascade
);
insert into organization_private.identities(organization,member)select organization,member from social_private.organization_admins;
create table organization_private.invitations(
 id uuid primary key default gen_random_uuid(),organization uuid not null references social_private.organizations on delete cascade,
 issuer uuid references social_private.members on delete set null,target uuid not null references social_private.members on delete cascade,
 kind text not null check(kind in('admin','ownership')),status text not null default 'pending' check(status in('pending','accepted','declined','revoked','expired')),
 nonce uuid not null,created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '7 days',
 unique(organization,issuer,nonce)
);
create index organization_invitation_recipient on organization_private.invitations(target,status);
create index organization_invitation_issuer on organization_private.invitations(issuer);
create unique index organization_pending_invite on organization_private.invitations(organization,target,kind)where status='pending';
create unique index organization_pending_handoff on organization_private.invitations(organization)where status='pending'and kind='ownership';
alter table organization_private.identities enable row level security;
alter table organization_private.invitations enable row level security;
create policy service_only on organization_private.identities to service_role using(true)with check(true);
create policy service_only on organization_private.invitations to service_role using(true)with check(true);
grant all on all tables in schema organization_private to service_role;
revoke all on all tables in schema organization_private from public,anon,authenticated;
create function organization_private.admin_added()returns trigger language plpgsql set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization::text,938));
 if not exists(select 1 from social_private.organization_admins where organization=new.organization)then new.role:='owner';end if;
 return new;
end $$;
create trigger organization_first_owner before insert on social_private.organization_admins for each row execute function organization_private.admin_added();
create function organization_private.admin_identity()returns trigger language plpgsql set search_path='' as $$
begin insert into organization_private.identities(organization,member)values(new.organization,new.member)on conflict do nothing;return new;end $$;
create trigger organization_admin_identity after insert on social_private.organization_admins for each row execute function organization_private.admin_identity();
-- Removing an administrator revokes their private organization conversation access.
-- Historical customer conversations are closed, never silently handed to another admin.
create function organization_private.admin_removed()returns trigger language plpgsql set search_path='' as $$
begin
 update organization_private.invitations set status='revoked' where organization=old.organization and status='pending'and(target=old.member or issuer=old.member);
 update social_private.rooms r set status='closed' where r.kind='dm' and r.meta->>'organization'=old.organization::text and exists(select 1 from social_private.room_members rm where rm.room=r.id and rm.member=old.member and rm.role='owner');
 delete from social_private.room_members rm using social_private.rooms r where rm.room=r.id and rm.member=old.member and rm.role='owner'and r.meta->>'organization'=old.organization::text;
 if old.role='owner'and not exists(select 1 from social_private.organization_admins where organization=old.organization and role='owner')then
  update social_private.organizations set status='suspended' where id=old.organization;
 end if;
 return old;
end $$;
create trigger organization_admin_removed after delete on social_private.organization_admins for each row execute function organization_private.admin_removed();
create function public.organization_access(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql set search_path='' as $$
declare me uuid; oid uuid; org social_private.organizations; inv organization_private.invitations; current_owner uuid; target_id uuid; my_role text; kind_value text; username_value text; nonce_value uuid; result jsonb;
begin
 me:=case when p_action in('invite','accept')then social_private.require_member(p_hash)else social_private.require_account(p_hash)end;
 if p_action='incoming'then
  return jsonb_build_object('invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'organizationID',o.id,'organizationName',o.name,'kind',i.kind,'expiresAt',extract(epoch from i.expires_at))order by i.created_at desc)
   from organization_private.invitations i join social_private.organizations o on o.id=i.organization join social_private.organization_admins a on a.organization=i.organization and a.member=i.issuer and a.role='owner' join social_private.members m on m.id=i.issuer
   where i.target=me and i.status='pending'and i.expires_at>now()and o.status='verified'and not m.banned and not social_private.blocked(me,i.issuer)),'[]'::jsonb));
 end if;
 if p_action in('accept','decline')then select organization into oid from organization_private.invitations where id=(p_input->>'invitation_id')::uuid and target=me;
 else oid:=(p_input->>'organization_id')::uuid;end if;
 if oid is null then raise exception 'forbidden:This organization invitation is unavailable.';end if;
 perform pg_advisory_xact_lock(hashtextextended(oid::text,938));
 select * into org from social_private.organizations where id=oid;
 select member into current_owner from social_private.organization_admins where organization=oid and role='owner';
 select role into my_role from social_private.organization_admins where organization=oid and member=me;
 if p_action='get'then
  if my_role is null then raise exception 'forbidden:Administrator access is no longer available.';end if;
  return jsonb_build_object('organizationID',org.id,'organizationName',org.name,'status',org.status,'myRole',my_role,'hasOwner',current_owner is not null,
   'administrators',case when my_role='owner'then coalesce((select jsonb_agg(jsonb_build_object('id',i.member_key,'username',m.username,'role',a.role,'isMe',a.member=me)order by a.role desc,m.username)from social_private.organization_admins a join social_private.members m on m.id=a.member join organization_private.identities i using(organization,member)where a.organization=oid),'[]'::jsonb)else '[]'::jsonb end,
   'pending',case when my_role='owner'then coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'username',m.username,'kind',i.kind,'expiresAt',extract(epoch from i.expires_at))order by i.created_at)from organization_private.invitations i join social_private.members m on m.id=i.target where i.organization=oid and i.status='pending'and i.expires_at>now()),'[]'::jsonb)else '[]'::jsonb end);
 elsif p_action in('accept','decline')then
  select * into inv from organization_private.invitations where id=(p_input->>'invitation_id')::uuid and target=me for update;
  if p_action='decline'and inv.status='declined'then return jsonb_build_object('changed',true);end if;
  if p_action='accept'and inv.status='accepted'and my_role is not null then return jsonb_build_object('changed',true);end if;
  if inv.status<>'pending'or inv.expires_at<=now()then raise exception 'forbidden:This invitation is no longer available.';end if;
  if p_action='decline'then update organization_private.invitations set status='declined'where id=inv.id;return jsonb_build_object('changed',true);end if;
  if org.status<>'verified'or current_owner is distinct from inv.issuer or social_private.blocked(me,inv.issuer)or exists(select 1 from social_private.members where id=inv.issuer and banned)then raise exception 'forbidden:This invitation is no longer available.';end if;
  if inv.kind='admin'then
   if(select count(*)from social_private.organization_admins where organization=oid)>=10 and my_role is null then raise exception 'full:This organization already has ten administrators.';end if;
   insert into social_private.organization_admins values(oid,me,'admin')on conflict do nothing;
  else
   if my_role is distinct from 'admin'then raise exception 'forbidden:Accept administrator access before receiving ownership.';end if;
   update social_private.organization_admins set role='admin'where organization=oid and member=current_owner;
   update social_private.organization_admins set role='owner'where organization=oid and member=me;
   update organization_private.invitations set status='revoked'where organization=oid and status='pending'and id<>inv.id;
  end if;
  update organization_private.invitations set status='accepted'where id=inv.id;
 elsif p_action='leave'then
  if my_role='owner'then raise exception 'invalid:Transfer ownership before leaving.';end if;
  delete from social_private.organization_admins where organization=oid and member=me;
 elsif p_action in('invite','revoke','remove')then
  if current_owner is distinct from me then raise exception 'forbidden:Only the organization owner can manage administrator access.';end if;
  if p_action='invite'then
   if org.status<>'verified'then raise exception 'forbidden:The organization must be verified before inviting administrators.';end if;
   username_value:=lower(btrim(coalesce(p_input->>'username','')));kind_value:=p_input->>'kind';nonce_value:=(p_input->>'nonce')::uuid;
   if username_value!~'^[a-z0-9_]{3,20}$'or kind_value not in('admin','ownership')or kind_value is null or nonce_value is null then raise exception 'invalid:Choose a username and invitation type.';end if;
   select id into target_id from social_private.members where username=username_value and not banned;
   if target_id is null or target_id=me or social_private.blocked(me,target_id)then raise exception 'forbidden:This account cannot receive the invitation.';end if;
   select *into inv from organization_private.invitations where organization=oid and issuer=me and nonce=nonce_value;
   if inv.id is not null then
    if inv.target<>target_id or inv.kind<>kind_value then raise exception 'invalid:This invitation draft has already been used.';end if;
    return jsonb_build_object('changed',true,'invitationID',inv.id);
   end if;
   if(kind_value='admin'and exists(select 1 from social_private.organization_admins where organization=oid and member=target_id))or(kind_value='ownership'and not exists(select 1 from social_private.organization_admins where organization=oid and member=target_id and role='admin'))then raise exception 'invalid:Ownership can only be offered to an accepted administrator; existing administrators do not need another invitation.';end if;
   update organization_private.invitations set status='expired'where organization=oid and status='pending'and expires_at<=now();
   if(select count(*)from organization_private.invitations where organization=oid and created_at>now()-interval '1 day')>=20 then raise exception 'rate_limit:Invitation limit reached. Try again tomorrow.';end if;
   if kind_value='admin'and(select count(*)from social_private.organization_admins where organization=oid)+(select count(*)from organization_private.invitations where organization=oid and kind='admin'and status='pending')>=10 then raise exception 'full:There are already ten administrators or pending invitations.';end if;
   if exists(select 1 from organization_private.invitations where organization=oid and status='pending'and((target=target_id and kind=kind_value)or(kind='ownership'and kind_value='ownership')))then raise exception 'invalid:Revoke the existing invitation before sending another.';end if;
   insert into organization_private.invitations(organization,issuer,target,kind,nonce)values(oid,me,target_id,kind_value,nonce_value)returning *into inv;
   return jsonb_build_object('changed',true,'invitationID',inv.id);
  elsif p_action='revoke'then update organization_private.invitations set status='revoked'where id=(p_input->>'invitation_id')::uuid and organization=oid and status='pending';
  else
   select member into target_id from organization_private.identities where organization=oid and member_key=(p_input->>'administrator_key')::uuid;
   if target_id=me then raise exception 'invalid:Transfer ownership before leaving.';end if;
   delete from social_private.organization_admins where organization=oid and member=target_id and role='admin';
  end if;
 else raise exception 'invalid:Unknown administrator action.';end if;
 return jsonb_build_object('changed',true);
exception when others then
 if sqlerrm ~ '^(forbidden|unauthorized|invalid|full|rate_limit):'then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));end if;
 return jsonb_build_object('error','Administrator access could not be updated. Please try again.','code','invalid');
end $$;
revoke all on all functions in schema organization_private from public,anon,authenticated;
grant execute on all functions in schema organization_private to service_role;
revoke all on function public.organization_access(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.organization_access(text,text,jsonb)to service_role;
-- Patch the current gateway, preserving all previous cohort/media/poll wrappers.
do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='nonce_value:=coalesce((p_input->>''nonce'')::uuid,gen_random_uuid());';
 replacement:=old||$code$
 -- Share the organization access lock before touching activities or rooms.
 if p_action in('organization.publish','organization.update','organization.message')or(p_action='activity.create'and p_input->>'kind'='Organizations')then
  perform pg_advisory_xact_lock(hashtextextended(p_input->>'organization_id',938));
 elsif p_action in('activity.edit','activity.approve','activity.cancel')then
  perform pg_advisory_xact_lock(hashtextextended(r.meta->>'organization',938))from social_private.activities a join social_private.rooms r on r.id=a.room where a.id=(p_input->>'activity_id')::uuid and r.meta?'organization';
 end if;
$code$;
 if strpos(def,old)=0 then raise exception 'gateway lock anchor missing';end if;def:=replace(def,old,replacement);
 old:='r.meta?''organization'' and p_action not in(''activity.leave'',''activity.cancel'')';
 if strpos(def,old)=0 then raise exception 'activity access anchor missing';end if;
 def:=replace(def,old,'r.meta?''organization'' and p_action<>''activity.leave''');
 def:=replace(def,'p_action in(''activity.edit'',''activity.approve'') and not exists','p_action in(''activity.edit'',''activity.approve'',''activity.cancel'') and not exists');
 def:=replace(def,'if a.host<>me then raise exception ''forbidden:Only the host can manage this activity.''; end if;','if not(r.meta?''organization'')and a.host<>me then raise exception ''forbidden:Only the host can manage this activity.''; end if;');
 old:='rooms.kind=''dm''and rooms.meta->>''organization''=org.id::text and exists(select 1 from social_private.room_members where room=rooms.id and member=me)limit 1';
 replacement:='rooms.kind=''dm''and rooms.status<>''closed''and rooms.meta->>''organization''=org.id::text and exists(select 1 from social_private.room_members where room=rooms.id and member=me)and exists(select 1 from social_private.room_members rm join social_private.organization_admins oa on oa.member=rm.member and oa.organization=org.id where rm.room=rooms.id and rm.role=''owner'')limit 1';
 if strpos(def,old)=0 then raise exception 'organization conversation anchor missing';end if;def:=replace(def,old,replacement);
 execute def;
end $patch$;
