create or replace function public.push_delivery(p_action text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$declare row_delivery push_private.deliveries;j push_private.jobs;device_value push_private.devices;items jsonb:='[]';status_value integer;lease_value uuid;begin
 if p_action='take'then
  delete from push_private.jobs where expires_at<=now();delete from push_private.unlink_limits where window_start<now()-interval '1 day';delete from push_private.installations where updated_at<now()-interval '90 days'and not exists(select 1 from push_private.devices where id=push_private.installations.id);delete from push_private.devices where updated_at<now()-interval '90 days';
  insert into push_private.deliveries(job,device)select source_job.id,d.id from push_private.jobs source_job join push_private.devices d on d.member=source_job.recipient and d.enabled where source_job.expires_at>now()on conflict do nothing;
  for row_delivery in select *from push_private.deliveries where state='pending'and available_at<=now()and(lease is null or leased_at<now()-interval '2 minutes')order by available_at limit least(50,greatest(1,coalesce((p_input->>'limit')::integer,25)))for update skip locked loop
   select *into j from push_private.jobs where id=row_delivery.job;select *into device_value from push_private.devices where id=row_delivery.device;
   if device_value.member is distinct from j.recipient or not device_value.enabled or(device_value.auth_session is not null and not exists(select 1 from auth.sessions where id=device_value.auth_session and(not_after is null or not_after>now())))or not push_private.deliverable(j)then update push_private.deliveries set state='dropped',lease=null where job=row_delivery.job and device=row_delivery.device;continue;end if;
   lease_value:=gen_random_uuid();update push_private.deliveries set lease=lease_value,leased_at=now(),leased_version=device_value.version,attempts=attempts+1 where job=row_delivery.job and device=row_delivery.device;
   items:=items||jsonb_build_array(jsonb_build_object('job',j.id,'device',device_value.id,'lease',lease_value,'token',device_value.token,'environment',device_value.environment,'kind',j.kind,'room_id',j.room,'reference',j.reference,'expires_at',extract(epoch from j.expires_at)));
  end loop;return jsonb_build_object('items',items);
 elsif p_action='complete'then
  select *into row_delivery from push_private.deliveries where job=(p_input->>'job')::uuid and device=(p_input->>'device')::uuid and lease=(p_input->>'lease')::uuid for update;
  if row_delivery.job is null then return jsonb_build_object('completed',false);end if;
  status_value:=(p_input->>'status')::integer;
  if status_value in(410,400)and p_input->>'reason'in('Unregistered','BadDeviceToken','DeviceTokenNotForTopic')then update push_private.devices set enabled=false where id=row_delivery.device and version=row_delivery.leased_version;end if;
  update push_private.deliveries set state=case when status_value=200 then 'delivered'when(status_value in(400,410)and p_input->>'reason'in('Unregistered','BadDeviceToken','DeviceTokenNotForTopic'))or attempts>=8 then 'dropped'else 'pending'end,last_status=status_value,lease=null,available_at=now()+make_interval(secs=>least(3600,10*power(2,least(attempts,8))::integer))where job=row_delivery.job and device=row_delivery.device;
  return jsonb_build_object('completed',true);
 end if;raise exception 'Invalid delivery action';end $$;
alter table push_private.jobs add column read_at timestamptz;
create function push_private.route(j push_private.jobs)returns jsonb language plpgsql stable security invoker set search_path=''as $$declare post_id uuid;begin
 if j.id is null or not exists(select 1 from social_private.members where id=j.recipient and not banned)or(j.actor is not null and(exists(select 1 from social_private.members where id=j.actor and banned)or social_private.blocked(j.recipient,j.actor)))then return null;end if;
 if j.kind='activity'then select n.post_id into post_id from social_private.notification_items(j.recipient)n where n.id=j.reference;if not found then return null;end if;return jsonb_build_object('kind',j.kind,'postID',post_id);end if;
 if not exists(select 1 from social_private.rooms r join social_private.room_members rm on rm.room=r.id where r.id=j.room and r.status in('active','pending')and rm.member=j.recipient and rm.status in('accepted','invited'))then return null;end if;
 if j.kind='request'then
  if not(exists(select 1 from community_private.invitations where room=j.room and member=j.recipient and invitation_key=j.reference)or exists(select 1 from social_private.messages m join social_private.rooms r on r.id=m.room where m.id=j.reference and m.room=j.room and not m.deleted and r.kind='dm'))then return null;end if;
 elsif not social_private.can_read_room(j.recipient,j.room)then return null;end if;
 if j.kind in('game_invite','game_turn')and not exists(select 1 from games_private.sessions g where g.id=j.reference and g.room=j.room and j.recipient in(g.inviter,g.opponent)and social_private.can_message(g.inviter,g.room)and social_private.can_message(g.opponent,g.room)and not social_private.blocked(g.inviter,g.opponent))then return null;end if;
 return jsonb_build_object('kind',j.kind,'roomID',j.room,'gameID',case when j.kind in('game_invite','game_turn')then j.reference else null end);
end $$;
alter function public.push_devices(text,text,jsonb)rename to push_devices_before_routes;
revoke all on function public.push_devices_before_routes(text,text,jsonb)from public,anon,authenticated;
create function public.push_devices(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$declare me uuid;j push_private.jobs;result jsonb;begin
 if p_action not in('resolve','inbox','read')then return public.push_devices_before_routes(p_action,p_hash,p_input);end if;
 me:=social_private.require_account(p_hash);
 if p_action='resolve'then
  select *into j from push_private.jobs where recipient=me and reference=(p_input->>'reference')::uuid and kind=p_input->>'kind'order by created_at desc limit 1;
  result:=push_private.route(j);
  if result is null then raise exception 'unavailable:This notification is no longer available.';end if;
  return result;
 elsif p_action='read'then
  update push_private.jobs set read_at=coalesce(read_at,now())where id=(p_input->>'id')::uuid and recipient=me and kind in('game_turn','game_invite');return jsonb_build_object('read',true);
 else
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'kind',kind,'title',case when kind='game_turn'then 'Your turn'else 'Game invitation'end,'roomID',room,'gameID',reference,'created',extract(epoch from created_at),'read',read_at is not null)order by created_at desc),'[]')into result from(select j.*from push_private.jobs j where recipient=me and kind in('game_turn','game_invite')and expires_at>now()and push_private.route(j)is not null and(read_at is not null or push_private.deliverable(j))order by created_at desc limit 50)x;
  return jsonb_build_object('items',result);
 end if;
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid notification destination.','code','invalid');end $$;
revoke all on function push_private.route(push_private.jobs),public.push_devices(text,text,jsonb)from public,anon,authenticated;
grant execute on function push_private.route(push_private.jobs),public.push_devices(text,text,jsonb)to service_role;
