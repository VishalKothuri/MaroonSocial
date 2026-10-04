-- Synthetic Auth identities/sessions only; all data and gate changes roll back.
begin;
create temporary table auth_bridge_qa (users uuid[], sessions uuid[], member_id uuid, legacy text, network text, receipt text, second_session uuid);
grant select,update on auth_bridge_qa to service_role;
do $$
declare users uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];sessions uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 h text:=encode(extensions.gen_random_bytes(32),'hex');n text:=encode(extensions.gen_random_bytes(32),'hex');r text:=encode(extensions.gen_random_bytes(32),'hex');m uuid;i integer;s2 uuid:=gen_random_uuid();
begin
 if has_function_privilege('anon','public.social_auth_bridge(text,uuid,uuid,jsonb)','EXECUTE') or has_function_privilege('authenticated','public.social_auth_bridge(text,uuid,uuid,jsonb)','EXECUTE') then raise exception 'Public auth bridge exposure';end if;
 if has_schema_privilege('authenticated','social_auth_private','USAGE') or has_table_privilege('service_role','social_auth_private.settings','UPDATE') then raise exception 'Private configuration exposure';end if;
 for i in 1..5 loop
  insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,aud,role)values(users[i],'auth-qa-'||users[i]::text||'@example.invalid',case when i=3 then null else now() end,now(),now(),'authenticated','authenticated');
  insert into auth.sessions(id,user_id,created_at,updated_at,aal)values(sessions[i],users[i],now(),now(),'aal1');
 end loop;
 insert into auth.sessions(id,user_id,created_at,updated_at,aal) values(s2,users[2],now(),now(),'aal1');
 insert into social_private.members(token_hash,username,adult,network_hash)values(h,'authqa_'||substr(h,1,8),true,n)returning id into m;
 insert into social_private.posts(author,nonce,body) values(m,gen_random_uuid(),'Identity must survive email linking');
 insert into auth_bridge_qa values(users,sessions,m,h,n,r,s2);
end $$;
set local role service_role;
do $$ declare q auth_bridge_qa;o jsonb;begin
 select * into q from auth_bridge_qa;
 o:=public.social_auth_bridge('capabilities');if o->>'enabled' is distinct from 'false' then raise exception 'Deployment unexpectedly enabled';end if;
 o:=public.social_auth_bridge('register',q.users[1],q.sessions[1],jsonb_build_object('username','disabledqa','adult',true,'network',q.network));if o->>'code' is distinct from 'unavailable' then raise exception 'Disabled registration allowed %',o;end if;
 o:=public.social_auth_bridge('link',q.users[1],q.sessions[1],jsonb_build_object('legacy_hash',q.legacy));if o->>'code' is distinct from 'unavailable' then raise exception 'Disabled linking allowed %',o;end if;
 o:=public.social_auth_bridge('status',q.users[1],q.sessions[2]);if o->>'code' is distinct from 'unauthorized' then raise exception 'Cross-account session accepted %',o;end if;
 o:=public.social_auth_bridge('status',q.users[3],q.sessions[3]);if o->>'code' is distinct from 'unauthorized' then raise exception 'Unconfirmed Auth identity accepted %',o;end if;
end $$;
reset role;
update social_auth_private.settings set enabled=true where singleton;
set local role service_role;
do $$ declare q auth_bridge_qa;o jsonb;rotated text;registered uuid;job jsonb;i integer;before_count integer;begin
 select * into q from auth_bridge_qa;
 o:=public.social_auth_bridge('link',q.users[1],q.sessions[1],jsonb_build_object('legacy_hash',q.legacy));if o->>'state' is distinct from 'linked' then raise exception 'Link failed %',o;end if;
 select token_hash into rotated from social_private.members where id=q.member_id;
 if rotated=q.legacy or not exists(select 1 from social_private.posts where author=q.member_id and body='Identity must survive email linking') then raise exception 'Link lost content or retained legacy credential';end if;
 o:=public.social_gateway('snapshot',q.legacy);if o->>'code' is distinct from 'unauthorized' then raise exception 'Old device token still accepted %',o;end if;
 o:=public.social_auth_bridge('resolve',q.users[1],q.sessions[1]);if o->>'token_hash' is distinct from rotated or o?'auth_id' or o?'member_id' or o?'email' then raise exception 'Wrong internal resolution %',o;end if;
 o:=public.social_auth_bridge('status',q.users[1],q.sessions[1]);if o?'token_hash' then raise exception 'Status leaks secret';end if;
 o:=public.social_auth_bridge('link',q.users[1],q.sessions[1],jsonb_build_object('legacy_hash',q.legacy));if o->>'state' is distinct from 'linked' then raise exception 'Lost-response link retry failed %',o;end if;
 o:=public.social_auth_bridge('link',q.users[2],q.sessions[2],jsonb_build_object('legacy_hash',q.legacy));if coalesce(o->>'code','') not in ('unauthorized','conflict') then raise exception 'Another Auth user claimed linked credential %',o;end if;
 o:=public.social_auth_bridge('link',q.users[1],q.sessions[1],jsonb_build_object('legacy_hash',repeat('f',64)));if o->>'code' is distinct from 'conflict' then raise exception 'Mapped account credential switched %',o;end if;
 select count(*) into before_count from social_private.members;
 o:=public.social_auth_bridge('register',q.users[1],q.sessions[1],'{"username":"","adult":false}');if o->>'state' is distinct from 'linked' or o->>'created' is distinct from 'false' then raise exception 'Existing registration recovery failed %',o;end if;
 if(select count(*)from social_private.members)<>before_count then raise exception 'Recovery created another member';end if;
 o:=public.social_auth_bridge('register',q.users[2],q.sessions[2],jsonb_build_object('username','authqa_new_'||substr(q.network,1,8),'adult',true,'network',q.network));if o->>'created' is distinct from 'true' then raise exception 'New registration failed %',o;end if;
 select member_id into registered from social_auth_private.members where auth_id=q.users[2];
 if exists(select 1 from verification_private.memberships where member=registered) then raise exception 'Personal email granted university access';end if;
 o:=public.social_auth_bridge('register',q.users[4],q.sessions[4],jsonb_build_object('username','authqa_new_'||substr(q.network,1,8),'adult',true,'network',q.network));if o->>'code' is distinct from 'conflict' then raise exception 'Existing username claimed %',o;end if;
 update social_private.members set banned=true where id=q.member_id;
 o:=public.social_auth_bridge('resolve',q.users[1],q.sessions[1]);if o->>'code' is distinct from 'forbidden' then raise exception 'Suspended member resolved %',o;end if;
 update social_private.members set banned=false where id=q.member_id;
 o:=public.social_auth_bridge('prepare-deletion',q.users[1],q.sessions[1],jsonb_build_object('receipt_hash',q.receipt));if o->>'prepared' is distinct from 'true' then raise exception 'Deletion preparation failed %',o;end if;
 o:=public.social_auth_bridge('deletion-status',null,null,jsonb_build_object('receipt_hash',q.receipt,'network_hash',q.network));if o->>'deleted' is distinct from 'false' then raise exception 'Premature deletion success';end if;
 o:=public.social_gateway('account.delete',rotated);if o?'error' then raise exception 'Account deletion failed %',o;end if;
 if not exists(select 1 from social_auth_private.revoked_sessions where session_id=q.sessions[1] and auth_id=q.users[1]) then raise exception 'Deletion did not revoke session at adapter boundary';end if;
 if not exists(select 1 from social_auth_private.members where auth_id=q.users[1] and member_id is null and deleted_at is not null) then raise exception 'Deletion missing tombstone';end if;
 o:=public.social_auth_bridge('resolve',q.users[1],q.sessions[1]);if o->>'code' is distinct from 'unauthorized' then raise exception 'Cached JWT survived account deletion %',o;end if;
 o:=public.social_auth_bridge('deletion-status',null,null,jsonb_build_object('receipt_hash',q.receipt,'network_hash',q.network));if o->>'deleted' is distinct from 'true' then raise exception 'Lost-ack deletion receipt failed %',o;end if;
 o:=public.social_auth_bridge('deletion-status',null,null,jsonb_build_object('receipt_hash',repeat('0',64),'network_hash',q.network));if o->>'deleted' is distinct from 'false' then raise exception 'Unknown receipt accepted';end if;
 o:=public.social_auth_bridge('cleanup.take',null,null,'{"limit":20}');select value into job from jsonb_array_elements(o->'jobs')where value->>'auth_id'=q.users[1]::text;if job is null then raise exception 'Deletion worker did not claim job %',o;end if;
 o:=public.social_auth_bridge('cleanup.take',null,null,'{"limit":20}');if exists(select 1 from jsonb_array_elements(o->'jobs')where value->>'auth_id'=q.users[1]::text) then raise exception 'Cleanup lease allowed double claim';end if;
 o:=public.social_auth_bridge('cleanup.complete',null,null,jsonb_build_object('auth_id',q.users[1],'lease_id',gen_random_uuid(),'success',true));if o->>'completed' is distinct from 'false' then raise exception 'Forged cleanup lease accepted';end if;
 o:=public.social_auth_bridge('cleanup.complete',null,null,job||'{"success":true}'::jsonb);if o->>'completed' is distinct from 'true' then raise exception 'Cleanup acknowledgment failed';end if;
 o:=public.social_auth_bridge('logout',q.users[2],q.sessions[2]);if o->>'state' is distinct from 'signed_out' then raise exception 'Logout failed';end if;
 o:=public.social_auth_bridge('resolve',q.users[2],q.sessions[2]);if o->>'code' is distinct from 'unauthorized' then raise exception 'Logged-out JWT accepted';end if;
 o:=public.social_auth_bridge('resolve',q.users[2],q.second_session);if o->>'state' is distinct from 'linked' then raise exception 'Logout revoked unrelated session';end if;
 for i in 1..121 loop o:=public.social_auth_bridge('deletion-status',null,null,jsonb_build_object('receipt_hash',q.receipt,'network_hash',q.network));end loop;
 if o->>'code' is distinct from 'rate_limit' then raise exception 'Receipt polling limit absent %',o;end if;
end $$;
reset role;
do $$ declare q auth_bridge_qa;o jsonb;fresh uuid:=gen_random_uuid();begin
 select * into q from auth_bridge_qa;
 -- Even a new Auth session cannot resurrect a deleted social mapping.
 insert into auth.sessions(id,user_id,created_at,updated_at,aal)values(fresh,q.users[1],now(),now(),'aal1');
 o:=public.social_auth_bridge('register',q.users[1],fresh,jsonb_build_object('username','resurrectedqa','adult',true,'network',q.network));if o->>'code' is distinct from 'account_deleted' then raise exception 'Deleted mapping recreated %',o;end if;
 update auth.users set banned_until=now()+interval '1 hour'where id=q.users[5];
 o:=public.social_auth_bridge('status',q.users[5],q.sessions[5]);if o->>'code' is distinct from 'unauthorized' then raise exception 'Auth ban bypassed';end if;
 o:=public.social_auth_bridge('logout',q.users[5],q.sessions[5]);if o->>'state' is distinct from 'signed_out' then raise exception 'Auth ban trapped sign-out';end if;
 update auth.users set banned_until=null where id=q.users[5];delete from social_auth_private.revoked_sessions where session_id=q.sessions[5];update auth.sessions set not_after=now()-interval '1 second'where id=q.sessions[5];
 o:=public.social_auth_bridge('status',q.users[5],q.sessions[5]);if o->>'code' is distinct from 'unauthorized' then raise exception 'Expired Auth session accepted';end if;
 delete from auth.users where id=q.users[1];
 o:=public.social_auth_bridge('deletion-status',null,null,jsonb_build_object('receipt_hash',q.receipt,'network_hash',encode(extensions.gen_random_bytes(32),'hex')));if o->>'deleted' is distinct from 'true' then raise exception 'Provider deletion erased receipt';end if;
 update social_auth_private.settings set enabled=false;
 o:=public.social_auth_bridge('register',q.users[2],q.second_session,'{"username":"","adult":false}');if o->>'state' is distinct from 'linked' then raise exception 'Disabled gate blocked existing recovery %',o;end if;
end $$;
select 'PASS private RPC/config; disabled gate; confirmed user/live matching sessions; link rotation/content/retry/anti-takeover; idempotent register; username and ban protection; no TAMU grant; deletion receipts/tombstones/outbox/leases; current-session logout; receipt rate limits; provider deletion recovery' as result;
rollback;
