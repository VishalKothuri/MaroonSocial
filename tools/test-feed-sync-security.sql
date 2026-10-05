-- Transactional protocol checks for the incremental reads (feed.page, feed.delta, feed.posts,
-- comments.page, room.messages) and the slim snapshot, after both 20261005160000 and the review
-- fixes in 20261005170000. Run as the database owner with psql; everything rolls back.
-- Inside one transaction now() is constant, so every fixture post shares created_at and the
-- keyset order falls back to the id tiebreak, which is exactly the case that must not skip.
begin;
set local role service_role;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;ids uuid[]:='{}';seen uuid[]:='{}';out jsonb;page jsonb;cursor jsonb:='{}';obj jsonb;since double precision;i int;
 inserted uuid;blocked_post uuid;dm_room text;first_seq bigint;known jsonb;snap jsonb;conversation jsonb;comment_ids uuid[]:='{}';
 hd text:=encode(extensions.gen_random_bytes(32),'hex');d uuid;named_a uuid;c_named uuid;c_anon uuid;c_zero uuid;voted uuid;stamp timestamptz;stamps jsonb;msg_one uuid;msg_two uuid;
begin
 if has_function_privilege('anon','social_private.feed_sync(uuid,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','social_private.feed_sync(uuid,text,jsonb)','EXECUTE')
  or has_function_privilege('authenticated','social_private.post_json(uuid,social_private.posts,integer)','EXECUTE')or has_function_privilege('anon','social_private.message_page(uuid,text,bigint,bigint,integer)','EXECUTE')
  or has_function_privilege('authenticated','social_private.feed_posts(uuid,text,uuid[])','EXECUTE')or has_function_privilege('anon','social_private.message_changes(uuid,text,bigint,timestamptz)','EXECUTE')
  or has_function_privilege('authenticated','social_private.mark_feed_resync(uuid[])','EXECUTE')
  or has_table_privilege('anon','social_private.post_tombstones','SELECT')or has_table_privilege('authenticated','social_private.post_tombstones','SELECT')
  or has_table_privilege('anon','social_private.feed_resyncs','SELECT')or has_table_privilege('authenticated','social_private.feed_resyncs','SELECT')then raise exception 'Incremental read API exposed';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'feed_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'feed_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'feed_c_'||substr(hc,1,8),true,hc)returning id into c;
 for i in 1..7 loop
  out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Feed page QA '||i,'anonymous',true,'community','Graduates','acceptsDM',true));
  if out->>'resource_id' is null then raise exception 'Fixture post failed %',out;end if;
  ids:=ids||(out->>'resource_id')::uuid;
 end loop;

 -- Keyset pages neither duplicate nor skip while a post is inserted between pages.
 for i in 1..40 loop
  page:=public.social_gateway('feed.page',hb,jsonb_build_object('community','Graduates','limit',3)||cursor);
  if page?'error' then raise exception 'feed.page failed %',page;end if;
  if jsonb_array_length(page->'posts')>3 then raise exception 'Page size ignored';end if;
  for obj in select value from jsonb_array_elements(page->'posts') loop
   if (obj->>'id')::uuid=any(seen) then raise exception 'Keyset page repeated %',obj->>'id';end if;
   seen:=seen||(obj->>'id')::uuid;
   if not(obj?'commentCount'and obj?'syncedAt'and obj?'repostCount'and obj?'comments'and obj?'score')then raise exception 'Post JSON shape changed %',obj;end if;
   if obj?'changedAt' then raise exception 'Raw change time exposed';end if;
  end loop;
  if i=1 then out:=public.social_gateway('post.create',hc,'{"text":"Inserted between pages","anonymous":true,"community":"Graduates"}');inserted:=(out->>'resource_id')::uuid;end if;
  exit when ids<@seen or jsonb_typeof(page->'next')is distinct from 'object';
  cursor:=page->'next';
 end loop;
 if not ids<@seen then raise exception 'Keyset pages skipped a post';end if;
 page:=public.social_gateway('feed.page',hb,'{"community":"Graduates","limit":500}');
 if jsonb_array_length(page->'posts')>50 then raise exception 'Page limit not clamped';end if;
 page:=public.social_gateway('feed.page',hb,'{"community":"Graduates","limit":1e10}');
 if page?'error' or jsonb_array_length(page->'posts')>50 then raise exception 'Huge page size not clamped %',page;end if;
 for obj in select value from jsonb_array_elements('[{"before_created":1e300},{"before_created":"not-a-date"},{"before_created":"infinity"},{"before_created":-1}]'::jsonb) loop
  page:=public.social_gateway('feed.page',hb,jsonb_build_object('community','Graduates')||obj);
  if page->>'code' is distinct from 'invalid' then raise exception 'Out-of-range cursor accepted % %',obj,page;end if;
 end loop;
 if (public.social_gateway('feed.delta',hb,'{"community":"Graduates","since":1e300}'))->>'code' is distinct from 'invalid' then raise exception 'Out-of-range clock accepted';end if;
 page:=public.social_gateway('feed.page',hb,'{"community":"Graduates","limit":"all"}');
 if page->>'code' is distinct from 'invalid' then raise exception 'Non-numeric limit accepted %',page;end if;
 page:=public.social_gateway('feed.page',hb,'{"community":"Elsewhere"}');
 if page->>'code' is distinct from 'invalid' then raise exception 'Unknown community accepted %',page;end if;
 page:=public.social_gateway('feed.page',hb,'{"community":"NSFW"}');
 if jsonb_array_length(page->'posts')<>0 then raise exception 'NSFW page readable without joining';end if;

 -- The snapshot carries only the first page and the cursors.
 snap:=social_private.snapshot(b);
 if jsonb_array_length(snap->'posts')>30 or not snap?'serverNow' or not snap?'feedNext' then raise exception 'Snapshot is not slim %',jsonb_array_length(snap->'posts');end if;

 -- Delta: a voted, a commented and a deleted post come back; an untouched one does not.
 since:=extract(epoch from clock_timestamp());
 perform pg_sleep(0.01);
 out:=public.social_gateway('post.vote',hb,jsonb_build_object('post_id',ids[1],'value',1));if out?'error' then raise exception 'Vote failed %',out;end if;
 out:=public.social_gateway('comment.create',hb,jsonb_build_object('post_id',ids[2],'text','Delta reply'));if out?'error' then raise exception 'Reply failed %',out;end if;
 out:=public.social_gateway('post.delete',ha,jsonb_build_object('post_id',ids[3]));if out?'error' then raise exception 'Delete failed %',out;end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Graduates','since',since,'known_ids',to_jsonb(ids)));
 if page?'error' then raise exception 'feed.delta failed %',page;end if;
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=ids[1]::text and (e->>'vote')::int=1)then raise exception 'Voted post missing from delta';end if;
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=ids[2]::text and (e->>'commentCount')::int=1)then raise exception 'Commented post missing from delta';end if;
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=ids[3]::text and (e->>'deleted')::boolean)then raise exception 'Deleted post missing from delta';end if;
 if exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=ids[4]::text)then raise exception 'Untouched post returned by delta';end if;
 if page::text like '%feed_a_%' then raise exception 'Anonymous author leaked by delta';end if;
 if (page->>'now')::double precision>extract(epoch from now()) then raise exception 'Delta clock has no overlap';end if;

 -- Removed: hidden, blocked author and physically deleted posts, reported only for known ids.
 out:=public.social_gateway('post.create',hc,'{"text":"Blocked author post","anonymous":false,"community":"Graduates"}');blocked_post:=(out->>'resource_id')::uuid;
 since:=extract(epoch from clock_timestamp());
 out:=public.social_gateway('report',hb,jsonb_build_object('target_type','post','target_id',ids[5],'reason','QA hide'));if out?'error' then raise exception 'Report failed %',out;end if;
 insert into social_private.blocks values(b,c)on conflict do nothing;
 delete from social_private.posts where id=ids[6];
 if not exists(select 1 from social_private.post_tombstones where id=ids[6])then raise exception 'Physical delete left no tombstone';end if;
 known:=to_jsonb(ids)||jsonb_build_array(blocked_post,gen_random_uuid());
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Graduates','since',since,'known_ids',known));
 if not(page->'removed' ? ids[5]::text and page->'removed' ? ids[6]::text and page->'removed' ? blocked_post::text)then raise exception 'Hidden/tombstoned/blocked post not removed %',page->'removed';end if;
 if exists(select 1 from jsonb_array_elements_text(page->'removed')r where not known ? r)then raise exception 'Delta reported an id the caller did not hold';end if;
 if exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id' in(blocked_post::text,ids[5]::text))then raise exception 'Unreadable post returned as changed';end if;
 if (public.social_gateway('feed.delta',hb,'{"community":"Graduates"}'))->>'code' is distinct from 'invalid' then raise exception 'Delta without a clock accepted';end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Graduates','since',since,'known_ids',(select jsonb_agg(gen_random_uuid())from generate_series(1,400))));
 if jsonb_array_length(page->'removed')>300 then raise exception 'Known ids not clamped';end if;

 -- Replies: the newest 50 ride on the post, older ones page without duplicates.
 insert into social_private.comments(post,author,nonce,body,anonymous)select ids[2],b,gen_random_uuid(),'Bulk reply '||g,true from generate_series(1,60)g;
 obj:=social_private.post_json(b,(select p from social_private.posts p where p.id=ids[2]),50);
 if jsonb_array_length(obj->'comments')<>50 or (obj->>'commentCount')::int<>61 then raise exception 'Reply window wrong % %',jsonb_array_length(obj->'comments'),obj->>'commentCount';end if;
 cursor:='{}';
 for i in 1..5 loop
  page:=public.social_gateway('comments.page',hb,jsonb_build_object('post_id',ids[2],'limit',50)||cursor);
  if page?'error' then raise exception 'comments.page failed %',page;end if;
  for obj in select value from jsonb_array_elements(page->'comments') loop
   if (obj->>'id')::uuid=any(comment_ids) then raise exception 'Reply page repeated';end if;
   comment_ids:=comment_ids||(obj->>'id')::uuid;
  end loop;
  exit when jsonb_typeof(page->'next')is distinct from 'object';
  cursor:=page->'next';
 end loop;
 if cardinality(comment_ids)<>61 then raise exception 'Reply pages skipped replies %',cardinality(comment_ids);end if;
 if (public.social_gateway('comments.page',hc,jsonb_build_object('post_id',ids[5])))?'error' then raise exception 'Readable post replies refused';end if;
 if (public.social_gateway('comments.page',hb,jsonb_build_object('post_id',ids[5])))->>'code' is distinct from 'forbidden' then raise exception 'Hidden post replies served';end if;

 -- Messages: after_seq returns only newer rows, anonymity and membership hold.
 out:=public.social_gateway('dm.request',hb,jsonb_build_object('post_id',ids[7],'text','Feed QA hello'));dm_room:=out->>'resource_id';
 if dm_room is null then raise exception 'DM request failed %',out;end if;
 out:=public.social_gateway('dm.accept',ha,jsonb_build_object('room_id',dm_room));if out?'error' then raise exception 'Accept failed %',out;end if;
 select max(seq)into first_seq from social_private.messages where room=dm_room;
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',dm_room,'text','Newer one','nonce',gen_random_uuid()));
 out:=public.social_gateway('room.send',hb,jsonb_build_object('room_id',dm_room,'text','Newer two','nonce',gen_random_uuid()));
 page:=public.social_gateway('room.messages',hb,jsonb_build_object('room_id',dm_room,'after_seq',first_seq));
 if page?'error' or jsonb_array_length(page->'messages')<>2 then raise exception 'after_seq page wrong %',page;end if;
 if exists(select 1 from jsonb_array_elements(page->'messages')e where (e->>'sequence')::bigint<=first_seq)then raise exception 'after_seq returned old rows';end if;
 if exists(select 1 from jsonb_array_elements(page->'messages')e where e->>'author' not in('You','Them'))or page::text like '%feed_a_%' then raise exception 'Anonymous DM leaked a name %',page;end if;
 if page->'meta'->>'id' is distinct from dm_room then raise exception 'Room metadata missing';end if;
 if (public.social_gateway('room.messages',hc,jsonb_build_object('room_id',dm_room)))->>'code' is distinct from 'forbidden' then raise exception 'Non-member read the room';end if;
 if (public.social_gateway('room.messages',hb,jsonb_build_object('room_id',dm_room,'after_seq',1,'before_seq',9)))->>'code' is distinct from 'invalid' then raise exception 'Both cursors accepted';end if;
 insert into social_private.messages(room,author,nonce,body)select dm_room,a,gen_random_uuid(),'Bulk '||g from generate_series(1,70)g;
 page:=public.social_gateway('room.messages',hb,jsonb_build_object('room_id',dm_room,'after_seq',first_seq,'limit',500));
 if jsonb_array_length(page->'messages')<>50 or not (page->>'more')::boolean then raise exception 'Message limit not clamped';end if;
 if ((page->'messages'->0)->>'sequence')::bigint<>(select min(seq)from social_private.messages where room=dm_room and seq>first_seq)then raise exception 'after_seq does not start right after the cursor';end if;
 select e into conversation from jsonb_array_elements(social_private.snapshot(b)->'conversations')e where e->>'id'=dm_room;
 if jsonb_array_length(conversation->'messages')<>50 or ((conversation->'messages'->49)->>'sequence')::bigint<>(select max(seq)from social_private.messages where room=dm_room)then raise exception 'Snapshot does not embed the newest 50 messages';end if;
 insert into social_private.blocks values(b,a)on conflict do nothing;
 if (public.social_gateway('room.messages',hb,jsonb_build_object('room_id',dm_room)))->>'code' is distinct from 'forbidden' then raise exception 'Blocked DM still readable';end if;
 delete from social_private.blocks where blocker=b and blocked=a;

 -- An open chat sees deletions and reactions on held messages (changed_since with after_seq).
 select max(seq)into first_seq from social_private.messages where room=dm_room;
 select id into msg_one from social_private.messages where room=dm_room and author=a order by seq desc limit 1;
 select id into msg_two from social_private.messages where room=dm_room and author=b order by seq desc limit 1;
 since:=extract(epoch from clock_timestamp());
 perform pg_sleep(0.01);
 out:=public.social_gateway('room.delete',hb,jsonb_build_object('message_id',msg_two));if out?'error' then raise exception 'Message delete failed %',out;end if;
 out:=public.social_gateway('room.react',hb,jsonb_build_object('message_id',msg_one,'emoji','👍'));if out?'error' then raise exception 'Reaction failed %',out;end if;
 page:=public.social_gateway('room.messages',ha,jsonb_build_object('room_id',dm_room,'after_seq',first_seq,'changed_since',since));
 if page?'error' or jsonb_array_length(page->'messages')<>0 then raise exception 'changed_since page wrong %',page;end if;
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=msg_two::text and (e->>'deleted')::boolean)then raise exception 'Deleted message not reported as changed';end if;
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=msg_one::text and (e->'reactions'->>'👍')::int=1)then raise exception 'Reaction not reported as changed';end if;
 if exists(select 1 from jsonb_array_elements(page->'changed')e where (e->>'sequence')::bigint>first_seq)then raise exception 'Changes beyond after_seq';end if;
 if (public.social_gateway('room.messages',ha,jsonb_build_object('room_id',dm_room,'changed_since',since)))->>'code' is distinct from 'invalid' then raise exception 'Changes without after_seq accepted';end if;
 for obj in select value from jsonb_array_elements('[{"after_seq":1e30},{"before_seq":-1},{"after_seq":1,"changed_since":1e300}]'::jsonb) loop
  page:=public.social_gateway('room.messages',ha,jsonb_build_object('room_id',dm_room)||obj);
  if page->>'code' is distinct from 'invalid' then raise exception 'Out-of-range message cursor accepted % %',obj,page;end if;
 end loop;
 select changed_at into stamp from social_private.messages where id=msg_two;
 update social_private.messages set deleted=true,body='' where id=msg_two;
 if (select changed_at from social_private.messages where id=msg_two)<>stamp then raise exception 'Rewriting a deleted message moved it';end if;

 -- Renames, blocks and bookmarks move nothing a third party could use to link anonymous content.
 -- (B and C stay blocked from the removal checks above, so C and D play the other members here.)
 insert into social_private.members(token_hash,username,adult,network_hash)values(hd,'feed_d_'||substr(hd,1,8),true,hd)returning id into d;
 out:=public.social_gateway('post.create',hc,'{"text":"Named C post","anonymous":false,"community":"Graduates"}');c_named:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',hc,'{"text":"Anonymous C post","anonymous":true,"community":"Graduates"}');c_anon:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',hc,'{"text":"Zero-score C post","anonymous":true,"community":"Graduates"}');c_zero:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.vote',hc,jsonb_build_object('post_id',c_zero,'value',0));if out?'error' then raise exception 'Withdrawing the author vote failed %',out;end if;
 out:=public.social_gateway('post.create',ha,'{"text":"Named A post","anonymous":false,"community":"Graduates"}');named_a:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('comment.create',ha,jsonb_build_object('post_id',c_named,'text','Anonymous A reply','anonymous',true));if out?'error' then raise exception 'Reply failed %',out;end if;
 out:=public.social_gateway('post.vote',hd,jsonb_build_object('post_id',c_anon,'value',1));if out?'error' then raise exception 'Vote failed %',out;end if;
 select jsonb_object_agg(id,changed_at)into stamps from social_private.posts where id in(c_named,c_anon,c_zero,named_a,ids[1],ids[7]);
 perform pg_sleep(0.01);
 out:=public.social_gateway('profile.update',ha,jsonb_build_object('username','feed_r_'||substr(ha,1,8)));if out?'error' then raise exception 'Rename failed %',out;end if;
 if (select changed_at from social_private.posts where id=named_a)=(stamps->>named_a::text)::timestamptz then raise exception 'Named post did not move with the rename';end if;
 if (select changed_at from social_private.posts where id=c_named)<>(stamps->>c_named::text)::timestamptz then raise exception 'A rename moved a post holding only an anonymous reply';end if;
 if (select changed_at from social_private.posts where id=ids[1])<>(stamps->>ids[1]::text)::timestamptz then raise exception 'A rename moved an anonymous post';end if;
 if not exists(select 1 from social_private.feed_resyncs where member=a)then raise exception 'Renaming member not asked to resync';end if;
 out:=public.social_gateway('post.save',hd,jsonb_build_object('post_id',ids[7],'saved',true));if out?'error' then raise exception 'Save failed %',out;end if;
 if (select changed_at from social_private.posts where id=ids[7])<>(stamps->>ids[7]::text)::timestamptz then raise exception 'A bookmark moved the post';end if;
 stamp:=clock_timestamp();
 perform pg_sleep(0.01);
 insert into social_private.blocks values(d,c);
 if (select changed_at from social_private.posts where id=c_anon)=(stamps->>c_anon::text)::timestamptz then raise exception 'A block did not move the post whose score lost the vote';end if;
 if (select changed_at from social_private.posts where id=c_named)<>(stamps->>c_named::text)::timestamptz then raise exception 'A block moved a post without a vote between the members';end if;
 if not exists(select 1 from social_private.feed_resyncs where member=d and at>stamp)or not exists(select 1 from social_private.feed_resyncs where member=c and at>stamp)then raise exception 'Block parties not asked to resync';end if;
 -- since+5 s is when the previous delta read; markers before that were answered already.
 page:=public.social_gateway('feed.delta',hd,jsonb_build_object('community','Graduates','since',extract(epoch from stamp)-5,'known_ids','[]'::jsonb));
 if not (page->>'resync')::boolean then raise exception 'Delta did not report the resync';end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Graduates','since',extract(epoch from stamp)-5,'known_ids','[]'::jsonb));
 if (page->>'resync')::boolean then raise exception 'A third party was told to resync';end if;
 page:=public.social_gateway('feed.posts',hd,jsonb_build_object('community','Graduates','ids',jsonb_build_array(c_named,named_a,gen_random_uuid())));
 if page?'error' or jsonb_array_length(page->'posts')<>1 or page->'posts'->0->>'id'<>named_a::text or jsonb_array_length(page->'removed')<>2 or not page->'removed' ? c_named::text then raise exception 'feed.posts wrong %',page;end if;
 if (public.social_gateway('feed.posts',hd,'{"ids":"all"}'))->>'code' is distinct from 'invalid' then raise exception 'feed.posts accepted a non-list';end if;
 delete from social_private.blocks where blocker=d and blocked=c;

 -- A suspension moves what visibly changes: their scored posts and the posts they voted on,
 -- never a post of theirs that looks the same (zero score, no poll).
 out:=public.social_gateway('post.vote',hc,jsonb_build_object('post_id',named_a,'value',1));if out?'error' then raise exception 'Vote failed %',out;end if;
 select jsonb_object_agg(id,changed_at)into stamps from social_private.posts where id in(c_named,c_zero,named_a);
 perform pg_sleep(0.01);
 update social_private.members set banned=true where id=c;
 if (select changed_at from social_private.posts where id=c_named)=(stamps->>c_named::text)::timestamptz then raise exception 'Suspension did not move a scored post';end if;
 if (select changed_at from social_private.posts where id=named_a)=(stamps->>named_a::text)::timestamptz then raise exception 'Suspension did not move a post the member voted on';end if;
 if (select changed_at from social_private.posts where id=c_zero)<>(stamps->>c_zero::text)::timestamptz then raise exception 'Suspension moved a post that looks the same';end if;
 update social_private.members set banned=false where id=c;

 -- Account deletion soft-deletes posts; the delta reports them deleted with no author.
 since:=extract(epoch from clock_timestamp());
 select changed_at into stamp from social_private.posts where id=ids[3];
 out:=public.social_gateway('account.delete',ha);if out?'error' then raise exception 'Account delete failed %',out;end if;
 if (select changed_at from social_private.posts where id=ids[3])<>stamp then raise exception 'Account deletion moved a long-deleted post';end if;
 page:=public.social_gateway('feed.delta',hb,jsonb_build_object('community','Graduates','since',since,'known_ids',jsonb_build_array(ids[7])));
 if not exists(select 1 from jsonb_array_elements(page->'changed')e where e->>'id'=ids[7]::text and (e->>'deleted')::boolean and e->>'author'='[deleted]')and not(page->'removed' ? ids[7]::text)then raise exception 'Deleted account post not synced %',page;end if;
end $$;
select 'PASS keyset feed/reply pages without skips under inserts, delta for votes/replies/deletes, removed for hidden/blocked/tombstoned, after_seq messages and changes to held messages, renames/blocks/bookmarks/suspensions moving only visible changes, per-member resync, feed.posts, anonymity, membership, blocks, clamped limits, invalid ranges and a slim snapshot' result;
rollback;
