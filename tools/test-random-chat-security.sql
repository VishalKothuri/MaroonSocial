-- Run as the database operator. All synthetic records and mutations roll back.
begin;
do $$
declare
  hash_a text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  hash_b text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  hash_unknown text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  network_hash text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  a_id uuid;
  b_id uuid;
  room_id uuid;
  old_instance uuid := gen_random_uuid();
  new_instance uuid := gen_random_uuid();
  result jsonb;
  total integer;
begin
  if has_function_privilege('anon','public.random_chat_gateway(text,text,jsonb)','EXECUTE')
    or has_function_privilege('authenticated','public.random_chat_gateway(text,text,jsonb)','EXECUTE')
    or has_schema_privilege('anon','random_private','USAGE')
    or has_schema_privilege('authenticated','random_private','USAGE') then
    raise exception 'Guest tables or gateway exposed to API roles';
  end if;
  select count(*) into total from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='random_private' and c.relkind='r' and c.relrowsecurity;
  if total<>7 then raise exception 'RLS missing on a chat table'; end if;

  result := public.random_chat_gateway('poll',hash_unknown,'{}');
  if result->>'code'<>'unauthorized' then raise exception 'Unknown token accepted'; end if;
  if exists(select 1 from pg_locks where pid=pg_backend_pid() and locktype='advisory' and objid=77330001) then
    raise exception 'Unknown token acquired matchmaking lock';
  end if;
  insert into random_private.participants(token_hash,network_hash,banned)
    values(hash_a,network_hash,true) returning id into a_id;
  result := public.random_chat_gateway('poll',hash_a,'{}');
  if result->>'code'<>'forbidden' then raise exception 'Banned token not distinguished'; end if;
  update random_private.participants set banned=false,seen_at=now()-interval '31 days' where id=a_id;
  result := public.random_chat_gateway('poll',hash_a,'{}');
  if result->>'code'<>'unauthorized' then raise exception 'Expired token accepted'; end if;
  update random_private.participants set seen_at=now(),request_count=600 where id=a_id;
  result := public.random_chat_gateway('poll',hash_a,'{}');
  if result->>'code'<>'rate_limit' then raise exception 'Minute quota not enforced'; end if;
  update random_private.participants set request_count=0,burst_count=40 where id=a_id;
  result := public.random_chat_gateway('poll',hash_a,'{}');
  if result->>'code'<>'rate_limit' then raise exception 'Burst quota not enforced'; end if;
  if exists(select 1 from pg_locks where pid=pg_backend_pid() and locktype='advisory' and objid=77330001) then
    raise exception 'Rejected requests acquired matchmaking lock';
  end if;

  update random_private.participants set request_count=600,burst_count=40,
    request_window=now()-interval '2 minutes',burst_window=now()-interval '2 seconds' where id=a_id;
  result := public.random_chat_gateway('poll',hash_a,'{}');
  if result->>'state'<>'idle' then raise exception 'Quota did not reset'; end if;
  select request_count into total from random_private.participants where id=a_id;
  if total<>1 then raise exception 'Quota reset counter wrong'; end if;
  insert into random_private.participants(token_hash,network_hash) values(hash_b,network_hash) returning id into b_id;
  insert into random_private.rooms(a,b,mode) values(a_id,b_id,'text') returning id into room_id;
  update random_private.participants set active_instance=old_instance where id=a_id;
  result := public.random_chat_gateway('join',hash_a,jsonb_build_object('mode','text','instance',new_instance));
  if result->>'state'<>'connected' then raise exception 'Existing-room adoption failed'; end if;
  if (select active_instance from random_private.participants where id=a_id)<>new_instance then
    raise exception 'Join did not claim view instance';
  end if;
  result := public.random_chat_gateway('leave',hash_a,jsonb_build_object('room',room_id,'instance',old_instance));
  if result->>'code'<>'stale_instance' then raise exception 'Stale view ended adopted room'; end if;
  result := public.random_chat_gateway('send',hash_a,jsonb_build_object('room',gen_random_uuid(),'instance',new_instance,'body','wrong room','nonce',gen_random_uuid()));
  if result->>'code'<>'ended' then raise exception 'Cross-room write accepted'; end if;
  result := public.random_chat_gateway('send',hash_a,jsonb_build_object('room',room_id,'instance',new_instance,'body','Synthetic security test','nonce',gen_random_uuid()));
  if result->>'state'<>'connected' or jsonb_array_length(result->'messages')<>1 then
    raise exception 'Authorized send failed';
  end if;
  result := public.random_chat_gateway('poll',hash_b,'{}');
  if (result->'messages'->0->>'body')<>'Synthetic security test' or (result->'messages'->0->>'mine')<>'false' then
    raise exception 'Peer message read failed';
  end if;
  -- Actual WebRTC client ICE kind must survive the gateway unchanged.
  update random_private.rooms set mode='video' where id=room_id;
  result := public.random_chat_gateway('signal',hash_a,jsonb_build_object('room',room_id,'instance',new_instance,
    'nonce',gen_random_uuid(),'kind','ice','payload',jsonb_build_object('candidate','candidate:1 1 UDP 1 192.0.2.1 12345 typ relay','sdpMid','0','sdpMLineIndex',0)));
  if result->>'state'<>'connected' then raise exception 'ICE candidate was rejected'; end if;
  result := public.random_chat_gateway('poll',hash_b,jsonb_build_object('after_signal',0));
  if jsonb_array_length(result->'signals')<>1 or result->'signals'->0->>'kind'<>'ice'
    or result->'signals'->0->'payload'->>'candidate'<>'candidate:1 1 UDP 1 192.0.2.1 12345 typ relay' then
    raise exception 'Peer ICE candidate delivery failed';
  end if;
  update random_private.rooms set mode='text' where id=room_id;
  result := public.random_chat_gateway('report',hash_a,jsonb_build_object('room',room_id,'instance',new_instance,'reason',''));
  if result->>'code'<>'invalid' or exists(select 1 from random_private.blocks where blocker=a_id and blocked=b_id) then
    raise exception 'Invalid report had a moderation side effect';
  end if;
  result := public.random_chat_gateway('report',hash_a,jsonb_build_object('room',room_id,'instance',new_instance,'reason','Synthetic test report'));
  if result->>'state'<>'ended' or result->>'report_id' is null then raise exception 'Report failed'; end if;
  if not exists(select 1 from random_private.blocks where blocker=a_id and blocked=b_id) then raise exception 'Report did not block'; end if;
  select jsonb_array_length(evidence) into total from random_private.reports where room=room_id and reporter=a_id;
  if total<>1 then raise exception 'Report evidence missing'; end if;
  result := public.random_chat_gateway('send',hash_b,jsonb_build_object('room',room_id,'body','after end','nonce',gen_random_uuid()));
  if result->>'code'<>'ended' then raise exception 'Blocked conversation still writable'; end if;

  -- Verify synchronous 45-second expiry without running the bulk cleanup function.
  update random_private.rooms set ended_at=null,end_reason=null where id=room_id;
  update random_private.participants set seen_at=now()-interval '46 seconds' where id=b_id;
  result := public.random_chat_gateway('poll',hash_a,'{}');
  if result->>'state'<>'ended' or result->>'end_reason'<>'disconnected' then
    raise exception 'Stale peer was not expired on poll';
  end if;
  if not exists(select 1 from cron.job where jobname='random-chat-cleanup' and active) then
    raise exception 'Retention cleanup is not scheduled';
  end if;
  if position('perform random_private.cleanup()' in pg_get_functiondef('public.random_chat_gateway(text,text,jsonb)'::regprocedure))>0 then
    raise exception 'Bulk cleanup remains in request path';
  end if;
end $$;
select 'PASS: authorization, pre-lock rejection, quotas, existing-room adoption, owner isolation, ICE candidate delivery, report evidence, block enforcement, stale expiry, cron retention' as result;
rollback;
