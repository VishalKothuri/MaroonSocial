-- Prefer the active handshake when an old ended session shares a transaction time.
do $p$declare d text;begin d:=pg_get_functiondef('public.discovery_gateway(text,text,jsonb)'::regprocedure);d:=replace(d,'and(case when a=me then instance_a else instance_b end)=instance_value order by created_at desc limit 1','and(case when a=me then instance_a else instance_b end)=instance_value order by(ended_at is null)desc,created_at desc,id desc limit 1');execute d;end $p$;
create index discovery_request_expiry on discovery_private.requests(expires_at)where status='pending';
create index discovery_sessions_deadline on discovery_private.sessions(ends_at)where ended_at is null;
create index discovery_sessions_ack on discovery_private.sessions(ack_deadline)where ended_at is null and room is null;
