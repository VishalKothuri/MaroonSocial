-- Restrict leasing to explicitly supported APNs credential environments. The
-- worker supplies its allowlist; this service-only RPC fails closed if absent.
do $migration$
declare definition text; old_clause text; new_clause text;
begin
 definition:=pg_get_functiondef('public.push_delivery(text,jsonb)'::regprocedure);
 old_clause:='for row_delivery in select *from push_private.deliveries where state=''pending''and available_at<=now()and(lease is null or leased_at<now()-interval ''2 minutes'')';
 new_clause:='for row_delivery in select *from push_private.deliveries where state=''pending''and exists(select 1 from push_private.devices allowed_device where allowed_device.id=push_private.deliveries.device and allowed_device.environment in(select jsonb_array_elements_text(case when jsonb_typeof(p_input->''environments'')=''array''then p_input->''environments''else ''[]''::jsonb end)))and available_at<=now()and(lease is null or leased_at<now()-interval ''2 minutes'')';
 if strpos(definition,old_clause)=0 then raise exception 'Expected push lease implementation missing';end if;
 execute replace(definition,old_clause,new_clause);
end $migration$;
