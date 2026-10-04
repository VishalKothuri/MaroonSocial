-- Rollback suite for private organization administrator access (public.organization_access).
-- Run the whole file through the database connector; every fixture row is rolled back.
begin;
set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;o uuid;r jsonb;inv uuid;handoff uuid;to_a uuid;to_c uuid;room_id text;akey uuid;ub text;uc text;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'oadm_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'oadm_'||substr(hb,1,8),true,hb)returning id,username into b,ub;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'oadm_'||substr(hc,1,8),true,hc)returning id,username into c,uc;
 insert into social_private.organizations(name,about,status)values('Rollback org admins','Testing','verified')returning id into o;
 insert into social_private.organization_admins(organization,member,role)values(o,a,'admin');
 if(select role from social_private.organization_admins where organization=o and member=a)<>'owner'then raise exception 'First administrator must become owner';end if;
 if not exists(select 1 from organization_private.identities where organization=o and member=a)then raise exception 'Identity key missing';end if;
 begin insert into social_private.organization_admins(organization,member,role)values(o,b,'owner');raise exception 'Second owner accepted';exception when unique_violation then null;end;
 if public.organization_access('get',hb,jsonb_build_object('organization_id',o))->>'code'<>'forbidden'then raise exception 'Outsider read the roster';end if;
 if public.organization_access('invite',hb,jsonb_build_object('organization_id',o,'username',uc,'kind','admin','nonce',gen_random_uuid()))->>'code'<>'forbidden'then raise exception 'Outsider invited';end if;
 r:=public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',ub,'kind','admin','nonce','11111111-1111-1111-1111-111111111111'));inv:=(r->>'invitationID')::uuid;
 if inv is null then raise exception 'Invite failed %',r;end if;
 if(public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',ub,'kind','admin','nonce','11111111-1111-1111-1111-111111111111'))->>'invitationID')::uuid<>inv then raise exception 'Nonce retry duplicated';end if;
 if public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',uc,'kind','admin','nonce','11111111-1111-1111-1111-111111111111'))->>'code'<>'invalid'then raise exception 'Used nonce changed target';end if;
 if public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',ub,'kind','admin','nonce',gen_random_uuid()))->>'code'<>'invalid'then raise exception 'Duplicate pending invitation accepted';end if;
 begin insert into organization_private.invitations(organization,issuer,target,kind,nonce)values(o,a,b,'admin',gen_random_uuid());raise exception 'Pending uniqueness index missing';exception when unique_violation then null;end;
 if jsonb_array_length(public.organization_access('incoming',hb,'{}')->'invitations')<>1 or jsonb_array_length(public.organization_access('incoming',hc,'{}')->'invitations')<>0 then raise exception 'Incoming visibility wrong';end if;
 if public.organization_access('accept',hc,jsonb_build_object('invitation_id',inv))->>'code'<>'forbidden'then raise exception 'Wrong recipient accepted';end if;
 if public.organization_access('accept',hb,jsonb_build_object('invitation_id',inv))->>'changed'<>'true'then raise exception 'Accept failed';end if;
 r:=public.organization_access('get',hb,jsonb_build_object('organization_id',o));
 if r->>'myRole'<>'admin'or r->'administrators'<>'[]'::jsonb or r->'pending'<>'[]'::jsonb then raise exception 'Roster leaked to a non-owner %',r;end if;
 r:=public.organization_access('get',ha,jsonb_build_object('organization_id',o));
 if jsonb_array_length(r->'administrators')<>2 or exists(select 1 from jsonb_array_elements(r->'administrators')x where(x->>'id')::uuid in(a,b))then raise exception 'Owner roster wrong or leaks member ids %',r;end if;
 if public.organization_access('leave',ha,jsonb_build_object('organization_id',o))->>'code'<>'invalid'then raise exception 'Owner left without transfer';end if;
 if public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',uc,'kind','ownership','nonce',gen_random_uuid()))->>'code'<>'invalid'then raise exception 'Ownership offered to a non-admin';end if;
 r:=public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',ub,'kind','ownership','nonce',gen_random_uuid()));handoff:=(r->>'invitationID')::uuid;
 if handoff is null then raise exception 'Handoff invite failed %',r;end if;
 if public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',ub,'kind','ownership','nonce',gen_random_uuid()))->>'code'<>'invalid'then raise exception 'Second pending handoff accepted';end if;
 if public.organization_access('accept',hb,jsonb_build_object('invitation_id',handoff))->>'changed'<>'true'then raise exception 'Handoff accept failed';end if;
 if(select count(*)from social_private.organization_admins where organization=o and role='owner')<>1 or(select role from social_private.organization_admins where organization=o and member=b)<>'owner'or(select role from social_private.organization_admins where organization=o and member=a)<>'admin'then raise exception 'Ownership swap wrong';end if;
 if public.organization_access('invite',ha,jsonb_build_object('organization_id',o,'username',uc,'kind','admin','nonce',gen_random_uuid()))->>'code'<>'forbidden'then raise exception 'Former owner still manages';end if;
 -- a is now an admin holding a private organization conversation and a pending handoff addressed to them.
 insert into social_private.rooms(kind,title,meta)values('dm','Org conversation',jsonb_build_object('organization',o))returning id into room_id;
 insert into social_private.room_members(room,member,role)values(room_id,a,'owner'),(room_id,c,'member');
 insert into organization_private.invitations(organization,issuer,target,kind,nonce)values(o,b,a,'ownership',gen_random_uuid())returning id into to_a;
 insert into organization_private.invitations(organization,issuer,target,kind,nonce)values(o,b,c,'admin',gen_random_uuid())returning id into to_c;
 select member_key into akey from organization_private.identities where organization=o and member=a;
 if public.organization_access('remove',hb,jsonb_build_object('organization_id',o,'administrator_key',gen_random_uuid()))->>'code'<>'invalid'then raise exception 'Unknown key removed nobody silently';end if;
 if public.organization_access('remove',ha,jsonb_build_object('organization_id',o,'administrator_key',akey))->>'code'<>'forbidden'then raise exception 'Non-owner removed';end if;
 if public.organization_access('remove',hb,jsonb_build_object('organization_id',o,'administrator_key',(select member_key from organization_private.identities where organization=o and member=b)))->>'code'<>'invalid'then raise exception 'Owner removed themselves';end if;
 if public.organization_access('remove',hb,jsonb_build_object('organization_id',o,'administrator_key',akey))->>'changed'<>'true'then raise exception 'Remove failed';end if;
 if exists(select 1 from social_private.organization_admins where organization=o and member=a)then raise exception 'Admin still listed';end if;
 if(select status from social_private.rooms where id=room_id)<>'closed'or exists(select 1 from social_private.room_members where room=room_id and member=a)then raise exception 'Removed admin conversation not closed';end if;
 if(select status from organization_private.invitations where id=to_a)<>'revoked'or(select status from organization_private.invitations where id=to_c)<>'pending'then raise exception 'Invitation revocation on removal wrong';end if;
 if(select status from social_private.organizations where id=o)<>'verified'then raise exception 'Removing an admin must not suspend';end if;
 if public.organization_access('get',ha,jsonb_build_object('organization_id',o))->>'code'<>'forbidden'then raise exception 'Removed admin still reads';end if;
 if public.organization_access('revoke',hb,jsonb_build_object('organization_id',o,'invitation_id',to_c))->>'changed'<>'true'then raise exception 'Revoke failed';end if;
 if public.organization_access('revoke',hb,jsonb_build_object('organization_id',o,'invitation_id',to_c))->>'code'<>'invalid'then raise exception 'Repeated revoke reported a change';end if;
 if public.organization_access('accept',hc,jsonb_build_object('invitation_id',to_c))->>'code'<>'forbidden'then raise exception 'Revoked invitation accepted';end if;
 -- Account deletion of the last owner leaves no owner: the organization is suspended.
 delete from social_private.organization_admins where organization=o and member=b;
 if(select status from social_private.organizations where id=o)<>'suspended'then raise exception 'Ownerless organization not suspended';end if;
 if has_function_privilege('anon','public.organization_access(text,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','public.organization_access(text,text,jsonb)','EXECUTE')
  or has_schema_privilege('anon','organization_private','USAGE')or has_schema_privilege('authenticated','organization_private','USAGE')
  or has_table_privilege('authenticated','organization_private.invitations','SELECT')or has_table_privilege('authenticated','organization_private.identities','SELECT')then raise exception 'Client grants leaked';end if;
 raise notice 'organization administrator security suite passed';
end $$;
rollback;
