// Realtime JWTs for private broadcast channels (caching phase 3).
// The token says only "this member may join the topics RLS allows": role `authenticated`
// (which holds no table grants in this project), sub = member uuid, 15-minute lifetime.
// Realtime checks the topic policy when a channel joins and again whenever the app sends a
// refreshed token, and disconnects a channel whose token expires; a short lifetime therefore
// bounds how long a removed, suspended or lapsed member keeps receiving pokes. The app refreshes
// five minutes before expiry (every ten minutes while it is active).
// Signed HS256 with REALTIME_JWT_SECRET (the project's JWT secret, or an imported signing key).
// Never log the token or the secret.
export const REALTIME_TOKEN_TTL = 900;
export const REALTIME_TOKEN_ISSUER = 'maroon-social';
const memberID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const encoder = new TextEncoder();
export function base64url(bytes: Uint8Array) {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
const segment = (value: unknown) => base64url(encoder.encode(JSON.stringify(value)));
export type RealtimeClaims = { role: 'authenticated'; sub: string; aud: 'authenticated'; iss: string; iat: number; exp: number };
export async function hmacKey(secret: string, usage: KeyUsage) {
  return await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, [usage]);
}
/** Mints the token. `now` is seconds since 1970 (injectable for tests). */
export async function mintRealtimeToken(secret: string, member: string, now = Math.floor(Date.now() / 1000), ttl = REALTIME_TOKEN_TTL) {
  if (!secret) throw new Error('realtime_secret_missing');
  if (!memberID.test(member)) throw new Error('realtime_member_invalid');
  const claims: RealtimeClaims = { role: 'authenticated', sub: member.toLowerCase(), aud: 'authenticated', iss: REALTIME_TOKEN_ISSUER, iat: now, exp: now + ttl };
  const input = segment({ alg: 'HS256', typ: 'JWT' }) + '.' + segment(claims);
  const signature = new Uint8Array(await crypto.subtle.sign('HMAC', await hmacKey(secret, 'sign'), encoder.encode(input)));
  return { token: input + '.' + base64url(signature), expiresAt: claims.exp, claims };
}
