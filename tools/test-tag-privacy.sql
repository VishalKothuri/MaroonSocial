-- Synthetic coordinates only. Rollback keeps this check isolated from real accounts.
begin;
do $$
declare v_members uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 v_seats uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 v_lobby uuid:=gen_random_uuid(); row tag_private.players; view jsonb; n int;
begin
 for n in 1..3 loop
  insert into social_private.members(id,token_hash,username,adult,network_hash)
  values(v_members[n],encode(extensions.gen_random_bytes(32),'hex'),'tagqa_'||substr(replace(v_members[n]::text,'-',''),1,12),true,'transactional-fixture');
 end loop;
 insert into tag_private.lobbies(id,code,host_id,request_id,title,area,capacity,duration_seconds,hide_seconds,radius_m,state,seek_at,ends_at)
 values(v_lobby,upper(substr(replace(v_lobby::text,'-',''),1,8)),v_members[1],gen_random_uuid(),'Transactional fixture','Synthetic test area',3,300,30,150,'seeking',now()-interval '1 minute',now()+interval '4 minutes');
 for n in 1..3 loop
  insert into tag_private.players(id,lobby_id,member_id,role,consented,ready,latitude,longitude,accuracy,location_at)
  values(v_seats[n],v_lobby,v_members[n],case when n=1 then 'seeker' else 'hider' end,true,true,30.6123,-96.3412,8,now());
 end loop;
 view:=tag_private.snapshot(v_lobby,v_members[1]);
 if jsonb_array_length(view->'hints')<>2 then raise exception 'Expected two synthetic hints'; end if;
 update social_private.members set banned=true where id=v_members[2];
 view:=tag_private.snapshot(v_lobby,v_members[1]);
 if jsonb_array_length(view->'hints')<>1 then raise exception 'Suspended cached hint was exposed'; end if;
 perform tag_private.cleanup();
 select * into row from tag_private.players where id=v_seats[2];
 if row.left_at is null or row.latitude is not null or row.longitude is not null or row.location_at is not null or row.consented or row.ready then raise exception 'Suspended player retained location or consent'; end if;
 if (select state from tag_private.lobbies where id=v_lobby)<>'seeking' then raise exception 'Remaining valid teams should keep playing'; end if;
 update tag_private.players set caught=true where id=v_seats[3];
 view:=tag_private.snapshot(v_lobby,v_members[1]);
 if jsonb_array_length(view->'hints')<>0 then raise exception 'Caught cached hint was exposed'; end if;
 update tag_private.players set caught=false,location_at=now()-interval '70 seconds' where id=v_seats[3];
 perform tag_private.cleanup();
 if (select latitude from tag_private.players where id=v_seats[3]) is not null then raise exception 'Expired position retained'; end if;
 if (select state from tag_private.lobbies where id=v_lobby)<>'seeking' then raise exception 'Location expiry should not end active match'; end if;
 update tag_private.players set seen_at=now()-interval '2 minutes' where id=v_seats[1];
 perform tag_private.cleanup();
 if (select state from tag_private.lobbies where id=v_lobby)<>'finished' then raise exception 'Abandoned seeker failed to end match'; end if;
end $$;
select 'PASS suspended/caught cached hints, immediate position removal, stale location expiry, abandoned match cleanup' as result;
rollback;
