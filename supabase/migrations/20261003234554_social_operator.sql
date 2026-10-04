create table social_private.operator_audit(id bigint generated always as identity primary key,reviewer text not null,db_role text not null default current_user,action text not null,target text,reason text not null,created_at timestamptz not null default now());
alter table social_private.operator_audit enable row level security;
create policy database_operator on social_private.operator_audit to postgres using(true)with check(true);
revoke all on social_private.operator_audit from public,anon,authenticated,service_role;
create or replace function social_private.operator(p_action text,p_input jsonb default '{}',p_reviewer text default '')returns jsonb language plpgsql security invoker set search_path=''as $$
declare result jsonb;target uuid;rep social_private.reports;note text:=btrim(coalesce(p_input->>'note',''));decision text:=p_input->>'decision';
begin
 if p_action='reports.list'then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]')into result from(select id,target_type,target_id,reason,evidence,status,created_at from social_private.reports where status=coalesce(p_input->>'status','pending')order by created_at limit 100)x;return result;
 elsif p_action='organizations.list'then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]')into result from(select id,name,about,status,application,created_at from social_private.organizations where status=coalesce(p_input->>'status','pending')order by created_at limit 100)x;return result;
 elsif p_action='audit.list'then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]')into result from(select *from social_private.operator_audit order by id desc limit 100)x;return result;
 elsif p_action='storage.list'then
  select coalesce(jsonb_agg(to_jsonb(x)),'[]')into result from(select *from social_private.storage_deletions order by created_at limit 100)x;return result;
 end if;
 if char_length(btrim(p_reviewer))not between 3 and 100 or char_length(note)not between 5 and 2000 then raise exception 'Provide a reviewer label and a specific review note (5–2,000 characters).';end if;
 if p_action='reports.review'then
  select *into rep from social_private.reports where id=(p_input->>'id')::uuid for update;
  if rep.id is null then raise exception 'Unknown report';end if;
  if decision not in('resolved','dismissed','remove')then raise exception 'Choose resolved, dismissed or remove';end if;
  if decision='remove'then
   if rep.target_type='post'then update social_private.posts set deleted=true,body='',accepts_dm=false where id=rep.target_id::uuid;
   elsif rep.target_type='comment'then update social_private.comments set deleted=true,body=''where id=rep.target_id::uuid;
   elsif rep.target_type='message'then update social_private.messages set deleted=true,body=''where id=rep.target_id::uuid;
   elsif rep.target_type='activity'then update social_private.activities set cancelled=true where id=rep.target_id::uuid;update social_private.rooms set status='closed'where id=(select room from social_private.activities where id=rep.target_id::uuid);
   elsif rep.target_type='organization'then update social_private.organizations set status='suspended'where id=rep.target_id::uuid;
   elsif rep.target_type='room'then update social_private.rooms set status='closed'where id=rep.target_id;update social_private.calls set state='ended',ended_at=now(),end_reason='moderated'where room=rep.target_id and state<>'ended';
   else raise exception 'Use the feature-specific moderation workflow for this target';end if;
  end if;
  update social_private.reports set status=case when decision='remove'then 'action_taken'else decision end where id=rep.id;target:=rep.id;
 elsif p_action='organizations.review'then
  if decision not in('verified','declined','suspended')then raise exception 'Choose verified, declined or suspended';end if;
  if decision='verified'and not coalesce((p_input->>'evidence_checked')::boolean,false)then raise exception 'Review evidence and authority before verification';end if;
  update social_private.organizations set status=decision where id=(p_input->>'id')::uuid returning id into target;
  if target is null then raise exception 'Unknown organization';end if;
  if decision<>'verified'then update social_private.calls set state='ended',ended_at=now(),end_reason='moderated'where state<>'ended'and room in(select id from social_private.rooms where meta->>'organization'=target::text);end if;
 elsif p_action='members.suspend'then
  if p_input->>'username' is not null then select id into target from social_private.members where username=p_input->>'username';
  else
   select *into rep from social_private.reports where id=(p_input->>'report_id')::uuid;
   if rep.target_type='post'then select author into target from social_private.posts where id=rep.target_id::uuid;
   elsif rep.target_type='comment'then select author into target from social_private.comments where id=rep.target_id::uuid;
   elsif rep.target_type='message'then select author into target from social_private.messages where id=rep.target_id::uuid;
   elsif rep.target_type='activity'then select host into target from social_private.activities where id=rep.target_id::uuid;
   elsif rep.target_type='room'then select member into target from social_private.room_members where room=rep.target_id and member<>rep.reporter and exists(select 1 from social_private.rooms where id=rep.target_id and kind='dm')limit 1;
   end if;
  end if;
  if target is null then raise exception 'No current member resolved; specify a named username or a report about a specific author';end if;
  update social_private.members set banned=true where id=target;
  update social_private.calls set state='ended',ended_at=now(),end_reason='moderated'where state<>'ended'and target in(caller,callee);
  update social_private.rooms set status='closed'where kind='dm'and exists(select 1 from social_private.room_members where room=rooms.id and member=target);
 else raise exception 'Unknown operator action';end if;
 insert into social_private.operator_audit(reviewer,action,target,reason)values(btrim(p_reviewer),p_action||':'||coalesce(decision,''),target::text,note);
 return jsonb_build_object('applied',true,'action',p_action,'decision',decision);
end $$;
revoke all on function social_private.operator(text,jsonb,text)from public,anon,authenticated,service_role;
