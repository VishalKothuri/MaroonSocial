-- Synthetic accounts and course membership changes are rolled back.
begin;
set local role service_role;
do $$declare a text:=encode(extensions.gen_random_bytes(32),'hex');b text:=encode(extensions.gen_random_bytes(32),'hex');label text:=substr(gen_random_uuid()::text,1,8);r jsonb;s jsonb;rid text:='DDHS 3020-Fall 2026';before_count int;after_count int;item record;joined_count int:=0;begin
 if (select count(*)from course_private.catalog)<10000 then raise exception 'Catalog incomplete';end if;
 select count(*)into before_count from social_private.rooms;
 r:=public.social_gateway('register',a,jsonb_build_object('username','catalog_a_'||label,'adult',true,'network',a));
 s:=public.social_gateway('register',b,jsonb_build_object('username','catalog_b_'||label,'adult',true,'network',a));
 r:=public.course_activity(a,'Fall 2026');
 select count(*)into after_count from social_private.rooms;
 if before_count<>after_count then raise exception 'Browsing created rooms';end if;
 r:=public.social_gateway('course.join',a,'{"code":"NOTAC 999","term":"Fall 2026","title":"Fake"}');
 if r->>'code'<>'invalid'then raise exception 'Unknown catalog code accepted';end if;
 r:=public.social_gateway('course.join',a,'{"code":"DDHS 3020","term":"Fall 2026","title":"Forged title"}');
 if r->>'resource_id'<>rid then raise exception 'Professional course join failed: %',r;end if;
 if exists(select 1 from social_private.rooms where id=rid and meta->>'title'='Forged title')then raise exception 'Client title trusted';end if;
 s:=public.social_gateway('course.join',b,'{"code":"DDHS 3020","term":"Fall 2026"}');
 if s->>'resource_id'<>rid then raise exception 'Second member got a different room';end if;
 s:=public.social_gateway('course.join',b,'{"code":"DDHS 3020","term":"Fall 2026"}');
 r:=public.course_activity(a,'Fall 2026');
 if not exists(select 1 from jsonb_array_elements(r->'courses')x where x->>'code'='DDHS 3020'and(x->>'members')::int>=2)then raise exception 'Count missing';end if;
 if (r::text like '%catalog_a_%')or(r::text like '%catalog_b_%')then raise exception 'Aggregate leaked identity';end if;
 r:=public.social_gateway('room.send',a,jsonb_build_object('room_id',rid,'text','Synthetic class message'));
 if r?'error'then raise exception 'Joined member cannot chat: %',r;end if;
 r:=public.social_gateway('course.leave',a,jsonb_build_object('room_id',rid));
 s:=public.social_gateway('course.leave',b,jsonb_build_object('room_id',rid));
 r:=public.social_gateway('room.send',a,jsonb_build_object('room_id',rid,'text','Should fail'));
 if r->>'code'<>'forbidden'then raise exception 'Former member still allowed to send';end if;
 if not exists(select 1 from social_private.messages where room=rid and body='Synthetic class message')then raise exception 'Leaving lost class history';end if;
for item in select code from course_private.catalog where not exists(select 1 from social_private.rooms where id=code||'-Fall 2026')order by code limit 21 loop
 joined_count:=joined_count+1;
 r:=public.social_gateway('course.join',b,jsonb_build_object('code',item.code,'term','Fall 2026'));
 if joined_count<=20 and r?'error'then raise exception 'Early cap: %',r;end if;
 if joined_count=21 then
  if r->>'code'<>'full'then raise exception 'Course membership cap bypassed';end if;
  if exists(select 1 from social_private.rooms where id=item.code||'-Fall 2026')then raise exception 'Rejected join created an empty room';end if;
 end if;
end loop;
end $$;
rollback;
