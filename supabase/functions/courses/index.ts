import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
const base = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
Deno.serve(async request => {
 if (request.method !== 'POST') return respond({ error: 'Use POST.' }, 405);
 try {
  const raw = await request.text();
  if (raw.length > 1024) return respond({ error: 'Request too large.' }, 413);
  const body = JSON.parse(raw);
  if (!['terms', 'activity'].includes(body?.action)) return respond({ error: 'Choose a course action.' }, 400);
  if (body.action === 'activity' && (typeof body.term !== 'string' || !/^(Spring|Summer|Fall) 20\d{2}$/.test(body.term))) return respond({ error: 'Choose a semester.' }, 400);
  const hash = await socialHash(request);
  const response = await fetch(base + '/rest/v1/rpc/' + (body.action === 'terms' ? 'course_terms' : 'course_activity'), { method: 'POST', headers: { apikey: secret, Authorization: 'Bearer ' + secret, 'Content-Type': 'application/json' }, body: JSON.stringify(body.action === 'terms' ? { p_hash: hash } : { p_hash: hash, p_term: body.term }), signal: AbortSignal.timeout(15000) });
  if (!response.ok) return respond({ error: 'Class activity is temporarily unavailable.' }, 503);
  const result = await response.json();
  return respond(result, result.error ? result.code === 'unauthorized' ? 401 : 403 : 200);
 } catch (error) {
  if (error instanceof SocialAuthError) return respond(authFailure(error), error.status);
  if (error instanceof SyntaxError) return respond({ error: 'Invalid request.' }, 400);
  return respond({ error: 'Couldn’t refresh class activity.' }, 503);
 }
});
