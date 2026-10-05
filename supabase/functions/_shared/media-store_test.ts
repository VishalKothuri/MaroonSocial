import { AwsV4Signer } from 'npm:aws4fetch@1.0.20';
import {
  groupByBackend, isValidR2Path, mediaBackend, MediaStoreError, newMediaPath, R2_CACHE_CONTROL, R2_PRIVATE_CACHE_CONTROL, R2Store,
  r2PrivateBucket, RoutedMediaStore, SupabaseStorageStore, type Env, type MediaStore,
} from './media-store.ts';

function assert(value: unknown, message = 'Assertion failed'): asserts value { if (!value) throw new Error(message); }
function equal(actual: unknown, expected: unknown, label = '') {
  assert(JSON.stringify(actual) === JSON.stringify(expected), `${label} expected ${JSON.stringify(expected)}; got ${JSON.stringify(actual)}`);
}
async function rejects(body: () => Promise<unknown>, check: (error: unknown) => boolean) {
  let error: unknown = null;
  try { await body(); } catch (caught) { error = caught; }
  assert(error && check(error), `Unexpected rejection: ${String(error)}`);
}

// Fixed, obviously fake credentials. Nothing here is a real account.
const fake = {accountId: '0123456789abcdef0123456789abcdef', accessKeyId: 'FAKEACCESSKEY000', secretAccessKey: 'fake/secret+key/for/deterministic/tests0', bucket: 'maroon-media', privateBucket: 'maroon-media-private'};
const purge = {zoneId: 'fakezone0000000000000000000000ff', token: 'fake-purge-token'};
const datetime = '20260101T000000Z';
const now = () => Date.UTC(2026, 0, 1);
const envOf = (values: Record<string, string>): Env => name => values[name];
const fullR2 = {MEDIA_BACKEND: 'r2', R2_ACCOUNT_ID: fake.accountId, R2_ACCESS_KEY_ID: fake.accessKeyId, R2_SECRET_ACCESS_KEY: fake.secretAccessKey, R2_BUCKET: fake.bucket, R2_PRIVATE_BUCKET: fake.privateBucket};
const privatePath = 'r2/private/00000000-0000-4000-8000-000000000001.png';
const publicPath = 'r2/public/00000000-0000-4000-8000-000000000002.jpg';

// Independent SigV4 reference (AWS "Signature Version 4" spec), used to cross-check aws4fetch.
const encoder = new TextEncoder();
const hex = (buffer: ArrayBuffer) => Array.from(new Uint8Array(buffer)).map(v => v.toString(16).padStart(2, '0')).join('');
async function hmac(key: string | ArrayBuffer, value: string) {
  const imported = await crypto.subtle.importKey('raw', typeof key === 'string' ? encoder.encode(key) : key, {name: 'HMAC', hash: 'SHA-256'}, false, ['sign']);
  return await crypto.subtle.sign('HMAC', imported, encoder.encode(value));
}
async function referenceSignature(input: {method: string; host: string; path: string; query: string; headers: [string, string][]; payload: string; datetime: string; region: string; secret: string}) {
  const signedHeaders = input.headers.map(([name]) => name).join(';');
  const canonical = [input.method, input.path, input.query, input.headers.map(([n, v]) => `${n}:${v}\n`).join(''), signedHeaders, input.payload].join('\n');
  const scope = `${input.datetime.slice(0, 8)}/${input.region}/s3/aws4_request`;
  const toSign = ['AWS4-HMAC-SHA256', input.datetime, scope, hex(await crypto.subtle.digest('SHA-256', encoder.encode(canonical)))].join('\n');
  let key = await hmac('AWS4' + input.secret, input.datetime.slice(0, 8));
  for (const part of [input.region, 's3', 'aws4_request']) key = await hmac(key, part);
  return hex(await hmac(key, toSign));
}
const rfc3986 = (value: string) => encodeURIComponent(value).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase());

Deno.test('reference signer matches the published AWS presigned-URL example', async () => {
  // AWS S3 documentation example (query-string auth, GET examplebucket/test.txt).
  const credential = 'AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request';
  const query = `X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=${rfc3986(credential)}&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host`;
  const signature = await referenceSignature({method: 'GET', host: 'examplebucket.s3.amazonaws.com', path: '/test.txt', query, headers: [['host', 'examplebucket.s3.amazonaws.com']], payload: 'UNSIGNED-PAYLOAD', datetime: '20130524T000000Z', region: 'us-east-1', secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'});
  equal(signature, 'aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404', 'AWS example');
  // aws4fetch's own signer (as the spec asks) agrees with the documented vector.
  const signer = new AwsV4Signer({url: 'https://examplebucket.s3.amazonaws.com/test.txt?X-Amz-Expires=86400', method: 'GET', accessKeyId: 'AKIAIOSFODNN7EXAMPLE', secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY', service: 's3', region: 'us-east-1', datetime: '20130524T000000Z', signQuery: true});
  equal((await signer.sign()).url.searchParams.get('X-Amz-Signature'), signature, 'aws4fetch');
});

Deno.test('R2 presigned GET: host, path, X-Amz-* parameters and signature are deterministic', async () => {
  const store = new R2Store({...fake, datetime: () => datetime, now});
  const read = await store.read(privatePath);
  assert('url' in read);
  equal(read.expires, now() / 1000 + 86400, 'expires');
  const url = new URL(read.url);
  equal(url.protocol, 'https:'); equal(url.host, `${fake.accountId}.r2.cloudflarestorage.com`);
  equal(url.pathname, `/${fake.privateBucket}/private/00000000-0000-4000-8000-000000000001.png`, 'room media lives in the private bucket; the key drops the r2/ routing prefix');
  equal(url.searchParams.get('X-Amz-Expires'), '86400');
  equal(url.searchParams.get('X-Amz-Algorithm'), 'AWS4-HMAC-SHA256');
  equal(url.searchParams.get('X-Amz-Date'), datetime);
  equal(url.searchParams.get('X-Amz-Credential'), `${fake.accessKeyId}/20260101/auto/s3/aws4_request`);
  equal(url.searchParams.get('X-Amz-SignedHeaders'), 'host');
  const query = [...url.searchParams].filter(([k]) => k !== 'X-Amz-Signature').map(([k, v]) => [rfc3986(k), rfc3986(v)]).sort(([a], [b]) => a < b ? -1 : 1).map(p => p.join('=')).join('&');
  const expected = await referenceSignature({method: 'GET', host: url.host, path: url.pathname, query, headers: [['host', url.host]], payload: 'UNSIGNED-PAYLOAD', datetime, region: 'auto', secret: fake.secretAccessKey});
  equal(url.searchParams.get('X-Amz-Signature'), expected, 'signature');
  // Same inputs, same URL: nothing random leaks into the signature.
  equal((await store.read(privatePath) as {url: string}).url, read.url, 'stable');
  // aws4fetch's AwsV4Signer with the fixed datetime produces the identical URL.
  const signer = new AwsV4Signer({url: store.objectUrl(privatePath) + '?X-Amz-Expires=86400', method: 'GET', accessKeyId: fake.accessKeyId, secretAccessKey: fake.secretAccessKey, service: 's3', region: 'auto', datetime, signQuery: true});
  equal((await signer.sign()).url.toString(), read.url, 'AwsV4Signer');
});

Deno.test('R2 put sends Content-Type and immutable Cache-Control, signed with SigV4', async () => {
  const requests: Request[] = [];
  const fetcher: typeof fetch = (input) => { requests.push(input as Request); return Promise.resolve(new Response(null, {status: 200})); };
  const store = new R2Store({...fake, datetime: () => datetime, fetcher});
  await store.put(publicPath, new Uint8Array([1, 2, 3]), 'image/jpeg');
  equal(requests.length, 1);
  const request = requests[0];
  equal(request.method, 'PUT');
  equal(new URL(request.url).pathname, `/${fake.bucket}/public/00000000-0000-4000-8000-000000000002.jpg`);
  equal(request.headers.get('Content-Type'), 'image/jpeg');
  equal(request.headers.get('Cache-Control'), 'public, max-age=31536000, immutable');
  equal(R2_CACHE_CONTROL, 'public, max-age=31536000, immutable');
  equal(request.headers.get('X-Amz-Date'), datetime);
  equal(request.headers.get('X-Amz-Content-Sha256'), 'UNSIGNED-PAYLOAD');
  equal(new Uint8Array(await request.arrayBuffer()), new Uint8Array([1, 2, 3]), 'body');
  const auth = request.headers.get('Authorization') ?? '';
  assert(auth.startsWith(`AWS4-HMAC-SHA256 Credential=${fake.accessKeyId}/20260101/auto/s3/aws4_request, SignedHeaders=cache-control;host;x-amz-content-sha256;x-amz-date, Signature=`), auth);
  const host = new URL(request.url).host;
  const expected = await referenceSignature({method: 'PUT', host, path: new URL(request.url).pathname, query: '', headers: [['cache-control', R2_CACHE_CONTROL], ['host', host], ['x-amz-content-sha256', 'UNSIGNED-PAYLOAD'], ['x-amz-date', datetime]], payload: 'UNSIGNED-PAYLOAD', datetime, region: 'auto', secret: fake.secretAccessKey});
  equal(auth.split('Signature=')[1], expected, 'put signature');
  await rejects(() => new R2Store({...fake, fetcher: () => Promise.resolve(new Response(null, {status: 500}))}).put(publicPath, new Uint8Array([1]), 'image/jpeg'), e => e instanceof MediaStoreError && e.kind === 'unavailable');
  // Room/DM media: the private bucket, and a Cache-Control no shared cache may keep.
  await store.put(privatePath, new Uint8Array([4]), 'image/png');
  equal(new URL(requests[1].url).pathname, `/${fake.privateBucket}/private/00000000-0000-4000-8000-000000000001.png`);
  equal(requests[1].headers.get('Cache-Control'), 'private, max-age=86400');
  equal(R2_PRIVATE_CACHE_CONTROL, 'private, max-age=86400');
  assert(!/public|immutable/.test(requests[1].headers.get('Cache-Control')!), 'private objects are never public or immutable');
});

Deno.test('R2 public base URL serves only post (public/) media; room media stays presigned', async () => {
  const store = new R2Store({...fake, publicBaseUrl: 'https://media.example.test/', purge, datetime: () => datetime, now});
  assert(store.cdnEnabled);
  equal(await store.read(publicPath), {url: 'https://media.example.test/public/00000000-0000-4000-8000-000000000002.jpg', expires: now() / 1000 + 31536000});
  const room = await store.read(privatePath) as {url: string};
  equal(new URL(room.url).host, `${fake.accountId}.r2.cloudflarestorage.com`);
  assert(new URL(room.url).searchParams.has('X-Amz-Signature'));
  // Without a public base URL, post media is presigned too.
  const plain = await new R2Store({...fake, datetime: () => datetime}).read(publicPath) as {url: string};
  assert(new URL(plain.url).searchParams.has('X-Amz-Signature'));
  // A CDN that cannot be purged is never used: deleted post media would stay public at the edge.
  const unpurgeable = new R2Store({...fake, publicBaseUrl: 'https://media.example.test', datetime: () => datetime, now});
  assert(!unpurgeable.cdnEnabled);
  const presigned = await unpurgeable.read(publicPath) as {url: string; expires: number};
  equal(new URL(presigned.url).host, `${fake.accountId}.r2.cloudflarestorage.com`); equal(presigned.expires, now() / 1000 + 86400);
  assert(!R2Store.fromEnv(envOf({...fullR2, R2_PUBLIC_BASE_URL: 'https://media.example.test', R2_CDN_ZONE_ID: purge.zoneId}))!.cdnEnabled, 'zone without token');
  assert(R2Store.fromEnv(envOf({...fullR2, R2_PUBLIC_BASE_URL: 'https://media.example.test', R2_CDN_ZONE_ID: purge.zoneId, R2_CDN_PURGE_TOKEN: purge.token}))!.cdnEnabled);
});

Deno.test('removing post media purges its CDN URL; room media and a CDN-less store never call the purge API', async () => {
  const seen: {method: string; url: string; auth: string | null; body: string}[] = [];
  let purgeStatus = 200, purgeSuccess = true;
  const fetcher: typeof fetch = async (input) => {
    const request = input as Request;
    seen.push({method: request.method, url: request.url, auth: request.headers.get('Authorization'), body: request.method === 'POST' ? await request.text() : ''});
    if (request.url.startsWith('https://api.cloudflare.com/')) return new Response(JSON.stringify({success: purgeSuccess, errors: [], messages: [], result: {}}), {status: purgeStatus});
    return new Response(null, {status: 204});
  };
  const store = new R2Store({...fake, publicBaseUrl: 'https://media.example.test/', purge, datetime: () => datetime, fetcher});
  const publics = Array.from({length: 31}, (_, i) => `r2/public/00000000-0000-4000-8000-${(100 + i).toString(16).padStart(12, '0')}.jpg`);
  await store.remove([privatePath, ...publics]);
  const deletes = seen.filter(r => r.method === 'DELETE'), purges = seen.filter(r => r.method === 'POST');
  equal(deletes.length, 32);
  equal(purges.length, 2, 'purged in batches of 30');
  for (const call of purges) {
    equal(call.url, `https://api.cloudflare.com/client/v4/zones/${purge.zoneId}/purge_cache`);
    equal(call.auth, `Bearer ${purge.token}`);
  }
  equal(purges.flatMap(call => JSON.parse(call.body).files), publics.map(path => `https://media.example.test/${path.slice(3)}`));
  assert(!purges.some(call => call.body.includes('private/')), 'room media is never on the CDN, so it is never purged');
  assert(seen.findIndex(r => r.method === 'POST') > seen.findLastIndex(r => r.method === 'DELETE'), 'origin deleted before the edge copy is purged');
  // A failed purge keeps the removal pending (the queue row stays and the worker retries).
  for (const [status, success] of [[500, true], [200, false]] as const) {
    purgeStatus = status; purgeSuccess = success;
    await rejects(() => store.remove([publicPath]), e => e instanceof MediaStoreError && e.kind === 'unavailable');
  }
  // Without CDN settings (or with a public base URL but no purge credentials) nothing is purged.
  seen.length = 0;
  await new R2Store({...fake, datetime: () => datetime, fetcher}).remove([publicPath]);
  await new R2Store({...fake, publicBaseUrl: 'https://media.example.test', datetime: () => datetime, fetcher}).remove([publicPath]);
  equal(seen.map(r => r.method), ['DELETE', 'DELETE']);
});

Deno.test('room media needs its own bucket: without R2_PRIVATE_BUCKET it stays on Supabase Storage', async () => {
  const noPrivate: Record<string, string> = {...fullR2}; delete noPrivate.R2_PRIVATE_BUCKET;
  equal(r2PrivateBucket(envOf(noPrivate)), undefined);
  equal(r2PrivateBucket(envOf({...fullR2, R2_PRIVATE_BUCKET: fake.bucket})), undefined, 'the CDN bucket is never reused for room media');
  equal(r2PrivateBucket(envOf(fullR2)), fake.privateBucket);
  for (const env of [noPrivate, {...fullR2, R2_PRIVATE_BUCKET: fake.bucket}, {...fullR2, R2_PRIVATE_BUCKET: ''}]) {
    assert(/^[a-f0-9-]{36}\.png$/.test(newMediaPath('.png', 'private', envOf(env))), 'room media on Supabase');
    assert(/^r2\/public\/[a-f0-9-]{36}\.png$/.test(newMediaPath('.png', 'public', envOf(env))), 'post media still on R2');
  }
  // An r2/private object without a private bucket is refused before any request (it stays queued, never read from the CDN bucket).
  const calls: string[] = [];
  const store = R2Store.fromEnv(envOf(noPrivate), (input) => { calls.push(String(input)); return Promise.resolve(new Response(null, {status: 204})); })!;
  await rejects(() => store.read(privatePath), e => e instanceof MediaStoreError && e.kind === 'unconfigured');
  await rejects(() => store.remove([privatePath]), e => e instanceof MediaStoreError && e.kind === 'unconfigured');
  await rejects(() => store.put(privatePath, new Uint8Array([1]), 'image/png'), e => e instanceof MediaStoreError && e.kind === 'unconfigured');
  equal(calls, []);
});

Deno.test('R2 endpoint override (tests only), path validation and idempotent delete', async () => {
  const seen: string[] = [];
  const fetcher: typeof fetch = (input) => { const r = input as Request; seen.push(`${r.method} ${new URL(r.url).pathname}`); return Promise.resolve(new Response(null, {status: r.url.includes('0003') ? 404 : 204})); };
  const store = new R2Store({...fake, endpoint: 'http://127.0.0.1:9000/', datetime: () => datetime, fetcher});
  equal(new URL(store.objectUrl(privatePath)).origin, 'http://127.0.0.1:9000');
  await store.remove([privatePath, 'r2/public/00000000-0000-4000-8000-000000000003.gif']);
  equal(seen.sort(), [`DELETE /${fake.privateBucket}/private/00000000-0000-4000-8000-000000000001.png`, `DELETE /${fake.bucket}/public/00000000-0000-4000-8000-000000000003.gif`]);
  for (const bad of ['r2/../secret', 'r2/public/../../x.png', 'r2/other/00000000-0000-4000-8000-000000000001.png', '00000000-0000-4000-8000-000000000001.png']) {
    assert(!isValidR2Path(bad), bad);
    await rejects(() => store.read(bad), e => e instanceof MediaStoreError && e.kind === 'invalid');
  }
  const failing = new R2Store({...fake, fetcher: () => Promise.resolve(new Response(null, {status: 503}))});
  await rejects(() => failing.remove([privatePath]), e => e instanceof MediaStoreError && e.status === 503);
});

Deno.test('mediaBackend() is r2 only with MEDIA_BACKEND=r2 and every credential', () => {
  equal(mediaBackend(envOf(fullR2)), 'r2');
  equal(mediaBackend(envOf({})), 'supabase');
  equal(mediaBackend(envOf({...fullR2, MEDIA_BACKEND: 'supabase'})), 'supabase');
  equal(mediaBackend(envOf({...fullR2, MEDIA_BACKEND: 'R2'})), 'supabase');
  for (const name of ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET']) {
    const partial: Record<string, string> = {...fullR2}; delete partial[name];
    equal(mediaBackend(envOf(partial)), 'supabase', name);
    equal(mediaBackend(envOf({...fullR2, [name]: ''})), 'supabase', name + ' empty');
  }
  assert(/^[a-f0-9-]{36}\.png$/.test(newMediaPath('.png', 'public', envOf({}))));
  assert(/^r2\/public\/[a-f0-9-]{36}\.png$/.test(newMediaPath('.png', 'public', envOf(fullR2))));
  assert(/^r2\/private\/[a-f0-9-]{36}\.mp4$/.test(newMediaPath('.mp4', 'private', envOf(fullR2))));
  assert(isValidR2Path(newMediaPath('.gif', 'private', envOf(fullR2))));
  assert(R2Store.fromEnv(envOf({...fullR2, R2_BUCKET: ''})) === null);
});

Deno.test('Supabase store is selected when MEDIA_BACKEND is unset and keeps today\'s requests', async () => {
  const calls: {url: string; method: string; headers: Headers; body: string}[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    calls.push({url: String(input), method: init?.method ?? 'GET', headers: new Headers(init?.headers), body: init?.body instanceof ArrayBuffer ? `bytes:${init.body.byteLength}` : String(init?.body ?? '')});
    assert(init?.signal instanceof AbortSignal);
    return String(input).includes('/authenticated/') ? new Response(new Uint8Array([9, 8, 7]), {status: 200}) : new Response('[]', {status: 200});
  };
  const env = envOf({SUPABASE_URL: 'https://fixture.supabase.co'});
  equal(mediaBackend(env), 'supabase');
  const store = new RoutedMediaStore(new SupabaseStorageStore({origin: 'https://fixture.supabase.co', serviceKey: 'synthetic-server-key', fetcher}), R2Store.fromEnv(env));
  const path = newMediaPath('.png', 'public', env);
  await store.put(path, new Uint8Array([1, 2]), 'image/png');
  const read = await store.read(path, {mime: 'image/png'});
  equal(read, {bytes: new Uint8Array([9, 8, 7]), mime: 'image/png'});
  await store.remove([path]);
  equal(calls.map(c => `${c.method} ${c.url}`), [
    `POST https://fixture.supabase.co/storage/v1/object/social-media/${path}`,
    `GET https://fixture.supabase.co/storage/v1/object/authenticated/social-media/${path}`,
    'DELETE https://fixture.supabase.co/storage/v1/object/social-media',
  ]);
  equal(calls[0].headers.get('Content-Type'), 'image/png'); equal(calls[0].headers.get('x-upsert'), 'false');
  equal(calls[0].headers.get('apikey'), 'synthetic-server-key'); equal(calls[0].headers.get('Authorization'), 'Bearer synthetic-server-key');
  equal(calls[0].body, 'bytes:2');
  equal(JSON.parse(calls[2].body), {prefixes: [path]});
  const missing = new SupabaseStorageStore({origin: 'https://fixture.supabase.co', serviceKey: 'k', fetcher: () => Promise.resolve(new Response('', {status: 400}))});
  await rejects(() => missing.read('x.png'), e => e instanceof MediaStoreError && e.kind === 'not_found');
  await rejects(() => missing.remove(['x.png']), e => e instanceof MediaStoreError && e.status === 400);
});

Deno.test('routed store dispatches on the r2/ prefix and groups removals by backend', async () => {
  const log: string[] = [];
  const fakeStore = (name: string): MediaStore => ({
    put: (path) => { log.push(`${name}.put ${path}`); return Promise.resolve(); },
    read: (path) => { log.push(`${name}.read ${path}`); return Promise.resolve({url: name, expires: 1}); },
    remove: (paths) => { log.push(`${name}.remove ${paths.join(',')}`); return Promise.resolve(); },
  });
  const store = new RoutedMediaStore(fakeStore('supabase'), fakeStore('r2'));
  await store.put('a.png', new Uint8Array(), 'image/png'); await store.put(privatePath, new Uint8Array(), 'image/png');
  await store.read('a.png'); await store.read(publicPath);
  await store.remove(['a.png', privatePath, 'b.jpg', publicPath]);
  equal(log, ['supabase.put a.png', `r2.put ${privatePath}`, 'supabase.read a.png', `r2.read ${publicPath}`, 'supabase.remove a.png,b.jpg', `r2.remove ${privatePath},${publicPath}`]);
  equal(groupByBackend(['a.png', privatePath]), {supabase: ['a.png'], r2: [privatePath]});
  // Old R2 objects after a switch back without credentials: Supabase paths still drain, R2 reports unconfigured.
  const without = new RoutedMediaStore(fakeStore('supabase'), null);
  await rejects(() => without.read(privatePath), e => e instanceof MediaStoreError && e.kind === 'unconfigured');
  log.length = 0;
  await rejects(() => without.remove(['a.png', privatePath]), e => e instanceof MediaStoreError && e.kind === 'unconfigured');
  equal(log, ['supabase.remove a.png']);
});

// End-to-end through real HTTP against a local S3-compatible stub that verifies every
// signature with the reference signer (R2_ENDPOINT_OVERRIDE path). Needs --allow-net.
const netGranted = (await Deno.permissions.query({name: 'net', host: '127.0.0.1'})).state === 'granted';
Deno.test({name: 'R2 round trip against a signature-verifying local S3 stub', ignore: !netGranted, fn: async () => {
  const objects = new Map<string, {bytes: Uint8Array<ArrayBuffer>; type: string; cache: string}>();
  const verify = async (request: Request) => {
    const url = new URL(request.url);
    const presigned = url.searchParams.get('X-Amz-Signature');
    if (presigned) {
      const query = [...url.searchParams].filter(([k]) => k !== 'X-Amz-Signature').map(([k, v]) => [rfc3986(k), rfc3986(v)]).sort(([a], [b]) => a < b ? -1 : 1).map(p => p.join('=')).join('&');
      return presigned === await referenceSignature({method: request.method, host: url.host, path: url.pathname, query, headers: [['host', url.host]], payload: 'UNSIGNED-PAYLOAD', datetime: url.searchParams.get('X-Amz-Date')!, region: 'auto', secret: fake.secretAccessKey});
    }
    const auth = request.headers.get('Authorization') ?? '';
    const names = /SignedHeaders=([^,]+)/.exec(auth)?.[1].split(';') ?? [];
    const headers = names.map(name => [name, name === 'host' ? url.host : (request.headers.get(name) ?? '').trim()] as [string, string]);
    const date = request.headers.get('X-Amz-Date')!;
    return auth.split('Signature=')[1] === await referenceSignature({method: request.method, host: url.host, path: url.pathname, query: '', headers, payload: request.headers.get('X-Amz-Content-Sha256')!, datetime: date, region: 'auto', secret: fake.secretAccessKey});
  };
  const server = Deno.serve({hostname: '127.0.0.1', port: 0, onListen: () => {}}, async request => {
    if (!await verify(request)) return new Response('SignatureDoesNotMatch', {status: 403});
    const key = new URL(request.url).pathname;
    if (request.method === 'PUT') { objects.set(key, {bytes: new Uint8Array(await request.arrayBuffer()), type: request.headers.get('Content-Type')!, cache: request.headers.get('Cache-Control')!}); return new Response(null, {status: 200}); }
    if (request.method === 'DELETE') { objects.delete(key); return new Response(null, {status: 204}); }
    const object = objects.get(key);
    return object ? new Response(object.bytes, {headers: {'Content-Type': object.type, 'Cache-Control': object.cache}}) : new Response('NoSuchKey', {status: 404});
  });
  try {
    const env = envOf({...fullR2, R2_ENDPOINT_OVERRIDE: `http://127.0.0.1:${server.addr.port}`});
    const store = new RoutedMediaStore(new SupabaseStorageStore({origin: 'http://unused.invalid', serviceKey: 'k', fetcher: () => Promise.reject(new Error('Supabase must not be called'))}), R2Store.fromEnv(env));
    const path = newMediaPath('.png', 'private', env);
    await store.put(path, new Uint8Array([137, 80, 78, 71]), 'image/png');
    const read = await store.read(path);
    assert('url' in read);
    const fetched = await fetch(read.url);
    equal(fetched.status, 200); equal(fetched.headers.get('Content-Type'), 'image/png'); equal(fetched.headers.get('Cache-Control'), R2_PRIVATE_CACHE_CONTROL);
    equal(new URL(read.url).pathname.split('/')[1], fake.privateBucket, 'room media round-trips through the private bucket');
    const post = newMediaPath('.jpg', 'public', env);
    await store.put(post, new Uint8Array([255, 216, 255]), 'image/jpeg');
    const postRead = await store.read(post); assert('url' in postRead);
    const postFetched = await fetch(postRead.url);
    equal(postFetched.headers.get('Cache-Control'), R2_CACHE_CONTROL); equal(new URL(postRead.url).pathname.split('/')[1], fake.bucket);
    await postFetched.body?.cancel();
    await store.remove([post]);
    equal(new Uint8Array(await fetched.arrayBuffer()), new Uint8Array([137, 80, 78, 71]));
    const tampered = new URL(read.url); tampered.searchParams.set('X-Amz-Expires', '604800');
    const denied = await fetch(tampered); equal(denied.status, 403); await denied.body?.cancel();
    await store.remove([path]);
    const gone = await fetch(read.url); equal(gone.status, 404); await gone.body?.cancel();
  } finally { await server.shutdown(); }
}});
