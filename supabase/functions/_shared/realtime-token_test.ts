import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { base64url, hmacKey, mintRealtimeToken, REALTIME_TOKEN_TTL } from './realtime-token.ts';

// A fixed, obviously fake secret: never a real project key.
const secret = 'test-only-realtime-secret-with-at-least-32-characters';
const member = '6f1c2b3a-4d5e-4f60-8a71-92b3c4d5e6f7';
const now = 1_790_000_000;
const decode = (part: string) => JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(part.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(part.length / 4) * 4, '=')), (c) => c.charCodeAt(0))));
const bytes = (part: string) => Uint8Array.from(atob(part.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(part.length / 4) * 4, '=')), (c) => c.charCodeAt(0));

Deno.test('realtime token carries exactly the documented header and claims (15-minute lifetime)', async () => {
  const { token, expiresAt } = await mintRealtimeToken(secret, member, now);
  const [header, claims, signature] = token.split('.');
  assertEquals(decode(header), { alg: 'HS256', typ: 'JWT' });
  assertEquals(decode(claims), { role: 'authenticated', sub: member, aud: 'authenticated', iss: 'maroon-social', iat: now, exp: now + 900 });
  assertEquals(expiresAt, now + REALTIME_TOKEN_TTL);
  assert(/^[A-Za-z0-9_-]+$/.test(signature), 'signature is unpadded base64url');
});

Deno.test('signature verifies with the same secret and fails with another', async () => {
  const { token } = await mintRealtimeToken(secret, member, now);
  const [header, claims, signature] = token.split('.');
  const input = new TextEncoder().encode(header + '.' + claims);
  assert(await crypto.subtle.verify('HMAC', await hmacKey(secret, 'verify'), bytes(signature), input));
  assert(!(await crypto.subtle.verify('HMAC', await hmacKey(secret + 'x', 'verify'), bytes(signature), input)));
  const tampered = new TextEncoder().encode(header + '.' + claims.slice(0, -2) + 'AA');
  assert(!(await crypto.subtle.verify('HMAC', await hmacKey(secret, 'verify'), bytes(signature), tampered)));
});

Deno.test('matches an independently computed HS256 vector (Python hmac/hashlib)', async () => {
  const { token } = await mintRealtimeToken(secret, member, now);
  assertEquals(token, EXPECTED);
});

Deno.test('rejects a missing secret and anything but a member uuid', async () => {
  await assertRejects(() => mintRealtimeToken('', member, now));
  await assertRejects(() => mintRealtimeToken(secret, 'member:' + member, now));
  await assertRejects(() => mintRealtimeToken(secret, '../' + member, now));
  assertEquals(base64url(new Uint8Array([251, 255])), '-_8');
});

// Generated once with: python3 -c "import hmac,hashlib,base64,json; ..." (see TESTING.md, Realtime).
const EXPECTED = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYXV0aGVudGljYXRlZCIsInN1YiI6IjZmMWMyYjNhLTRkNWUtNGY2MC04YTcxLTkyYjNjNGQ1ZTZmNyIsImF1ZCI6ImF1dGhlbnRpY2F0ZWQiLCJpc3MiOiJtYXJvb24tc29jaWFsIiwiaWF0IjoxNzkwMDAwMDAwLCJleHAiOjE3OTAwMDA5MDB9.PGpxZ2xCmKqWigbWR1B_SdtKFXXpWYt_N3AeNSjRzIY';
