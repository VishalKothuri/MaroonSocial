-- Entirely rolled back. Synthetic members and coordinates only.
begin;
set local role service_role;
do $$
declare members uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 hashes text[]:=array[encode(extensions.gen_random_bytes(32),'hex'),encode(extensions.gen_random_bytes(32),'hex'),encode(extensions.gen_random_bytes(32),'hex'),encode(extensions.gen_random_bytes(32),'hex')];
 seats uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 lid uuid:=gen_random_uuid(); cid uuid; nonce uuid:=gen_random_uuid(); nextid uuid; value jsonb; n int;
begin
 for n in 1..4 loop
  insert into social_private.members(id,token_hash,username,adult,network_hash)
  values(members[n],hashes[n],'tagqa_'||substr(replace(members[n]::text,'-',''),1,12),true,'transactional-fixture');
 end loop;
 insert into tag_private.lobbies(id,code,host_id,request_id,title,area,capacity,duration_seconds,hide_seconds,radius_m,state,seek_at,ends_at)
 values(lid,upper(substr(replace(lid::text,'-',''),1,8)),members[1],gen_random_uuid(),'Results fixture','Synthetic test area',3,300,30,150,'seeking',now()-interval '1 minute',now()+interval '4 minutes');
 for n in 1..3 loop
  insert into tag_private.players(id,lobby_id,member_id,role,consented,ready,latitude,longitude,accuracy,location_at)
  values(seats[n],lid,members[n],case when n=1 then 'seeker'else 'hider'end,true,true,30.6123,-96.3412,8,now());
 end loop;
 value:=public.tag_gateway('pause',hashes[4],jsonb_build_object('lobby',lid));
 if value->>'state'<>'idle' then raise exception 'Outsider accessed pause';end if;
 value:=public.tag_gateway('catch',hashes[1],jsonb_build_object('lobby',lid,'target',seats[2]));
 cid:=(value->'catches'->0->>'id')::uuid;
 value:=public.tag_gateway('confirm',hashes[2],jsonb_build_object('lobby',lid,'catch',cid,'accept',true));
 if (select resolved_at from tag_private.catches where id=cid) is null then raise exception 'Confirmed catch lacks actual resolution timestamp';end if;
 value:=public.tag_gateway('pause',hashes[3],jsonb_build_object('lobby',lid));
 if value->'me'->>'paused_at' is null or (value->'me'->>'consented')::bool or exists(select 1 from tag_private.players where id=seats[3] and latitude is not null)then raise exception 'Pause retained consent or coordinates';end if;
 value:=tag_private.enhanced_snapshot(lid,members[1]);
 if jsonb_array_length(value->'hints')<>0 then raise exception 'Paused/caught cached hint still visible';end if;
 value:=public.tag_gateway('location',hashes[3],jsonb_build_object('lobby',lid,'latitude',30.6123,'longitude',-96.3412,'accuracy',8,'captured_at',extract(epoch from now())));
 if not(value?'error')then raise exception 'Paused player uploaded location';end if;
 value:=public.tag_gateway('resume',hashes[3],jsonb_build_object('lobby',lid,'consent',false));
 if not(value?'error')then raise exception 'Resume accepted without consent';end if;
 value:=public.tag_gateway('resume',hashes[3],jsonb_build_object('lobby',lid,'consent',true));
 if not(value->'me'->>'consented')::bool or value->'me'->>'paused_at' is not null or (value->'me'->>'location_fresh')::bool then raise exception 'Resume reused a stale position or missed consent';end if;
 perform public.tag_gateway('pause',hashes[3],jsonb_build_object('lobby',lid));
 update tag_private.players set paused_at=now()-interval '91 seconds',seen_at=now()where id=seats[3];
 perform tag_private.cleanup();
 if(select left_at from tag_private.players where id=seats[3])is null then raise exception 'Heartbeats bypassed bounded pause';end if;
 value:=public.tag_gateway('poll',hashes[1],jsonb_build_object('lobby',lid));
 if value->>'state'<>'finished' or (value->'results'->>'total_catches')::int<>1 or jsonb_array_length(value->'results'->'players')<>3 then raise exception 'Final result statistics incorrect';end if;
 if exists(select 1 from jsonb_array_elements(value->'results'->'players')p where p?'member_id' or p?'latitude')then raise exception 'Results leak private identifiers or location';end if;
 value:=public.tag_gateway('rematch',hashes[2],jsonb_build_object('lobby',lid,'nonce',nonce));
 if value->>'code'<>'forbidden'then raise exception 'Non-host created rematch';end if;
 value:=public.tag_gateway('rematch',hashes[1],jsonb_build_object('lobby',lid,'nonce',nonce));
 nextid:=(value->'lobby'->>'id')::uuid;
 if nextid is null or nextid=lid or value->>'state'<>'lobby' or jsonb_array_length(value->'players')<>1 or (value->'me'->>'consented')::bool or (value->'me'->>'ready')::bool then raise exception 'Rematch autojoined or reused consent';end if;
 value:=public.tag_gateway('rematch',hashes[1],jsonb_build_object('lobby',lid,'nonce',nonce));
 if(value->'lobby'->>'id')::uuid<>nextid then raise exception 'Rematch retry duplicated lobby';end if;
 value:=tag_private.enhanced_snapshot(lid,members[2]);
 if value->>'rematch_code' is null then raise exception 'Former participant cannot choose rematch';end if;
 if has_function_privilege('anon','tag_private.enhanced_snapshot(uuid,uuid)','execute') or has_function_privilege('authenticated','public.tag_gateway(text,text,jsonb)','execute')then raise exception 'Private Tag RPC exposed';end if;
end $$;
select 'PASS Tag pause/reconsent/expiry, timestamped catch results, outsider denial, host-only idempotent rematch with fresh consent and private ACLs' as result;
rollback;
