begin;
do $$begin
 if has_function_privilege('anon','public.web_pool_gateway(text,text,jsonb)','execute')or has_function_privilege('authenticated','public.web_pool_session(text,text,text,uuid,uuid)','execute')or has_table_privilege('anon','web_pool_private.games','select')then raise exception 'Pool private API exposed';end if;
end$$;
set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');sa text:=encode(extensions.gen_random_bytes(32),'hex');sb text:=encode(extensions.gen_random_bytes(32),'hex');sc text:=encode(extensions.gen_random_bytes(32),'hex');a uuid;b uuid;c uuid;na uuid:=gen_random_uuid();nb uuid:=gen_random_uuid();turnnonce uuid:=gen_random_uuid();v jsonb;g uuid;state jsonb:='{"kind":"pool","rules":"maroon-web-pool-3.0.0","turn":0,"shots":0,"winner":null}';
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'wp_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'wp_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,'wp_c_'||substr(hc,1,8),true,hc)returning id into c;
 perform public.web_pool_session(ha,sa,'create');perform public.web_pool_session(hb,sb,'create');perform public.web_pool_session(hc,sc,'create');
 v:=public.web_pool_gateway('cancel',sa,jsonb_build_object('nonce',na));v:=public.web_pool_gateway('join',sa,jsonb_build_object('nonce',na,'state',state));if v->>'queue'is distinct from 'cancelled'then raise exception 'Late join revived cancelled search %',v;end if;
 na:=gen_random_uuid();v:=public.web_pool_gateway('join',sa,jsonb_build_object('nonce',na,'state',state));if v->>'queue'is distinct from 'waiting'then raise exception 'Queue failed %',v;end if;
 v:=public.web_pool_gateway('join',sb,jsonb_build_object('nonce',nb,'state',state));g:=(v->'game'->>'id')::uuid;if g is null or v->'game'->'players'is distinct from '["Player 1","Player 2"]'::jsonb then raise exception 'Pair/privacy failed %',v;end if;
 v:=public.web_pool_gateway('cancel',sa,jsonb_build_object('nonce',na));if v->'game'->>'id'is distinct from g::text then raise exception 'Lost match after cancel race';end if;
 v:=public.web_pool_gateway('get',sc,jsonb_build_object('id',g));if v->>'code'is distinct from 'not_found'then raise exception 'Outsider read match';end if;
 v:=public.web_pool_gateway('prepare',sb,jsonb_build_object('id',g,'version',0,'nonce',turnnonce,'input','{}'::jsonb));if v->>'code'is distinct from 'turn'then raise exception 'Opponent moved';end if;
 v:=public.web_pool_gateway('commit',sa,jsonb_build_object('id',g,'version',0,'nonce',turnnonce,'input','{}'::jsonb,'state',state||'{"shots":1,"turn":1}'::jsonb,'replay','{}'::jsonb));if(v->'game'->>'version')::int<>1 then raise exception 'Commit failed %',v;end if;
 v:=public.web_pool_gateway('commit',sa,jsonb_build_object('id',g,'version',0,'nonce',turnnonce,'input','{}'::jsonb));if v->>'duplicate'is distinct from 'true'or(v->'game'->>'version')::int<>1 then raise exception 'Duplicate turn changed match';end if;
 v:=public.web_pool_gateway('prepare',sa,jsonb_build_object('id',g,'version',0,'nonce',turnnonce,'input','{"power":2}'::jsonb));if v->>'code'is distinct from 'conflict'then raise exception 'Changed retry accepted';end if;
 update social_private.members set banned=true where id=b;v:=public.web_pool_gateway('get',sa,jsonb_build_object('id',g));if v->>'code'is distinct from 'forbidden'then raise exception 'Banned peer still playable';end if;update social_private.members set banned=false where id=b;
 perform public.web_pool_session(ha,sa,'revoke');v:=public.web_pool_gateway('get',sa,jsonb_build_object('id',g));if v->>'code'is distinct from 'unauthorized'then raise exception 'Revoked scope accepted';end if;
 update web_pool_private.browser_sessions set expires_at=now()-interval '1 second'where token_hash=sb;v:=public.web_pool_gateway('active',sb);if v->>'code'is distinct from 'unauthorized'then raise exception 'Expired scope accepted';end if;
 update social_private.members set token_hash=encode(extensions.gen_random_bytes(32),'hex')where id=c;v:=public.web_pool_gateway('active',sc);if v->>'code'is distinct from 'unauthorized'then raise exception 'Rotated identity resurrected scope';end if;
 delete from social_private.members where id=a;if exists(select 1 from web_pool_private.games where id=g)then raise exception 'Deleted account retained game';end if;
end$$;
select 'PASS pool ACLs, private seats, cancel race, participant isolation, turn authorization, CAS/nonce, ban, scope revoke/expiry/rotation and account cascade' as result;
rollback;
