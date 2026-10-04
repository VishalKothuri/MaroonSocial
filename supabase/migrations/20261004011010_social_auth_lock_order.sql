-- Avoid mapping/member lock inversion with concurrent account deletion.
create or replace function public.social_auth_bridge(p_action text,p_auth_id uuid default null,p_session_id uuid default null,p_input jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
 mapping social_auth_private.members;
 person social_private.members;
 legacy text; new_hash text; user_name text; network_value text; receipt text;
 result jsonb; jobs jsonb; failure text; failure_code text;
 accepted boolean; count_value integer; claimed uuid;
begin
 if p_action='capabilities' then
  return (select jsonb_build_object('enabled',enabled,'stage',stage) from social_auth_private.settings where singleton);
 end if;
 -- These actions are intentionally independent of Auth sessions. The gateway
 -- verifies a 256-bit deletion receipt; workers alone may call cleanup actions.
 if p_action='deletion-status' then
  receipt:=p_input->>'receipt_hash'; network_value:=p_input->>'network_hash';
  if receipt is null or receipt !~ '^[a-f0-9]{64}$' or network_value is null or network_value !~ '^[a-f0-9]{64}$' then
   raise exception 'invalid:Invalid deletion receipt.';
  end if;
  insert into social_auth_private.receipt_limits(network_hash) values(network_value) on conflict do nothing;
  update social_auth_private.receipt_limits set
   requests=case when window_at<now()-interval '1 minute' then 1 else requests+1 end,
   window_at=case when window_at<now()-interval '1 minute' then now() else window_at end
   where network_hash=network_value returning requests into count_value;
  -- Return instead of raising, so the rate increment is not rolled back.
  if count_value>120 then return jsonb_build_object('error','Please try again shortly.','code','rate_limit'); end if;
  delete from social_auth_private.receipt_limits where window_at<now()-interval '1 day';
  return jsonb_build_object('deleted',exists(select 1 from social_auth_private.deletion_receipts where receipt_hash=receipt and deleted));
 elsif p_action='cleanup.take' then
  delete from social_auth_private.revoked_sessions r where not exists(select 1 from auth.sessions s where s.id=r.session_id); 
  count_value:=least(20,greatest(1,coalesce((p_input->>'limit')::integer,10)));
  with pending as (
   select q.auth_id from social_auth_private.deletion_outbox q
   join social_auth_private.members a on a.auth_id=q.auth_id and a.deleted_at is not null
   where q.completed_at is null and q.available_at<=now()
   order by q.created_at for update of q skip locked limit count_value
  ), claimed as (
   update social_auth_private.deletion_outbox q set lease_id=gen_random_uuid(),attempts=q.attempts+1,available_at=now()+interval '2 minutes'
   from pending p where q.auth_id=p.auth_id returning q.auth_id,q.lease_id
  ) select coalesce(jsonb_agg(jsonb_build_object('auth_id',auth_id,'lease_id',lease_id)),'[]') into jobs from claimed;
  return jsonb_build_object('jobs',jobs);
 elsif p_action='cleanup.complete' then
  accepted:=coalesce((p_input->>'success')::boolean,false);
  update social_auth_private.deletion_outbox set
   completed_at=case when accepted then now() else null end,
   lease_id=null,
   available_at=now()+make_interval(secs=>least(3600,30*greatest(1,attempts)))
   where auth_id=(p_input->>'auth_id')::uuid and lease_id=(p_input->>'lease_id')::uuid and completed_at is null
   returning auth_id into claimed;
  return jsonb_build_object('completed',claimed is not null);
 end if;
 if p_action not in ('status','resolve','link','register','logout','prepare-deletion') then raise exception 'invalid:Unsupported sign-in action.'; end if;
 if p_auth_id is null or p_session_id is null then raise exception 'unauthorized:Sign in to continue.'; end if;
 if not exists(select 1 from auth.users u where u.id=p_auth_id and u.email_confirmed_at is not null and u.deleted_at is null) then
  raise exception 'unauthorized:This sign-in is unavailable.';
 end if;
 if not exists(select 1 from auth.sessions s where s.id=p_session_id and s.user_id=p_auth_id and (s.not_after is null or s.not_after>now())) then
  raise exception 'unauthorized:Your session has ended. Sign in again.';
 end if;
 -- Same-user register/link requests serialize; the member row lock below also
 -- prevents two different Auth users racing to claim the same legacy account.
 perform pg_advisory_xact_lock(hashtextextended(p_auth_id::text,921044));
 -- Do not lock the mapping before the member: account deletion locks
 -- member first and then tombstones this mapping. The auth advisory lock
 -- already serializes link/register retries for this Auth identity.
 select * into mapping from social_auth_private.members where auth_id=p_auth_id;
 if p_action='logout' then
  insert into social_auth_private.revoked_sessions(session_id,auth_id) values(p_session_id,p_auth_id) on conflict do nothing;
  return jsonb_build_object('state','signed_out');
 end if;
 if exists(select 1 from social_auth_private.revoked_sessions where session_id=p_session_id) then raise exception 'unauthorized:Your session has ended. Sign in again.'; end if;
 if exists(select 1 from auth.users where id=p_auth_id and banned_until>now()) then raise exception 'unauthorized:This sign-in is unavailable.'; end if;
 if mapping.auth_id is not null and mapping.deleted_at is not null then
  if p_action='status' then return jsonb_build_object('state','account_deleted'); end if;
  raise exception 'account_deleted:This account was deleted.';
 end if;
 if mapping.member_id is not null then
  select * into person from social_private.members where id=mapping.member_id for no key update;
  if person.id is null then raise exception 'account_deleted:This account was deleted.'; end if;
  if person.banned then raise exception 'forbidden:This account is suspended.'; end if;
  if p_action='resolve' then return jsonb_build_object('state','linked','token_hash',person.token_hash); end if;
  if p_action in ('register','status') then return jsonb_build_object('state','linked','created',false); end if;
  if p_action='link' then
   if mapping.legacy_token_hash is not null and mapping.legacy_token_hash=p_input->>'legacy_hash' then
    return jsonb_build_object('state','linked','created',false);
   end if;
   raise exception 'conflict:This sign-in already belongs to an account.';
  end if;
  if p_action='prepare-deletion' then
   receipt:=p_input->>'receipt_hash';
   if receipt is null or receipt !~ '^[a-f0-9]{64}$' then raise exception 'invalid:Invalid deletion receipt.'; end if;
   if exists(select 1 from social_auth_private.deletion_receipts where receipt_hash=receipt and auth_id<>p_auth_id) then raise exception 'conflict:Invalid deletion receipt.'; end if;
   -- Keep bounded retry receipts for this account, including a lost response.
   if not exists(select 1 from social_auth_private.deletion_receipts where receipt_hash=receipt) and
      (select count(*) from social_auth_private.deletion_receipts where auth_id=p_auth_id)>=5 then
    raise exception 'rate_limit:Too many deletion attempts. Reuse the previous receipt.';
   end if;
   insert into social_auth_private.deletion_receipts(receipt_hash,auth_id) values(receipt,p_auth_id) on conflict do nothing;
   return jsonb_build_object('prepared',true);
  end if;
 else
  if p_action='status' then return jsonb_build_object('state','not_linked'); end if;
  if p_action in ('resolve','prepare-deletion') then raise exception 'not_linked:Finish setting up your account.'; end if;
 end if;
 if not (select enabled from social_auth_private.settings where singleton) then raise exception 'unavailable:Email sign-in is not ready yet.'; end if;
 new_hash:=encode(extensions.gen_random_bytes(32),'hex');
 if p_action='link' then
  legacy:=p_input->>'legacy_hash';
  if legacy is null or legacy !~ '^[a-f0-9]{64}$' then raise exception 'unauthorized:Your existing account credential is unavailable.'; end if;
  select * into person from social_private.members where token_hash=legacy for no key update;
  if person.id is null then raise exception 'unauthorized:Your existing account credential is unavailable.'; end if;
  if person.banned then raise exception 'forbidden:This account is suspended.'; end if;
  if exists(select 1 from social_auth_private.members where member_id=person.id or legacy_token_hash=legacy) then raise exception 'conflict:This account is already linked to another sign-in.'; end if;
  insert into social_auth_private.members(auth_id,member_id,legacy_token_hash) values(p_auth_id,person.id,legacy);
  update social_private.members set token_hash=new_hash where id=person.id;
  return jsonb_build_object('state','linked','created',false);
 elsif p_action='register' then
  user_name:=lower(btrim(coalesce(p_input->>'username','')));
  if user_name !~ '^[a-z0-9_]{3,20}$' then raise exception 'invalid:Use 3–20 lowercase letters, numbers or underscores.'; end if;
  if coalesce((p_input->>'adult')::boolean,false) is not true then raise exception 'forbidden:You must be 18 or older to join.'; end if;
  network_value:=p_input->>'network';
  if network_value is null or network_value !~ '^[a-f0-9]{64}$' then raise exception 'invalid:Unable to verify this request.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(network_value,778));
  if (select count(*) from social_private.members where network_hash=network_value and created_at>now()-interval '1 hour')>=20 then raise exception 'rate_limit:Too many new accounts. Try again later.'; end if;
  insert into social_private.members(token_hash,username,adult,network_hash) values(new_hash,user_name,true,network_value) returning * into person;
  insert into social_auth_private.members(auth_id,member_id) values(p_auth_id,person.id);
  return jsonb_build_object('state','linked','created',true);
 end if;
 raise exception 'invalid:Unsupported sign-in action.';
exception
 when raise_exception then
  failure:=sqlerrm; failure_code:=split_part(failure,':',1);
  return jsonb_build_object('error',substr(failure,length(failure_code)+2),'code',failure_code);
 when unique_violation then return jsonb_build_object('error','That username or account is already in use.','code','conflict');
 when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('error','Invalid sign-in request.','code','invalid');
end $$;
