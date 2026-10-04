import { authBridge, authFailure, sha256, SocialAuthError, verifiedIdentity } from '../_shared/social-auth.ts';
const respond = (value: unknown, status = 200) => new Response(JSON.stringify(value), {status, headers: {'Content-Type': 'application/json', 'Cache-Control': 'no-store'}});
Deno.serve(async request => {
  if (request.method !== 'POST') return respond({error:'Use POST.'}, 405);
  try {
    const raw = await request.text();
    if (raw.length > 4096) return respond({error:'Request too large.'}, 413);
    const body = JSON.parse(raw);
    if (!body || typeof body !== 'object' || Array.isArray(body)) return respond({error:'Invalid request.'}, 400);
    const action = body.action;
    if (action === 'capabilities') {
      const config = await authBridge('capabilities', null);
      return respond({enabled:config.enabled === true, stage:config.stage ?? 'email_setup'});
    }
    if (action === 'deletion-status') {
      if (!/^[a-f0-9]{64}$/.test(body.receipt ?? '')) throw new SocialAuthError('Invalid deletion receipt.', 'invalid', 400);
      const result = await authBridge('deletion-status', null, {receipt_hash:await sha256(body.receipt),network_hash:await sha256(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!+':delete-status:'+(request.headers.get('x-forwarded-for')?.split(',')[0]??'unknown'))});
      return respond({deleted:result.deleted === true});
    }
    if (!['status', 'link', 'register', 'logout'].includes(action)) return respond({error:'Unknown login action.'}, 400);
    const identity = await verifiedIdentity(request);
    const input:Record<string, unknown> = {};
    if (action === 'link') {
      const legacy = request.headers.get('X-Social-Token') ?? '';
      if (!/^[a-f0-9]{64}$/.test(legacy)) throw new SocialAuthError('Your existing device credential is required to link this account.');
      input.legacy_hash = await sha256(legacy);
    }
    if (action === 'register') {
      input.username = body.username; input.adult = body.adult;
      input.network = await sha256(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! + ':auth-register:' + (request.headers.get('x-forwarded-for')?.split(',')[0] ?? 'unknown'));
    }
    const result = await authBridge(action, identity, input);
    if (action === 'logout') {
      // Bridge revocation already takes effect immediately. Also revoke the
      // provider refresh session; the SDK repeats this harmlessly on local logout.
      try { await fetch(Deno.env.get('SUPABASE_URL')! + '/auth/v1/logout?scope=local', {
        method:'POST',headers:{apikey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,Authorization:request.headers.get('Authorization')!},signal:AbortSignal.timeout(5000),
      }); } catch { /* Private session revocation remains authoritative. */ }
    }
    // No member UUID, email, internal credential hash or Auth UUID in app responses.
    return respond({state:result.state, created:result.created === true});
  } catch (error) {
    const failure = authFailure(error);
    if (failure) return respond(failure, (error as SocialAuthError).status);
    return respond({error:'Login could not finish. Please retry.',code:'unavailable'},503);
  }
});
