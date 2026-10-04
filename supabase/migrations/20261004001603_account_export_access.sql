-- Export authored text without revealing new metadata from rooms the caller left.
create or replace function public.account_controls(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;other uuid;f social_private.friends;v_name text;v_id uuid;items jsonb;section text:=p_input->>'section';offset_n int:=coalesce((p_input->>'offset')::int,0);resource uuid;context_label text;
begin
 me:=social_private.require_account(p_hash);
 if p_action like 'connection.%'then me:=social_private.require_member(p_hash);end if;
 if p_action='connection.request'then
  v_name:=lower(btrim(replace(coalesce(p_input->>'username',''),'@','')));
  if v_name!~'^[a-z0-9_]{3,20}$'then raise exception 'invalid:Enter a valid username.';end if;
  select id into other from social_private.members where username=v_name and not banned and id<>me;
  if other is null or social_private.blocked(me,other)then raise exception 'unavailable:This connection is unavailable.';end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me,other)::text||greatest(me,other)::text,883));
  select *into f from social_private.friends where (a=me and b=other)or(a=other and b=me)for update;
  if f.id is not null and f.status in('pending','accepted')then
   return jsonb_build_object('connections',social_private.connection_list(me),'notice',case when f.status='accepted'then 'You are already connected.'when f.b=me then 'This person already invited you. Accept their request below.'else 'Your request is waiting for acceptance.'end);
  end if;
  if f.id is not null and f.updated_at>now()-interval '24 hours'then raise exception 'rate_limit:Please wait before requesting this connection again.';end if;
  if(select count(*)from social_private.friends where a=me and created_at>now()-interval '1 hour')>=20 or(select count(*)from social_private.friends where a=me and status='pending')>=50 then raise exception 'rate_limit:Too many pending requests. Try again later.';end if;
  if f.id is null then insert into social_private.friends(a,b,status)values(me,other,'pending')returning id into resource;
  else update social_private.friends set a=me,b=other,status='pending',created_at=now(),updated_at=now()where id=f.id returning id into resource;end if;
 elsif p_action in('connection.accept','connection.remove')then
  select *into f from social_private.friends where id=(p_input->>'id')::uuid and me in(a,b)for update;
  if f.id is null then raise exception 'unavailable:This request is unavailable.';end if;
  if p_action='connection.accept'then
   if f.b<>me or f.status<>'pending'or social_private.blocked(f.a,f.b)or exists(select 1 from social_private.members where id in(f.a,f.b)and banned)then raise exception 'forbidden:Only the invited person can accept an active request.';end if;
   update social_private.friends set status='accepted',updated_at=now()where id=f.id;
  else update social_private.friends set status='declined',updated_at=now()where id=f.id;end if;
 elsif p_action='block.remove'then
  delete from social_private.blocks where blocker=me and blocked=(select blocked from social_private.block_labels where blocker=me and id=(p_input->>'id')::uuid);
 elsif p_action in('block.context','block.tag_context')then
  -- Internal decoration only: the Edge allowlist never exposes these actions.
  -- The calling feature invokes this only after its authorized block succeeds.
  if p_action='block.tag_context'then
   select p.member_id,'Campus Tag · '||left(l.title,60)into other,context_label from tag_private.players p join tag_private.lobbies l on l.id=p.lobby_id where p.id=(p_input->>'target')::uuid and exists(select 1 from tag_private.players mine where mine.lobby_id=l.id and mine.member_id=me);
  elsif p_input?'post_id'or p_input->>'target_type'='post'then
   select author,case when anonymous then 'Anonymous post'else 'Community post'end||' · '||left(body,70)into other,context_label from social_private.posts where id=coalesce(p_input->>'post_id',p_input->>'target_id')::uuid;
  elsif p_input->>'target_type'='message'then
   select m.author,case when r.anonymous then 'Anonymous conversation'else 'Message in '||left(r.title,50)end into other,context_label from social_private.messages m join social_private.rooms r on r.id=m.room where m.id=(p_input->>'target_id')::uuid and exists(select 1 from social_private.room_members where room=r.id and member=me);
  else
   select rm.member,case when r.anonymous then 'Anonymous conversation'else 'Direct conversation'end into other,context_label from social_private.room_members rm join social_private.rooms r on r.id=rm.room where r.id=coalesce(p_input->>'room_id',p_input->>'target_id')and r.kind='dm'and rm.member<>me and exists(select 1 from social_private.room_members mine where mine.room=r.id and mine.member=me)limit 1;
  end if;
  if other is not null and context_label is not null then update social_private.block_labels set label=context_label where blocker=me and blocked=other;end if;
  return jsonb_build_object('ok',true);
 elsif p_action='export'then
  if offset_n<0 or offset_n>1000000 then raise exception 'invalid:Invalid export page.';end if;
  if section='account'then
   select jsonb_build_object('username',username,'adult_self_attested',adult,'nsfw_enabled',nsfw_enabled,'created_at',extract(epoch from created_at),'mailbox',verification_private.status(me))into items from social_private.members where id=me;
   return jsonb_build_object('data',items,'has_more',false);
  elsif section='posts'then
   select coalesce(jsonb_agg(x),'[]')into items from(select id,body,anonymous,community,accepts_dm,deleted,created_at from social_private.posts where author=me order by created_at,id limit 200 offset offset_n)x;
  elsif section='replies'then
   select coalesce(jsonb_agg(x),'[]')into items from(select id,post as post_id,body,anonymous,deleted,created_at from social_private.comments where author=me order by created_at,id limit 200 offset offset_n)x;
  elsif section='messages'then
   select coalesce(jsonb_agg(x),'[]')into items from(select m.id,m.room as room_id,case when not social_private.can_read_room(me,r.id)then 'Former conversation'when r.anonymous then 'Anonymous conversation'else r.title end as context,m.body,m.deleted,m.created_at from social_private.messages m join social_private.rooms r on r.id=m.room where m.author=me order by m.created_at,m.id limit 200 offset offset_n)x;
  elsif section='memberships'then
   select coalesce(jsonb_agg(x),'[]')into items from(select r.id as room_id,case when not social_private.can_read_room(me,r.id)then 'Former or declined conversation'when r.anonymous then 'Anonymous conversation'else r.title end as title,r.kind,rm.role,rm.status,rm.joined_at from social_private.room_members rm join social_private.rooms r on r.id=rm.room where rm.member=me order by rm.joined_at,r.id limit 200 offset offset_n)x;
  elsif section='activities'then
   select coalesce(jsonb_agg(x),'[]')into items from(select id,title,kind,place,starts,capacity,details,course,cancelled,approval_required,created_at from social_private.activities where host=me order by created_at,id limit 200 offset offset_n)x;
  elsif section='media_metadata'then
   select coalesce(jsonb_agg(x),'[]')into items from(select id,kind,mime,size,ready,created_at from social_private.attachments where owner=me order by created_at,id limit 200 offset offset_n)x;
  elsif section='submitted_reports'then
   select coalesce(jsonb_agg(x),'[]')into items from(select id,target_type,reason,status,created_at from social_private.reports where reporter=me order by created_at,id limit 200 offset offset_n)x;
  elsif section='preferences'then
   return jsonb_build_object('data',jsonb_build_object('saved_events',(select coalesce(jsonb_agg(event_id),'[]')from social_private.saved_events where member=me),'saved_posts',(select coalesce(jsonb_agg(post),'[]')from social_private.bookmarks where member=me),'hidden_posts',(select coalesce(jsonb_agg(post),'[]')from social_private.hidden where member=me),'votes',(select coalesce(jsonb_agg(jsonb_build_object('post_id',post,'value',value)),'[]')from social_private.votes where member=me),'connections',social_private.connection_list(me),'blocks',social_private.block_list(me)),'has_more',false);
  else raise exception 'invalid:Unknown export section.';end if;
  return jsonb_build_object('data',items,'has_more',jsonb_array_length(items)=200);
 elsif p_action not in('connections','blocks')then raise exception 'invalid:Unknown account control.';end if;
 return jsonb_build_object('connections',social_private.connection_list(me),'blocks',social_private.block_list(me),'resource_id',resource);
end $$;
revoke all on function public.account_controls(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.account_controls(text,text,jsonb)to service_role;
