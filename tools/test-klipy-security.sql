begin;
set local role service_role;
do $$
declare ha text:=repeat('a',32)||replace(gen_random_uuid()::text,'-','');hb text:=repeat('b',32)||replace(gen_random_uuid()::text,'-','');hc text:=repeat('c',32)||replace(gen_random_uuid()::text,'-','');aid uuid;bid uuid;cid uuid;room text;pid uuid;att uuid;nonce uuid:=gen_random_uuid();r jsonb;ref jsonb;url text;mid uuid;
begin
 if has_function_privilege('anon','public.social_external_media(text,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','public.social_external_media(text,text,jsonb)','EXECUTE')then raise exception 'External media RPC exposed';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'klipy_a_'||substr(ha,33,10),true,ha)returning id into aid;insert into social_private.guidelines_acceptances(member,version)select aid,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'klipy_b_'||substr(hb,33,10),true,hb)returning id into bid;insert into social_private.guidelines_acceptances(member,version)select bid,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'klipy_c_'||substr(hc,33,10),true,hc)returning id into cid;insert into social_private.guidelines_acceptances(member,version)select cid,required_version from social_private.guidelines_settings;
 ref:='{"provider":"klipy","id":"fixture-id","slug":"fixture-slug","title":"Synthetic reference only","category":"gifs","kind":"gif","mime":"image/gif","url":"https://static.klipy.com/synthetic.gif?preserve=yes%2Bplease","previewURL":"https://static.klipy.com/synthetic.gif?preserve=yes%2Bplease","size":300}';
 r:=public.social_gateway('dm.request',ha,jsonb_build_object('username',(select username from social_private.members where id=bid),'text','Synthetic KLIPY media test'));room:=r->>'resource_id';if room is null then raise exception 'DM failed %',r;end if;
 r:=public.social_external_media('create',ha,jsonb_build_object('room_id',room,'nonce',nonce,'reference',ref));if r->>'code'<>'forbidden'then raise exception 'Pending request could attach %',r;end if;
 perform public.social_gateway('dm.accept',hb,jsonb_build_object('room_id',room));
 r:=public.social_external_media('create',hc,jsonb_build_object('room_id',room,'nonce',nonce,'reference',ref));if r->>'code'<>'forbidden'then raise exception 'Outsider could attach %',r;end if;
 foreach url in array array['http://static.klipy.com/x.gif','https://static.klipy.com.evil.example/x','https://evil.example/x','https://user@static.klipy.com/x','https://static.klipy.com:444/x','https://static.klipy.com/x#fragment','https://static.klipy.com\@evil.example/x']loop
  r:=public.social_external_media('create',ha,jsonb_build_object('room_id',room,'nonce',nonce,'reference',jsonb_set(ref,'{url}',to_jsonb(url))));if r->>'code'<>'invalid'then raise exception 'Unsafe URL accepted %',r;end if;
 end loop;
 r:=public.social_external_media('create',ha,jsonb_build_object('room_id',room,'nonce',nonce,'reference',ref-'category'));if r->>'code'<>'invalid'then raise exception 'Missing category accepted %',r;end if;
 r:=public.social_external_media('create',ha,jsonb_build_object('room_id',room,'nonce',nonce,'reference',jsonb_set(ref,'{size}','5000001')));if r->>'code'<>'invalid'then raise exception 'Oversized ref accepted %',r;end if;
 r:=public.social_external_media('create',ha,jsonb_build_object('room_id',room,'nonce',nonce,'reference',ref));att:=(r->>'attachment_id')::uuid;if att is null then raise exception 'Valid reference failed %',r;end if;
 r:=public.social_external_media('create',ha,jsonb_build_object('room_id',room,'nonce',nonce,'reference',ref));if r->>'attachment_id'<>att::text then raise exception 'Lost ack retry duplicated';end if;
 r:=public.social_external_media('read',hb,jsonb_build_object('attachment_id',att));if r->>'code'<>'forbidden'then raise exception 'Recipient read unsent draft';end if;
 r:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',room,'text','','attachment_id',att,'nonce',gen_random_uuid()));mid:=(r->>'resource_id')::uuid;if mid is null then raise exception 'Reference send failed %',r;end if;
 r:=public.social_external_media('read',hb,jsonb_build_object('attachment_id',att));if r->'external_media' is distinct from ref then raise exception 'Original reference mutated %',r;end if;
 r:=public.social_external_media('read',hc,jsonb_build_object('attachment_id',att));if r->>'code'<>'forbidden'then raise exception 'Outsider read media';end if;
 r:=public.social_gateway('post.create',ha,'{"text":"Synthetic external media post","community":"Texas A&M","anonymous":true}');pid:=(r->>'resource_id')::uuid;
 r:=public.social_external_media('create',ha,jsonb_build_object('post_id',pid,'nonce',gen_random_uuid(),'reference',ref));if not r?'attachment_id'then raise exception 'Post reference failed %',r;end if;
 r:=public.social_external_media('read',hb,jsonb_build_object('attachment_id',r->>'attachment_id'));if r->'external_media' is distinct from ref then raise exception 'Visible post media unreadable';end if;
 perform public.social_gateway('block',hb,jsonb_build_object('room_id',room));
 r:=public.social_external_media('read',hb,jsonb_build_object('attachment_id',att));if r->>'code'<>'forbidden'then raise exception 'Blocked attachment readable';end if;
 r:=public.social_gateway('account.delete',ha,'{}');if r->'storage_paths'<>'[]'::jsonb then raise exception 'External references queued as stored bytes';end if;
 if exists(select 1 from social_private.attachments where owner=aid)then raise exception 'External reference survived account deletion';end if;
end $$;
select 'PASS: direct reference preservation, private draft/room/post access, unsafe URL/size rejection, idempotency, block, account deletion, client RPC denial' as result;
rollback;
