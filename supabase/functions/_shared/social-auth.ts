// Identity stays private. Only server-validated Auth sessions may resolve a member.
export class SocialAuthError extends Error {
  constructor(message: string, public code = 'unauthorized', public status = 401) { super(message); }
}
export const sha256 = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map(x => x.toString(16).padStart(2, '0')).join('');
const base = () => Deno.env.get('SUPABASE_URL')!;
const secret = () => Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export type AuthIdentity = { userID: string; sessionID: string };
export async function authBridge(action: string, identity: AuthIdentity | null, input: Record<string, unknown> = {}) {
  const response = await fetch(base() + '/rest/v1/rpc/social_auth_bridge', {
    method: 'POST', headers: { apikey: secret(), Authorization: 'Bearer ' + secret(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_action: action, p_auth_id: identity?.userID ?? null, p_session_id: identity?.sessionID ?? null, p_input: input }), signal: AbortSignal.timeout(12000),
  });
  let value; try { value = await response.json(); } catch { throw new SocialAuthError('Login is temporarily unavailable.', 'unavailable', 503); }
  if (!response.ok || value.error) {
    const raw = String(value.error ?? value.message ?? '');
    const separator = raw.indexOf(':');
    const code = value.code ?? (separator > 0 ? raw.slice(0, separator) : 'unavailable');
    const known = ['unauthorized', 'forbidden', 'not_linked', 'account_deleted', 'conflict', 'invalid', 'rate_limit', 'not_configured'].includes(code);
    throw new SocialAuthError(known ? (value.error ?? raw.slice(separator + 1)) : 'Login is temporarily unavailable.', known ? code : 'unavailable', code === 'unauthorized' ? 401 : code === 'forbidden' ? 403 : code === 'rate_limit' ? 429 : known ? 400 : 503);
  }
  return value;
}
export async function verifiedIdentity(request: Request): Promise<AuthIdentity> {
  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [^\s]{20,8192}$/.test(authorization)) throw new SocialAuthError('Sign in with your email to continue.');
  // Supabase Auth verifies signature, audience, expiry and user state. Never trust
  // a locally decoded JWT or user_metadata as authentication/authorization.
  const response = await fetch(base() + '/auth/v1/user', {
    headers: { apikey: secret(), Authorization: authorization }, signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) {
    if ([400, 401, 403, 404].includes(response.status)) throw new SocialAuthError('Your login expired. Sign in again.');
    throw new SocialAuthError('Login is temporarily unavailable.', 'unavailable', 503);
  }
  const user = await response.json();
  if (!uuid.test(user.id ?? '') || !user.email_confirmed_at || user.is_anonymous === true) throw new SocialAuthError('Confirm your personal email to continue.');
  // Only inspect claims AFTER Auth has verified this exact token. The database
  // additionally checks auth.sessions for immediate logout/deletion revocation.
  let claims;
  try { const segment = authorization.slice(7).split('.')[1]; const normal = segment.replace(/-/g, '+').replace(/_/g, '/'); claims = JSON.parse(atob(normal.padEnd(Math.ceil(normal.length / 4) * 4, '='))); }
  catch { throw new SocialAuthError('The login session could not be read.'); }
  if (claims.sub !== user.id || claims.role !== 'authenticated' || !uuid.test(claims.session_id ?? '')) throw new SocialAuthError('The login session is invalid.');
  return { userID: user.id, sessionID: claims.session_id };
}
export async function socialIdentity(request: Request): Promise<{ hash: string; auth: AuthIdentity | null }> {
  // A supplied invalid bearer must never fall back to another device credential.
  if (request.headers.has('Authorization')) {
    const identity = await verifiedIdentity(request);
    const result = await authBridge('resolve', identity);
    if (result.state === 'account_deleted') throw new SocialAuthError('This account was deleted.', 'account_deleted', 401);
    if (result.state !== 'linked' || !/^[a-f0-9]{64}$/.test(result.token_hash ?? '')) throw new SocialAuthError('Finish setting up your email account.', 'not_linked', 403);
    return { hash: result.token_hash, auth: identity };
  }
  const token = request.headers.get('X-Social-Token') ?? '';
  if (!/^[a-f0-9]{64}$/.test(token)) throw new SocialAuthError('Sign in to continue.');
  return { hash: await sha256(token), auth: null };
}
export async function socialHash(request: Request) { return (await socialIdentity(request)).hash; }
export const authFailure = (error: unknown) => error instanceof SocialAuthError ? { error: error.message, code: error.code } : null;
