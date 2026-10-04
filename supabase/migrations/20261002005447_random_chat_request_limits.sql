-- Keep untrusted and over-quota requests off the shared matchmaking lock.
alter table random_private.participants
  add column request_window timestamptz not null default now(),
  add column request_count integer not null default 0,
  add column burst_window timestamptz not null default now(),
  add column burst_count integer not null default 0;

create or replace function public.random_chat_gateway(p_action text, p_hash text, p_input jsonb default '{}'::jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  me random_private.participants;
  other_id uuid;
  current_room random_private.rooms;
  mode_value text := coalesce(p_input->>'mode','text');
  msg text;
  nonce_value uuid;
  supplied_room uuid;
  report_value uuid;
  state_value text;
  messages_value jsonb := '[]'::jsonb;
  signals_value jsonb := '[]'::jsonb;
  after_signal bigint := 0;
  request_time timestamptz := clock_timestamp();
begin
  if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then
    return jsonb_build_object('error','Session expired. Start a new chat.','code','unauthorized');
  end if;
  if p_action is null or p_action not in ('register','poll','join','next','leave','send','block','report','signal') then
    return jsonb_build_object('error','Unknown chat action.','code','invalid');
  end if;
  -- Unknown tokens cannot acquire the global match lock or trigger cleanup work.
  -- The token_hash unique index makes this rejection one bounded indexed lookup.
  if p_action='register' then
    if coalesce(p_input->>'network','') !~ '^[a-f0-9]{64}$' then
      return jsonb_build_object('error','Unable to establish a session.','code','invalid');
    end if;
    if (select count(*) from random_private.participants where network_hash=p_input->>'network'
      and created_at > request_time - interval '1 hour') >= 12 then
      return jsonb_build_object('error','Too many new sessions. Please try again in an hour.','code','rate_limit');
    end if;
  else
    select * into me from random_private.participants where token_hash=p_hash;
    if me.id is null or me.seen_at < request_time - interval '30 days' then
      return jsonb_build_object('error','Your guest session expired. Start a new chat.','code','unauthorized');
    end if;
    if me.banned then
      return jsonb_build_object('error','This guest session is suspended.','code','forbidden');
    end if;
    if (me.request_window > request_time - interval '1 minute' and me.request_count >= 600)
      or (me.burst_window > request_time - interval '1 second' and me.burst_count >= 40) then
      return jsonb_build_object('error','Too many chat requests. Please wait a moment.','code','rate_limit');
    end if;
  end if;
  -- Serialize only requests that have passed authentication and the fast quota check.
  -- Recheck counters under the lock so concurrent calls cannot exceed the quota.
  perform pg_advisory_xact_lock(77330001);
  request_time := clock_timestamp();
  if p_action='register' then
    if (select count(*) from random_private.participants where network_hash=p_input->>'network'
      and created_at > request_time - interval '1 hour') >= 12 then
      return jsonb_build_object('error','Too many new sessions. Please try again in an hour.','code','rate_limit');
    end if;
    insert into random_private.participants (token_hash, network_hash)
      values (p_hash, p_input->>'network') returning * into me;
  else
    select * into me from random_private.participants where token_hash=p_hash;
    if me.id is null or me.seen_at < request_time - interval '30 days' then
      return jsonb_build_object('error','Your guest session expired. Start a new chat.','code','unauthorized');
    end if;
    if me.banned then
      return jsonb_build_object('error','This guest session is suspended.','code','forbidden');
    end if;
    if (me.request_window > request_time - interval '1 minute' and me.request_count >= 600)
      or (me.burst_window > request_time - interval '1 second' and me.burst_count >= 40) then
      return jsonb_build_object('error','Too many chat requests. Please wait a moment.','code','rate_limit');
    end if;
  end if;
  update random_private.participants set
    request_count=case when request_window <= request_time-interval '1 minute' then 1 else request_count+1 end,
    request_window=case when request_window <= request_time-interval '1 minute' then request_time else request_window end,
    burst_count=case when burst_window <= request_time-interval '1 second' then 1 else burst_count+1 end,
    burst_window=case when burst_window <= request_time-interval '1 second' then request_time else burst_window end
    where id=me.id;
  if p_action in ('leave','send','signal','next','block','report') and p_input ? 'instance'
    and me.active_instance is not null and me.active_instance is distinct from (p_input->>'instance')::uuid then
    return jsonb_build_object('error','This conversation is active on another screen.','code','stale_instance');
  end if;
  if p_action='report' and char_length(btrim(coalesce(p_input->>'reason',''))) not between 1 and 500 then
    return jsonb_build_object('error','Choose a report reason.','code','invalid');
  end if;
  if p_action='next' and me.joined_at > now() - interval '1 second' then
    return jsonb_build_object('error','One moment before finding someone new.','code','rate_limit');
  end if;
  select * into current_room from random_private.rooms where (a=me.id or b=me.id)
    order by created_at desc limit 1;
  -- Expire only this caller's session synchronously. Cron owns bulk retention cleanup.
  if me.seen_at < request_time-interval '45 seconds' then
    delete from random_private.queue where participant=me.id;
  end if;
  if current_room.id is not null and current_room.ended_at is null and exists (
    select 1 from random_private.participants p where p.id in (current_room.a,current_room.b)
      and p.seen_at < request_time-interval '45 seconds') then
    update random_private.rooms set ended_at=request_time,end_reason='disconnected'
      where id=current_room.id returning * into current_room;
  end if;
  update random_private.participants set seen_at=request_time where id=me.id;
  if p_input ? 'room' and p_input->>'room' <> '' then
    supplied_room := (p_input->>'room')::uuid;
  end if;
  if p_action in ('send','signal','block','report') and
      (current_room.id is null or supplied_room is distinct from current_room.id) then
    return jsonb_build_object('error','That conversation has ended.','code','ended');
  end if;
  if p_action in ('leave','next','block','report') then
    -- A delayed leave from a previous screen must not end a newer conversation.
    if supplied_room is not null and current_room.id is distinct from supplied_room then
      return jsonb_build_object('error','That conversation has ended.','code','ended');
    end if;
    delete from random_private.queue where participant=me.id;
    if current_room.id is not null then
      other_id := case when current_room.a=me.id then current_room.b else current_room.a end;
      if p_action in ('block','report') then
        insert into random_private.blocks (blocker,blocked) values (me.id,other_id) on conflict do nothing;
      end if;
      if p_action='report' then
        msg := btrim(coalesce(p_input->>'reason',''));
        if char_length(msg) not between 1 and 500 then
          return jsonb_build_object('error','Choose a report reason.','code','invalid');
        end if;
        insert into random_private.reports(room,reporter,reported,reason,evidence)
        values (current_room.id,me.id,other_id,msg,
          (select coalesce(jsonb_agg(to_jsonb(e)),'[]'::jsonb) from (
            select sender,body,created_at from random_private.messages
            where room=current_room.id order by id desc limit 50) e))
        on conflict (room,reporter) do update set reason=excluded.reason
        returning id into report_value;
      end if;
      update random_private.rooms set ended_at=coalesce(ended_at,now()),
        end_reason=coalesce(end_reason,case when p_action in ('block','report') then 'ended' else 'left' end)
        where id=current_room.id returning * into current_room;
    end if;
  end if;
  if p_action in ('join','next') then
    if mode_value not in ('text','voice','video') then
      return jsonb_build_object('error','Unknown conversation type.','code','invalid');
    end if;
    -- Explicitly joining adopts an existing conversation on this view instance too.
    if p_action='join' then
      update random_private.participants set active_instance=(p_input->>'instance')::uuid where id=me.id;
    end if;
    if current_room.id is null or current_room.ended_at is not null then
      if me.joined_at > now() - interval '1 second' then
        return jsonb_build_object('error','One moment before finding someone new.','code','rate_limit');
      end if;
      update random_private.participants set joined_at=now(), active_instance=(p_input->>'instance')::uuid where id=me.id;
      insert into random_private.queue(participant,mode) values(me.id,mode_value)
        on conflict(participant) do update set mode=excluded.mode,joined_at=now();
      select q.participant into other_id from random_private.queue q
        join random_private.participants p on p.id=q.participant
        where q.participant<>me.id and q.mode=mode_value and not p.banned
          and p.seen_at > now()-interval '45 seconds'
          and not exists (select 1 from random_private.blocks b where
            (b.blocker=me.id and b.blocked=q.participant) or (b.blocker=q.participant and b.blocked=me.id))
          and not exists (select 1 from random_private.rooms r where r.created_at > now()-interval '5 minutes'
            and ((r.a=me.id and r.b=q.participant) or (r.b=me.id and r.a=q.participant)))
        order by q.joined_at limit 1;
      if other_id is not null then
        insert into random_private.rooms(a,b,mode) values(other_id,me.id,mode_value) returning * into current_room;
        delete from random_private.queue where participant in (me.id,other_id);
      end if;
    end if;
  end if;
  if p_action in ('send','signal') then
    if current_room.ended_at is not null then
      return jsonb_build_object('error','That conversation has ended.','code','ended');
    end if;
    nonce_value := (p_input->>'nonce')::uuid;
    if nonce_value is null then
      return jsonb_build_object('error','Missing request identifier.','code','invalid');
    end if;
    if p_action='send' then
      msg := btrim(coalesce(p_input->>'body',''));
      if char_length(msg) not between 1 and 2000 then
        return jsonb_build_object('error','Messages must be 1–2,000 characters.','code','invalid');
      end if;
      if not exists(select 1 from random_private.messages where sender=me.id and nonce=nonce_value) then
        if me.sent_at > now()-interval '300 milliseconds' then
          return jsonb_build_object('error','You’re sending too quickly. Try again.','code','rate_limit');
        end if;
        if (select count(*) from random_private.messages where sender=me.id and created_at>now()-interval '1 minute')>=60 then
          return jsonb_build_object('error','Take a moment before sending another message.','code','rate_limit');
        end if;
        insert into random_private.messages(room,sender,nonce,body) values(current_room.id,me.id,nonce_value,msg);
        update random_private.participants set sent_at=now() where id=me.id;
      end if;
    else
      if current_room.mode='text' or coalesce(p_input->>'kind','') not in ('offer','answer','ice','media')
        or octet_length(coalesce((p_input->'payload')::text,'')) > 24000 or p_input->'payload' is null then
        return jsonb_build_object('error','Invalid call signal.','code','invalid');
      end if;
      if (select count(*) from random_private.signals where sender=me.id and room=current_room.id)>=300 then
        return jsonb_build_object('error','Call signaling limit reached. Please reconnect.','code','rate_limit');
      end if;
      insert into random_private.signals(room,sender,nonce,kind,payload)
        values(current_room.id,me.id,nonce_value,p_input->>'kind',p_input->'payload') on conflict do nothing;
    end if;
  end if;
  state_value := case when exists(select 1 from random_private.queue where participant=me.id) then 'waiting'
    when current_room.id is null then 'idle' when current_room.ended_at is not null then 'ended' else 'connected' end;
  if current_room.id is not null and state_value<>'waiting' then
    select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]'::jsonb) into messages_value from (
      select id,body,sender=me.id as mine,created_at from random_private.messages
      where room=current_room.id order by id desc limit 200) m;
    after_signal := greatest(coalesce((p_input->>'after_signal')::bigint,0),0);
    select coalesce(jsonb_agg(to_jsonb(s) order by s.id),'[]'::jsonb) into signals_value from (
      select id,kind,payload from random_private.signals where room=current_room.id and sender<>me.id
        and id>after_signal order by id limit 300) s;
  end if;
  return jsonb_build_object('state',state_value,'room',case when state_value='waiting' then null else current_room.id end,
    'mode',coalesce(current_room.mode,mode_value),'initiator',coalesce(current_room.a=me.id,false),
    'end_reason',current_room.end_reason,'messages',messages_value,'signals',signals_value,'report_id',report_value);
exception when invalid_text_representation then
  return jsonb_build_object('error','Invalid request.','code','invalid');
end $$;
revoke all on function public.random_chat_gateway(text,text,jsonb) from public, anon, authenticated;
grant execute on function public.random_chat_gateway(text,text,jsonb) to service_role;
