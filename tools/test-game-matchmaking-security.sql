begin;
do $$ begin
 if has_function_privilege('anon','public.games_matchmaking(text,text,jsonb)','execute') or has_function_privilege('authenticated','public.games_matchmaking(text,text,jsonb)','execute') then raise exception 'Public role can call private matchmaking RPC';end if;
 if has_table_privilege('anon','games_private.match_queue','select') or has_table_privilege('authenticated','games_private.cancelled_searches','select') then raise exception 'Public role can enumerate queue';end if;
end $$;
set local role service_role;
do $$
declare ha text:=encode(extensions.gen_random_bytes(32),'hex'); hb text:=encode(extensions.gen_random_bytes(32),'hex'); a uuid;b uuid;na uuid:=gen_random_uuid();nb uuid:=gen_random_uuid();out jsonb;payload jsonb;g uuid;
begin
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,'qm_a_'||substr(ha,1,8),true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'qm_b_'||substr(hb,1,8),true,hb)returning id into b;
 payload:=jsonb_build_object('kind','chess','nonce',na,'rules','maroon-games-2.1.0','state',jsonb_build_object('rules','maroon-games-2.1.0','turn',0,'shots',0));
 out:=public.games_matchmaking('match.join',ha,payload);if out->'queue'->>'status' is distinct from 'waiting' then raise exception 'Could not queue: %',out;end if;
 update games_private.match_queue set heartbeat_at=now()-interval '46 seconds' where member=a;
 out:=public.games_matchmaking('match.join',hb,payload||jsonb_build_object('nonce',nb));if out->'queue'->>'status' is distinct from 'waiting' then raise exception 'Stale queue matched: %',out;end if;
 if (select status from games_private.match_queue where member=a) is distinct from 'cancelled' then raise exception 'Abandoned queue was not cleaned up';end if;
 out:=public.games_matchmaking('match.status',ha,payload);if out->'queue'->>'status' is distinct from 'expired' then raise exception 'Stale status revived';end if;
 na:=gen_random_uuid();payload:=payload||jsonb_build_object('nonce',na);
 out:=public.games_matchmaking('match.cancel',ha,payload);out:=public.games_matchmaking('match.join',ha,payload);
 if out->'queue'->>'status' is distinct from 'cancelled' then raise exception 'Late join revived cancelled queue';end if;
 na:=gen_random_uuid();payload:=payload||jsonb_build_object('nonce',na);
 update social_private.members set banned=true where id=b;
 out:=public.games_matchmaking('match.join',ha,payload);if out->'queue'->>'status' is distinct from 'waiting' then raise exception 'Banned peer matched';end if;
 update social_private.members set banned=false where id=b;
 out:=public.games_matchmaking('match.status',ha,payload);g:=(out->'game'->>'id')::uuid;
 if g is null or out->'game'->'players' is distinct from '["Player 1","Player 2"]'::jsonb then raise exception 'Peer not matched anonymously %',out;end if;
 update social_private.members set banned=true where id=b;
 out:=public.games_matchmaking('match.join',ha,payload||jsonb_build_object('nonce',gen_random_uuid()));
 if out?'game' or out->'queue'->>'status' is distinct from 'waiting' then raise exception 'New nonce recovered banned peer game: %',out;end if;
 if (select status from games_private.match_queue where member=b) is distinct from 'matched' then raise exception 'Waiting cleanup changed matched row';end if;
 out:=public.games_matchmaking('match.status',hb,payload||jsonb_build_object('nonce',nb));
 if out->>'code' is distinct from 'forbidden' then raise exception 'Banned caller authorized';end if;
 out:=public.games_matchmaking('match.status',encode(extensions.gen_random_bytes(32),'hex'),payload);
 if out->>'code' is distinct from 'unauthorized' then raise exception 'Unknown credential authorized';end if;
 delete from social_private.members where id=a;
 if exists(select 1 from games_private.match_queue where session=g) then raise exception 'Deleted match retained queue';end if;
end $$;
select 'PASS RPC/table ACLs; stale queue cleanup; matched preservation; cancelled late join; banned recovery exclusion; invalid credential; anonymous seats; account deletion cascade' as result;
rollback;
