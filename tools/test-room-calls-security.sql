begin;
do $$
declare ha text:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');hb text:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');hc text:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');a uuid;b uuid;c uuid;r text:=gen_random_uuid()::text;call uuid;out jsonb;nonce uuid:=gen_random_uuid();
begin
 if has_function_privilege('anon','public.social_call_gateway(text,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','public.social_call_gateway(text,text,jsonb)','EXECUTE')then raise exception 'Calls RPC exposed to app roles';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'callsql_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'callsql_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'callsql_'||substr(hc,1,8),true,hc)returning id into c;
 insert into social_private.rooms(id,kind,title,status)values(r,'dm','Synthetic call','active');insert into social_private.room_members(room,member)values(r,a),(r,b);
 out:=public.social_call_gateway('invite',ha,jsonb_build_object('room_id',r,'mode','video','transport','direct','nonce',nonce));if out->>'code'<>'consent'then raise exception 'Missing caller consent allowed';end if;
 out:=public.social_call_gateway('invite',ha,jsonb_build_object('room_id',r,'mode','video','transport','direct','nonce',nonce,'allow_direct',true));call:=(out->'call'->>'id')::uuid;if call is null then raise exception 'Call invite failed %',out;end if;
 out:=public.social_call_gateway('signal',ha,jsonb_build_object('room_id',r,'call_id',call,'kind','offer','payload','{}'::jsonb));if out->>'code'<>'ended'then raise exception 'Signal before acceptance allowed';end if;
 out:=public.social_call_gateway('poll',hc,jsonb_build_object('room_id',r,'call_id',call));if out->>'code'<>'forbidden'then raise exception 'Outsider read allowed';end if;
 out:=public.social_call_gateway('accept',hb,jsonb_build_object('room_id',r,'call_id',call));if out->>'code'<>'consent'then raise exception 'Missing receiver consent allowed';end if;
 out:=public.social_call_gateway('accept',hb,jsonb_build_object('room_id',r,'call_id',call,'allow_direct',true));if out->'call'->>'state'<>'connected'then raise exception 'Call acceptance failed %',out;end if;
 out:=public.social_call_gateway('signal',ha,jsonb_build_object('room_id',r,'call_id',call,'kind','ice','payload',jsonb_build_object('candidate','synthetic-candidate')));if out?'error'then raise exception 'ICE signal rejected';end if;
 out:=public.social_call_gateway('poll',hb,jsonb_build_object('room_id',r,'call_id',call));if out->'call'->'signals'->0->'payload'->>'candidate'<>'synthetic-candidate'then raise exception 'ICE signal delivery failed';end if;
 update social_private.calls set callee_seen=now()-interval '31 seconds'where id=call;
 out:=public.social_call_gateway('poll',ha,jsonb_build_object('room_id',r,'call_id',call));if out->'call'->>'state'<>'ended'or out->'call'->>'end_reason'<>'expired'then raise exception 'Dead peer TTL missing';end if;
 out:=public.social_call_gateway('media',ha,jsonb_build_object('room_id',r,'call_id',call));if out->>'code'<>'consent'then raise exception 'Ended call media allowed';end if;
 out:=public.social_call_gateway('invite',ha,jsonb_build_object('room_id',r,'mode','voice','transport','direct','nonce',gen_random_uuid(),'allow_direct',true));call:=(out->'call'->>'id')::uuid;
 insert into social_private.blocks values(b,a);
 out:=public.social_call_gateway('poll',ha,jsonb_build_object('room_id',r,'call_id',call));if out->>'code'<>'forbidden'then raise exception 'Blocked call still readable';end if;
end $$;
select 'PASS calls RPC grants, both-party consent, outsider denial, ICE delivery, peer TTL, ended media and block revocation' as result;
rollback;
