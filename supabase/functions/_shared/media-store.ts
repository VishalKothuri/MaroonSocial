import { AwsClient } from 'npm:aws4fetch@1.0.20';

/**
 * Where attachment bytes live. Supabase Storage (the `social-media` bucket) is the
 * default; Cloudflare R2 is used for NEW uploads only when MEDIA_BACKEND=r2 and all
 * four R2 credentials are present. The backend is encoded in the stored object path,
 * so no schema change is needed and both kinds of objects keep working side by side:
 *
 *   <uuid>.<ext>                 Supabase Storage (every object written before R2)
 *   r2/public/<uuid>.<ext>       R2_BUCKET, post media (may be served by the CDN domain)
 *   r2/private/<uuid>.<ext>      R2_PRIVATE_BUCKET, room/DM media (presigned S3 GETs only)
 *
 * The R2 object key is the path without the leading `r2/`. Room/DM media lives in its own
 * bucket, which must never get a custom domain, so the CDN cannot serve it whatever the
 * dashboard rules say; without R2_PRIVATE_BUCKET it stays on Supabase Storage. Keys are
 * random and never reused.
 *
 * CDN URLs bypass per-read authorization, so they are only issued when a deleted object
 * can also be purged from the edge (R2_CDN_ZONE_ID + R2_CDN_PURGE_TOKEN); removing a
 * `public/` object purges its CDN URL before the removal counts as done.
 */
export type Env = (name: string) => string | undefined;
export type MediaRead = {url: string; expires: number} | {bytes: Uint8Array; mime: string};
export type MediaVisibility = 'public' | 'private';
export interface MediaStore {
  put(path: string, bytes: Uint8Array, mime: string): Promise<void>;
  remove(paths: string[], options?: {timeoutMs?: number}): Promise<void>;
  read(path: string, options?: {mime?: string}): Promise<MediaRead>;
}
export class MediaStoreError extends Error {
  constructor(message: string, public kind: 'not_found' | 'unavailable' | 'unconfigured' | 'invalid', public status?: number) { super(message); }
}

export const R2_PREFIX = 'r2/';
export const R2_ENV = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET'] as const;
export const R2_CACHE_CONTROL = 'public, max-age=31536000, immutable';
/** Room/DM objects: never stored by a shared cache, never cached longer than a presigned URL lives. */
export const R2_PRIVATE_CACHE_CONTROL = 'private, max-age=86400';
export const PRESIGN_SECONDS = 86400;
/** URLs per Cloudflare purge-by-URL request (the lowest per-plan limit). */
export const PURGE_BATCH = 30;
export const CLOUDFLARE_API = 'https://api.cloudflare.com/client/v4';
const uuid = '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}';
const r2Path = new RegExp(`^r2/(public|private)/${uuid}\\.(?:jpg|png|gif|mp4|img)$`, 'i');
const denoEnv: Env = name => Deno.env.get(name);

export const isR2Path = (path: string) => path.startsWith(R2_PREFIX);
export const isValidR2Path = (path: string) => r2Path.test(path);
/** True when R2 can be reached at all (also used to read/delete old R2 objects after a switch back). */
export const r2Configured = (env: Env = denoEnv) => R2_ENV.every(name => !!env(name));
/** The backend NEW uploads go to. Anything less than a complete R2 configuration stays on Supabase. */
export function mediaBackend(env: Env = denoEnv): 'r2' | 'supabase' {
  return env('MEDIA_BACKEND') === 'r2' && r2Configured(env) ? 'r2' : 'supabase';
}
/** The bucket for room/DM media. It must differ from R2_BUCKET (the one a CDN domain may serve). */
export function r2PrivateBucket(env: Env = denoEnv): string | undefined {
  const bucket = env('R2_PRIVATE_BUCKET');
  return bucket && bucket !== env('R2_BUCKET') ? bucket : undefined;
}
/** A fresh, never-reused object path for the active backend. */
export function newMediaPath(extension: string, visibility: MediaVisibility, env: Env = denoEnv): string {
  const name = crypto.randomUUID() + extension;
  if (mediaBackend(env) !== 'r2') return name;
  // Room/DM media goes to R2 only when it has its own bucket; otherwise it stays on authenticated Supabase Storage.
  if (visibility === 'private' && !r2PrivateBucket(env)) return name;
  return `${R2_PREFIX}${visibility}/${name}`;
}
/** Splits paths by the backend that holds them, preserving order inside each group. */
export function groupByBackend(paths: string[]): {supabase: string[]; r2: string[]} {
  const groups = {supabase: [] as string[], r2: [] as string[]};
  for (const path of paths) (isR2Path(path) ? groups.r2 : groups.supabase).push(path);
  return groups;
}

/** Today's Supabase Storage calls, unchanged on the wire. */
export class SupabaseStorageStore implements MediaStore {
  private headers: Record<string, string>;
  private fetcher: typeof fetch;
  private bucket: string;
  constructor(private options: {origin: string; serviceKey: string; bucket?: string; fetcher?: typeof fetch; timeoutMs?: number}) {
    this.headers = {apikey: options.serviceKey, Authorization: 'Bearer ' + options.serviceKey};
    this.fetcher = options.fetcher ?? fetch;
    this.bucket = options.bucket ?? 'social-media';
  }
  private get timeout() { return this.options.timeoutMs ?? 18000; }
  async put(path: string, bytes: Uint8Array, mime: string) {
    const uploaded = await this.fetcher(`${this.options.origin}/storage/v1/object/${this.bucket}/${path}`, {method: 'POST', headers: {...this.headers, 'Content-Type': mime, 'x-upsert': 'false'}, body: new Uint8Array(bytes).buffer, signal: AbortSignal.timeout(this.timeout)});
    if (!uploaded.ok) throw new MediaStoreError('Upload failed', 'unavailable', uploaded.status);
  }
  async remove(paths: string[], options: {timeoutMs?: number} = {}) {
    if (!paths.length) return;
    const removed = await this.fetcher(`${this.options.origin}/storage/v1/object/${this.bucket}`, {method: 'DELETE', headers: {...this.headers, 'Content-Type': 'application/json'}, body: JSON.stringify({prefixes: paths}), signal: AbortSignal.timeout(options.timeoutMs ?? this.timeout)});
    if (!removed.ok) throw new MediaStoreError('Removal pending', 'unavailable', removed.status);
  }
  async read(path: string, options: {mime?: string} = {}): Promise<MediaRead> {
    const media = await this.fetcher(`${this.options.origin}/storage/v1/object/authenticated/${this.bucket}/${path}`, {headers: this.headers, signal: AbortSignal.timeout(this.timeout)});
    if (!media.ok) throw new MediaStoreError('Media unavailable', 'not_found', media.status);
    return {bytes: new Uint8Array(await media.arrayBuffer()), mime: options.mime ?? media.headers.get('Content-Type') ?? 'application/octet-stream'};
  }
}

export interface R2Options {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  /** Post media (`public/` keys). The only bucket a custom domain may be attached to. */
  bucket: string;
  /** Room/DM media (`private/` keys). Never attach a custom domain to it. */
  privateBucket?: string;
  /** Custom-domain CDN base for `public/` objects, e.g. https://media.example.edu */
  publicBaseUrl?: string;
  /** Cloudflare zone of the CDN domain and an API token with Cache Purge permission. */
  purge?: {zoneId: string; token: string};
  /** Local tests only (MinIO or a stub). Production always uses the account's S3 host. */
  endpoint?: string;
  fetcher?: typeof fetch;
  /** Fixed SigV4 time (YYYYMMDDTHHMMSSZ) for deterministic tests. */
  datetime?: () => string;
  now?: () => number;
  timeoutMs?: number;
}
/** Cloudflare R2 through its S3 API, signed with aws4fetch (fetch + SubtleCrypto only). */
export class R2Store implements MediaStore {
  private client: AwsClient;
  private fetcher: typeof fetch;
  readonly endpoint: string;
  constructor(private options: R2Options) {
    this.client = new AwsClient({service: 's3', region: 'auto', accessKeyId: options.accessKeyId, secretAccessKey: options.secretAccessKey});
    this.fetcher = options.fetcher ?? fetch;
    this.endpoint = (options.endpoint ?? `https://${options.accountId}.r2.cloudflarestorage.com`).replace(/\/+$/, '');
  }
  static fromEnv(env: Env = denoEnv, fetcher?: typeof fetch): R2Store | null {
    if (!r2Configured(env)) return null;
    const zoneId = env('R2_CDN_ZONE_ID'), token = env('R2_CDN_PURGE_TOKEN');
    return new R2Store({
      accountId: env('R2_ACCOUNT_ID')!, accessKeyId: env('R2_ACCESS_KEY_ID')!, secretAccessKey: env('R2_SECRET_ACCESS_KEY')!,
      bucket: env('R2_BUCKET')!, privateBucket: r2PrivateBucket(env), publicBaseUrl: env('R2_PUBLIC_BASE_URL') || undefined,
      purge: zoneId && token ? {zoneId, token} : undefined, endpoint: env('R2_ENDPOINT_OVERRIDE') || undefined, fetcher,
    });
  }
  /** CDN URLs are issued only when a deleted object can also be purged from the edge. */
  get cdnEnabled() { return !!(this.options.publicBaseUrl && this.options.purge); }
  private isPublic(path: string) { return this.key(path).startsWith('public/'); }
  private bucketFor(key: string) {
    if (key.startsWith('public/')) return this.options.bucket;
    if (!this.options.privateBucket) throw new MediaStoreError('Private R2 bucket is not configured', 'unconfigured');
    return this.options.privateBucket;
  }
  /** `r2/public/<uuid>.png` -> `public/<uuid>.png`. Anything else is refused before any request. */
  key(path: string) {
    if (!isValidR2Path(path)) throw new MediaStoreError('Invalid media path', 'invalid');
    return path.slice(R2_PREFIX.length);
  }
  objectUrl(path: string) {
    const key = this.key(path);
    return `${this.endpoint}/${encodeURIComponent(this.bucketFor(key))}/${key}`;
  }
  /** The CDN URL of a `public/` object (only meaningful when `publicBaseUrl` is set). */
  cdnUrl(path: string) { return `${(this.options.publicBaseUrl ?? '').replace(/\/+$/, '')}/${this.key(path)}`; }
  private aws(extra: Record<string, unknown> = {}) {
    const datetime = this.options.datetime?.();
    return datetime ? {...extra, datetime} : extra;
  }
  private get timeout() { return this.options.timeoutMs ?? 18000; }
  async signedPut(path: string, bytes: Uint8Array, mime: string): Promise<Request> {
    const cacheControl = this.isPublic(path) ? R2_CACHE_CONTROL : R2_PRIVATE_CACHE_CONTROL;
    return await this.client.sign(this.objectUrl(path), {method: 'PUT', headers: {'Content-Type': mime, 'Cache-Control': cacheControl}, body: new Uint8Array(bytes), aws: this.aws()});
  }
  async presignedGet(path: string, seconds = PRESIGN_SECONDS): Promise<string> {
    const signed = await this.client.sign(`${this.objectUrl(path)}?X-Amz-Expires=${seconds}`, {method: 'GET', aws: this.aws({signQuery: true})});
    return signed.url;
  }
  async put(path: string, bytes: Uint8Array, mime: string) {
    const request = await this.signedPut(path, bytes, mime);
    const uploaded = await this.fetcher(new Request(request, {signal: AbortSignal.timeout(this.timeout)}));
    if (!uploaded.ok) throw new MediaStoreError('Upload failed', 'unavailable', uploaded.status);
  }
  async remove(paths: string[], options: {timeoutMs?: number} = {}) {
    const failures: number[] = [];
    const removed = new Set<string>();
    // DeleteObject is idempotent (a missing key is a success); a few at a time keeps the isolate light.
    for (let index = 0; index < paths.length; index += 8) {
      await Promise.all(paths.slice(index, index + 8).map(async path => {
        const request = await this.client.sign(this.objectUrl(path), {method: 'DELETE', aws: this.aws()});
        const response = await this.fetcher(new Request(request, {signal: AbortSignal.timeout(options.timeoutMs ?? this.timeout)}));
        if (response.ok || response.status === 404) removed.add(path); else failures.push(response.status);
      }));
    }
    // The origin object is gone; the edge copy must go too before the removal counts as done.
    await this.purge(paths.filter(path => removed.has(path) && this.isPublic(path)), options.timeoutMs);
    if (failures.length) throw new MediaStoreError('Removal pending', 'unavailable', failures[0]);
  }
  /** Cloudflare purge-by-URL for deleted `public/` objects. A failure keeps the paths queued for a retry. */
  async purge(paths: string[], timeoutMs?: number) {
    const purge = this.options.purge;
    if (!this.cdnEnabled || !purge || !paths.length) return;
    const urls = paths.map(path => this.cdnUrl(path));
    for (let index = 0; index < urls.length; index += PURGE_BATCH) {
      const response = await this.fetcher(new Request(`${CLOUDFLARE_API}/zones/${encodeURIComponent(purge.zoneId)}/purge_cache`, {
        method: 'POST', headers: {Authorization: `Bearer ${purge.token}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({files: urls.slice(index, index + PURGE_BATCH)}), signal: AbortSignal.timeout(timeoutMs ?? this.timeout),
      }));
      const result = await response.json().catch(() => null) as {success?: boolean} | null;
      if (!response.ok || result?.success !== true) throw new MediaStoreError('CDN purge pending', 'unavailable', response.status);
    }
  }
  async read(path: string): Promise<MediaRead> {
    const now = Math.floor((this.options.now?.() ?? Date.now()) / 1000);
    if (this.cdnEnabled && this.isPublic(path)) {
      // Content-addressed and immutable: the CDN URL never changes for this attachment. Deleting
      // the post queues the object, and its removal purges this URL (see remove()).
      return {url: this.cdnUrl(path), expires: now + 31536000};
    }
    return {url: await this.presignedGet(path), expires: now + PRESIGN_SECONDS};
  }
}

/** Dispatches on the stored path: `r2/...` -> R2, everything else -> Supabase Storage. */
export class RoutedMediaStore implements MediaStore {
  constructor(public supabase: MediaStore, public r2: MediaStore | null) {}
  private target(path: string): MediaStore {
    if (!isR2Path(path)) return this.supabase;
    if (!this.r2) throw new MediaStoreError('R2 is not configured', 'unconfigured');
    return this.r2;
  }
  put(path: string, bytes: Uint8Array, mime: string) { return this.target(path).put(path, bytes, mime); }
  read(path: string, options?: {mime?: string}) { return this.target(path).read(path, options); }
  async remove(paths: string[], options?: {timeoutMs?: number}) {
    const groups = groupByBackend(paths);
    let failure: unknown = null;
    if (groups.supabase.length) { try { await this.supabase.remove(groups.supabase, options); } catch (error) { failure = error; } }
    if (groups.r2.length) {
      try {
        if (!this.r2) throw new MediaStoreError('R2 is not configured', 'unconfigured');
        await this.r2.remove(groups.r2, options);
      } catch (error) { failure ??= error; }
    }
    if (failure) throw failure;
  }
}

let shared: RoutedMediaStore | null = null;
/** One store per isolate. Logs which backend is active once, never any credential value. */
export function mediaStore(env: Env = denoEnv, options: {timeoutMs?: number} = {}): RoutedMediaStore {
  if (shared) return shared;
  const supabase = new SupabaseStorageStore({origin: env('SUPABASE_URL') ?? '', serviceKey: env('SUPABASE_SERVICE_ROLE_KEY') ?? '', timeoutMs: options.timeoutMs});
  const r2 = R2Store.fromEnv(env);
  shared = new RoutedMediaStore(supabase, r2);
  // Booleans only: never a credential, bucket name or URL.
  console.log(JSON.stringify({event: 'media_backend', backend: mediaBackend(env), r2_reachable: !!r2, private_bucket: !!(r2 && r2PrivateBucket(env)), cdn: !!r2?.cdnEnabled}));
  if (r2 && env('R2_PUBLIC_BASE_URL') && !r2.cdnEnabled) console.warn(JSON.stringify({event: 'media_cdn_disabled', reason: 'purge_unconfigured'}));
  return shared;
}
