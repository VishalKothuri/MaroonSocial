-- Accepting an invitation cancels still-waiting searches under the same queue
-- lock as matchmaking. It does not cancel another already-paired async game.
do $patch$declare d text;needle text:=E'begin\n if p_action=''list''then';begin
 d:=pg_get_functiondef('web_pool_private.action(text,uuid,jsonb)'::regprocedure);
 if strpos(d,needle)=0 then raise exception 'Pool action lock patch missing';end if;
 execute replace(d,needle,E'begin\n if p_action=''accept''then perform pg_advisory_xact_lock(739126483);end if;\n if p_action=''list''then');
end $patch$;
