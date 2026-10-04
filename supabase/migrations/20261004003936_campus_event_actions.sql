-- Avoid the gateway's comment-row variable `c` shadowing the campus cache alias.
-- Preserve the current gateway body and its grants instead of replacing unrelated actions.
do $migration$
declare definition text;
 old_lookup text := $old$from public.campus_cache c,jsonb_array_elements(c.payload->'events')e$old$;
 old_validation text := $old$if not exists(select 1 from public.campus_cache as campus_snapshot cross join lateral jsonb_array_elements(campus_snapshot.payload->'events') as e where e->>'id'=p_input->>'event_id')then raise exception 'invalid:That event is no longer available.';end if;$old$;
begin
 definition := pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 if (length(definition)-length(replace(definition,old_lookup,'')))/length(old_lookup) <> 2 then
  raise exception 'Expected exactly two campus cache lookups in social_gateway';
 end if;
 definition := replace(definition,old_lookup,$new$from public.campus_cache as campus_snapshot cross join lateral jsonb_array_elements(campus_snapshot.payload->'events') as e$new$);
 definition := replace(definition,$old$where c.id='current' and e->>'id'=p_input->>'event_id'$old$,$new$where campus_snapshot.id='current' and e->>'id'=p_input->>'event_id'$new$);
 if position(old_validation in definition)=0 then raise exception 'Expected campus bookmark validation was not found';end if;
 -- Unsave must remain possible after a previously saved event ages out of the feed.
 definition := replace(definition,old_validation,$new$if coalesce((p_input->>'saved')::boolean,true) and not exists(select 1 from public.campus_cache as campus_snapshot cross join lateral jsonb_array_elements(campus_snapshot.payload->'events') as e where campus_snapshot.id='current' and e->>'id'=p_input->>'event_id')then raise exception 'invalid:That event is no longer available.';end if;$new$);
 execute definition;
end $migration$;
