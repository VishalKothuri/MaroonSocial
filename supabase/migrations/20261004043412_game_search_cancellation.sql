-- Keep cancellation receipts for late HTTP arrivals, without reviving a stopped search.
create table games_private.cancelled_searches (
 member uuid references social_private.members on delete cascade, nonce uuid not null,
 created_at timestamptz not null default now(), primary key(member,nonce)
);
create index cancelled_game_search_age on games_private.cancelled_searches(created_at);
alter table games_private.cancelled_searches enable row level security;
revoke all on games_private.cancelled_searches from public,anon,authenticated;
grant all on games_private.cancelled_searches to service_role;
create policy cancelled_game_search_service on games_private.cancelled_searches to service_role using(true) with check(true);
do $migration$
declare definition text; needle text;
begin
 definition:=pg_get_functiondef('public.games_matchmaking(text,text,jsonb)'::regprocedure);
 needle:=$fragment$ if p_action='match.cancel' then
  if q.nonce=$fragment$;
 if strpos(definition,needle)=0 then raise exception 'Match cancellation patch target missing';end if;
 definition:=replace(definition,needle,$fragment$ delete from games_private.cancelled_searches where created_at<now()-interval '1 day';
 if p_action='match.cancel' then
  insert into games_private.cancelled_searches(member,nonce)values(me,requested_nonce)on conflict do nothing;
  if q.nonce=$fragment$);
 needle:=$fragment$ elsif p_action='match.join' then
  if q.nonce=$fragment$;
 -- The existing comparison is IS DISTINCT FROM, not equality.
 needle:=$fragment$ elsif p_action='match.join' then
  if q.nonce is distinct$fragment$;
 if strpos(definition,needle)=0 then raise exception 'Match join patch target missing';end if;
 definition:=replace(definition,needle,$fragment$ elsif p_action='match.join' then
  if exists(select 1 from games_private.cancelled_searches where member=me and nonce=requested_nonce) then
   return jsonb_build_object('queue',jsonb_build_object('status','cancelled'));
  end if;
  if q.nonce is distinct$fragment$);
 execute definition;
end $migration$;
