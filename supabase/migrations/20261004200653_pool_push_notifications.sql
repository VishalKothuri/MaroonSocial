-- New3.0 pool uses separate authoritative storage; notification access must use
-- that engine's participant and room authorization rather than assume2.x IDs.
create function push_private.on_web_pool_game()returns trigger language plpgsql security invoker set search_path=''as $$
declare recipient_id uuid;actor_id uuid;
begin
 if new.status='pending'and tg_op='INSERT'then
  perform push_private.enqueue(new.b,new.a,'game_invite',new.room,new.id,new.version);
 elsif new.status='active'and(tg_op='INSERT'or old.status is distinct from new.status or old.state->>'turn'is distinct from new.state->>'turn')then
  if new.state->>'turn'not in('0','1')then return new;end if;
  recipient_id:=case when new.state->>'turn'='0'then new.a else new.b end;
  actor_id:=case when recipient_id=new.a then new.b else new.a end;
  perform push_private.enqueue(recipient_id,actor_id,'game_turn',new.room,new.id,new.version);
 end if;return new;
end $$;
create trigger push_web_pool_game after insert or update on web_pool_private.games for each row execute function push_private.on_web_pool_game();
alter function push_private.deliverable(push_private.jobs)rename to deliverable_before_pool;
create function push_private.deliverable(j push_private.jobs)returns boolean language plpgsql stable security invoker set search_path=''as $$
declare g web_pool_private.games;pref push_private.preferences;
begin
 if j.kind not in('game_invite','game_turn')then return push_private.deliverable_before_pool(j);end if;
 -- Reading foreground game activity also suppresses a delayed queued alert.
 if j.read_at is not null then return false;end if;
 select *into g from web_pool_private.games where id=j.reference;
 if g.id is null then return push_private.deliverable_before_pool(j);end if;
 if j.expires_at<=now()or j.recipient not in(g.a,g.b)or g.room is distinct from j.room or not web_pool_private.available(g)then return false;end if;
 if(select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships where member=j.recipient and expires_at>now())then return false;end if;
 select *into pref from push_private.preferences where member=j.recipient;
 if pref.member is null or not pref.enabled or not pref.games then return false;end if;
 if g.room is not null and exists(select 1 from social_private.room_members where room=g.room and member=j.recipient and muted_until>now())then return false;end if;
 if j.kind='game_invite'then return g.status='pending'and g.expires_at>now()and j.recipient=g.b;end if;
 return g.status='active'and g.version=j.revision and j.recipient=case when g.state->>'turn'='0'then g.a when g.state->>'turn'='1'then g.b else null end;
end $$;
alter function push_private.route(push_private.jobs)rename to route_before_pool;
create function push_private.route(j push_private.jobs)returns jsonb language plpgsql stable security invoker set search_path=''as $$
declare g web_pool_private.games;
begin
 if j.kind not in('game_invite','game_turn')then return push_private.route_before_pool(j);end if;
 select *into g from web_pool_private.games where id=j.reference;
 if g.id is null then return push_private.route_before_pool(j);end if;
 if j.recipient not in(g.a,g.b)or g.room is distinct from j.room or not web_pool_private.available(g)then return null;end if;
 if(select require_verified from verification_private.settings where id)and not exists(select 1 from verification_private.memberships where member=j.recipient and expires_at>now())then return null;end if;
 return jsonb_build_object('kind',j.kind,'roomID',g.room,'gameID',g.id);
end $$;
revoke all on function push_private.on_web_pool_game(),push_private.deliverable_before_pool(push_private.jobs),push_private.deliverable(push_private.jobs),push_private.route_before_pool(push_private.jobs),push_private.route(push_private.jobs)from public,anon,authenticated;
grant execute on function push_private.on_web_pool_game(),push_private.deliverable_before_pool(push_private.jobs),push_private.deliverable(push_private.jobs),push_private.route_before_pool(push_private.jobs),push_private.route(push_private.jobs)to service_role;
-- Queue retention must continue even while APNs credentials are unconfigured.
select cron.schedule('maroon-push-retention','*/10 * * * *',$job$delete from push_private.jobs where id in(select id from push_private.jobs where expires_at<=now()order by expires_at limit 5000);$job$);
