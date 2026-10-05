import { refreshCourseCalendar, type CourseCalendarDB } from './course-calendar.ts';
import { groupByBackend, isValidR2Path, R2Store, type MediaStore } from './media-store.ts';

interface RetentionOptions {
  fetcher?: typeof fetch;
  storage?: {origin: string; serviceKey: string};
  /** R2 objects (`r2/...` paths). Defaults to the env-configured store; null when R2 is not configured. */
  r2?: MediaStore | null;
}
const generatedMediaPath = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\.(?:jpg|png|gif|mp4)$/i;

/** Reuses the campus worker. No room needs its own scheduled task. */
export async function maintainCourseChats(db: CourseCalendarDB, options: RetentionOptions = {}): Promise<void> {
  const fetcher = options.fetcher ?? fetch;
  await refreshCourseCalendar(db, fetcher);
  // Access expires exactly at the database deadline, even if this worker is late.
  // Bounded batches prevent a busy past semester from monopolizing the worker.
  for (let batch = 0; batch < 5; batch++) {
    const response = await db('rpc/course_lifecycle_maintenance', {method: 'POST', body: JSON.stringify({p_limit: 500})});
    if (!response.ok) throw new Error('Course maintenance pending');
    const result = await response.json();
    if (!result || !Number.isInteger(result.purged) || result.purged < 0 || result.purged > 500) throw new Error('Invalid course maintenance result');
    if (result.purged < 500) break;
  }
  for (let batch = 0; batch < 5; batch++) {
    const response = await db('rpc/course_media_cleanup_batch', {method: 'POST', body: JSON.stringify({p_limit: 100})});
    if (!response.ok) throw new Error('Course media cleanup pending');
    const paths: unknown = await response.json();
    if (!Array.isArray(paths) || paths.length > 100 || !paths.every(path => typeof path === 'string' && (generatedMediaPath.test(path) || isValidR2Path(path)))) throw new Error('Invalid cleanup batch');
    if (paths.length === 0) break;
    const groups = groupByBackend(paths as string[]);
    const done: string[] = [];
    if (groups.r2.length) {
      // R2 objects are removed only when credentials exist (they remain after a switch back).
      // Without them the paths stay queued and Supabase paths in the same batch still drain.
      const r2 = options.r2 === undefined ? R2Store.fromEnv() : options.r2;
      if (!r2) console.error('r2_media_cleanup_unconfigured', groups.r2.length);
      else {
        try { await r2.remove(groups.r2); done.push(...groups.r2); }
        catch { console.error('r2_media_cleanup_pending'); }
      }
    }
    if (groups.supabase.length) {
      const secret = options.storage?.serviceKey ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
      const origin = options.storage?.origin ?? Deno.env.get('SUPABASE_URL');
      if (!secret || !origin) throw new Error('Course media cleanup configuration unavailable');
      const deleted = await fetcher(origin + '/storage/v1/object/social-media', {
        method: 'DELETE', headers: {apikey: secret, Authorization: 'Bearer ' + secret, 'Content-Type': 'application/json'},
        body: JSON.stringify({prefixes: groups.supabase}), signal: AbortSignal.timeout(20000),
      });
      // Storage's bulk-delete endpoint returns 200 when complete. A 202/204 or
      // failed/ambiguous response must retain the queue for an idempotent retry.
      if (deleted.status !== 200) {
        if (done.length) await db('rpc/social_media_cleanup_complete', {method: 'POST', body: JSON.stringify({p_paths: done})});
        throw new Error('Course media cleanup pending');
    }
    done.push(...groups.supabase);
    }
    if (!done.length) break;
    const acknowledged = await db('rpc/social_media_cleanup_complete', {method: 'POST', body: JSON.stringify({p_paths: done})});
    if (!acknowledged.ok) throw new Error('Course media acknowledgement pending');
    // Anything left (unconfigured or failed R2 removal) would come back first; stop instead of spinning.
    if (paths.length < 100 || done.length < paths.length) break;
  }
}
