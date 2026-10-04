begin;set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');a uuid;b uuid;c uuid;ia uuid:=gen_random_uuid();ib uuid:=gen_random_uuid();dm text;grp text;out jsonb;call_id uuid;other_call uuid;nonce_id uuid:=gen_random_uuid();target uuid;req uuid;session_id uuid;
begin
 if has_function_privilege('anon','public.discovery_gateway(text,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','group_call_private.admission_lock(uuid[])','EXECUTE')then raise exception 'Admission exposed';end if;
 -- Lock order: the caller's members row is the first lock of every admission (same first lock as every unwrapped action), and a residual deadlock answers code 'retry', never 'busy'.
 if(select provolatile from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='group_call_private'and p.proname='admission_member')<>'v'or strpos(pg_get_functiondef('group_call_private.admission_member(text)'::regprocedure),'where token_hash=p_hash for no key update')=0 then raise exception 'Admission does not lock the members row first';end if;
 if exists(select 1 from unnest(array['public.discovery_gateway(text,text,jsonb)','public.social_call_gateway(text,text,jsonb)','public.group_call_gateway(text,text,jsonb)'])f where strpos(pg_get_functiondef(f::regprocedure),'when deadlock_detected then return jsonb_build_object(''error'',''Please try again.'',''code'',''retry'')')=0 or strpos(pg_get_functiondef(f::regprocedure),'me:=group_call_private.admission_member(p_hash);')=0)then raise exception 'Deadlock backstop missing, not code retry, or member lock not first';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'ad_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'ad_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'ad_c_'||substr(hc,1,8),true,hc)returning id into c;
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
