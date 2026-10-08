-- KLIPY references (social_external_media 'create') forwarded feed_community to
-- attachment.reserve as p_input->>'feed_community'. When the caller left it out,
-- jsonb_build_object stored a JSON null, which the gateway's community check rejects
-- ("Choose an available community."), although the gateway documents feed_community as
-- optional for legacy callers. Forward the key only when the caller sent it, unchanged,
-- so a present but invalid value is still rejected by the gateway.
do $patch$
declare def text; old text; replacement text;
begin
 def:=pg_get_functiondef('public.social_external_media(text,text,jsonb)'::regprocedure);
 old:='jsonb_build_object(''feed_community'',p_input->>''feed_community'',''room_id'',room_id,';
 replacement:='(case when p_input?''feed_community'' then jsonb_build_object(''feed_community'',p_input->''feed_community'') else ''{}''::jsonb end)||jsonb_build_object(''room_id'',room_id,';
 if strpos(def,old)=0 then raise exception 'external media community anchor missing';end if;
 execute replace(def,old,replacement);
end $patch$;
