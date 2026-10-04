-- Bound the waiting candidate set even when clients disappear without Cancel.
create index game_queue_waiting_heartbeat on games_private.match_queue(heartbeat_at) where status='waiting';

do $migration$
declare definition text;needle text;replacement text;
begin
 definition:=pg_get_functiondef('public.games_matchmaking(text,text,jsonb)'::regprocedure);
 needle:=' perform pg_advisory_xact_lock(739126481);';
 if strpos(definition,needle)=0 then raise exception 'Matchmaking lock patch target missing';end if;
 replacement:=$fragment$ -- Reject unavailable credentials without taking the shared matchmaking lock.
 -- require_member below still revalidates under its account lock; this preflight
 -- never changes the global-before-account lock order.
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' or not exists(select 1 from social_private.members where token_hash=p_hash) then
  raise exception 'unauthorized:Your account credential is unavailable.';
 end if;
 if exists(select 1 from social_private.members where token_hash=p_hash and banned) then
  raise exception 'forbidden:This account is suspended.';
 end if;
 perform pg_advisory_xact_lock(739126481);$fragment$;
 definition:=replace(definition,needle,replacement);
 needle:=' select * into q from games_private.match_queue where member=me for update;';
 if strpos(definition,needle)=0 then raise exception 'Matchmaking queue cleanup target missing';end if;
 replacement:=$fragment$ update games_private.match_queue set status='cancelled' where status='waiting' and heartbeat_at<now()-interval '45 seconds';
 select * into q from games_private.match_queue where member=me for update;$fragment$;
 definition:=replace(definition,needle,replacement);
 needle:='and s.status=''active'' and r.meta->>''gameMatchmaking''=''true'' and not social_private.blocked(s.inviter,s.opponent)';
 if (length(definition)-length(replace(definition,needle,'')))/length(needle)<>2 then raise exception 'Expected both matchmaking recovery predicates';end if;
 replacement:='and s.status=''active'' and r.meta->>''gameMatchmaking''=''true'' and not exists(select 1 from social_private.members suspended where suspended.id in(s.inviter,s.opponent) and suspended.banned) and not social_private.blocked(s.inviter,s.opponent)';
 execute replace(definition,needle,replacement);
end $migration$;
