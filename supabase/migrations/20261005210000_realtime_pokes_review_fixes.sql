-- Caching phase 3 review fixes. Apply after 20261005200000_realtime_pokes.sql.
--
-- 1. Pokes follow message_list's access rule. A message's inbox fan-out reaches only members who
--    can read the room (can_read_room): a pending group invitee gets its invitation poke and
--    nothing about the group's messages.
-- 2. Receiving any topic needs what the gateway needs (require_member): an active account and,
--    while the campus requires it, an unexpired TAMU verification. Realtime re-checks this when a
--    channel is joined and whenever the app sends a refreshed token; tokens now last 15 minutes
--    (edge function `realtime.token`), so a removed, suspended or lapsed member drops off within
--    minutes instead of an hour.
-- 3. Calls poke the room on ring, answer and end, and ring the callee's inbox, so an open chat
--    shows the incoming-call banner within a second instead of at the next 60 s snapshot.
-- 4. Membership and room status changes (DM accept/decline, removals, closures) poke the open
--    room, and a DM answer pokes the requester's inbox.
-- Payloads stay ids only: {room} or {room, seq}.

-- 1 + 2. Who may receive a topic.
create or replace function social_private.realtime_member_allowed(p_member uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  -- Same gates as require_member: not suspended, and verified while verification is required.
  select exists(select 1 from social_private.members m where m.id = p_member and not m.banned)
    and (not coalesce((select s.require_verified from verification_private.settings s where s.id), false)
         or exists(select 1 from verification_private.memberships v where v.member = p_member and v.expires_at > now()))
$$;
revoke all on function social_private.realtime_member_allowed(uuid) from public, anon, authenticated;
grant execute on function social_private.realtime_member_allowed(uuid) to service_role;

create or replace function social_private.realtime_topic_allowed(p_member uuid, p_topic text)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_member is null or p_topic is null then return false; end if;
  if p_topic = 'member:' || p_member::text then
    return social_private.realtime_member_allowed(p_member);
  end if;
  if left(p_topic, 5) = 'room:' and length(p_topic) > 5 then
    -- Same predicate as message_list / room.messages: accepted membership (or an invited DM),
    -- course term open, no block in a DM.
    return social_private.realtime_member_allowed(p_member)
      and social_private.can_read_room(p_member, substr(p_topic, 6));
  end if;
  return false;
end $$;
revoke all on function social_private.realtime_topic_allowed(uuid, text) from public, anon, authenticated;
grant execute on function social_private.realtime_topic_allowed(uuid, text) to service_role;

-- 1. Message pokes: the inbox fan-out goes only to members who can read the room.
create or replace function social_private.realtime_message_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  room_kind text;
  recipients integer;
  poke jsonb := jsonb_build_object('room', new.room, 'seq', new.seq);
begin
  perform realtime.send(poke, 'message', 'room:' || new.room, true);
  select r.kind into room_kind from social_private.rooms r where r.id = new.room;
  if room_kind is distinct from 'sports' then
    -- The size check uses the cheap status gate of can_read_room (invitees count only in a DM).
    select count(*) into recipients from social_private.room_members rm
      where rm.room = new.room and (rm.status = 'accepted' or (room_kind = 'dm' and rm.status = 'invited'));
    if recipients <= 100 then
      perform realtime.send(poke, 'inbox', 'member:' || rm.member::text, true)
        from social_private.room_members rm
        where rm.room = new.room and rm.status in ('accepted', 'invited')
          and social_private.can_read_room(rm.member, new.room);
    end if;
  end if;
  return null;
end $$;

-- 4. Typing, and membership changes: invitations, requests, joins, answers, removals.
create or replace function social_private.realtime_member_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  changed boolean;
  room_kind text;
begin
  if tg_op = 'UPDATE' then
    if new.typing_until is distinct from old.typing_until and new.typing_until > now() then
      perform realtime.send(jsonb_build_object('room', new.room), 'typing', 'room:' || new.room, true);
    end if;
    changed := new.status is distinct from old.status;
  else
    changed := true;
  end if;
  if not changed then return null; end if;
  select r.kind into room_kind from social_private.rooms r where r.id = new.room;
  -- Game-day rooms: joins are frequent and the chat is live only while open.
  if room_kind is not distinct from 'sports' then return null; end if;
  -- An open chat re-reads the room (an answered request, a removal, a new member).
  perform realtime.send(jsonb_build_object('room', new.room), 'change', 'room:' || new.room, true);
  -- The member's own inbox learns about an invitation, a request or a join.
  if new.status in ('accepted', 'invited') then
    perform realtime.send(jsonb_build_object('room', new.room), 'inbox', 'member:' || new.member::text, true);
  end if;
  -- A DM answer (accept, decline, leave) reaches the other member's inbox too: the requester.
  if room_kind = 'dm' and tg_op = 'UPDATE' then
    perform realtime.send(jsonb_build_object('room', new.room), 'inbox', 'member:' || rm.member::text, true)
      from social_private.room_members rm
      where rm.room = new.room and rm.member <> new.member and rm.status in ('accepted', 'invited');
  end if;
  return null;
end $$;

-- 4. Room status changes (DM accepted or declined, closed by a block, moderation or term end).
create or replace function social_private.realtime_room_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status is not distinct from old.status or new.kind = 'sports' then return null; end if;
  perform realtime.send(jsonb_build_object('room', new.id), 'change', 'room:' || new.id, true);
  return null;
end $$;

-- 3. Calls: ring, answer and end poke the room; a ring also reaches the callee's inbox.
create or replace function social_private.realtime_call_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.state is not distinct from old.state then return null; end if;
  perform realtime.send(jsonb_build_object('room', new.room), 'change', 'room:' || new.room, true);
  if tg_op = 'INSERT' then
    perform realtime.send(jsonb_build_object('room', new.room), 'inbox', 'member:' || new.callee::text, true);
  end if;
  return null;
end $$;

revoke all on function social_private.realtime_message_poke() from public, anon, authenticated;
revoke all on function social_private.realtime_member_poke() from public, anon, authenticated;
revoke all on function social_private.realtime_room_poke() from public, anon, authenticated;
revoke all on function social_private.realtime_call_poke() from public, anon, authenticated;

drop trigger if exists t_realtime_room_poke on social_private.rooms;
create trigger t_realtime_room_poke after update of status on social_private.rooms
  for each row execute function social_private.realtime_room_poke();
drop trigger if exists t_realtime_call_poke on social_private.calls;
create trigger t_realtime_call_poke after insert or update of state on social_private.calls
  for each row execute function social_private.realtime_call_poke();
