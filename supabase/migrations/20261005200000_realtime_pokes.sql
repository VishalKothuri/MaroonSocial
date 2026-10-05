-- Caching phase 3: Supabase Realtime pokes for DMs, the inbox and game-day chat.
--
-- The database never broadcasts message content. Triggers send a tiny private broadcast
-- ("poke": room id + sequence) and the client then reads `room.messages after_seq` through the
-- gateway, which keeps personalisation, block filtering and can_read_room server side.
--
-- Topics
--   member:<member uuid>  inbox pokes for one member (new message, invitation, request)
--   room:<room id>        message / change / typing pokes for one room (joined only while a chat is open)
--
-- Authorization is RLS on realtime.messages (SELECT = may receive). There is no INSERT policy:
-- clients never broadcast. Realtime JWTs are minted by the `social` edge function
-- (`realtime.token`) with sub = member uuid and role = authenticated; `authenticated` holds no
-- table grants in this project, so such a token opens nothing but these private channels.
--
-- Until this migration is applied the edge function still answers `realtime.token`, but the
-- private joins are refused and no pokes arrive; the app notices and keeps polling.

-- 1. Who may receive a topic. Private: only the policy wrapper below and service_role call it.
create or replace function social_private.realtime_topic_allowed(p_member uuid, p_topic text)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_member is null or p_topic is null then return false; end if;
  if p_topic = 'member:' || p_member::text then
    return exists(select 1 from social_private.members m where m.id = p_member and not m.banned);
  end if;
  if left(p_topic, 5) = 'room:' and length(p_topic) > 5 then
    -- Same predicate as message_list / room.messages: accepted membership (or an invited DM),
    -- course term open, no block in a DM.
    return exists(select 1 from social_private.members m where m.id = p_member and not m.banned)
      and social_private.can_read_room(p_member, substr(p_topic, 6));
  end if;
  return false;
end $$;
revoke all on function social_private.realtime_topic_allowed(uuid, text) from public, anon, authenticated;
grant execute on function social_private.realtime_topic_allowed(uuid, text) to service_role;

-- 2. Policy wrapper. `authenticated` needs EXECUTE on whatever the policy calls; this wrapper
-- answers only for the caller's own JWT subject, so it reveals nothing about anyone else.
-- Its schema is not exposed through PostgREST.
create schema if not exists realtime_access;
revoke all on schema realtime_access from public;
grant usage on schema realtime_access to authenticated;
create or replace function realtime_access.can_receive(p_topic text)
returns boolean
language sql stable security definer set search_path = ''
as $$ select social_private.realtime_topic_allowed(auth.uid(), p_topic) $$;
revoke all on function realtime_access.can_receive(text) from public, anon;
grant execute on function realtime_access.can_receive(text) to authenticated;

drop policy if exists "maroon members receive their topics" on realtime.messages;
create policy "maroon members receive their topics" on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension in ('broadcast', 'presence')
    and realtime_access.can_receive((select realtime.topic()))
  );
-- No INSERT policy on purpose: only these triggers (as the function owner) send.

-- 3. Member resolution for the edge function's token endpoint (service_role only).
create or replace function public.social_realtime(p_action text, p_hash text, p_input jsonb default '{}'::jsonb)
returns jsonb
language plpgsql set search_path = ''
as $$
declare me uuid;
begin
  if p_action = 'member' then
    me := social_private.require_member(p_hash);
    return jsonb_build_object('member', me);
  end if;
  raise exception 'invalid:Unknown realtime action.';
exception when raise_exception then
  return jsonb_build_object('error', split_part(sqlerrm, ':', 2), 'code', split_part(sqlerrm, ':', 1));
end $$;
revoke all on function public.social_realtime(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.social_realtime(text, text, jsonb) to service_role;

-- 4. Pokes. Payloads carry ids and sequences only, never message text or authors.
-- Inbox fan-out skips game-day rooms (they can be large; their chat is live only while open)
-- and rooms with more than 100 recipients (the 60 s reconciliation snapshot covers those).
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
    select count(*) into recipients from social_private.room_members rm
      where rm.room = new.room and rm.status in ('accepted', 'invited');
    if recipients <= 100 then
      perform realtime.send(poke, 'inbox', 'member:' || rm.member::text, true)
        from social_private.room_members rm
        where rm.room = new.room and rm.status in ('accepted', 'invited');
    end if;
  end if;
  return null;
end $$;

-- Edits/deletions of a message and reactions only matter to an open chat.
create or replace function social_private.realtime_message_change_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare reacted uuid;
begin
  if tg_table_name = 'reactions' then
    if tg_op = 'DELETE' then reacted := old.message; else reacted := new.message; end if;
    perform realtime.send(jsonb_build_object('room', m.room), 'change', 'room:' || m.room, true)
      from social_private.messages m where m.id = reacted;
  elsif new.deleted is distinct from old.deleted or new.body is distinct from old.body then
    perform realtime.send(jsonb_build_object('room', new.room), 'change', 'room:' || new.room, true);
  end if;
  return null;
end $$;

-- Typing (room.typing sets typing_until) and membership changes (invitations, requests, accepts).
create or replace function social_private.realtime_member_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare announce boolean := false;
begin
  if tg_op = 'UPDATE' then
    if new.typing_until is distinct from old.typing_until and new.typing_until > now() then
      perform realtime.send(jsonb_build_object('room', new.room), 'typing', 'room:' || new.room, true);
    end if;
    announce := new.status is distinct from old.status;
  else
    announce := true;
  end if;
  if announce and new.status in ('accepted', 'invited')
     and not exists(select 1 from social_private.rooms r where r.id = new.room and r.kind = 'sports') then
    perform realtime.send(jsonb_build_object('room', new.room), 'inbox', 'member:' || new.member::text, true);
  end if;
  return null;
end $$;

revoke all on function social_private.realtime_message_poke() from public, anon, authenticated;
revoke all on function social_private.realtime_message_change_poke() from public, anon, authenticated;
revoke all on function social_private.realtime_member_poke() from public, anon, authenticated;

drop trigger if exists t_realtime_message_poke on social_private.messages;
create trigger t_realtime_message_poke after insert on social_private.messages
  for each row execute function social_private.realtime_message_poke();
drop trigger if exists t_realtime_message_change_poke on social_private.messages;
create trigger t_realtime_message_change_poke after update of deleted, body on social_private.messages
  for each row execute function social_private.realtime_message_change_poke();
drop trigger if exists t_realtime_reaction_poke on social_private.reactions;
create trigger t_realtime_reaction_poke after insert or delete on social_private.reactions
  for each row execute function social_private.realtime_message_change_poke();
drop trigger if exists t_realtime_member_poke on social_private.room_members;
create trigger t_realtime_member_poke after insert or update of typing_until, status on social_private.room_members
  for each row execute function social_private.realtime_member_poke();
