-- APNs tokens and jobs are server-only. Payloads contain generic text and scoped
-- destinations, never message bodies, sender names, emails or global member IDs.
create schema push_private;
revoke all on schema push_private from public,anon,authenticated;
grant usage on schema push_private to service_role;
create table push_private.devices(id uuid primary key,member uuid not null references social_private.members on delete cascade,secret_hash text not null check(secret_hash~'^[a-f0-9]{64}$'),token text not null check(token~'^[a-f0-9]{32,512}$'),environment text not null check(environment in('sandbox','production')),auth_session uuid,version integer not null default 1,enabled boolean not null default true,updated_at timestamptz not null default now(),unique(environment,token));
create index push_devices_member on push_private.devices(member);
create index push_devices_session on push_private.devices(auth_session)where auth_session is not null;
create table push_private.installations(id uuid primary key,secret_hash text not null check(secret_hash~'^[a-f0-9]{64}$'),sequence bigint not null check(sequence>0),updated_at timestamptz not null default now());
create table push_private.unlink_limits(network text primary key,window_start timestamptz not null,count integer not null);
create table push_private.preferences(member uuid primary key references social_private.members on delete cascade,enabled boolean not null default true,messages boolean not null default true,games boolean not null default true,calls boolean not null default true,activity boolean not null default true);
create table push_private.jobs(id uuid primary key default gen_random_uuid(),recipient uuid not null references social_private.members on delete cascade,actor uuid references social_private.members on delete set null,kind text not null check(kind in('message','request','game_invite','game_turn','call','group_call','activity')),room text references social_private.rooms on delete cascade,reference uuid not null,revision bigint not null default 0,created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '1 day',unique(recipient,kind,reference,revision));
create index push_jobs_expiry on push_private.jobs(expires_at);
create index push_jobs_recipient on push_private.jobs(recipient,created_at);
create index push_jobs_room on push_private.jobs(room)where room is not null;
create index push_jobs_actor on push_private.jobs(actor)where actor is not null;
create table push_private.deliveries(job uuid references push_private.jobs on delete cascade,device uuid references push_private.devices on delete cascade,state text not null default 'pending'check(state in('pending','delivered','dropped')),attempts integer not null default 0,available_at timestamptz not null default now(),lease uuid,leased_at timestamptz,leased_version integer,last_status integer,primary key(job,device));
create index push_delivery_device on push_private.deliveries(device);
create index push_delivery_pending on push_private.deliveries(available_at)where state='pending';
do $$declare t text;begin foreach t in array array['devices','installations','unlink_limits','preferences','jobs','deliveries']loop execute format('alter table push_private.%I enable row level security',t);execute format('create policy server_only on push_private.%I to service_role using(true)with check(true)',t);end loop;end $$;
revoke all on all tables in schema push_private from public,anon,authenticated;
grant all on all tables in schema push_private to service_role;

create function public.push_devices(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;did uuid;existing push_private.devices;row_preferences push_private.preferences;installation_value push_private.installations;sequence_value bigint;attempts_value integer;
begin
 if p_action<>'unregister'then me:=social_private.require_account(p_hash);end if;
 if p_action in('register','unregister')then
  did:=(p_input->>'installation_id')::uuid;sequence_value:=(p_input->>'sequence')::bigint;
  if did is null or sequence_value is null or sequence_value<=0 or coalesce(p_input->>'secret_hash','')!~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid installation proof.';end if;
  perform pg_advisory_xact_lock(hashtextextended('push:'||did::text,0));
  select *into installation_value from push_private.installations where id=did for update;
  if installation_value.id is not null and installation_value.secret_hash<>p_input->>'secret_hash'then raise exception 'forbidden:This installation could not be verified.';end if;
  if installation_value.id is not null and sequence_value<=installation_value.sequence then return jsonb_build_object('registered',false,'unregistered',p_action='unregister');end if;
  if p_action='unregister'and installation_value.id is null then
   if coalesce(p_input->>'network_hash','')!~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid installation request.';end if;
   insert into push_private.unlink_limits(network,window_start,count)values(p_input->>'network_hash',now(),1)on conflict(network)do update set window_start=case when push_private.unlink_limits.window_start<now()-interval '1 minute'then now()else push_private.unlink_limits.window_start end,count=case when push_private.unlink_limits.window_start<now()-interval '1 minute'then 1 else push_private.unlink_limits.count+1 end returning count into attempts_value;
   if attempts_value>10 then return jsonb_build_object('error','Please retry device cleanup in a minute.','code','rate_limit');end if;
  end if;
  insert into push_private.installations(id,secret_hash,sequence)values(did,p_input->>'secret_hash',sequence_value)on conflict(id)do update set sequence=greatest(push_private.installations.sequence,excluded.sequence),updated_at=now();
  if p_action='unregister'then delete from push_private.devices where id=did;return jsonb_build_object('unregistered',true);end if;
 end if;
 insert into push_private.preferences(member)values(me)on conflict do nothing;
 if p_action='register'then
  did:=(p_input->>'installation_id')::uuid;
  if did is null or coalesce(p_input->>'secret_hash','')!~'^[a-f0-9]{64}$'or coalesce(p_input->>'token','')!~'^[a-f0-9]{32,512}$'or p_input->>'environment'not in('sandbox','production')then raise exception 'invalid:Invalid device registration.';end if;
  select *into existing from push_private.devices where id=did for update;
  if existing.id is not null and existing.secret_hash<>p_input->>'secret_hash'then raise exception 'forbidden:This installation could not be verified.';end if;
  if exists(select 1 from push_private.devices where environment=p_input->>'environment'and token=p_input->>'token'and id<>did)then raise exception 'conflict:This device is already registered. Disable notifications on its previous installation first.';end if;
  if existing.id is null and(select count(*)from push_private.devices where member=me)>=10 then raise exception 'rate_limit:Up to ten devices can receive notifications.';end if;
  insert into push_private.devices(id,member,secret_hash,token,environment,auth_session)values(did,me,p_input->>'secret_hash',p_input->>'token',p_input->>'environment',(p_input->>'auth_session')::uuid)
  on conflict(id)do update set member=me,token=excluded.token,environment=excluded.environment,auth_session=excluded.auth_session,enabled=true,version=push_private.devices.version+1,updated_at=now();
  -- Never deliver a previous account's queued item to the new account on this installation.
  delete from push_private.deliveries d using push_private.jobs j where d.device=did and j.id=d.job and j.recipient<>me;
 elsif p_action='preferences.set'then
  if jsonb_typeof(p_input->'enabled')is distinct from 'boolean'or jsonb_typeof(p_input->'messages')is distinct from 'boolean'or jsonb_typeof(p_input->'games')is distinct from 'boolean'or jsonb_typeof(p_input->'calls')is distinct from 'boolean'or jsonb_typeof(p_input->'activity')is distinct from 'boolean'then raise exception 'invalid:Choose notification preferences.';end if;
  update push_private.preferences set enabled=(p_input->>'enabled')::boolean,messages=(p_input->>'messages')::boolean,games=(p_input->>'games')::boolean,calls=(p_input->>'calls')::boolean,activity=(p_input->>'activity')::boolean where member=me;
 elsif p_action<>'status'then raise exception 'invalid:Unknown notification action.';end if;
 select *into row_preferences from push_private.preferences where member=me;
 return jsonb_build_object('preferences',to_jsonb(row_preferences)-'member','registered',exists(select 1 from push_private.devices where member=me and id=(p_input->>'installation_id')::uuid and enabled));
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation or check_violation or not_null_violation then return jsonb_build_object('error','Invalid notification request.','code','invalid');
end $$;
create function push_private.enqueue(p_recipient uuid,p_actor uuid,p_kind text,p_room text,p_reference uuid,p_revision bigint default 0)returns void language plpgsql security invoker set search_path=''as $$begin
 if p_reference is null or p_recipient is null or p_recipient=p_actor or exists(select 1 from social_private.members where id=p_recipient and banned)or social_private.blocked(p_recipient,p_actor)then return;end if;
 insert into push_private.jobs(recipient,actor,kind,room,reference,revision,expires_at)values(p_recipient,p_actor,p_kind,p_room,p_reference,p_revision,now()+case when p_kind in('call','group_call')then interval '60 seconds'else interval '1 day'end)on conflict do nothing;
end $$;
create function push_private.on_message()returns trigger language plpgsql security invoker set search_path=''as $$declare rm record;begin
 if new.deleted or new.author is null or new.game_session_id is not null then return new;end if;
 for rm in select member,status from social_private.room_members where room=new.room and member<>new.author and status in('accepted','invited')loop
  perform push_private.enqueue(rm.member,new.author,case when rm.status='invited'then 'request'else 'message'end,new.room,new.id);
 end loop;return new;end $$;
create trigger push_message after insert on social_private.messages for each row execute function push_private.on_message();
create function push_private.on_group_invite()returns trigger language plpgsql security invoker set search_path=''as $$declare sender uuid;begin
 if new.status='invited'and(tg_op='INSERT'or old.status<>'invited')and exists(select 1 from social_private.rooms where id=new.room and kind='group')then
  select member into sender from social_private.room_members where room=new.room and role='owner'and status='accepted';
  perform push_private.enqueue(new.member,sender,'request',new.room,(select invitation_key from community_private.invitations where room=new.room and member=new.member));
 end if;return new;end $$;
create trigger push_group_invite after insert or update of status on social_private.room_members for each row execute function push_private.on_group_invite();
create function push_private.on_game()returns trigger language plpgsql security invoker set search_path=''as $$declare recipient_id uuid;actor_id uuid;begin
 if new.status='pending'and tg_op='INSERT'then perform push_private.enqueue(new.opponent,new.inviter,'game_invite',new.room,new.id,new.version);
 elsif new.status='active'and(tg_op='INSERT'or old.status is distinct from new.status or old.version<>new.version)then
  recipient_id:=case when(new.state->>'turn')::integer=0 then new.inviter else new.opponent end;actor_id:=case when recipient_id=new.inviter then new.opponent else new.inviter end;
  perform push_private.enqueue(recipient_id,actor_id,'game_turn',new.room,new.id,new.version);
 end if;return new;end $$;
create trigger push_game after insert or update on games_private.sessions for each row execute function push_private.on_game();
create function push_private.on_call()returns trigger language plpgsql security invoker set search_path=''as $$begin
 perform push_private.enqueue(new.callee,new.caller,'call',new.room,new.id);return new;end $$;
create trigger push_call after insert on social_private.calls for each row execute function push_private.on_call();
create function push_private.on_group_call()returns trigger language plpgsql security invoker set search_path=''as $$declare peer uuid;begin
 for peer in select member from social_private.room_members where room=new.room and member<>new.creator and status='accepted'loop perform push_private.enqueue(peer,new.creator,'group_call',new.room,new.id);end loop;return new;end $$;
create trigger push_group_call after insert on group_call_private.calls for each row execute function push_private.on_group_call();
create function push_private.on_activity()returns trigger language plpgsql security invoker set search_path=''as $$begin
 perform push_private.enqueue(new.recipient,null,'activity',null,new.id);return new;end $$;
create trigger push_activity after insert on social_private.notifications for each row execute function push_private.on_activity();
create function push_private.on_logout()returns trigger language plpgsql security invoker set search_path=''as $$begin delete from push_private.devices where auth_session=new.session_id;return new;end $$;
create trigger push_logout after insert on social_auth_private.revoked_sessions for each row execute function push_private.on_logout();

create function push_private.deliverable(j push_private.jobs)returns boolean language plpgsql stable security invoker set search_path=''as $$declare pref push_private.preferences;rm social_private.room_members;g games_private.sessions;begin
 if j.expires_at<=now()or not exists(select 1 from social_private.members where id=j.recipient and not banned)or(j.actor is not null and exists(select 1 from social_private.members where id=j.actor and banned))or social_private.blocked(j.recipient,j.actor)then return false;end if;
 if(select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships where member=j.recipient and expires_at>now())then return false;end if;
 select *into pref from push_private.preferences where member=j.recipient;
 if pref.member is null or not pref.enabled then return false;end if;
 if j.kind='activity'then return pref.activity and exists(select 1 from social_private.notification_items(j.recipient)n where n.id=j.reference and not n.is_read);end if;
 select *into rm from social_private.room_members where room=j.room and member=j.recipient;
 if rm.member is null or(rm.muted_until is not null and rm.muted_until>now())or not exists(select 1 from social_private.rooms where id=j.room and status in('active','pending'))then return false;end if;
 if j.kind='request'then return pref.messages and rm.status='invited'and(exists(select 1 from community_private.invitations where room=j.room and member=j.recipient and invitation_key=j.reference)or exists(select 1 from social_private.messages m join social_private.rooms r on r.id=m.room where m.id=j.reference and m.room=j.room and not m.deleted and r.kind='dm'));end if;
 if rm.status<>'accepted'or not social_private.can_read_room(j.recipient,j.room)then return false;end if;
 if j.kind='message'then return pref.messages and exists(select 1 from social_private.messages where id=j.reference and not deleted and seq>rm.last_read);end if;
 if j.kind in('game_invite','game_turn')then
  if not pref.games then return false;end if;
  select *into g from games_private.sessions where id=j.reference and room=j.room and j.recipient in(inviter,opponent);
  if g.id is null or not social_private.can_message(g.inviter,g.room)or not social_private.can_message(g.opponent,g.room)or social_private.blocked(g.inviter,g.opponent)then return false;end if;
  if j.kind='game_invite'then return g.status='pending'and g.opponent=j.recipient;end if;
  return g.status='active'and g.version=j.revision and j.recipient=case when(g.state->>'turn')::integer=0 then g.inviter else g.opponent end;
 elsif j.kind='call'then return pref.calls and exists(select 1 from social_private.calls where id=j.reference and state='ringing'and callee=j.recipient and created_at>now()-interval '60 seconds'and social_private.can_message(caller,room)and social_private.can_message(callee,room));
 elsif j.kind='group_call'then return pref.calls and exists(select 1 from group_call_private.calls c where c.id=j.reference and c.ended_at is null and c.ends_at>now()and not exists(select 1 from group_call_private.peers p where p.call=c.id and p.member=j.recipient));end if;
 return false;
end $$;
create function public.push_delivery(p_action text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$declare row_delivery push_private.deliveries;j push_private.jobs;device_value push_private.devices;items jsonb:='[]';status_value integer;lease_value uuid;begin
 if p_action='take'then
  delete from push_private.jobs where expires_at<=now();delete from push_private.unlink_limits where window_start<now()-interval '1 day';delete from push_private.installations where updated_at<now()-interval '90 days'and not exists(select 1 from push_private.devices where id=push_private.installations.id);delete from push_private.devices where updated_at<now()-interval '90 days';
  insert into push_private.deliveries(job,device)select j.id,d.id from push_private.jobs j join push_private.devices d on d.member=j.recipient and d.enabled where j.expires_at>now()on conflict do nothing;
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
revoke all on all functions in schema push_private from public,anon,authenticated;
grant execute on all functions in schema push_private to service_role;
revoke all on function public.push_devices(text,text,jsonb),public.push_delivery(text,jsonb)from public,anon,authenticated;
grant execute on function public.push_devices(text,text,jsonb),public.push_delivery(text,jsonb)to service_role;
-- No outbound requests until the owner installs the matching worker secret.
select cron.schedule('maroon-push-delivery','* * * * *',$job$select net.http_post(url:=(select decrypted_secret from vault.decrypted_secrets where name='maroon_project_url')||'/functions/v1/push-delivery',headers:=jsonb_build_object('Content-Type','application/json','x-worker-secret',(select decrypted_secret from vault.decrypted_secrets where name='maroon_push_worker')),body:='{}'::jsonb,timeout_milliseconds:=50000)where exists(select 1 from vault.decrypted_secrets where name='maroon_push_worker');$job$);
