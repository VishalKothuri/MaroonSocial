-- Transactional checks for community guidelines acceptance (20261007100000_community_guidelines).
-- Run as the database owner with psql; everything rolls back. Gateway calls run as service_role
-- (the edge function's role); operator commands run as the owner.
begin;

-- Privileges and seed -----------------------------------------------------------------------------
do $$
declare fn text;
begin
 foreach fn in array array['social_private.guidelines_state(uuid)','social_private.require_guidelines(uuid)'] loop
  if has_function_privilege('anon',fn,'EXECUTE') or has_function_privilege('authenticated',fn,'EXECUTE') then raise exception 'Exposed to clients: %',fn;end if;
  if not has_function_privilege('service_role',fn,'EXECUTE') then raise exception 'Gateway cannot call %',fn;end if;
 end loop;
 if has_function_privilege('service_role','social_private.operator(text,jsonb,text)','EXECUTE') then raise exception 'Operator reachable by the app role';end if;
 if has_table_privilege('anon','social_private.guidelines_settings','SELECT') or has_table_privilege('authenticated','social_private.guidelines_settings','SELECT')
  or has_table_privilege('anon','social_private.guidelines_acceptances','SELECT') or has_table_privilege('authenticated','social_private.guidelines_acceptances','SELECT')
  or has_table_privilege('anon','social_private.guidelines_acceptances','INSERT') or has_table_privilege('authenticated','social_private.guidelines_acceptances','INSERT') then raise exception 'Guidelines tables exposed to clients';end if;
 if has_table_privilege('service_role','social_private.guidelines_settings','UPDATE') or has_table_privilege('service_role','social_private.guidelines_settings','INSERT')
  or has_table_privilege('service_role','social_private.guidelines_acceptances','UPDATE') or has_table_privilege('service_role','social_private.guidelines_acceptances','DELETE') then raise exception 'App role can change guidelines records';end if;
 if not (select relrowsecurity from pg_class where oid='social_private.guidelines_settings'::regclass) or not (select relrowsecurity from pg_class where oid='social_private.guidelines_acceptances'::regclass) then raise exception 'RLS off on guidelines tables';end if;
 if (select count(*) from social_private.guidelines_settings)<>1 or not exists(select 1 from social_private.guidelines_settings where id and required_version=1 and enforced) then raise exception 'Guidelines setting is not version 1, enforced';end if;
 if (select confdeltype from pg_constraint where conrelid='social_private.guidelines_acceptances'::regclass and contype='f') is distinct from 'c' then raise exception 'Acceptances do not cascade with the member';end if;
 raise notice 'PASS privileges and seed';
end $$;

set local role service_role;
create temporary table qa(k text primary key,v text) on commit drop;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;out jsonb;g jsonb;pb uuid;room text;na uuid:=gen_random_uuid();nc uuid:=gen_random_uuid();nm uuid:=gen_random_uuid();bad jsonb;
 copy text:='Review and accept the community guidelines to post.';
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'guide_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'guide_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'guide_c_'||substr(hc,1,8),true,hc)returning id into c;
 -- A new member's snapshot reports the requirement and no acceptance.
 out:=public.social_gateway('snapshot',ha,'{}');
 if out?'error' then raise exception 'Snapshot failed %',out;end if;
 if out->'snapshot'->'guidelines' is distinct from '{"required":1,"accepted":null,"accepted_at":null}'::jsonb then raise exception 'Unaccepted guidelines state wrong %',out->'snapshot'->'guidelines';end if;
 -- b and c accept through the gateway; the reply is the usual snapshot.
 out:=public.social_gateway('guidelines.accept',hb,'{"version":1}');
 if out?'error' or out->'snapshot'->'guidelines'->>'accepted' is distinct from '1' then raise exception 'Accept failed %',out;end if;
 out:=public.social_gateway('guidelines.accept',hc,'{"version":1}');if out?'error' then raise exception 'Accept failed %',out;end if;

 -- Not accepted: each of the four writes is refused with the guidelines prefix, and nothing is written.
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Guidelines QA post','nonce',na));
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted post allowed or wrong error %',out;end if;
 if exists(select 1 from social_private.posts where author=a) then raise exception 'Refused post was written';end if;
 out:=public.social_gateway('post.create',hb,'{"text":"Guidelines QA host post"}');
 if out?'error' then raise exception 'Accepted member post failed %',out;end if;
 pb:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('comment.create',ha,jsonb_build_object('post_id',pb,'text','Guidelines QA reply','nonce',nc));
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted reply allowed %',out;end if;
 if exists(select 1 from social_private.comments where author=a) then raise exception 'Refused reply was written';end if;
 out:=public.social_gateway('dm.request',ha,jsonb_build_object('username','guide_b_'||substr(hb,1,8),'text','Guidelines QA request'));
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted DM request allowed %',out;end if;
 if exists(select 1 from social_private.rooms where requester=a) then raise exception 'Refused request opened a room';end if;
 -- b asks a; answering a request is not gated, sending in it is.
 out:=public.social_gateway('dm.request',hb,jsonb_build_object('username','guide_a_'||substr(ha,1,8),'text','Hello from b'));
 if out?'error' then raise exception 'Accepted member DM request failed %',out;end if;
 room:=out->>'resource_id';
 out:=public.social_gateway('dm.accept',ha,jsonb_build_object('room_id',room));
 if out?'error' then raise exception 'Answering a request was gated %',out;end if;
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',room,'text','Guidelines QA message','nonce',nm));
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted message allowed %',out;end if;
 if exists(select 1 from social_private.messages where author=a) then raise exception 'Refused message was written';end if;
 -- An existing conversation is still returned to dm.request (nothing new is opened or sent).
 out:=public.social_gateway('dm.request',ha,jsonb_build_object('username','guide_b_'||substr(hb,1,8)));
 if out->>'resource_id' is distinct from room then raise exception 'Existing conversation not returned %',out;end if;
 -- Reading stays open.
 out:=public.social_gateway('feed.page',ha,'{}');if out?'error' then raise exception 'Reading gated %',out;end if;

 -- Malformed and future versions are refused without a record.
 foreach bad in array array['{}','{"version":"1"}','{"version":1.5}','{"version":0}','{"version":-1}','{"version":null}','{"version":2}','{"version":99999999999}']::jsonb[] loop
  out:=public.social_gateway('guidelines.accept',ha,bad);
  if out->>'code' is distinct from 'invalid' then raise exception 'Bad acceptance % allowed %',bad,out;end if;
 end loop;
 if exists(select 1 from social_private.guidelines_acceptances where member=a) then raise exception 'Refused acceptance recorded';end if;

 -- Accept, then accept again (idempotent: one row, first date kept).
 out:=public.social_gateway('guidelines.accept',ha,'{"version":1}');
 if out?'error' then raise exception 'Accept failed %',out;end if;
 g:=out->'snapshot'->'guidelines';
 if g->>'required' is distinct from '1' or g->>'accepted' is distinct from '1' or coalesce(g->>'accepted_at','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$' then raise exception 'Accepted state wrong %',g;end if;
 if g->>'accepted_at' is distinct from to_char((select accepted_at from social_private.guidelines_acceptances where member=a and version=1) at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') then raise exception 'accepted_at is not the recorded UTC time %',g;end if;
 insert into qa values('a_first',(select accepted_at::text from social_private.guidelines_acceptances where member=a));
 out:=public.social_gateway('guidelines.accept',ha,'{"version":1}');
 if out?'error' or (select count(*) from social_private.guidelines_acceptances where member=a)<>1 then raise exception 'Repeated acceptance not idempotent %',out;end if;

 -- Accepted: the four writes go through.
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Guidelines QA post','nonce',na));
 if out?'error' then raise exception 'Accepted post failed %',out;end if;
 insert into qa values('pa',out->>'resource_id');
 out:=public.social_gateway('comment.create',ha,jsonb_build_object('post_id',pb,'text','Guidelines QA reply','nonce',nc));
 if out?'error' then raise exception 'Accepted reply failed %',out;end if;
 insert into qa values('ca',out->>'resource_id');
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',room,'text','Guidelines QA message','nonce',nm));
 if out?'error' then raise exception 'Accepted message failed %',out;end if;
 insert into qa values('ma',out->>'resource_id');
 out:=public.social_gateway('dm.request',ha,jsonb_build_object('username','guide_c_'||substr(hc,1,8),'text','Guidelines QA request'));
 if out?'error' then raise exception 'Accepted DM request failed %',out;end if;
 insert into qa values('a',a),('b',b),('c',c),('ha',ha),('hb',hb),('hc',hc),('pb',pb),('room',room),('na',na),('nc',nc),('nm',nm);
 raise notice 'PASS not accepted: post, reply, DM request and message refused; malformed/future versions refused; accept is idempotent; accepted: all four allowed';
end $$;

-- The operator raises the required version (owner only, audited).
reset role;
do $$
declare out jsonb;
begin
 begin
  perform social_private.operator('guidelines.require','{"version":2,"note":"QA guidelines bump"}','');
  raise exception 'Unreviewed bump allowed';
 exception when raise_exception then if sqlerrm='Unreviewed bump allowed' then raise; end if; end;
 begin
  perform social_private.operator('guidelines.require','{"version":0,"note":"QA guidelines bump"}','qa-guidelines');
  raise exception 'Version 0 allowed';
 exception when raise_exception then if sqlerrm='Version 0 allowed' then raise; end if; end;
 out:=social_private.operator('guidelines.require','{"version":2,"note":"QA guidelines bump"}','qa-guidelines');
 if out->>'required_version' is distinct from '2' or out->>'enforced' is distinct from 'true' then raise exception 'Bump failed %',out;end if;
 if not exists(select 1 from social_private.operator_audit where reviewer='qa-guidelines' and action='guidelines.require') then raise exception 'Bump not audited';end if;
end $$;

set local role service_role;
do $$
declare
 a uuid:=(select v from qa where k='a');ha text:=(select v from qa where k='ha');hb text:=(select v from qa where k='hb');hc text:=(select v from qa where k='hc');
 pb uuid:=(select v from qa where k='pb');room text:=(select v from qa where k='room');out jsonb;g jsonb;
 copy text:='Review and accept the community guidelines to post.';
begin
 -- After the bump, a version-1 acceptance no longer covers new writes.
 g:=(public.social_gateway('snapshot',ha,'{}'))->'snapshot'->'guidelines';
 if g->>'required' is distinct from '2' or g->>'accepted' is distinct from '1' or g->>'accepted_at' is null then raise exception 'Bumped state wrong %',g;end if;
 out:=public.social_gateway('post.create',ha,'{"text":"After the bump"}');
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Post allowed after bump %',out;end if;
 out:=public.social_gateway('comment.create',ha,jsonb_build_object('post_id',pb,'text','After the bump'));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Reply allowed after bump %',out;end if;
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',room,'text','After the bump'));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Message allowed after bump %',out;end if;
 out:=public.social_gateway('post.create',hb,'{"text":"b after the bump"}');
 if out->>'code' is distinct from 'guidelines' then raise exception 'Other member post allowed after bump %',out;end if;
 out:=public.social_gateway('dm.request',hc,jsonb_build_object('username',(select username from social_private.members where id=(select v::uuid from qa where k='b')),'text','After the bump'));
 if out->>'code' is distinct from 'guidelines' then raise exception 'DM request allowed after bump %',out;end if;
 -- Nonce retries of writes that already exist still return them (no duplicate after a bump).
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Guidelines QA post','nonce',(select v from qa where k='na')));
 if out->>'resource_id' is distinct from (select v from qa where k='pa') then raise exception 'Post retry refused after bump %',out;end if;
 out:=public.social_gateway('comment.create',ha,jsonb_build_object('post_id',pb,'text','Guidelines QA reply','nonce',(select v from qa where k='nc')));
 if out->>'resource_id' is distinct from (select v from qa where k='ca') then raise exception 'Reply retry refused after bump %',out;end if;
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',room,'text','Guidelines QA message','nonce',(select v from qa where k='nm')));
 if out->>'resource_id' is distinct from (select v from qa where k='ma') then raise exception 'Message retry refused after bump %',out;end if;
 -- A version above the new requirement is still refused; the new version is accepted.
 out:=public.social_gateway('guidelines.accept',ha,'{"version":3}');
 if out->>'code' is distinct from 'invalid' then raise exception 'Future version accepted %',out;end if;
 out:=public.social_gateway('guidelines.accept',ha,'{"version":2}');
 g:=out->'snapshot'->'guidelines';
 if out?'error' or g->>'required' is distinct from '2' or g->>'accepted' is distinct from '2' then raise exception 'Accepting the new version failed %',out;end if;
 if (select accepted_at::text from social_private.guidelines_acceptances where member=a and version=1) is distinct from (select v from qa where k='a_first') then raise exception 'First acceptance date changed';end if;
 out:=public.social_gateway('post.create',ha,'{"text":"After accepting version 2"}');
 if out?'error' then raise exception 'Post after accepting the new version failed %',out;end if;
 out:=public.social_gateway('room.send',ha,jsonb_build_object('room_id',room,'text','After accepting version 2'));
 if out?'error' then raise exception 'Message after accepting the new version failed %',out;end if;
 -- The export lists every accepted version with its date.
 out:=public.account_controls('export',ha,'{"section":"account"}');
 if jsonb_typeof(out->'data'->'guidelines_acceptances') is distinct from 'array' or (select string_agg(value->>'version',',' order by ordinality) from jsonb_array_elements(out->'data'->'guidelines_acceptances') with ordinality) is distinct from '1,2'
  or exists(select 1 from jsonb_array_elements(out->'data'->'guidelines_acceptances') where value->>'accepted_at' is null) then raise exception 'Export misses acceptances %',out;end if;
 out:=public.account_controls('export',hb,'{"section":"account"}');
 if jsonb_typeof(out->'data'->'guidelines_acceptances') is distinct from 'array' or (select count(*) from jsonb_array_elements(out->'data'->'guidelines_acceptances'))<>1 then raise exception 'Export shows another member''s acceptances %',out;end if;
 raise notice 'PASS version bump: earlier acceptance no longer covers new writes, retries return existing writes, future version refused, new version accepted, export';
end $$;

-- With enforcement off, writes are not gated (the requirement is still reported).
reset role;
select social_private.operator('guidelines.require','{"version":2,"enforced":false,"note":"QA enforcement off"}','qa-guidelines');
set local role service_role;
do $$
declare hb text:=(select v from qa where k='hb');out jsonb;
begin
 out:=public.social_gateway('post.create',hb,'{"text":"Enforcement off"}');
 if out?'error' then raise exception 'Post gated with enforcement off %',out;end if;
 if out->'snapshot'->'guidelines'->>'required' is distinct from '2' then raise exception 'Requirement not reported %',out->'snapshot'->'guidelines';end if;
end $$;
reset role;
select social_private.operator('guidelines.require','{"version":2,"enforced":true,"note":"QA enforcement on"}','qa-guidelines');
set local role service_role;

-- Account deletion removes the member's acceptances.
do $$
declare a uuid:=(select v from qa where k='a');ha text:=(select v from qa where k='ha');out jsonb;
begin
 if not exists(select 1 from social_private.guidelines_acceptances where member=a) then raise exception 'Fixture acceptances missing';end if;
 out:=public.social_gateway('account.delete',ha,'{}');
 if out?'error' then raise exception 'Account deletion failed %',out;end if;
 if exists(select 1 from social_private.guidelines_acceptances where member=a) then raise exception 'Deletion kept acceptances';end if;
 if not exists(select 1 from social_private.guidelines_acceptances where member=(select v::uuid from qa where k='b')) then raise exception 'Deletion removed another member''s acceptance';end if;
 raise notice 'PASS enforcement switch and account deletion';
end $$;

-- The other public writes ---------------------------------------------------------------------
-- u writes while accepted, then loses the acceptance (as after a version bump); v and the
-- organization administrator w have accepted. Each new write is refused for u and allowed for v or w;
-- retries and the existing-conversation path stay open for u.
reset role;
do $$
declare
 hu text:=encode(extensions.gen_random_bytes(32),'hex');hv text:=encode(extensions.gen_random_bytes(32),'hex');hw text:=encode(extensions.gen_random_bytes(32),'hex');
 uid uuid;vid uuid;wid uuid;o1 uuid;o2 uuid;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(hu,'guide_u_'||substr(hu,1,8),true,hu)returning id into uid;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hv,'guide_v_'||substr(hv,1,8),true,hv)returning id into vid;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hw,'guide_w_'||substr(hw,1,8),true,hw)returning id into wid;
 insert into social_private.guidelines_acceptances(member,version)select m,required_version from social_private.guidelines_settings,unnest(array[uid,vid,wid])m;
 insert into social_private.organizations(name,about,status)values('Guidelines QA org one','Testing','verified')returning id into o1;
 insert into social_private.organizations(name,about,status)values('Guidelines QA org two','Testing','verified')returning id into o2;
 insert into social_private.organization_admins(organization,member,role)values(o1,wid,'admin'),(o2,wid,'admin');
 insert into social_private.organization_admins(organization,member,role)values(o2,uid,'admin');
 insert into qa values('u',uid),('v',vid),('w',wid),('hu',hu),('hv',hv),('hw',hw),('o1',o1),('o2',o2),('nact',gen_random_uuid()),('nmsg',gen_random_uuid()),('iu',gen_random_uuid()),('iv',gen_random_uuid());
end $$;

set local role service_role;
do $$
declare
 hu text:=(select v from qa where k='hu');hv text:=(select v from qa where k='hv');uid uuid:=(select v::uuid from qa where k='u');vid uuid:=(select v::uuid from qa where k='v');
 iu uuid:=(select v::uuid from qa where k='iu');iv uuid:=(select v::uuid from qa where k='iv');out jsonb;pu uuid;att uuid;pv uuid;req uuid;sid uuid;
 starts double precision:=extract(epoch from now()+interval '3 days');
begin
 -- While accepted: u hosts an activity, posts with media waiting to attach, opens an organization
 -- conversation and sends a discovery chat message.
 out:=public.social_gateway('activity.create',hu,jsonb_build_object('title','Guidelines QA study','place','Evans Library','kind','Study','starts',starts,'capacity',4,'nonce',(select v from qa where k='nact')));
 if out?'error' then raise exception 'Fixture activity %',out;end if;insert into qa values('au',out->>'resource_id');
 out:=public.social_gateway('post.create',hu,'{"text":"Guidelines QA post with media"}');if out?'error' then raise exception 'Fixture post %',out;end if;pu:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('attachment.reserve',hu,jsonb_build_object('post_id',pu,'path',gen_random_uuid()||'.png','kind','image','mime','image/png','size',10));
 if out?'error' then raise exception 'Fixture reserve %',out;end if;att:=(out->>'attachment_id')::uuid;
 out:=public.social_gateway('attachment.commit',hu,jsonb_build_object('attachment_id',att));if out?'error' then raise exception 'Fixture commit %',out;end if;
 out:=public.social_gateway('organization.message',hu,jsonb_build_object('organization_id',(select v from qa where k='o1'),'text','Guidelines QA question'));
 if out?'error' then raise exception 'Fixture organization message %',out;end if;
 insert into qa values('pu',pu),('attu',att),('ru',out->>'resource_id');
 perform public.discovery_gateway('profile',hu,jsonb_build_object('instance',iu,'username','Gu'||substr(hu,1,10),'tags','["music"]'::jsonb));
 perform public.discovery_gateway('profile',hv,jsonb_build_object('instance',iv,'username','Gv'||substr(hv,1,10),'tags','["music"]'::jsonb));
 perform public.discovery_gateway('enter',hu,jsonb_build_object('instance',iu,'transport','direct','allow_direct',true));
 perform public.discovery_gateway('enter',hv,jsonb_build_object('instance',iv,'transport','direct','allow_direct',true));
 out:=public.discovery_gateway('request',hv,jsonb_build_object('instance',iv,'target',(select id from discovery_private.presence where member=uid),'nonce',gen_random_uuid()));
 req:=(out->'outgoing'->>'id')::uuid;if req is null then raise exception 'Fixture discovery request %',out;end if;
 out:=public.discovery_gateway('accept',hu,jsonb_build_object('instance',iu,'request_id',req,'transport','direct'));sid:=(out->'session'->>'id')::uuid;
 perform public.discovery_gateway('ack',hu,jsonb_build_object('instance',iu,'session_id',sid));
 out:=public.discovery_gateway('ack',hv,jsonb_build_object('instance',iv,'session_id',sid));
 if out->>'state' is distinct from 'connected' then raise exception 'Fixture discovery session %',out;end if;
 out:=public.discovery_gateway('send',hu,jsonb_build_object('instance',iu,'session_id',sid,'body','Guidelines QA hello','nonce',(select v from qa where k='nmsg')));
 if out?'error' then raise exception 'Fixture discovery message %',out;end if;
 insert into qa values('sid',sid);
end $$;

-- u's acceptance no longer covers the requirement.
reset role;
delete from social_private.guidelines_acceptances where member=(select v::uuid from qa where k='u');
set local role service_role;
do $$
declare
 hu text:=(select v from qa where k='hu');hv text:=(select v from qa where k='hv');hw text:=(select v from qa where k='hw');
 uid uuid:=(select v::uuid from qa where k='u');vid uuid:=(select v::uuid from qa where k='v');o1 text:=(select v from qa where k='o1');o2 text:=(select v from qa where k='o2');
 iu uuid:=(select v::uuid from qa where k='iu');iv uuid:=(select v::uuid from qa where k='iv');sid uuid:=(select v::uuid from qa where k='sid');
 out jsonb;pv uuid;att uuid;av text;series jsonb;group_input jsonb;meme jsonb;
 starts double precision:=extract(epoch from now()+interval '3 days');copy text:='Review and accept the community guidelines to post.';
begin
 -- organization.message: a new conversation is refused; the existing one is still returned.
 out:=public.social_gateway('organization.message',hu,jsonb_build_object('organization_id',o2,'text','Unaccepted question'));
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted organization message allowed %',out;end if;
 if (select count(*) from social_private.rooms where requester=uid)<>1 or exists(select 1 from social_private.messages where author=uid and body='Unaccepted question') then raise exception 'Refused organization message was written';end if;
 out:=public.social_gateway('organization.message',hu,jsonb_build_object('organization_id',o1));
 if out?'error' or out->>'resource_id' is distinct from (select v from qa where k='ru') then raise exception 'Existing organization conversation not returned %',out;end if;
 out:=public.social_gateway('organization.message',hv,jsonb_build_object('organization_id',o2,'text','Accepted question'));
 if out?'error' then raise exception 'Accepted organization message failed %',out;end if;

 -- activity.create and organization.publish: new activities refused, the nonce retry returned.
 out:=public.social_gateway('activity.create',hu,jsonb_build_object('title','Unaccepted study','place','MSC','kind','Study','starts',starts,'capacity',4));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted activity allowed %',out;end if;
 if (select count(*) from social_private.activities where host=uid)<>1 then raise exception 'Refused activity was written';end if;
 out:=public.social_gateway('activity.create',hu,jsonb_build_object('title','Guidelines QA study','place','Evans Library','kind','Study','starts',starts,'capacity',4,'nonce',(select v from qa where k='nact')));
 if out->>'resource_id' is distinct from (select v from qa where k='au') then raise exception 'Activity retry refused %',out;end if;
 out:=public.social_gateway('activity.create',hv,jsonb_build_object('title','Accepted study','place','MSC','kind','Study','starts',starts,'capacity',4));
 if out?'error' then raise exception 'Accepted activity failed %',out;end if;av:=out->>'resource_id';
 out:=public.social_gateway('organization.publish',hu,jsonb_build_object('organization_id',o2,'title','Unaccepted event','place','Rudder','kind','Organizations','starts',starts,'capacity',20));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted organization publication allowed %',out;end if;
 out:=public.social_gateway('organization.publish',hw,jsonb_build_object('organization_id',o2,'title','Accepted event','place','Rudder','kind','Organizations','starts',starts,'capacity',20));
 if out?'error' then raise exception 'Accepted organization publication failed %',out;end if;

 -- activity.edit: changing what others read is refused; capacity alone is not.
 out:=public.social_gateway('activity.edit',hu,jsonb_build_object('activity_id',(select v from qa where k='au'),'details','Unaccepted details'));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted activity edit allowed %',out;end if;
 if (select details from social_private.activities where id=(select v::uuid from qa where k='au'))='Unaccepted details' then raise exception 'Refused edit was written';end if;
 out:=public.social_gateway('activity.edit',hu,jsonb_build_object('activity_id',(select v from qa where k='au'),'capacity',6));
 if out?'error' then raise exception 'Capacity-only edit gated %',out;end if;
 out:=public.social_gateway('activity.edit',hv,jsonb_build_object('activity_id',av,'details','Accepted details'));
 if out?'error' then raise exception 'Accepted activity edit failed %',out;end if;

 -- Media on an existing post: authorize, reserve and attach are refused.
 out:=public.social_gateway('attachment.authorize',hu,jsonb_build_object('post_id',(select v from qa where k='pu')));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted upload authorization allowed %',out;end if;
 out:=public.social_gateway('attachment.reserve',hu,jsonb_build_object('post_id',(select v from qa where k='pu'),'path',gen_random_uuid()||'.png','kind','image','mime','image/png','size',10));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted reserve allowed %',out;end if;
 out:=public.social_gateway('post.attach',hu,jsonb_build_object('post_id',(select v from qa where k='pu'),'attachment_id',(select v from qa where k='attu')));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted attach allowed %',out;end if;
 out:=public.social_gateway('post.create',hv,'{"text":"Accepted post with media"}');pv:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('attachment.reserve',hv,jsonb_build_object('post_id',pv,'path',gen_random_uuid()||'.png','kind','image','mime','image/png','size',10));
 if out?'error' then raise exception 'Accepted reserve failed %',out;end if;att:=(out->>'attachment_id')::uuid;
 out:=public.social_gateway('attachment.commit',hv,jsonb_build_object('attachment_id',att));if out?'error' then raise exception 'Accepted commit failed %',out;end if;
 out:=public.social_gateway('post.attach',hv,jsonb_build_object('post_id',pv,'attachment_id',att));
 if out?'error' then raise exception 'Accepted attach failed %',out;end if;

 -- group.create (through the gateway and directly).
 group_input:=jsonb_build_object('title','Guidelines QA '||substr(hu,1,6),'description','Synthetic guidelines checks only.','category','Friends','avatar','gold','is_public',true,'alias','Copper','member_avatar','sage','nonce',gen_random_uuid());
 out:=public.communities_gateway('create',hu,group_input);
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted group allowed %',out;end if;
 out:=public.social_gateway('group.create',hu,group_input||jsonb_build_object('nonce',gen_random_uuid()));
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted group through the gateway allowed %',out;end if;
 if exists(select 1 from community_private.communities where creator=uid) then raise exception 'Refused group was written';end if;
 out:=public.communities_gateway('create',hv,group_input||jsonb_build_object('title','Guidelines QA '||substr(hv,1,6),'nonce',gen_random_uuid()));
 if out?'error' then raise exception 'Accepted group failed %',out;end if;

 -- meme.publish.
 meme:=jsonb_build_object('path',gen_random_uuid()::text||'.png','mime','image/png','size',100,'width',24,'height',16,'title','Guidelines QA meme');
 out:=public.social_memes('publish',hu,meme);
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted meme allowed %',out;end if;
 if exists(select 1 from social_private.shared_memes where owner=uid) then raise exception 'Refused meme was written';end if;
 out:=public.social_memes('publish',hv,meme||jsonb_build_object('path',gen_random_uuid()::text||'.png'));
 if out?'error' then raise exception 'Accepted meme failed %',out;end if;

 -- Weekly study series.
 series:=jsonb_build_object('nonce',gen_random_uuid(),'title','Guidelines QA series','place','MSC','starts',starts,'weeks',2,'capacity',6);
 out:=public.activity_plans('series.create',hu,series);
 if out->>'code' is distinct from 'guidelines' then raise exception 'Unaccepted series allowed %',out;end if;
 out:=public.activity_plans('series.create',hv,series||jsonb_build_object('nonce',gen_random_uuid()));
 if out?'error' then raise exception 'Accepted series failed %',out;end if;

 -- Discovery chat: a new message is refused, the retry of one sent earlier still answers, v can send.
 out:=public.discovery_gateway('send',hu,jsonb_build_object('instance',iu,'session_id',sid,'body','Unaccepted hello','nonce',gen_random_uuid()));
 if out->>'code' is distinct from 'guidelines' or out->>'error' is distinct from copy then raise exception 'Unaccepted discovery message allowed %',out;end if;
 if exists(select 1 from random_private.messages where body='Unaccepted hello') then raise exception 'Refused discovery message was written';end if;
 out:=public.discovery_gateway('send',hu,jsonb_build_object('instance',iu,'session_id',sid,'body','Guidelines QA hello','nonce',(select v from qa where k='nmsg')));
 if out?'error' or (select count(*) from random_private.messages where body='Guidelines QA hello')<>1 then raise exception 'Discovery retry refused or duplicated %',out;end if;
 out:=public.discovery_gateway('send',hv,jsonb_build_object('instance',iv,'session_id',sid,'body','Accepted hello','nonce',gen_random_uuid()));
 if out?'error' then raise exception 'Accepted discovery message failed %',out;end if;

 -- Accepting again opens everything for u.
 out:=public.social_gateway('guidelines.accept',hu,jsonb_build_object('version',(select required_version from social_private.guidelines_settings)));
 if out?'error' then raise exception 'Re-accept failed %',out;end if;
 out:=public.social_gateway('organization.message',hu,jsonb_build_object('organization_id',o2,'text','Accepted now'));
 if out?'error' then raise exception 'Organization message after accepting failed %',out;end if;
 raise notice 'PASS other public writes: organization message, activities, organization publication, activity edit, post media, groups, memes, series and discovery chat refused until accepted; retries and existing conversations open';
end $$;
-- The chat's 300 ms send spacing is measured with now(), which a transaction holds still.
reset role;
update random_private.participants set sent_at=now()-interval '1 second' where id=(select participant from random_private.member_links where member=(select v::uuid from qa where k='u'));
set local role service_role;
do $$
declare out jsonb;
begin
 out:=public.discovery_gateway('send',(select v from qa where k='hu'),jsonb_build_object('instance',(select v from qa where k='iu'),'session_id',(select v from qa where k='sid'),'body','Accepted now','nonce',gen_random_uuid()));
 if out?'error' then raise exception 'Discovery message after accepting failed %',out;end if;
end $$;

-- The full snapshot's postCount counts the member's posts that are not deleted; ownPostIDs keeps
-- listing deleted ones.
do $$
declare hv text:=(select v from qa where k='hv');vid uuid:=(select v::uuid from qa where k='v');out jsonb;p uuid;live int;
begin
 out:=public.social_gateway('post.create',hv,'{"text":"Guidelines QA post to delete"}');
 if out?'error' then raise exception 'Count fixture post failed %',out;end if;p:=(out->>'resource_id')::uuid;
 live:=(select count(*) from social_private.posts where author=vid and not deleted);
 if (out->'snapshot'->>'postCount')::int is distinct from live or live<2 then raise exception 'postCount % is not the % live posts',out->'snapshot'->>'postCount',live;end if;
 out:=public.social_gateway('post.delete',hv,jsonb_build_object('post_id',p));
 if out?'error' then raise exception 'Delete failed %',out;end if;
 if (out->'snapshot'->>'postCount')::int is distinct from live-1 then raise exception 'postCount counts a deleted post %',out->'snapshot'->>'postCount';end if;
 if not (out->'snapshot'->'ownPostIDs') ? p::text then raise exception 'ownPostIDs dropped the deleted post';end if;
 raise notice 'PASS postCount';
end $$;

select 'PASS community guidelines: privileges, gated writes, idempotent accept, future versions refused, version bump, retries, export, enforcement switch, deletion and postCount' result;
rollback;
