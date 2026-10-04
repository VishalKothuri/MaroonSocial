create table community_private.photos(
 room text not null references social_private.rooms(id) on delete cascade,
 subject text not null check(subject='group' or subject~'^[a-f0-9-]{36}$'),
 attachment uuid not null unique references social_private.attachments(id) on delete cascade,
 primary key(room,subject)
);
alter table community_private.photos enable row level security;
revoke all on community_private.photos from public,anon,authenticated;
grant all on community_private.photos to service_role;

create or replace function public.group_photo_gateway(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare me uuid; rid text:=p_input->>'room_id'; scope_value text:=p_input->>'scope'; subject_value text; mine_key uuid; result jsonb; a social_private.attachments; old_id uuid; old_path text;
begin
 me:=social_private.require_member(p_hash);
 if scope_value not in('group','member') or scope_value is null then raise exception 'invalid:Choose a group photo.';end if;
 result:=public.communities_gateway('detail',p_hash,jsonb_build_object('room_id',rid));
 if result?'error' then return result;end if;
 if scope_value='group' then subject_value:='group';
 else
  if not social_private.can_read_room(me,rid) or not exists(select 1 from social_private.room_members where room=rid and member=me and status='accepted') then raise exception 'forbidden:Join this group to see member photos.';end if;
  select member_key into mine_key from community_private.identities where room=rid and member=me;
  subject_value:=case when p_input->>'member_key' is null or p_input->>'member_key'='self' then mine_key::text else (p_input->>'member_key')::uuid::text end;
  if not exists(select 1 from community_private.identities i join social_private.room_members r on r.room=i.room and r.member=i.member where i.room=rid and i.member_key::text=subject_value and r.status='accepted' and not social_private.blocked(me,i.member))then raise exception 'forbidden:This group identity is unavailable.';end if;
 end if;
 if p_action='read' then
  select att.* into a from community_private.photos p join social_private.attachments att on att.id=p.attachment where p.room=rid and p.subject=subject_value and att.ready;
  if a.id is null then return jsonb_build_object('has_photo',false);end if;
  return jsonb_build_object('has_photo',true,'path',a.path,'mime',a.mime,'attachment_id',a.id);
 end if;
 if not social_private.can_message(me,rid) then raise exception 'forbidden:This group is not open for changes.';end if;
 if scope_value='group' and not exists(select 1 from social_private.room_members where room=rid and member=me and role='owner' and status='accepted')then raise exception 'forbidden:Only the owner may change the group photo.';end if;
 if scope_value='member' and subject_value is distinct from mine_key::text then raise exception 'forbidden:Only change your own group photo.';end if;
 perform pg_advisory_xact_lock(hashtextextended('group-photo:'||rid||':'||subject_value,0));
 if p_action='authorize' then return jsonb_build_object('authorized',true);
 elsif p_action='reserve' then
  if p_input->>'path' !~ '^[a-f0-9-]{36}\.jpg$' or coalesce((p_input->>'size')::integer,0) not between 1 and 350000 then raise exception 'invalid:Choose a small JPEG photo.';end if;
  if(select count(*)from social_private.attachments where owner=me and created_at>now()-interval '1 hour')>=30 then raise exception 'rate_limit:Upload limit reached. Please try later.';end if;
  insert into social_private.attachments(owner,room,kind,mime,size,path)values(me,rid,'image','image/jpeg',(p_input->>'size')::integer,p_input->>'path')returning * into a;
  return jsonb_build_object('attachment_id',a.id,'path',a.path);
 elsif p_action='commit' then
  select * into a from social_private.attachments where id=(p_input->>'attachment_id')::uuid for update;
  if a.id is null or a.owner is distinct from me or a.room is distinct from rid or a.message is not null or a.post is not null or a.kind<>'image' or a.mime<>'image/jpeg' or a.external_source is not null then raise exception 'forbidden:This upload cannot be a group photo.';end if;
  select p.attachment into old_id from community_private.photos p where p.room=rid and p.subject=subject_value;
  if exists(select 1 from community_private.photos where attachment=a.id and (room<>rid or subject<>subject_value))then raise exception 'forbidden:Choose a separate photo for each group identity.';end if;
  update social_private.attachments set ready=true where id=a.id;
  insert into community_private.photos(room,subject,attachment)values(rid,subject_value,a.id)on conflict(room,subject)do update set attachment=excluded.attachment;
 elsif p_action='remove' then
  delete from community_private.photos where room=rid and subject=subject_value returning attachment into old_id;
 else raise exception 'invalid:Unknown group photo action.';
 end if;
 if old_id is not null and old_id is distinct from a.id then
  delete from social_private.attachments where id=old_id returning path into old_path;
  if old_path is not null then insert into social_private.storage_deletions(path)values(old_path)on conflict do nothing;end if;
 end if;
 return jsonb_build_object('saved',true,'attachment_id',a.id);
exception when others then
 if position(':'in sqlerrm)>0 then return jsonb_build_object('code',split_part(sqlerrm,':',1),'error',substring(sqlerrm from position(':'in sqlerrm)+1));end if;
 return jsonb_build_object('code','invalid','error','This group photo could not be saved.');
end $$;
revoke all on function public.group_photo_gateway(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.group_photo_gateway(text,text,jsonb) to service_role;

-- Retain the caller's selected feed through the existing external-media reserve.
do $$declare source text;needle text;begin
 select pg_get_functiondef('public.social_external_media(text,text,jsonb)'::regprocedure)into source;
 needle:='jsonb_build_object(''room_id'',room_id,''post_id'',post_id,''path'',''external/''';
 if position(needle in source)>0 then source:=replace(source,needle,'jsonb_build_object(''feed_community'',p_input->>''feed_community'',''room_id'',room_id,''post_id'',post_id,''path'',''external/''');execute source;end if;
end $$;
