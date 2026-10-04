alter table social_private.attachments add column purpose text not null default 'content' check(purpose in('content','group_photo','member_photo'));
alter table social_private.attachments add constraint attachments_photo_no_message check(purpose='content' or(message is null and post is null and kind='image' and mime='image/jpeg' and external_source is null));
do $$declare source text;begin
 select pg_get_functiondef('public.group_photo_gateway(text,text,jsonb)'::regprocedure)into source;
 source:=replace(source,'insert into social_private.attachments(owner,room,kind,mime,size,path)values(me,rid,''image'',''image/jpeg'',','insert into social_private.attachments(owner,room,kind,mime,size,path,purpose)values(me,rid,''image'',''image/jpeg'',');
 source:=replace(source,'p_input->>''path'')returning * into a;','p_input->>''path'',scope_value||''_photo'')returning * into a;');
 source:=replace(source,'a.external_source is not null then','a.external_source is not null or a.purpose is distinct from scope_value||''_photo'' then');
 execute source;
end $$;
