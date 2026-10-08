-- Real private membership/room policies, synthetic identities, all rolled back.
begin;
set local role service_role;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');hd text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;d uuid;n uuid:=gen_random_uuid();private_nonce uuid:=gen_random_uuid();out jsonb;pub text;priv text;legacy text;code text;rotated text;msg text;tmp text;i integer;
begin
 if has_function_privilege('anon','public.communities_gateway(text,text,jsonb)','EXECUTE')or has_function_privilege('authenticated','public.communities_gateway(text,text,jsonb)','EXECUTE')or has_schema_privilege('authenticated','community_private','USAGE')then raise exception 'Private API exposed';end if;
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'comm_a_'||substr(ha,1,8),true,ha)returning id into a;insert into social_private.guidelines_acceptances(member,version)select a,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'comm_b_'||substr(hb,1,8),true,hb)returning id into b;insert into social_private.guidelines_acceptances(member,version)select b,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'comm_c_'||substr(hc,1,8),true,hc)returning id into c;insert into social_private.guidelines_acceptances(member,version)select c,required_version from social_private.guidelines_settings;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hd,'comm_d_'||substr(hd,1,8),true,hd)returning id into d;insert into social_private.guidelines_acceptances(member,version)select d,required_version from social_private.guidelines_settings;
 out:=public.social_gateway('group.create',ha,jsonb_build_object('title','Legacy private chat','description','Synthetic legacy group chat.','category','Other','is_public',false,'nonce',gen_random_uuid(),'alias','Captain','member_avatar','gold'));legacy:=out->>'resource_id';
 out:=public.communities_gateway('create',ha,jsonb_build_object('title','Public QA '||substr(ha,1,8),'description','A synthetic public campus chat.','category','Friends','is_public',true,'nonce',n,'avatar','maroon','alias','Captain','member_avatar','gold'));pub:=out->>'room_id';if pub is null then raise exception 'Create failed %',out;end if;
 out:=public.communities_gateway('create',ha,jsonb_build_object('title','Public QA '||substr(ha,1,8),'description','A synthetic public campus chat.','category','Friends','is_public',true,'nonce',n,'avatar','maroon','alias','Captain','member_avatar','gold'));if out->>'room_id' is distinct from pub then raise exception 'Creation retry duplicated room';end if;
 out:=public.communities_gateway('create',ha,jsonb_build_object('title','Private QA '||substr(ha,1,8),'description','A synthetic invitation-only chat.','category','Other','is_public',false,'nonce',private_nonce,'avatar','maroon','alias','Captain','member_avatar','gold'));priv:=out->>'room_id';code:=out->'community'->>'invite_code';if priv is null or length(code)<>10 then raise exception 'Private create missing code %',out;end if;
 out:=public.account_controls('export',ha,'{"section":"communities"}');if jsonb_array_length(out->'data')<>3 or out::text like '%invite_code%'or out::text like '%'||a::text||'%'then raise exception 'Community export metadata invalid %',out;end if;
 out:=public.communities_gateway('list',hb,jsonb_build_object('search',substr(ha,1,8)));
 if jsonb_array_length(out->'communities')<>1 or out->'communities'->0->>'id' is distinct from pub or (out->'communities'->0->>'invite_code')is not null or out::text like '%'||a::text||'%'or out::text like '%comm_a_%'then raise exception 'Directory privacy failed %',out;end if;
 out:=public.communities_gateway('detail',hb,jsonb_build_object('room_id',pub));if out->'members'<>'[]'::jsonb or out?'bans'then raise exception 'Unjoined roster exposed';end if;
 out:=public.communities_gateway('detail',hb,jsonb_build_object('room_id',legacy));if out->>'code' is distinct from 'unavailable' then raise exception 'Legacy private group enumerated';end if;
 out:=public.communities_gateway('detail',hb,jsonb_build_object('room_id',priv));if out->>'code' is distinct from 'unavailable'then raise exception 'Private detail exposed';end if;
 out:=public.communities_gateway('join',hb,jsonb_build_object('room_id',priv,'alias','Comet','member_avatar','sky'));if out->>'code' is distinct from 'unavailable'then raise exception 'Private direct-ID join accepted';end if;
 out:=public.social_gateway('room.send',hb,jsonb_build_object('room_id',pub,'text','outsider'));if out->>'code' is distinct from 'forbidden'then raise exception 'Outsider sent chat';end if;
 out:=public.social_gateway('attachment.authorize',hb,jsonb_build_object('room_id',pub,'kind','image','mime','image/jpeg','size',100));if out->>'code' is distinct from 'forbidden'then raise exception 'Outsider prepared media %',out;end if;
 out:=public.communities_gateway('join',hb,jsonb_build_object('room_id',pub));if out->>'code' is distinct from 'invalid'then raise exception 'Named consent missing';end if;
 out:=public.communities_gateway('join',hb,jsonb_build_object('room_id',pub,'alias','Comet','member_avatar','sky'));if out->'community'->>'joined' is distinct from 'true'then raise exception 'Join failed %',out;end if;
 out:=public.communities_gateway('join',hb,jsonb_build_object('room_id',pub,'alias','Comet','member_avatar','sky'));if out->'community'->>'member_count' is distinct from '2'then raise exception 'Join retry duplicated membership';end if;
 out:=public.social_gateway('room.send',hb,jsonb_build_object('room_id',pub,'text','Shared campus message'));msg:=out->>'resource_id';if msg is null then raise exception 'Joined member cannot chat %',out;end if;
 if not social_private.can_read_room(a,pub)or not social_private.can_message(b,pub)then raise exception 'Canonical chat authorization missing';end if;
 out:=public.communities_gateway('ban',hb,jsonb_build_object('room_id',pub,'member_key',(select member_key from community_private.identities where room=pub and member=a)));if out->>'code' is distinct from 'forbidden'then raise exception 'Member moderated owner';end if;
 out:=public.communities_gateway('ban',ha,jsonb_build_object('room_id',pub,'member_key',(select member_key from community_private.identities where room=pub and member=b)));if out?'error'then raise exception 'Owner ban failed %',out;end if;
 if social_private.can_read_room(b,pub)or social_private.can_message(b,pub)then raise exception 'Ban retained shared chat access';end if;
 out:=public.social_gateway('group.invite',ha,jsonb_build_object('room_id',pub,'username','comm_b_'||substr(hb,1,8)));if out->>'code' is distinct from 'unavailable'then raise exception 'Legacy invitation bypassed community ban %',out;end if;
 out:=public.communities_gateway('join',hb,jsonb_build_object('room_id',pub,'alias','Comet','member_avatar','sky'));if out->>'code' is distinct from 'forbidden'then raise exception 'Banned member rejoined';end if;
 out:=public.communities_gateway('unban',ha,jsonb_build_object('room_id',pub,'member_key',(select member_key from community_private.identities where room=pub and member=b)));
 out:=public.communities_gateway('join',hb,jsonb_build_object('room_id',pub,'alias','Comet','member_avatar','sky'));if out?'error'then raise exception 'Unban/rejoin failed %',out;end if;
 insert into social_private.blocks(blocker,blocked)values(b,a);
 if social_private.can_read_room(b,pub)or social_private.can_message(b,pub)then raise exception 'Owner block retained Inbox access';end if;
 delete from social_private.blocks where blocker=b and blocked=a;
 out:=public.communities_gateway('join_code',hb,jsonb_build_object('invite_code',lower(code),'alias','Comet','member_avatar','sky'));if out->>'room_id' is distinct from priv then raise exception 'Invite-code join failed %',out;end if;
 out:=public.communities_gateway('rotate_code',ha,jsonb_build_object('room_id',priv));rotated:=out->'community'->>'invite_code';if rotated=code then raise exception 'Code did not rotate';end if;
 out:=public.communities_gateway('join_code',hc,jsonb_build_object('invite_code',code,'alias','Comet','member_avatar','sky'));if out->>'code' is distinct from 'unavailable'then raise exception 'Old invite code remained active';end if;
 out:=public.communities_gateway('transfer',ha,jsonb_build_object('room_id',priv,'member_key',(select member_key from community_private.identities where room=priv and member=b)));if out->'community'->>'owner' is distinct from 'false'then raise exception 'Owner transfer failed %',out;end if;
 out:=public.communities_gateway('ban',hb,jsonb_build_object('room_id',priv,'member_key',(select member_key from community_private.identities where room=priv and member=a)));
 out:=public.account_controls('export',ha,'{"section":"communities"}');if exists(select 1 from jsonb_array_elements(out->'data')e where e->>'room_id'=priv)then raise exception 'Export leaked removed private membership';end if;
 out:=public.communities_gateway('create',ha,jsonb_build_object('title','Private QA '||substr(ha,1,8),'description','A synthetic invitation-only chat.','category','Other','is_public',false,'nonce',private_nonce,'avatar','maroon','alias','Captain','member_avatar','gold'));if out->>'code' is distinct from 'forbidden'then raise exception 'Revoked creator nonce leaked private metadata %',out;end if;
 out:=public.communities_gateway('report',hc,jsonb_build_object('room_id',pub,'reason','Synthetic moderation report'));if out->>'reported' is distinct from 'true'then raise exception 'Directory report failed %',out;end if;
 out:=public.communities_gateway('report',hc,jsonb_build_object('room_id',pub,'reason','Retry'));if(select count(*)from social_private.reports where reporter=c and target_id=pub)<>1 then raise exception 'Report retry duplicated';end if;
 for i in 1..13 loop out:=public.communities_gateway('join_code',hc,'{"invite_code":"0000000000","alias":"Orbit","member_avatar":"sage"}');end loop;
 if out->>'code' is distinct from 'rate_limit'then raise exception 'Wrong-code attempts rolled back %',out;end if;
 -- Trigger-level capacity prevents legacy invitation acceptance, too.
 update community_private.communities set capacity=3 where room=priv;
 out:=public.communities_gateway('unban',hb,jsonb_build_object('room_id',priv,'member_key',(select member_key from community_private.identities where room=priv and member=a)));
 out:=public.communities_gateway('join_code',ha,jsonb_build_object('invite_code',rotated,'alias','Captain','member_avatar','sky'));if out?'error'then raise exception 'Private rejoin failed %',out;end if;
 out:=public.social_gateway('group.invite',hb,jsonb_build_object('room_id',priv,'username','comm_d_'||substr(hd,1,8)));if out?'error'then raise exception 'Expected invitation failed %',out;end if;update community_private.communities set capacity=2 where room=priv;
 out:=public.social_gateway('group.accept',hd,jsonb_build_object('room_id',priv,'alias','Delta','member_avatar','rose'));if out->>'code' is distinct from 'full'then raise exception 'Legacy acceptance bypassed community capacity %',out;end if;
 update community_private.communities set capacity=200 where room=priv;
 -- Thirty memberships are enforced even on generic group.accept.
 for i in 1..30 loop
  insert into social_private.rooms(kind,title,meta)values('group','Cap fixture '||i,'{"campusCommunity":true}')returning id into tmp;
  insert into community_private.communities(room,creator,nonce,description,category)values(tmp,d,gen_random_uuid(),'Synthetic cap fixture','Other');
  perform community_private.set_identity(tmp,d,'Delta','rose');insert into social_private.room_members(room,member,role)values(tmp,d,'owner');
 end loop;
 out:=public.social_gateway('group.accept',hd,jsonb_build_object('room_id',priv,'alias','Delta','member_avatar','rose'));if out->>'code' is distinct from 'full'then raise exception 'Legacy acceptance bypassed 30 community cap %',out;end if;
 out:=public.communities_gateway('join',hc,jsonb_build_object('room_id',pub,'alias','Orbit','member_avatar','sky'));
 out:=public.communities_gateway('leave',ha,jsonb_build_object('room_id',pub));if out->>'code' is distinct from 'invalid'then raise exception 'Owner abandoned active community';end if;
 out:=public.communities_gateway('close',ha,jsonb_build_object('room_id',pub));if out->'community'->>'closed' is distinct from 'true'then raise exception 'Close failed %',out;end if;
 out:=public.social_gateway('room.send',hc,jsonb_build_object('room_id',pub,'text','closed'));if out->>'code' is distinct from 'forbidden'then raise exception 'Closed community accepted message';end if;
 out:=public.social_gateway('group.invite',ha,jsonb_build_object('room_id',pub,'username','comm_b_'||substr(hb,1,8)));if out->>'code' is distinct from 'unavailable'then raise exception 'Closed community accepted invitation';end if;
 out:=public.communities_gateway('leave',ha,jsonb_build_object('room_id',pub));if out->>'left' is distinct from 'true'then raise exception 'Owner cannot leave closed community';end if;
 update social_private.members set banned=true where id=b;if exists(select 1 from social_private.rooms where id=priv and status='active')then raise exception 'Owner suspension left community active';end if;
 update social_private.members set banned=false where id=b;
 out:=public.social_gateway('account.delete',hb);if out?'error'then raise exception 'Community owner deletion failed %',out;end if;
end $$;
select 'PASS community discovery/roster privacy; private ID denial and invite codes; idempotency/consent; shared chat/media membership; owner controls; legacy ban/cap bypass denial; owner-block revocation; revoked creator nonce denial; report retry; code rate limit; transfer/close/owner suspension/deletion' result;
rollback;
