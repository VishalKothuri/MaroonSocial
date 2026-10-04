// Isolated tests: no network, real credentials, OTP messages, or database mutations.
// Run: deno test --allow-env=SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY tools/test-social-auth-adapter.ts
import { socialIdentity, SocialAuthError, verifiedIdentity } from '../supabase/functions/_shared/social-auth.ts';

Deno.env.set('SUPABASE_URL', 'https://auth-adapter.example.invalid');
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'synthetic-service-key');
const user = '11111111-1111-4111-8111-111111111111';
const otherUser = '22222222-2222-4222-8222-222222222222';
const session = '33333333-3333-4333-8333-333333333333';
const legacy = 'a'.repeat(64);
const memberHash = 'b'.repeat(64);
const confirmedUser = { id: user, email_confirmed_at: '2026-10-01T00:00:00Z', is_anonymous: false };
type FetchCall = { url: string; init?: RequestInit };
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}
function same(actual: unknown, expected: unknown, message: string) {
  assert(JSON.stringify(actual) === JSON.stringify(expected), message);
}
function token(claims: Record<string, unknown>) {
  return 'synthetic-header.' + btoa(JSON.stringify(claims)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '') + '.synthetic-signature';
}
function bearer(claims: Record<string, unknown> = { sub: user, role: 'authenticated', session_id: session }, extra: Record<string, string> = {}) {
  return new Request('https://app.example.invalid', { headers: { Authorization: 'Bearer ' + token(claims), ...extra } });
}
function json(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } }); }
async function rejects(operation: () => Promise<unknown>, code: string, status?: number) {
  try { await operation(); } catch (error) {
    assert(error instanceof SocialAuthError, 'Must return a typed authentication failure');
    same(error.code, code, 'Incorrect authentication failure code');
    if (status !== undefined) same(error.status, status, 'Incorrect authentication failure HTTP status');
    return;
  }
  throw new Error('Expected authentication to fail');
}
async function mocked(responses: Response[], test: (calls: FetchCall[]) => Promise<void>) {
  const original = globalThis.fetch, calls: FetchCall[] = [];
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: input instanceof Request ? input.url : String(input), init });
    const response = responses.shift();
    if (!response) throw new Error('Unexpected network operation');
    return Promise.resolve(response);
  }) as typeof fetch;
  try { await test(calls); assert(responses.length === 0, 'Expected mocked response was not used'); }
  finally { globalThis.fetch = original; }
}

Deno.test('legacy credential uses SHA-256 without contacting Auth', async () => {
  await mocked([], async calls => {
    const result = await socialIdentity(new Request('https://app.example.invalid', { headers: { 'X-Social-Token': legacy } }));
    same(result, { hash: 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb', auth: null }, 'Legacy hash must match the independent SHA-256 test vector');
    same(calls.length, 0, 'Legacy credentials must not be treated as an Auth user');
  });
});
Deno.test('invalid supplied bearer never falls back to valid legacy credential', async () => {
  await mocked([], async () => {
    for (const authorization of ['', 'Basic invalid', 'Bearer short']) {
      await rejects(() => socialIdentity(new Request('https://app.example.invalid', { headers: { Authorization: authorization, 'X-Social-Token': legacy } })), 'unauthorized', 401);
    }
  });
});
Deno.test('unverified bearer claims are never decoded or sent to the bridge', async () => {
  const original = globalThis.atob;
  let decoded = false;
  globalThis.atob = () => { decoded = true; throw new Error('Unverified claims were decoded'); };
  try {
    await mocked([json({ error: 'invalid token' }, 401)], async calls => {
      await rejects(() => socialIdentity(bearer(undefined, { 'X-Social-Token': legacy })), 'unauthorized', 401);
      same(calls.length, 1, 'Rejected Auth user must never reach the database bridge');
      assert(calls[0].url.endsWith('/auth/v1/user'), 'Must verify with Supabase Auth');
      assert(!decoded, 'Token claims must stay unread before successful server verification');
    });
  } finally { globalThis.atob = original; }
});
Deno.test('verified identity resolves only the matching Auth subject and session', async () => {
  await mocked([json(confirmedUser), json({ state: 'linked', token_hash: memberHash })], async calls => {
    const request = bearer({ sub: user, role: 'authenticated', session_id: session, user_metadata: { member_id: otherUser, admin: true } });
    same(await socialIdentity(request), { hash: memberHash, auth: { userID: user, sessionID: session } }, 'Identity must come from verified subject plus the private bridge');
    same(calls.length, 2, 'Must verify Auth before resolving membership');
    const authHeaders = new Headers(calls[0].init?.headers);
    same(authHeaders.get('Authorization'), request.headers.get('Authorization'), 'Must verify the exact supplied token');
    const bridgeHeaders = new Headers(calls[1].init?.headers);
    same(bridgeHeaders.get('Authorization'), 'Bearer synthetic-service-key', 'Only the privileged server bridge uses the service credential');
    same(JSON.parse(String(calls[1].init?.body)), { p_action: 'resolve', p_auth_id: user, p_session_id: session, p_input: {} }, 'User-editable claims must never become authorization input');
  });
});
Deno.test('subject mismatch is rejected before member resolution', async () => {
  await mocked([json(confirmedUser)], async calls => {
    await rejects(() => socialIdentity(bearer({ sub: otherUser, role: 'authenticated', session_id: session })), 'unauthorized');
    same(calls.length, 1, 'Mismatched identity must never reach bridge');
  });
});
Deno.test('missing or malformed session and incorrect role are rejected', async () => {
  for (const claims of [
    { sub: user, role: 'authenticated' },
    { sub: user, role: 'authenticated', session_id: 'invalid-session' },
    { sub: user, role: 'service_role', session_id: session },
  ]) {
    await mocked([json(confirmedUser)], async () => { await rejects(() => verifiedIdentity(bearer(claims)), 'unauthorized'); });
  }
});
Deno.test('unconfirmed email and anonymous Auth user cannot establish social identity', async () => {
  for (const value of [{ ...confirmedUser, email_confirmed_at: null }, { ...confirmedUser, is_anonymous: true }]) {
    await mocked([json(value)], async calls => {
      await rejects(() => socialIdentity(bearer()), 'unauthorized');
      same(calls.length, 1, 'Unconfirmed or anonymous user must never reach bridge');
    });
  }
});
Deno.test('revoked database session cannot fall back to a legacy token', async () => {
  await mocked([json(confirmedUser), json({ error: 'Session is revoked', code: 'unauthorized' })], async calls => {
    await rejects(() => socialIdentity(bearer(undefined, { 'X-Social-Token': legacy })), 'unauthorized', 401);
    same(calls.length, 2, 'Revoked session must fail after the bridge check');
  });
});
Deno.test('deleted account and missing mapping stay distinct from a new account', async () => {
  await mocked([json(confirmedUser), json({ state: 'account_deleted' })], async () => {
    await rejects(() => socialIdentity(bearer()), 'account_deleted', 401);
  });
  await mocked([json(confirmedUser), json({ state: 'unlinked' })], async () => {
    await rejects(() => socialIdentity(bearer()), 'not_linked', 403);
  });
});
Deno.test('malformed private credential never reaches an authorized action', async () => {
  await mocked([json(confirmedUser), json({ state: 'linked', token_hash: 'not-a-credential' })], async () => {
    await rejects(() => socialIdentity(bearer()), 'not_linked', 403);
  });
});
Deno.test('Auth availability failures remain retryable rather than signing in or falling back', async () => {
  await mocked([json({ error: 'upstream failure' }, 503)], async () => {
    await rejects(() => socialIdentity(bearer(undefined, { 'X-Social-Token': legacy })), 'unavailable', 503);
  });
});
Deno.test('unknown bridge errors are sanitized', async () => {
  await mocked([json(confirmedUser), json({ message: 'internal_error: private database diagnostic' }, 500)], async () => {
    try { await socialIdentity(bearer()); throw new Error('Expected bridge failure'); }
    catch (error) {
      assert(error instanceof SocialAuthError && error.code === 'unavailable' && error.status === 503, 'Unknown errors should be unavailable');
      assert(!error.message.includes('private database'), 'Internal diagnostics must not reach the app');
    }
  });
});
