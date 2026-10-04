-- Explicit service-only policies document the deny-by-default boundary; the private schema remains inaccessible to clients.
create policy games_sessions_service on games_private.sessions to service_role using(true) with check(true);
create policy games_turns_service on games_private.turns to service_role using(true) with check(true);
