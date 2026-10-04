import { authBridge } from './social-auth.ts';

/// Only previously deleted community accounts can enter this private outbox.
/// Provider outages cannot restore membership or bypass the deletion tombstone.
export async function cleanupDeletedAuthUsers(limit = 4) {
  const base = Deno.env.get('SUPABASE_URL')!;
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  let completed = 0;
  const pending = await authBridge('cleanup.take', null, {limit});
  for (const job of pending.jobs ?? []) {
    let success = false;
    try {
      const response = await fetch(base + '/auth/v1/admin/users/' + encodeURIComponent(job.auth_id), {
        method:'DELETE', headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},
        body:JSON.stringify({should_soft_delete:false}), signal:AbortSignal.timeout(8000),
      });
      success = response.ok || response.status === 404;
    } catch { /* Durable lease is retried by the next cleanup invocation. */ }
    await authBridge('cleanup.complete', null, {auth_id:job.auth_id,lease_id:job.lease_id,success});
    if (success) completed += 1;
  }
  return {completed};
}
