alter table social_private.attachments drop constraint attachments_kind_check;
alter table social_private.attachments add constraint attachments_kind_check check(kind in('image','gif','video'));
alter table social_private.attachments add constraint attachments_video_mime check(kind<>'video' or (mime='video/mp4' and external_source is null));
update storage.buckets set allowed_mime_types=array['image/jpeg','image/png','image/gif','video/mp4'] where id='social-media' and not public;
