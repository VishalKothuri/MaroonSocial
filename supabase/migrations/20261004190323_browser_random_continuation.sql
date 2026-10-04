-- PostgreSQL ARE repetition bounds stop at255; APNs device tokens may be longer.
alter table push_private.devices drop constraint devices_token_check;
alter table push_private.devices add constraint devices_token_check check(token~'^[a-f0-9]+$'and char_length(token)between 32 and 512);
do $p$declare d text;begin d:=pg_get_functiondef('public.push_devices(text,text,jsonb)'::regprocedure);d:=replace(d,'coalesce(p_input->>''token'','''')!~''^[a-f0-9]{32,512}$''','(coalesce(p_input->>''token'','''')!~''^[a-f0-9]+$''or char_length(coalesce(p_input->>''token'',''''))not between 32 and 512)');execute d;end $p$;
create table random_private.browser_pairs(code_hash text primary key,member uuid not null references social_private.members on delete cascade,created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '60 seconds',used_at timestamptz);
create index browser_pairs_member on random_private.browser_pairs(member,created_at);
create table random_private.browser_sessions(token_hash text primary key,member uuid not null references social_private.members on delete cascade,expires_at timestamptz not null default now()+interval '1 hour',created_at timestamptz not null default now());
create index browser_sessions_member on random_private.browser_sessions(member);
create table random_private.browser_limits(network text primary key,window_start timestamptz not null,count integer not null);
create table random_private.continuations(room uuid primary key references random_private.rooms on delete cascade,conversation text not null references social_private.rooms on delete cascade,requester uuid references social_private.members on delete set null,created_at timestamptz not null default now());
create index random_continuation_room on random_private.continuations(conversation);
create index random_continuation_requester on random_private.continuations(requester,created_at);
do $$declare t text;begin foreach t in array array['browser_pairs','browser_sessions','browser_limits','continuations']loop execute format('alter table random_private.%I enable row level security',t);execute format('create policy server_only on random_private.%I to service_role using(true)with check(true)',t);end loop;end $$;
revoke all on random_private.browser_pairs,random_private.browser_sessions,random_private.browser_limits,random_private.continuations from public,anon,authenticated;
grant all on random_private.browser_pairs,random_private.browser_sessions,random_private.browser_limits,random_private.continuations to service_role;
create function public.random_browser_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;pair random_private.browser_pairs;session_value random_private.browser_sessions;n integer;member_hash text;
begin
 if p_action='pair.create'then
  me:=social_private.require_member(p_hash);
  if coalesce(p_input->>'code_hash','')!~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid pairing request.';end if;
  if(select count(*)from random_private.browser_pairs where member=me and created_at>now()-interval '1 hour')>=6 then raise exception 'rate_limit:Wait before creating another pairing code.';end if;
  update random_private.browser_pairs set used_at=now()where member=me and used_at is null;
  insert into random_private.browser_pairs(code_hash,member)values(p_input->>'code_hash',me)returning *into pair;
  return jsonb_build_object('expires_at',extract(epoch from pair.expires_at));
 elsif p_action='pair.claim'then
  if coalesce(p_input->>'network_hash','')!~'^[a-f0-9]{64}$'or coalesce(p_input->>'token_hash','')!~'^[a-f0-9]{64}$'then raise exception 'invalid:Invalid browser request.';end if;
  insert into random_private.browser_limits(network,window_start,count)values(p_input->>'network_hash',now(),1)on conflict(network)do update set window_start=case when random_private.browser_limits.window_start<now()-interval '1 minute'then now()else random_private.browser_limits.window_start end,count=case when random_private.browser_limits.window_start<now()-interval '1 minute'then 1 else random_private.browser_limits.count+1 end returning count into n;
  if n>10 then return jsonb_build_object('error','Wait a minute before retrying a pairing code.','code','rate_limit');end if;
  select *into pair from random_private.browser_pairs where code_hash=p_input->>'code_hash'for update;
  if pair.code_hash is null or pair.used_at is not null or pair.expires_at<=now()then return jsonb_build_object('error','This pairing code is invalid or expired.','code','invalid');end if;
  select token_hash into member_hash from social_private.members where id=pair.member;
  me:=social_private.require_member(member_hash);
  update random_private.browser_pairs set used_at=now()where code_hash=pair.code_hash;
  if(select count(*)from random_private.browser_sessions where member=me and expires_at>now())>=3 then raise exception 'rate_limit:Sign out of another browser before pairing a new one.';end if;
  insert into random_private.browser_sessions(token_hash,member)values(p_input->>'token_hash',me)returning *into session_value;
  return jsonb_build_object('expires_at',extract(epoch from session_value.expires_at));
 elsif p_action in('resolve','logout')then
  select *into session_value from random_private.browser_sessions where token_hash=p_hash;
  if p_action='logout'then delete from random_private.browser_sessions where token_hash=p_hash;return jsonb_build_object('signed_out',true);end if;
  if session_value.token_hash is null or session_value.expires_at<=now()then raise exception 'unauthorized:Pair this browser with your app again.';end if;
  select token_hash into member_hash from social_private.members where id=session_value.member;
  perform social_private.require_member(member_hash);
  return jsonb_build_object('token_hash',member_hash,'expires_at',extract(epoch from session_value.expires_at));
 end if;raise exception 'invalid:Unknown browser action.';
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));end $$;
alter function public.member_random_gateway(text,text,jsonb)rename to member_random_before_continue;
revoke all on function public.member_random_before_continue(text,text,jsonb)from public,anon,authenticated;
create function public.member_random_gateway(p_action text,p_hash text,p_input jsonb default '{}')returns jsonb language plpgsql security invoker set search_path=''as $$
declare me uuid;pid uuid;peer uuid;r random_private.rooms;existing random_private.continuations;dm social_private.rooms;result jsonb;body_value text;member_hash text;
begin
 if p_action<>'continue'then return public.member_random_before_continue(p_action,p_hash,p_input);end if;
 me:=social_private.require_member(p_hash);
 select participant into pid from random_private.member_links where member=me;
 select *into r from random_private.rooms where pid in(a,b)order by created_at desc limit 1;
 if r.id is null or r.id is distinct from(p_input->>'room')::uuid or(r.ended_at is not null and r.ended_at<now()-interval '5 minutes')then raise exception 'ended:Send a request during or shortly after this conversation.';end if;
 select member into peer from random_private.member_links where participant=case when r.a=pid then r.b else r.a end;
 if peer is null or not random_private.eligible_pair(pid,case when r.a=pid then r.b else r.a end)then raise exception 'forbidden:This person cannot receive your request.';end if;
 perform pg_advisory_xact_lock(hashtextextended('continue:'||r.id::text,0));
 select *into existing from random_private.continuations where room=r.id;
 if existing.room is not null then
  select *into dm from social_private.rooms where id=existing.conversation;
  if dm.status='closed'or not exists(select 1 from social_private.room_members where room=dm.id and member=me)then raise exception 'forbidden:This request is no longer available.';end if;
 else
  body_value:=btrim(coalesce(p_input->>'text','I would like to continue our conversation.'));
  if char_length(body_value)not between 1 and 500 then raise exception 'invalid:Write a request of1–500characters.';end if;
  if(select count(*)from random_private.continuations where requester=me and created_at>now()-interval '1 hour')>=10 then raise exception 'rate_limit:Wait before sending more conversation requests.';end if;
  insert into social_private.rooms(kind,title,status,anonymous,requester,meta)values('dm','Anonymous conversation','pending',true,me,'{"random_conversation":true}')returning *into dm;
  insert into social_private.room_members(room,member,status)values(dm.id,me,'accepted'),(dm.id,peer,'invited');
  insert into social_private.messages(room,author,nonce,body)values(dm.id,me,gen_random_uuid(),body_value);
  insert into random_private.continuations(room,conversation,requester)values(r.id,dm.id,me);
 end if;
 result:=public.member_random_before_continue('poll',p_hash,p_input);
 if result?'error'then return result;end if;
 return result||jsonb_build_object('continue_room',dm.id,'continue_status',dm.status);
exception when raise_exception then return jsonb_build_object('error',substr(sqlerrm,strpos(sqlerrm,':')+1),'code',split_part(sqlerrm,':',1));when invalid_text_representation then return jsonb_build_object('error','Invalid conversation request.','code','invalid');end $$;
-- A named request must never reveal that a selected account was an anonymous random peer.
do $p$declare f record;d text;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','social_private')and p.prokind='f'and pg_get_functiondef(p.oid)like '%rooms.context_post is not distinct from p.id%'loop
 d:=pg_get_functiondef(f.signature);d:=replace(d,'and not(rooms.meta?''organization'')','and not(rooms.meta?''organization'')and not(rooms.meta?''random_conversation'')');execute d;
 end loop;
end $p$;
revoke all on function public.random_browser_gateway(text,text,jsonb),public.member_random_gateway(text,text,jsonb)from public,anon,authenticated;
grant execute on function public.random_browser_gateway(text,text,jsonb),public.member_random_gateway(text,text,jsonb)to service_role;
select cron.schedule('random_browser_cleanup','23 * * * *',$job$delete from random_private.browser_pairs where created_at<now()-interval '1 day';delete from random_private.browser_sessions where expires_at<=now();delete from random_private.browser_limits where window_start<now()-interval '1 day';$job$);
