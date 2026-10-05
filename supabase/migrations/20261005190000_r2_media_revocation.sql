-- Caching phase 2 review: R2 media must be revocable.
-- Once an R2 object's URL is handed out (a 24 h presigned S3 GET, or a permanent CDN URL for
-- post media) it can be fetched without the per-read authorization that guards Supabase
-- Storage reads. So when a post is deleted (by its author, by account deletion, or by an
-- operator's reports.review 'remove') or an attachment row disappears (cascade from a room,
-- message, post or member), its `r2/...` object is queued in storage_deletions. The hourly
-- worker (_shared/course-retention.ts) deletes it from R2 and purges the CDN copy, and only
-- then acknowledges it through social_media_cleanup_complete.
-- Supabase Storage objects (bare `<uuid>.<ext>` paths) are deliberately not queued here: every
-- read of them is authorized per request, and leaving them alone keeps the behaviour with
-- MEDIA_BACKEND unset exactly as it was.

create or replace function social_private.queue_deleted_post_r2_media()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
 insert into social_private.storage_deletions(path)
 select a.path from social_private.attachments a
 where a.post=new.id and a.external_source is null and left(a.path,3)='r2/'
 on conflict(path) do nothing;
 return null;
end $$;

create or replace function social_private.queue_removed_attachment_r2_media()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
 insert into social_private.storage_deletions(path)values(old.path)on conflict(path) do nothing;
 return null;
end $$;

revoke all on function social_private.queue_deleted_post_r2_media() from public, anon, authenticated;
revoke all on function social_private.queue_removed_attachment_r2_media() from public, anon, authenticated;

drop trigger if exists queue_deleted_post_r2_media on social_private.posts;
create trigger queue_deleted_post_r2_media
 after update of deleted on social_private.posts
 for each row when (new.deleted and not old.deleted)
 execute function social_private.queue_deleted_post_r2_media();

drop trigger if exists queue_removed_attachment_r2_media on social_private.attachments;
create trigger queue_removed_attachment_r2_media
 after delete on social_private.attachments
 for each row when (left(old.path,3)='r2/' and old.external_source is null)
 execute function social_private.queue_removed_attachment_r2_media();
