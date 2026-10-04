-- All fixtures, cache changes and memberships are rolled back.
begin;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');
 hb text:=encode(extensions.gen_random_bytes(32),'hex');
 aid uuid;bid uuid;result jsonb;v_event_id text:='campus-regression-'||gen_random_uuid();
 sports_id text:='sports-regression-'||gen_random_uuid();
 v_room text;now_epoch double precision:=extract(epoch from now());
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'evt_a_'||substr(ha,1,8),true,ha)returning id into aid;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'evt_b_'||substr(hb,1,8),true,hb)returning id into bid;
 update public.campus_cache set payload=jsonb_set(payload,'{events}',coalesce(payload->'events','[]'::jsonb)||jsonb_build_array(
  jsonb_build_object('id',v_event_id,'category','Campus','title','Synthetic campus event','starts',now_epoch+3600),
  jsonb_build_object('id',sports_id,'category','Sports','title','Synthetic sports event','starts',now_epoch+1200),
  jsonb_build_object('id',sports_id||'-future','category','Sports','title','Future sports event','starts',now_epoch+1860),
  jsonb_build_object('id',sports_id||'-cancelled','category','Sports','title','Cancelled event','starts',now_epoch+60,'cancelled',true),
  jsonb_build_object('id',sports_id||'-ended','category','Sports','title','Ended event','starts',now_epoch-36000,'ends',now_epoch-32400)
 ))where id='current';
 -- Match the Edge Function's actual RPC execution role.
 perform set_config('role','service_role',true);
 result:=public.social_gateway('save_event',ha,jsonb_build_object('event_id',v_event_id,'saved',true));
 if result?'error'or not(result->'snapshot'->'savedEvents'?v_event_id)then raise exception 'Save did not persist %',result;end if;
 result:=public.social_gateway('save_event',ha,jsonb_build_object('event_id',v_event_id,'saved',true));
 if result?'error'or(select count(*)from social_private.saved_events saved where saved.member=aid and saved.event_id=v_event_id)<>1 then raise exception 'Duplicate bookmark retry failed';end if;
 result:=public.social_gateway('snapshot',hb,'{}');
 if result->'snapshot'->'savedEvents'?v_event_id then raise exception 'Bookmark visible to another account';end if;
 result:=public.social_gateway('save_event',hb,jsonb_build_object('event_id',v_event_id,'saved',false));
 if not exists(select 1 from social_private.saved_events saved where saved.member=aid and saved.event_id=v_event_id)then raise exception 'Another account removed bookmark';end if;
 result:=public.social_gateway('save_event',ha,jsonb_build_object('event_id',v_event_id,'saved',false));
 if result?'error'or result->'snapshot'->'savedEvents'?v_event_id then raise exception 'Unsave did not persist';end if;
 result:=public.social_gateway('save_event',ha,jsonb_build_object('event_id','missing-'||v_event_id,'saved',true));
 if result->>'code'<>'invalid'then raise exception 'Unknown event was saved';end if;
 insert into social_private.saved_events values(aid,'expired-'||v_event_id);
 result:=public.social_gateway('save_event',ha,jsonb_build_object('event_id','expired-'||v_event_id,'saved',false));
 if result?'error'or exists(select 1 from social_private.saved_events saved where saved.member=aid and saved.event_id='expired-'||v_event_id)then raise exception 'Expired event could not be unsaved';end if;
 result:=public.social_gateway('join_sports',ha,jsonb_build_object('event_id',sports_id));v_room:=result->>'resource_id';
 if v_room is null or v_room<>'sports:'||sports_id then raise exception 'Pregame room failed %',result;end if;
 result:=public.social_gateway('join_sports',ha,jsonb_build_object('event_id',sports_id));
 if result->>'resource_id'<>v_room then raise exception 'Repeated sports join created another room';end if;
 result:=public.social_gateway('sports.join',hb,jsonb_build_object('event_id',sports_id));
 if result->>'resource_id'<>v_room or(select count(*)from social_private.room_members where room_members.room=v_room)<>2 then raise exception 'Two members did not join canonical room';end if;
 for v_event_id in select unnest(array[sports_id||'-future',sports_id||'-cancelled',sports_id||'-ended',v_event_id,'unknown-event'])loop
  result:=public.social_gateway('join_sports',ha,jsonb_build_object('event_id',v_event_id));
  if result->>'code'<>'forbidden'then raise exception 'Sports eligibility bypass for %: %',v_event_id,result;end if;
 end loop;
 perform set_config('role','none',true);
end $$;
select 'PASS: service-role save/unsave, idempotency, private bookmarks, missing/expired events, sports pregame gate/cancellation/expiry and canonical two-client room' as result;
rollback;
