-- R2 media revocation (migration 20261005190000_r2_media_revocation) with synthetic fixtures; everything rolls back.
-- Run through psql as the database owner (the operator step needs it): the MCP SQL runner refuses scripts that write.
-- No R2 request is made: the assertions are about which paths land in social_private.storage_deletions.
begin;
select set_config('maroon.r2qa_post',gen_random_uuid()::text,true),set_config('maroon.r2qa_hash',encode(extensions.gen_random_bytes(32),'hex'),true);
do $$
begin
 if not exists(select 1 from pg_trigger where tgname='queue_deleted_post_r2_media' and tgrelid='social_private.posts'::regclass and not tgisinternal)
  or not exists(select 1 from pg_trigger where tgname='queue_removed_attachment_r2_media' and tgrelid='social_private.attachments'::regclass and not tgisinternal)then
  raise exception 'R2 revocation triggers are missing (apply 20261005190000_r2_media_revocation)';
 end if;
 if has_function_privilege('anon','social_private.queue_deleted_post_r2_media()','EXECUTE')or has_function_privilege('authenticated','social_private.queue_deleted_post_r2_media()','EXECUTE')
  or has_function_privilege('anon','social_private.queue_removed_attachment_r2_media()','EXECUTE')or has_function_privilege('authenticated','social_private.queue_removed_attachment_r2_media()','EXECUTE')then
  raise exception 'Revocation trigger functions are exposed to clients';
 end if;
end $$;
set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=current_setting('maroon.r2qa_hash');a uuid;b uuid;out jsonb;
 own_post uuid;bare_post uuid;mod_post uuid;hard_post uuid;
 r2_own text:='r2/public/'||gen_random_uuid()||'.png';bare text:=gen_random_uuid()||'.png';r2_mod text:='r2/public/'||gen_random_uuid()||'.jpg';r2_hard text:='r2/public/'||gen_random_uuid()||'.gif';r2_row text:='r2/public/'||gen_random_uuid()||'.mp4';
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'r2qa_a_'||substr(ha,1,10),true,ha)returning id into a;insert into social_private.guidelines_acceptances(member,version)select a,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'r2qa_b_'||substr(hb,1,10),true,hb)returning id into b;insert into social_private.guidelines_acceptances(member,version)select b,required_version from social_private.guidelines_settings;
 -- One post per case, each with one committed attachment at a chosen path.
 out:=public.social_gateway('post.create',ha,'{"text":"R2 revocation QA (author delete)","anonymous":true}');own_post:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('attachment.reserve',ha,jsonb_build_object('post_id',own_post,'path',r2_own,'kind','image','mime','image/png','size',10));if out?'error' then raise exception 'Reserve failed %',out;end if;
 perform public.social_gateway('attachment.commit',ha,jsonb_build_object('attachment_id',out->>'attachment_id'));
 out:=public.social_gateway('post.create',ha,'{"text":"R2 revocation QA (Supabase path)","anonymous":true}');bare_post:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('attachment.reserve',ha,jsonb_build_object('post_id',bare_post,'path',bare,'kind','image','mime','image/png','size',10));if out?'error' then raise exception 'Reserve failed %',out;end if;
 perform public.social_gateway('attachment.commit',ha,jsonb_build_object('attachment_id',out->>'attachment_id'));
 out:=public.social_gateway('post.create',ha,'{"text":"R2 revocation QA (moderator remove)","anonymous":true}');mod_post:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('attachment.reserve',ha,jsonb_build_object('post_id',mod_post,'path',r2_mod,'kind','image','mime','image/jpeg','size',10));if out?'error' then raise exception 'Reserve failed %',out;end if;
 perform public.social_gateway('attachment.commit',ha,jsonb_build_object('attachment_id',out->>'attachment_id'));
 out:=public.social_gateway('post.create',ha,'{"text":"R2 revocation QA (hard delete)","anonymous":true}');hard_post:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('attachment.reserve',ha,jsonb_build_object('post_id',hard_post,'path',r2_hard,'kind','gif','mime','image/gif','size',10));if out?'error' then raise exception 'Reserve failed %',out;end if;
 if exists(select 1 from social_private.storage_deletions where path in(r2_own,bare,r2_mod,r2_hard))then raise exception 'Live media queued before any deletion';end if;

 -- Author deletion queues the R2 object; the Supabase object is left exactly as before (its reads are authorized per request).
 out:=public.social_gateway('post.delete',ha,jsonb_build_object('post_id',own_post));if out?'error' then raise exception 'Delete failed %',out;end if;
 if not exists(select 1 from social_private.storage_deletions where path=r2_own)then raise exception 'Deleted post R2 media was not queued';end if;
 out:=public.social_gateway('post.delete',ha,jsonb_build_object('post_id',bare_post));if out?'error' then raise exception 'Delete failed %',out;end if;
 if exists(select 1 from social_private.storage_deletions where path=bare)then raise exception 'Supabase media of a deleted post was queued (MEDIA_BACKEND-unset behaviour changed)';end if;
 out:=public.social_gateway('attachment.read',hb,jsonb_build_object('attachment_id',(select id from social_private.attachments where path=r2_own)));if out->>'code' is distinct from 'forbidden' then raise exception 'Deleted post media still authorized %',out;end if;

 -- Once acknowledged, later writes to the tombstone do not queue it again (only the deleted=false -> true transition does).
 perform public.social_media_cleanup_complete(array[r2_own]);
 update social_private.posts set body='' where id=own_post;
 if exists(select 1 from social_private.storage_deletions where path=r2_own)then raise exception 'Tombstone update re-queued its media';end if;

 -- A physical post delete cascades to the attachment row, which queues its R2 object (reserved but never committed here).
 delete from social_private.posts where id=hard_post;
 if not exists(select 1 from social_private.storage_deletions where path=r2_hard)then raise exception 'Cascaded attachment R2 media was not queued';end if;
 -- Removing a room/DM attachment row directly (any purge path) queues it too.
 insert into social_private.attachments(owner,room,post,kind,mime,size,path,ready)values(a,null,mod_post,'video','video/mp4',10,r2_row,false);
 delete from social_private.attachments where path=r2_row;
 if not exists(select 1 from social_private.storage_deletions where path=r2_row)then raise exception 'Deleted attachment row R2 media was not queued';end if;

 -- Member B reports the moderator case; the operator step runs as the owner below.
 out:=public.social_gateway('report',hb,jsonb_build_object('target_type','post','target_id',mod_post,'reason','Synthetic R2 revocation QA'));if out?'error' then raise exception 'Report failed %',out;end if;
 perform set_config('maroon.r2qa_post',mod_post::text,true);perform set_config('maroon.r2qa_path',r2_mod,true);
 if exists(select 1 from social_private.storage_deletions where path=r2_mod)then raise exception 'A report alone queued media';end if;
end $$;
reset role;
do $$
declare rep uuid;
begin
 select id into rep from social_private.reports where target_type='post' and target_id=current_setting('maroon.r2qa_post') order by created_at desc limit 1;
 if rep is null then raise exception 'Report row missing';end if;
 perform social_private.operator_before_notifications('reports.review',jsonb_build_object('id',rep,'decision','remove','note','Synthetic R2 revocation QA removal'),'r2-qa');
 if not (select deleted from social_private.posts where id=current_setting('maroon.r2qa_post')::uuid)then raise exception 'Moderator removal did not tombstone the post';end if;
 if not exists(select 1 from social_private.storage_deletions where path=current_setting('maroon.r2qa_path'))then raise exception 'Moderator-removed post R2 media was not queued';end if;
end $$;
rollback;
