-- Course retention removes our Storage objects, never provider URL references.
-- Preserve the existing purge, cascade, and ordinary-media deletion behavior.
do $$
declare definition text; needle text:='from social_private.attachments where room=entry.id and path is not null';
begin
 definition:=pg_get_functiondef('public.course_lifecycle_maintenance(integer)'::regprocedure);
 if position(needle in definition)=0 then raise exception 'Course retention media query changed; review the patch.';end if;
 execute replace(definition,needle,needle||' and external_source is null');
end $$;
