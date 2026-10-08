-- Community guidelines acceptance (versioned).
-- * social_private.guidelines_settings is a one-row config: the guidelines version every member
--   must have accepted before writing, and whether that is enforced. Version 1 ships enforced.
--   The operator changes it with guidelines.require (audited; tools/social-admin.py
--   require-guidelines), never through the app.
-- * social_private.guidelines_acceptances records each version a member accepted and when. The rows
--   go with the member: deleting the account removes them (foreign key, on delete cascade), and the
--   data export lists them under "account".
-- * Gateway action guidelines.accept {"version": <whole number>} records an acceptance. It is
--   idempotent (accepting the same version again keeps the first date) and refuses a version above
--   the required one. It answers with the usual snapshot.
-- * The snapshot carries "guidelines": {"required": <int>, "accepted": <int or null>,
--   "accepted_at": "<UTC ISO-8601, seconds, Z>" or null}, where accepted is the highest version the
--   member accepted (it may be below required after a version bump). The full snapshot also carries
--   "postCount", the member's posts that are not deleted (ownPostIDs keeps listing deleted ones).
-- * New posts (rich_post_create), new replies (comment.create), new message requests (dm.request,
--   only when it opens a new request) and new chat messages (room.send) raise
--   "guidelines:Review and accept the community guidelines to post." until the member has accepted
--   the required version. Nonce retries of a post, reply or message that already exists still return
--   it, so a version bump never turns a retry into a duplicate.
-- * The same check covers the other ways a member puts words or images in front of other members:
--   a new organization conversation (organization.message), a new activity (activity.create,
--   organization.publish, a weekly study series), activity.edit when it changes the title, place or
--   details, media added to an existing post (post.attach, attachment.authorize/reserve for a post),
--   a new group (group.create), a shared meme (meme.publish) and a new interest discovery chat
--   message (discovery "send", through member_random_before_continue; browser sessions are paired
--   to an app account, which accepts in the app). Not gated: answering requests, reacting, voting,
--   reporting, blocking, leaving, profile and group settings, organization posters (verified
--   administrators, reviewed by the operator) and the Campus Tag lobby chat, which is switched off
--   in the app.
-- * Every function is patched from its current definition with anchors (post_topics, the text
--   filter and feed sync patched the same functions before this), and each anchor must occur once.

create table if not exists social_private.guidelines_settings(
 id boolean primary key default true check (id),
 required_version integer not null check (required_version>=1),
 enforced boolean not null default true,
 updated_at timestamptz not null default now()
);
insert into social_private.guidelines_settings(id,required_version,enforced)values(true,1,true)on conflict(id)do nothing;

create table if not exists social_private.guidelines_acceptances(
 member uuid not null references social_private.members(id) on delete cascade,
 version integer not null check (version>=1),
 accepted_at timestamptz not null default now(),
 primary key(member,version)
);

-- No policies: both tables are reached only through the gateway and the operator.
alter table social_private.guidelines_settings enable row level security;
alter table social_private.guidelines_acceptances enable row level security;
revoke all on social_private.guidelines_settings,social_private.guidelines_acceptances from public,anon,authenticated;
grant select on social_private.guidelines_settings to service_role;
grant select,insert on social_private.guidelines_acceptances to service_role;

-- The member's guidelines state for the snapshot.
create or replace function social_private.guidelines_state(p_me uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('required',s.required_version,'accepted',a.version,
  'accepted_at',to_char(a.accepted_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))
 from social_private.guidelines_settings s
 left join lateral(select version,accepted_at from social_private.guidelines_acceptances where member=p_me order by version desc limit 1)a on true
 where s.id
$$;

-- Raises the guidelines error when enforcement is on and the member has not accepted the required version.
create or replace function social_private.require_guidelines(p_me uuid) returns void language plpgsql stable set search_path='' as $$
begin
 if exists(select 1 from social_private.guidelines_settings s where s.id and s.enforced
   and not exists(select 1 from social_private.guidelines_acceptances a where a.member=p_me and a.version>=s.required_version))then
  raise exception 'guidelines:Review and accept the community guidelines to post.';
 end if;
end $$;

-- Replaces exactly one occurrence of an anchor (session-local helper, gone after the migration).
create function pg_temp.guidelines_patch(p_def text,p_old text,p_new text,p_label text) returns text language plpgsql as $$
begin
 if strpos(p_def,p_old)=0 then raise exception '% anchor missing',p_label;end if;
 if strpos(substr(p_def,strpos(p_def,p_old)+1),p_old)>0 then raise exception '% anchor is not unique',p_label;end if;
 return replace(p_def,p_old,p_new);
end $$;

do $patch$
declare def text; old text;
begin
 -- Posts: after the nonce lookup (an existing post is returned unchanged), before any limit or filter.
 def:=pg_get_functiondef('social_private.rich_post_create(uuid,uuid,jsonb)'::regprocedure);
 old:='if topic_value is not null and not social_private.topic_available(topic_value,community_value)then';
 execute pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(p_me);\n '||old,'rich_post_create guidelines');

 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 -- Replies: only a new reply (a nonce retry returns the existing one).
 old:='if(select count(*)from social_private.comments where author=me and created_at>now()-interval ''1 minute'')>=30 then raise exception ''rate_limit:Take a moment before replying again.'';end if;';
 def:=pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n    '||old,'gateway reply guidelines');
 -- Message requests: only when a new request is opened (an existing conversation is returned as before).
 old:='body_value:=btrim(coalesce(p_input->>''text'',''Hi! I’d like to chat.''));';
 def:=pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n   '||old,'gateway dm.request guidelines');
 -- Organization messages: only when a new conversation (and its first message) is opened.
 old:='body_value:=btrim(coalesce(p_input->>''text'',''Hi! I have a question for your organization.''));';
 def:=pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n   '||old,'gateway organization.message guidelines');
 -- Activities (activity.create, organization.publish): a new activity only (a nonce retry returns it).
 old:=E'  if resource is null then\n   resource:=gen_random_uuid()::text;\n';
 def:=pg_temp.guidelines_patch(def,old,old||E'   perform social_private.require_guidelines(me);\n','gateway activity guidelines');
 -- activity.edit: only when it changes the title, place or details others read.
 old:='if a.cancelled then raise exception ''forbidden:This activity has been cancelled.'';end if;';
 def:=pg_temp.guidelines_patch(def,old,old||E'\n    if p_input?''title''or p_input?''place''or p_input?''details''then perform social_private.require_guidelines(me);end if;','gateway activity.edit guidelines');
 -- Media on an existing post: post.attach, and attachment.authorize/reserve for a post.
 old:='if p.author<>me then raise exception ''forbidden:Only the author may add media.''; end if;';
 def:=pg_temp.guidelines_patch(def,old,old||E'\n   perform social_private.require_guidelines(me);','gateway post.attach guidelines');
 old:='if exists(select 1 from social_private.attachments where post=p.id and ready)then raise exception ''invalid:This post already has media.'';end if;';
 def:=pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n    '||old,'gateway post attachment guidelines');
 -- Chat messages: a new message only (a nonce retry of a sent message returns it).
 old:='then raise exception ''conflict:This send identifier was already used for another message. Retry the original message.'';end if;';
 def:=pg_temp.guidelines_patch(def,old,old||E'\n  if msg.id is null then perform social_private.require_guidelines(me);end if;','gateway room.send guidelines');
 -- guidelines.accept {"version": n}: 1 <= n <= the required version; idempotent.
 old:=E' elsif p_action=''account.delete''then\n';
 def:=pg_temp.guidelines_patch(def,old,$r$ elsif p_action='guidelines.accept'then
  if jsonb_typeof(p_input->'version')is distinct from 'number'or(p_input->>'version')!~'^[0-9]{1,9}$'or(p_input->>'version')::int<1 then raise exception 'invalid:Choose a guidelines version.';end if;
  if(p_input->>'version')::int>(select required_version from social_private.guidelines_settings where id)then raise exception 'invalid:These guidelines are not available yet. Refresh and try again.';end if;
  insert into social_private.guidelines_acceptances(member,version)values(me,(p_input->>'version')::int)on conflict(member,version)do nothing;
$r$||old,'gateway guidelines.accept');
 execute def;

 -- Snapshot: the full and the verification-gated forms both carry "guidelines".
 def:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 old:='''savedEvents'',''[]''::jsonb);';
 def:=pg_temp.guidelines_patch(def,old,'''savedEvents'',''[]''::jsonb,''guidelines'',social_private.guidelines_state(p_me));','snapshot gated guidelines');
 old:='return community_private.decorate_snapshot(p_me,result);';
 -- The full form also carries postCount: the member's posts that are not deleted (ownPostIDs lists
 -- deleted ones too), for the private Posts tile.
 execute pg_temp.guidelines_patch(def,old,'return community_private.decorate_snapshot(p_me,result)||jsonb_build_object(''guidelines'',social_private.guidelines_state(p_me),''postCount'',(select count(*)from social_private.posts where author=p_me and not deleted));','snapshot guidelines');

 -- Export: the account section lists every accepted version with its date.
 def:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 old:='''mailbox'',verification_private.status(me))into items from social_private.members where id=me;';
 execute pg_temp.guidelines_patch(def,old,'''mailbox'',verification_private.status(me),''guidelines_acceptances'',(select coalesce(jsonb_agg(jsonb_build_object(''version'',g.version,''accepted_at'',g.accepted_at)order by g.version),''[]'')from social_private.guidelines_acceptances g where g.member=me))into items from social_private.members where id=me;','account_controls export guidelines');

 -- Operator: guidelines.require {"version": n, "enforced": true|false (optional), "note"} (audited).
 def:=pg_get_functiondef('social_private.operator(text,jsonb,text)'::regprocedure);
 old:=E' if p_action in(''filter.add'',''filter.remove'')then\n';
 execute pg_temp.guidelines_patch(def,old,$r$ if p_action='guidelines.require'then
  if char_length(btrim(p_reviewer))not between 3 and 100 or char_length(note_value)not between 5 and 2000 then raise exception 'Provide a reviewer label and review note.';end if;
  if jsonb_typeof(p_input->'version')is distinct from 'number'or(p_input->>'version')!~'^[0-9]{1,9}$'or(p_input->>'version')::int<1 then raise exception 'Give a positive whole guidelines version';end if;
  if p_input?'enforced'and jsonb_typeof(p_input->'enforced')<>'boolean'then raise exception 'enforced must be true or false';end if;
  update social_private.guidelines_settings set required_version=(p_input->>'version')::int,enforced=coalesce((p_input->>'enforced')::boolean,enforced),updated_at=now()where id
   returning jsonb_build_object('required_version',required_version,'enforced',enforced)into result;
  insert into social_private.operator_audit(reviewer,action,target,reason)values(btrim(p_reviewer),p_action,result::text,note_value);
  return jsonb_build_object('applied',true,'action',p_action)||result;
 end if;
$r$||old,'operator guidelines.require');

 -- Groups: a new group (a nonce retry returns the existing one before this point).
 def:=pg_get_functiondef('public.communities_gateway(text,text,jsonb)'::regprocedure);
 old:='if(select count(*)from community_private.communities where creator=me and created_at>now()-interval ''1 day'')>=3 then';
 execute pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n  '||old,'communities create guidelines');

 -- Shared memes: publishing (the edge function removes the uploaded file when this refuses), and the
 -- handler passes the guidelines code through like the other client codes.
 def:=pg_get_functiondef('public.social_memes(text,text,jsonb)'::regprocedure);
 old:='if (select count(*) from social_private.shared_memes where owner=me and created_at>now()-interval ''24 hours'')>=30 then';
 def:=pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n  '||old,'meme.publish guidelines');
 old:='in(''unauthorized'',''forbidden'',''invalid'',''rate_limit'',''not_found'')';
 execute pg_temp.guidelines_patch(def,old,'in(''unauthorized'',''forbidden'',''invalid'',''rate_limit'',''not_found'',''guidelines'')','meme handler guidelines');

 -- Weekly study series (activity_plans series.create): a new series only (a retry returns it above).
 def:=pg_get_functiondef('public.activity_plans(text,text,jsonb)'::regprocedure);
 old:='count_value:=(args->>''weeks'')::int;';
 execute pg_temp.guidelines_patch(def,old,E'perform social_private.require_guidelines(me);\n   '||old,'series.create guidelines');

 -- Interest discovery text chat (and the member random chat it runs on): a new message only; a
 -- nonce the member already sent is passed through so its retry still answers.
 def:=pg_get_functiondef('public.member_random_before_continue(text,text,jsonb)'::regprocedure);
 old:='result:=public.random_chat_gateway(case when p_action in(''register'',''capabilities'',''media'')then ''poll''else p_action end,ph,p_input);';
 execute pg_temp.guidelines_patch(def,old,'if p_action=''send''and not exists(select 1 from random_private.messages where sender=pid and nonce=(p_input->>''nonce'')::uuid)then perform social_private.require_guidelines(me);end if;'||E'\n '||old,'discovery send guidelines');
end $patch$;
revoke all on function social_private.operator(text,jsonb,text) from public,anon,authenticated,service_role;

-- create or replace keeps the privileges of the patched functions; only the new helpers need them.
do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.guidelines_state(uuid)','social_private.require_guidelines(uuid)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end $grants$;
