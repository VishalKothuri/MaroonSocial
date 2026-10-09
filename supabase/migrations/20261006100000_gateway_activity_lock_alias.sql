-- The organization access lock for activity.edit, activity.approve and activity.cancel
-- (added in 20261004212123_organization_private_access) aliased its tables as "a" and
-- "r". social_gateway also declares PL/pgSQL variables named a and r, so r.id in that
-- statement was ambiguous and all three actions failed with "column reference r.id is
-- ambiguous". Rename the aliases; nothing else in the gateway changes.
do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='perform pg_advisory_xact_lock(hashtextextended(r.meta->>''organization'',938))from social_private.activities a join social_private.rooms r on r.id=a.room where a.id=(p_input->>''activity_id'')::uuid and r.meta?''organization'';';
 replacement:='perform pg_advisory_xact_lock(hashtextextended(lock_room.meta->>''organization'',938))from social_private.activities lock_activity join social_private.rooms lock_room on lock_room.id=lock_activity.room where lock_activity.id=(p_input->>''activity_id'')::uuid and lock_room.meta?''organization'';';
 if strpos(def,old)=0 then raise exception 'activity lock alias anchor missing';end if;
 execute replace(def,old,replacement);
end $patch$;
