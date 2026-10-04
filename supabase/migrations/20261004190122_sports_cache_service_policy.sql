create policy sports_cache_service_only on sports_private.cache for all to service_role using(true) with check(true);
