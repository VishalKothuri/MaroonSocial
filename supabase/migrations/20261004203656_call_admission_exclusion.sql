-- Reserve participants across discovery, DM calls and group calls before any
-- gateway acquires its account row or feature-specific lock. Sorted locks avoid
-- opposite-direction requests locking two participants in opposite order.
create function group_call_private.admission_member(p_hash text) returns uuid
language plpgsql stable security invoker set search_path='' as $$
declare m social_private.members;
begin
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'unauthorized:Sign in to continue.'; end if;
 select * into m from social_private.members where token_hash=p_hash;
 if m.id is null then raise exception 'unauthorized:Your account credential is unavailable.'; end if;
 if m.banned then raise exception 'forbidden:This account is suspended.'; end if;
 if (select require_verified from verification_private.settings where id) and not exists(select 1 from verification_private.memberships where member=m.id and expires_at>now()) then raise exception 'verification_required:Verify your TAMU mailbox to access the community.'; end if;
 -- The original gateway performs the authoritative locked check and rate count.
 return m.id;
end $$;
create function group_call_private.admission_lock(p_members uuid[]) returns void
language plpgsql security invoker set search_path='' as $$
declare member_id uuid;
begin
 for member_id in select distinct x from unnest(p_members) x where x is not null order by x loop
  perform pg_advisory_xact_lock(hashtextextended('maroon-call-admission:'||member_id::text,0));
 end loop;
end $$;
create function group_call_private.admission_cleanup(p_members uuid[]) returns void
language plpgsql security invoker set search_path='' as $$
declare member_id uuid;
begin
 update social_private.calls c set state='ended',ended_at=now(),end_reason='expired'
 where c.state<>'ended' and(c.caller=any(p_members)or c.callee=any(p_members))and(
  (c.state='ringing'and c.created_at<=now()-interval '60 seconds')or
  (c.state='connected'and(least(c.caller_seen,c.callee_seen)<=now()-interval '30 seconds'or c.connected_at<=now()-interval '2 hours'))or
  not social_private.can_message(c.caller,c.room)or not social_private.can_message(c.callee,c.room)or
  not discovery_private.eligible(c.caller,c.callee));
 update group_call_private.peers p set left_at=now()from group_call_private.calls c
 where c.id=p.call and p.member=any(p_members)and p.left_at is null and(
  c.ended_at is not null or c.ends_at<=now()or p.seen_at<=now()-interval '35 seconds'or
  not social_private.can_message(p.member,c.room)or not exists(select 1 from social_private.members where id=p.member and not banned)or
  ((select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships where member=p.member and expires_at>now())));
 update group_call_private.calls c set ended_at=now()where c.ended_at is null
 and exists(select 1 from group_call_private.peers p where p.call=c.id and p.member=any(p_members))
 and(c.ends_at<=now()or not exists(select 1 from group_call_private.peers p where p.call=c.id and p.left_at is null));
 for member_id in select distinct x from unnest(p_members) x where x is not null order by x loop
  perform discovery_private.cleanup(member_id);
 end loop;
end $$;
create function group_call_private.admission_assert(p_members uuid[],p_kind text,p_reference uuid default null)returns void
language plpgsql stable security invoker set search_path='' as $$
begin
 if exists(select 1 from social_private.calls where state<>'ended'and(caller=any(p_members)or callee=any(p_members))and not(p_kind='dm'and id is not distinct from p_reference))or
 exists(select 1 from group_call_private.peers p join group_call_private.calls c on c.id=p.call where p.member=any(p_members)and p.left_at is null and c.ended_at is null and c.ends_at>now()and not(p_kind='group'and c.id is not distinct from p_reference))or
 (p_kind<>'discovery'and exists(select 1 from discovery_private.presence where member=any(p_members)and seen_at>now()-interval '15 seconds'))then
  raise exception 'busy:Leave discovery or end the other call before connecting.';
 end if;
end $$;

alter function public.discovery_gateway(text,text,jsonb)rename to discovery_before_admission;
create function public.discovery_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;other_member uuid;participants uuid[];
begin
 if p_action not in('enter','accept','ack')then return public.discovery_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 if p_action='accept'then select sender into other_member from discovery_private.requests where id=(p_input->>'request_id')::uuid and recipient=me;
 elsif p_action='ack'then select case when a=me then b else a end into other_member from discovery_private.sessions where id=(p_input->>'session_id')::uuid and me in(a,b);end if;
 participants:=array[me,other_member];
 perform group_call_private.admission_lock(participants);
 perform group_call_private.admission_cleanup(participants);
 perform group_call_private.admission_assert(participants,'discovery');
 return public.discovery_before_admission(p_action,p_hash,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');end $$;

alter function public.social_call_gateway(text,text,jsonb)rename to social_call_before_admission;
create function public.social_call_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;other_member uuid;participants uuid[];call_id uuid;
begin
 if p_action not in('invite','accept')then return public.social_call_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 select rm.member into other_member from social_private.room_members rm join social_private.rooms r on r.id=rm.room where r.id=p_input->>'room_id'and r.kind='dm'and rm.member<>me and rm.status='accepted'and exists(select 1 from social_private.room_members where room=r.id and member=me and status='accepted')limit 1;
 participants:=array[me,other_member];
 perform group_call_private.admission_lock(participants);
 perform group_call_private.admission_cleanup(participants);
 if p_action='invite'then select id into call_id from social_private.calls where caller=me and nonce=(p_input->>'nonce')::uuid and room=p_input->>'room_id';
 else select id into call_id from social_private.calls where id=(p_input->>'call_id')::uuid and room=p_input->>'room_id'and me in(caller,callee);end if;
 perform group_call_private.admission_assert(participants,'dm',call_id);
 return public.social_call_before_admission(p_action,p_hash,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');end $$;

alter function public.group_call_gateway(text,text,jsonb)rename to group_call_before_admission;
create function public.group_call_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb
language plpgsql security invoker set search_path=''as $$
declare me uuid;call_id uuid;
begin
 if p_action not in('invite','accept')then return public.group_call_before_admission(p_action,p_hash,p_input);end if;
 me:=group_call_private.admission_member(p_hash);
 perform group_call_private.admission_lock(array[me]);
 perform group_call_private.admission_cleanup(array[me]);
 if p_action='invite'then select id into call_id from group_call_private.calls where creator=me and nonce=(p_input->>'nonce')::uuid and room=p_input->>'room_id';
 else select id into call_id from group_call_private.calls where id=(p_input->>'call_id')::uuid and room=p_input->>'room_id';end if;
 perform group_call_private.admission_assert(array[me],'group',call_id);
 return public.group_call_before_admission(p_action,p_hash,p_input);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid call request.','code','invalid');end $$;

revoke all on function group_call_private.admission_member(text),group_call_private.admission_lock(uuid[]),group_call_private.admission_cleanup(uuid[]),group_call_private.admission_assert(uuid[],text,uuid),public.discovery_before_admission(text,text,jsonb),public.discovery_gateway(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_before_admission(text,text,jsonb),public.group_call_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function group_call_private.admission_member(text),group_call_private.admission_lock(uuid[]),group_call_private.admission_cleanup(uuid[]),group_call_private.admission_assert(uuid[],text,uuid),public.discovery_before_admission(text,text,jsonb),public.discovery_gateway(text,text,jsonb),public.social_call_before_admission(text,text,jsonb),public.social_call_gateway(text,text,jsonb),public.group_call_before_admission(text,text,jsonb),public.group_call_gateway(text,text,jsonb)to service_role;
