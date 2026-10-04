-- Synthetic accounts and private rooms; every write rolls back.
begin;
do $$
declare v_me uuid:=gen_random_uuid();v_other uuid:=gen_random_uuid();v_hash text:=encode(extensions.gen_random_bytes(32),'hex');v_room text:=gen_random_uuid()::text;result jsonb;n int;
begin
 insert into social_private.members(id,token_hash,username,adult,network_hash)values(v_me,v_hash,'exportqa_'||substr(replace(v_me::text,'-',''),1,10),true,'synthetic'),(v_other,encode(extensions.gen_random_bytes(32),'hex'),'exportqa_'||substr(replace(v_other::text,'-',''),1,10),true,'synthetic');
 insert into social_private.rooms(id,kind,title)values(v_room,'group','Secret new group title after removal');
 insert into social_private.room_members(room,member,status)values(v_room,v_me,'declined'),(v_room,v_other,'accepted');
 insert into social_private.messages(room,author,nonce,body)values(v_room,v_me,gen_random_uuid(),'My old text'),(v_room,v_other,gen_random_uuid(),'Someone else private text');
 result:=public.account_controls('export',v_hash,'{"section":"messages"}');
 if jsonb_array_length(result->'data')<>1 or result->'data'->0->>'context'<>'Former conversation' or result->'data'->0->>'body'<>'My old text'then raise exception 'Removed member export leaked new room context or peer text';end if;
 result:=public.account_controls('export',v_hash,'{"section":"memberships"}');
 if result->'data'->0->>'title'<>'Former or declined conversation'then raise exception 'Removed member exported new title';end if;
 for n in 1..205 loop insert into social_private.posts(author,nonce,body)values(v_me,gen_random_uuid(),'Synthetic export page '||n);end loop;
 result:=public.account_controls('export',v_hash,'{"section":"posts"}');
 if jsonb_array_length(result->'data')<>200 or (result->>'has_more')::bool<>true then raise exception 'First export page incomplete';end if;
 result:=public.account_controls('export',v_hash,'{"section":"posts","offset":200}');
 if jsonb_array_length(result->'data')<>5 or (result->>'has_more')::bool<>false then raise exception 'Last export page incomplete';end if;
end $$;
select 'PASS export paging, authored-only data, no current metadata from removed private rooms' as result;
rollback;
