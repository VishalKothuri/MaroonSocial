-- Keep original provider references; KLIPY media is never mirrored into Storage.
alter table social_private.attachments add column external_source jsonb;
alter table social_private.attachments add column external_nonce uuid;
create unique index attachments_external_nonce on social_private.attachments(owner,external_nonce) where external_nonce is not null;
create or replace function public.social_external_media(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare me uuid; ref jsonb:=p_input->'reference'; a social_private.attachments; result jsonb; nonce uuid; room_id text; post_id uuid; candidate text;
begin
 me:=social_private.require_member(p_hash);
 if p_action='read' then
  result:=public.social_gateway('attachment.read',p_hash,p_input);
  if result?'error' then return result;end if;
  select * into a from social_private.attachments where id=(p_input->>'attachment_id')::uuid;
  return result||jsonb_build_object('external_media',a.external_source);
 elsif p_action<>'create' then raise exception 'invalid:Unknown media action.';end if;
 room_id:=p_input->>'room_id';post_id:=(p_input->>'post_id')::uuid;nonce:=(p_input->>'nonce')::uuid;
 if nonce is null or (room_id is null)=(post_id is null) then raise exception 'invalid:Choose one media destination.';end if;
 -- Check current membership even when recovering an acknowledged-or-lost upload.
 if room_id is not null and not social_private.can_message(me,room_id) then raise exception 'forbidden:Join or accept this conversation first.';end if;
 if post_id is not null and not exists(select 1 from social_private.posts p where p.id=post_id and p.author=me and not p.deleted and social_private.can_read_post(me,p.id))then raise exception 'forbidden:This post is unavailable.';end if;
 select * into a from social_private.attachments where owner=me and external_nonce=nonce;
 if a.id is not null then
  if a.room is distinct from room_id or a.post is distinct from post_id or a.external_source is distinct from ref then raise exception 'invalid:Use a new attachment selection.';end if;
  return jsonb_build_object('attachment_id',a.id);
 end if;
 if jsonb_typeof(ref) is distinct from 'object' or ref->>'provider' is distinct from 'klipy' or coalesce(ref->>'category','') not in('gifs','static-memes') or coalesce(ref->>'kind','') not in('gif','image') or coalesce(ref->>'mime','') not in('image/gif','image/jpeg','image/png') then raise exception 'invalid:Choose supported KLIPY media.';end if;
 if ref->>'id' is null or char_length(ref->>'id') not between 1 and 100 or ref->>'slug' is null or char_length(ref->>'slug')not between 1 and 200 or char_length(coalesce(ref->>'title',''))>300 or coalesce((ref->>'size')::bigint,0)not between 1 and 5000000 then raise exception 'invalid:Choose KLIPY media smaller than 5 MB.';end if;
 if (ref->>'kind'='gif') is distinct from (ref->>'mime'='image/gif')then raise exception 'invalid:Unsupported media type.';end if;
 foreach candidate in array array[ref->>'url',ref->>'previewURL'] loop
  if candidate is null or char_length(candidate)>3000 or candidate !~ '^https://static[12]?\.klipy\.com(:443)?/[^[:space:]\\]*$' or candidate ~ '[[:cntrl:]#]' then raise exception 'invalid:Only original secure KLIPY media URLs are supported.';end if;
 end loop;
 -- Keep only documented fields, never arbitrary caller metadata or identifiers.
 ref:=jsonb_build_object('provider','klipy','id',ref->>'id','slug',ref->>'slug','title',coalesce(ref->>'title',''),'category',ref->>'category','kind',ref->>'kind','mime',ref->>'mime','url',ref->>'url','previewURL',ref->>'previewURL','size',(ref->>'size')::integer);
 result:=public.social_gateway('attachment.reserve',p_hash,jsonb_build_object('room_id',room_id,'post_id',post_id,'path','external/'||pg_catalog.gen_random_uuid()::text,'kind',ref->>'kind','mime',ref->>'mime','size',(ref->>'size')::integer));
 if result?'error' then return result;end if;
 update social_private.attachments set external_source=ref,external_nonce=nonce,ready=true where id=(result->>'attachment_id')::uuid returning * into a;
 return jsonb_build_object('attachment_id',a.id,'snapshot',social_private.snapshot(me));
exception when others then
 if position(':' in sqlerrm)>0 then return jsonb_build_object('code',split_part(sqlerrm,':',1),'error',substring(sqlerrm from position(':' in sqlerrm)+1));end if;
 return jsonb_build_object('code','invalid','error','The media reference could not be saved.');
end $$;
revoke all on function public.social_external_media(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.social_external_media(text,text,jsonb) to service_role;
-- Account deletion queues only objects actually owned by our Storage bucket.
do $$ declare definition text;begin
 select pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure) into definition;
 definition:=replace(definition,'from social_private.attachments where owner=me;', 'from social_private.attachments where owner=me and external_source is null;');
 definition:=replace(definition,'from social_private.attachments where owner=me on conflict', 'from social_private.attachments where owner=me and external_source is null on conflict');
 execute definition;
end $$;
