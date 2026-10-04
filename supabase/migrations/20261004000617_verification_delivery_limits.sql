create or replace function public.verification_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;c verification_private.challenges;result jsonb;
begin
 me:=social_private.require_account(p_hash);
 if p_action='status'then return verification_private.status(me);
 elsif p_action='prepare'then
  if p_input->>'domain' is distinct from 'tamu.edu'or p_input->>'email_hash'!~'^[a-f0-9]{64}$'or p_input->>'code_hash'!~'^[a-f0-9]{64}$'then raise exception 'invalid:Use your exact @tamu.edu mailbox.';end if;
  perform pg_advisory_xact_lock(77844001);
  if exists(select 1 from verification_private.sends where member=me and created_at>now()-interval '60 seconds')then raise exception 'rate_limit:Wait one minute before requesting another code.';end if;
  if(select count(*)from verification_private.sends where member=me and created_at>now()-interval '1 hour')>=4 or(select count(*)from verification_private.sends where email_hash=p_input->>'email_hash'and created_at>now()-interval '1 day')>=8 or(select count(*)from verification_private.sends where network_hash=p_input->>'network_hash'and created_at>now()-interval '1 hour')>=15 or(select count(*)from verification_private.sends where created_at>=date_trunc('day',now()))>=least(250,greatest(1,coalesce((p_input->>'daily_limit')::integer,250))) then raise exception 'rate_limit:Verification sending limit reached. Please try again later.';end if;
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
  perform pg_advisory_xact_lock(hashtextextended(c.email_hash,77844002));
  if exists(select 1 from verification_private.memberships where email_hash=c.email_hash and member<>me)then update verification_private.challenges set state='cancelled',code_hash=null where id=c.id;return jsonb_build_object('error','This mailbox is linked to an existing account. Contact the owner for recovery.','code','account_exists');end if;
  insert into verification_private.memberships(member,email_hash)values(me,c.email_hash)on conflict(member)do update set email_hash=excluded.email_hash,verified_at=now(),expires_at=now()+interval '180 days';
  update verification_private.challenges set state='used',code_hash=null where id=c.id;
  return verification_private.status(me)||jsonb_build_object('message','TAMU mailbox verified. This confirms mailbox access, not current enrollment.');
 else raise exception 'invalid:Unknown verification action.';end if;
exception when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Invalid verification request.','code','invalid');when raise_exception then return jsonb_build_object('error',split_part(sqlerrm,':',2),'code',split_part(sqlerrm,':',1));
end $$;
