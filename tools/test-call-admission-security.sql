begin;set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');a uuid;b uuid;c uuid;ia uuid:=gen_random_uuid();ib uuid:=gen_random_uuid();dm text;grp text;out jsonb;call_id uuid;other_call uuid;nonce_id uuid:=gen_random_uuid();target uuid;req uuid;session_id uuid;f text;d text;p0 int;p1 int;p2 int;p3 int;p4 int;p5 int;pr int;
begin
 if has_function_privilege('anon','public.discovery_gateway(text,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','group_call_private.admission_lock(uuid[])','EXECUTE')then raise exception 'Admission exposed';end if;
 -- Lock order: the FIRST lock of every wrapped admission is the caller's own members row (same row, same 'for no key update' mode and same position as require_account inside every unwrapped action), taken before the per-member admission locks, 77833003, 77833002, the group rooms row and admission_cleanup; a residual deadlock answers code 'retry', never 'busy'.
 foreach f in array array['public.discovery_gateway(text,text,jsonb)','public.social_call_gateway(text,text,jsonb)','public.group_call_gateway(text,text,jsonb)']loop
  d:=pg_get_functiondef(f::regprocedure);
  p0:=strpos(d,'me:=group_call_private.admission_member(p_hash);');p1:=strpos(d,'perform 1 from social_private.members where id=me for no key update;');p2:=strpos(d,'perform group_call_private.admission_lock(');p3:=strpos(d,'perform pg_advisory_xact_lock(77833003);');p4:=strpos(d,'perform pg_advisory_xact_lock(77833002);');p5:=strpos(d,'perform group_call_private.admission_cleanup(');pr:=strpos(d,'and kind=''group''for update;');
  if not(p0>0 and p1>p0 and p2>p1 and p3>p2 and p4>p3 and p5>p4)then raise exception 'Members-row pre-lock is not the first lock in % (positions % % % % % %)',f,p0,p1,p2,p3,p4,p5;end if;
  if f like 'public.group%'and not(pr>p4 and pr<p5)then raise exception 'Group rooms row is not between 77833002 and admission_cleanup (%)',pr;end if;
  if strpos(d,'when deadlock_detected then return jsonb_build_object(''error'',''Please try again.'',''code'',''retry'')')=0 or strpos(d,'''code'',''busy''')>0 then raise exception 'Deadlock backstop missing or not code retry in %',f;end if;
 end loop;
 -- admission_member stays stable and lock-free: the members-row lock belongs to the wrapper, where its position is visible.
 if(select provolatile from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='group_call_private'and p.proname='admission_member')<>'s'or strpos(pg_get_functiondef('group_call_private.admission_member(text)'::regprocedure),'for no key update')>0 then raise exception 'admission_member must stay stable and lock-free';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'ad_a_'||substr(ha,1,8),true,ha)returning id into a;insert into social_private.guidelines_acceptances(member,version)select a,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'ad_b_'||substr(hb,1,8),true,hb)returning id into b;insert into social_private.guidelines_acceptances(member,version)select b,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'ad_c_'||substr(hc,1,8),true,hc)returning id into c;insert into social_private.guidelines_acceptances(member,version)select c,required_version from social_private.guidelines_settings;
 insert into social_private.rooms(kind,title,status,anonymous)values('dm','Admission QA','active',true)returning id into dm;
 insert into social_private.room_members(room,member,status)values(dm,a,'accepted'),(dm,c,'accepted');
 out:=public.communities_gateway('create',ha,jsonb_build_object('title','Admission QA','description','Synthetic admission checks only.','category','Friends','avatar','gold','is_public',true,'alias','Copper','member_avatar','sage','nonce',gen_random_uuid()));grp:=out->>'room_id';if grp is null then raise exception 'Group setup %',out;end if;
 perform public.communities_gateway('join',hb,jsonb_build_object('room_id',grp,'alias','Silver','member_avatar','sky'));
 perform public.communities_gateway('join',hc,jsonb_build_object('room_id',grp,'alias','Gold','member_avatar','rose'));
 perform public.discovery_gateway('profile',ha,jsonb_build_object('instance',ia,'username','Copper'||substr(ha,1,5),'tags','["music"]'::jsonb));
 perform public.discovery_gateway('profile',hb,jsonb_build_object('instance',ib,'username','Silver'||substr(hb,1,5),'tags','["music"]'::jsonb));
 out:=public.discovery_gateway('enter',ha,jsonb_build_object('instance',ia,'transport','direct','allow_direct',true));if out->>'state'<>'waiting'then raise exception 'Enter %',out;end if;
 out:=public.social_call_gateway('invite',hc,jsonb_build_object('room_id',dm,'mode','video','transport','direct','allow_direct',true,'nonce',gen_random_uuid()));if out->>'code'<>'busy'then raise exception 'Waiting recipient admitted DM %',out;end if;
 out:=public.group_call_gateway('invite',ha,jsonb_build_object('room_id',grp,'mode','video','transport','direct','allow_direct',true,'nonce',gen_random_uuid()));if out->>'code'<>'busy'then raise exception 'Waiting caller admitted group %',out;end if;
 -- An idle co-member may start a group call; it does not reserve every member.
 out:=public.group_call_gateway('invite',hb,jsonb_build_object('room_id',grp,'mode','video','transport','direct','allow_direct',true,'nonce',nonce_id));call_id:=(out->'call'->>'id')::uuid;if call_id is null then raise exception 'Idle co-member blocked %',out;end if;
 -- Retries by the already-joined creator are idempotent: same call, still joined, never 'Unknown group call action.'
 out:=public.group_call_gateway('invite',hb,jsonb_build_object('room_id',grp,'mode','video','transport','direct','allow_direct',true,'nonce',nonce_id));if(out->'call'->>'id')::uuid is distinct from call_id or out->'call'->>'joined'is distinct from 'true'then raise exception 'Group nonce retry %',out;end if;
 out:=public.group_call_gateway('accept',hb,jsonb_build_object('room_id',grp,'call_id',call_id,'allow_direct',true));if(out->'call'->>'id')::uuid is distinct from call_id or out->'call'->>'joined'is distinct from 'true'or(select count(*)from group_call_private.peers where call=call_id and member=b and left_at is null)<>1 then raise exception 'Joined member accept %',out;end if;
 out:=public.group_call_gateway('accept',ha,jsonb_build_object('room_id',grp,'call_id',call_id,'allow_direct',true));if out->>'code'<>'busy'then raise exception 'Waiting member joined group %',out;end if;
 perform public.discovery_gateway('leave',ha,jsonb_build_object('instance',ia));
 out:=public.group_call_gateway('accept',ha,jsonb_build_object('room_id',grp,'call_id',call_id,'allow_direct',true));if out->'call'->>'joined'<>'true'then raise exception 'Join after leave %',out;end if;
 out:=public.discovery_gateway('enter',ha,jsonb_build_object('instance',ia,'transport','direct','allow_direct',true));if out->>'code'<>'busy'then raise exception 'Group participant entered discovery %',out;end if;
 perform public.group_call_gateway('end',ha,jsonb_build_object('room_id',grp,'call_id',call_id));perform public.group_call_gateway('end',hb,jsonb_build_object('room_id',grp,'call_id',call_id));
 nonce_id:=gen_random_uuid();out:=public.social_call_gateway('invite',hc,jsonb_build_object('room_id',dm,'mode','voice','transport','direct','allow_direct',true,'nonce',nonce_id));call_id:=(out->'call'->>'id')::uuid;if call_id is null then raise exception 'DM invite %',out;end if;
 out:=public.social_call_gateway('invite',hc,jsonb_build_object('room_id',dm,'mode','voice','transport','direct','allow_direct',true,'nonce',nonce_id));if(out->'call'->>'id')::uuid is distinct from call_id then raise exception 'DM retry %',out;end if;
 out:=public.social_call_gateway('accept',ha,jsonb_build_object('room_id',dm,'call_id',call_id,'allow_direct',true));if out->'call'->>'state'<>'connected'then raise exception 'DM accept %',out;end if;
 out:=public.discovery_gateway('enter',ha,jsonb_build_object('instance',ia,'transport','direct','allow_direct',true));if out->>'code'<>'busy'then raise exception 'DM participant entered discovery %',out;end if;
 update social_private.calls set caller_seen=now()-interval '31 seconds'where id=call_id;
 out:=public.discovery_gateway('enter',ha,jsonb_build_object('instance',ia,'transport','direct','allow_direct',true));if out->>'state'<>'waiting'or not exists(select 1 from social_private.calls where id=call_id and state='ended')then raise exception 'Expired DM blocks discovery %',out;end if;
 -- Stale discovery must not permanently reserve a member.
 update discovery_private.presence set seen_at=now()-interval '16 seconds'where member=a;
 out:=public.social_call_gateway('invite',hc,jsonb_build_object('room_id',dm,'mode','voice','transport','direct','allow_direct',true,'nonce',gen_random_uuid()));call_id:=(out->'call'->>'id')::uuid;if call_id is null then raise exception 'Expired presence blocks DM %',out;end if;
 perform public.social_call_gateway('end',ha,jsonb_build_object('room_id',dm,'call_id',call_id));
 -- Preexisting overlaps cannot complete a handshake at accept or ack.
 perform public.discovery_gateway('enter',ha,jsonb_build_object('instance',ia,'transport','direct','allow_direct',true));perform public.discovery_gateway('enter',hb,jsonb_build_object('instance',ib,'transport','direct','allow_direct',true));select id into target from discovery_private.presence where member=b;
 out:=public.discovery_gateway('request',ha,jsonb_build_object('instance',ia,'target',target,'nonce',gen_random_uuid()));req:=(out->'outgoing'->>'id')::uuid;
 insert into social_private.calls(room,caller,callee,mode,transport,nonce)values(dm,c,a,'voice','direct',gen_random_uuid())returning id into other_call;
 out:=public.discovery_gateway('accept',hb,jsonb_build_object('instance',ib,'request_id',req,'transport','direct'));if out->>'code'<>'busy'then raise exception 'Discovery accept overlapped %',out;end if;
 update social_private.calls set state='ended',ended_at=now()where id=other_call;
 out:=public.discovery_gateway('accept',hb,jsonb_build_object('instance',ib,'request_id',req,'transport','direct'));session_id:=(out->'session'->>'id')::uuid;if session_id is null then raise exception 'Accept after end %',out;end if;
 insert into social_private.calls(room,caller,callee,mode,transport,nonce)values(dm,c,a,'voice','direct',gen_random_uuid())returning id into other_call;
 out:=public.discovery_gateway('ack',ha,jsonb_build_object('instance',ia,'session_id',session_id));if out->>'code'<>'busy'then raise exception 'Discovery ack overlapped %',out;end if;
 update social_private.calls set state='ended',ended_at=now()where id=other_call;
 perform public.discovery_gateway('ack',ha,jsonb_build_object('instance',ia,'session_id',session_id));out:=public.discovery_gateway('ack',hb,jsonb_build_object('instance',ib,'session_id',session_id));if out->>'state'<>'connected'then raise exception 'Double ack %',out;end if;
 out:=public.social_call_gateway('invite',hc,jsonb_build_object('room_id',dm,'mode','voice','transport','direct','allow_direct',true,'nonce',gen_random_uuid()));if out->>'code'<>'busy'then raise exception 'Connected discovery admitted DM %',out;end if;
 perform public.discovery_gateway('leave',ha,jsonb_build_object('instance',ia));perform public.discovery_gateway('leave',hb,jsonb_build_object('instance',ib));
 insert into social_private.blocks(blocker,blocked)values(a,c);
 out:=public.social_call_gateway('invite',hc,jsonb_build_object('room_id',dm,'mode','voice','transport','direct','allow_direct',true,'nonce',gen_random_uuid()));if out->>'code'<>'forbidden'then raise exception 'Block bypass %',out;end if;
 update social_private.members set banned=true where id=a;
 out:=public.discovery_gateway('enter',ha,jsonb_build_object('instance',ia,'transport','direct','allow_direct',true));if out->>'code'<>'forbidden'then raise exception 'Suspension bypass %',out;end if;
end $$;
select 'PASS members-row-first lock order and retry backstop shape, cross-feature admission, both DM participants, co-member independence, idempotent joined retries and accepts, stale cleanup, accept/ack rechecks, blocks and suspension' result;
rollback;
