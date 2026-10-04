import { maintainCourseChats } from './course-retention.ts';
import type { CourseCalendarDB } from './course-calendar.ts';
function assert(value: unknown, message = 'Assertion failed'): asserts value { if (!value) throw new Error(message); }
function equal(actual: unknown, expected: unknown) { assert(JSON.stringify(actual) === JSON.stringify(expected), `Expected ${JSON.stringify(expected)}; got ${JSON.stringify(actual)}`); }
async function rejects(body: () => Promise<void>, expected: string) {
  let error: unknown;
  try { await body(); } catch (caught) { error = caught; }
  assert(error instanceof Error && error.message === expected, `Expected ${expected}; got ${String(error)}`);
}
const path = (i: number) => `00000000-0000-4000-8000-${i.toString(16).padStart(12,'0')}.png`;
const storage = {origin:'https://retention-fixture.supabase.co',serviceKey:'synthetic-server-key'};
interface HarnessOptions {
  rooms?: number;
  paths?: unknown;
  storageStatus?: number;
  throwStorage?: boolean;
  ackStatus?: number;
  maintenanceStatus?: number;
  maintenanceResult?: unknown;
  queueStatus?: number;
}
function harness(options: HarnessOptions = {}) {
  let rooms = options.rooms ?? 0;
  let queue: unknown = options.paths ?? [];
  const calls: string[] = [];
  const deleted: unknown[][] = [];
  const acknowledged: unknown[][] = [];
  const db: CourseCalendarDB = (rpc, init) => {
    calls.push(rpc);
    equal(init?.method,'POST');
    if (rpc === 'rpc/claim_course_calendar_refresh') return Promise.resolve(Response.json(false));
    if (rpc === 'rpc/course_lifecycle_maintenance') {
      equal(JSON.parse(String(init?.body)), {p_limit:500});
      const purged = Math.min(rooms,500); rooms -= purged;
      return Promise.resolve(Response.json(options.maintenanceResult ?? {closed:0,purged}, {status: options.maintenanceStatus ?? 200}));
    }
    if (rpc === 'rpc/course_media_cleanup_batch') {
      equal(JSON.parse(String(init?.body)), {p_limit:100});
      return Promise.resolve(Response.json(Array.isArray(queue) && queue.every(p => typeof p === 'string' && /^00000000-/.test(p)) ? queue.slice(0,100) : queue, {status: options.queueStatus ?? 200}));
    }
    if (rpc === 'rpc/social_media_cleanup_complete') {
      const paths = JSON.parse(String(init?.body)).p_paths;
      acknowledged.push(paths);
      // The queue changes only after a successful DB acknowledgement.
      if ((options.ackStatus ?? 200) === 200 && Array.isArray(queue)) queue = queue.filter(p => !paths.includes(p));
      return Promise.resolve(Response.json(null,{status:options.ackStatus ?? 200}));
    }
    throw new Error(`Unexpected RPC ${rpc}`);
  };
  const fetcher: typeof fetch = (input, init) => {
    calls.push('storage');
    equal(input, storage.origin + '/storage/v1/object/social-media');
    equal(init?.method, 'DELETE');
    const headers = new Headers(init?.headers);
    equal(headers.get('apikey'), storage.serviceKey);
    equal(headers.get('Authorization'),'Bearer ' + storage.serviceKey);
    assert(init?.signal instanceof AbortSignal);
    const paths = JSON.parse(String(init?.body)).prefixes;
    assert(Array.isArray(paths) && paths.length <= 100);
    deleted.push(paths);
    if (options.throwStorage) return Promise.reject(new Error('Network failed'));
    return Promise.resolve(new Response(options.storageStatus === 204 ? null : '[]',{status:options.storageStatus ?? 200}));
  };
  return {db, fetcher, calls, deleted, acknowledged, remainingRooms:()=>rooms, queue:()=>queue};
}
Deno.test('empty queues and a false calendar claim perform no outbound fetch or ACK', async () => {
  const test = harness();
  await maintainCourseChats(test.db,{fetcher:test.fetcher,storage});
  equal(test.calls,['rpc/claim_course_calendar_refresh','rpc/course_lifecycle_maintenance','rpc/course_media_cleanup_batch']);
  equal(test.deleted,[]); equal(test.acknowledged,[]);
});
Deno.test('purge and media batches are bounded to five each and retain overflow', async () => {
  const test = harness({rooms:3001,paths:Array.from({length:601},(_,i)=>path(i))});
  await maintainCourseChats(test.db,{fetcher:test.fetcher,storage});
  equal(test.calls.filter(c=>c==='rpc/course_lifecycle_maintenance').length,5);
  equal(test.remainingRooms(),501);
  equal(test.calls.filter(c=>c==='rpc/course_media_cleanup_batch').length,5);
  equal(test.deleted.length,5); equal(test.acknowledged.length,5);
  assert(test.deleted.every(paths=>paths.length===100));
  equal((test.queue() as unknown[]).length,101);
});
Deno.test('partial batches stop after remaining rooms and successful storage deletion', async () => {
  const test = harness({rooms:501,paths:[path(1),path(2)]});
  await maintainCourseChats(test.db,{fetcher:test.fetcher,storage});
  equal(test.remainingRooms(),0);
  equal(test.calls,['rpc/claim_course_calendar_refresh','rpc/course_lifecycle_maintenance','rpc/course_lifecycle_maintenance','rpc/course_media_cleanup_batch','storage','rpc/social_media_cleanup_complete']);
  equal(test.deleted,[[path(1),path(2)]]);
  equal(test.acknowledged,test.deleted);equal(test.queue(),[]);
});
Deno.test('only completed HTTP 200 storage deletes may acknowledge queued paths', async () => {
  for (const status of [202,204,400,403,404,429,500,503]) {
    const test = harness({paths:[path(1)],storageStatus:status});
    await rejects(()=>maintainCourseChats(test.db,{fetcher:test.fetcher,storage}),'Course media cleanup pending');
    equal(test.deleted,[[path(1)]]);equal(test.acknowledged,[]);equal(test.queue(),[path(1)]);
  }
});
Deno.test('network failure retains queued paths, never acknowledges, and bubbles to worker', async () => {
  const test = harness({paths:[path(1)],throwStorage:true});
  await rejects(()=>maintainCourseChats(test.db,{fetcher:test.fetcher,storage}),'Network failed');
  equal(test.acknowledged,[]);equal(test.queue(),[path(1)]);
});
Deno.test('failed ACK after successful deletion retains queue for safe idempotent retry', async () => {
  const test = harness({paths:[path(1)],ackStatus:503});
  await rejects(()=>maintainCourseChats(test.db,{fetcher:test.fetcher,storage}),'Course media acknowledgement pending');
  equal(test.deleted,[[path(1)]]);equal(test.queue(),[path(1)]);
  const retry = harness({paths:test.queue()});
  await maintainCourseChats(retry.db,{fetcher:retry.fetcher,storage});
  equal(retry.deleted,[[path(1)]]);equal(retry.acknowledged,[[path(1)]]);equal(retry.queue(),[]);
});
Deno.test('invalid object paths cause no outbound request and no acknowledgement', async () => {
  for (const invalid of ['', '../elsewhere.png', '/other-bucket/a.png', 'folder/../../a.png', 'https://static.klipy.com/external.gif', path(1)+'?query=1', 'folder\\a.png', '%2e%2e%2fsecret.png', null, 1]) {
    const test = harness({paths:[path(1),invalid]});
    await rejects(()=>maintainCourseChats(test.db,{fetcher:test.fetcher,storage}),'Invalid cleanup batch');
    equal(test.deleted,[]);equal(test.acknowledged,[]);equal(test.queue(),[path(1),invalid]);
  }
});
Deno.test('malformed or overlarge cleanup batches fail closed', async () => {
  for (const invalid of [{paths:[path(1)]},'not an array',[...Array(100).fill(path(1)), '../invalid']]) {
    const test = harness({paths:invalid});
    await rejects(()=>maintainCourseChats(test.db,{fetcher:test.fetcher,storage}),'Invalid cleanup batch');
    equal(test.deleted,[]);equal(test.acknowledged,[]);
  }
});
Deno.test('RPC errors and malformed purge counts stop before storage', async () => {
  const badHTTP = harness({maintenanceStatus:503});
  await rejects(()=>maintainCourseChats(badHTTP.db,{fetcher:badHTTP.fetcher,storage}),'Course maintenance pending');
  equal(badHTTP.deleted,[]);
  for (const result of [{error:'failure'},{purged:-1},{purged:501},{purged:1.5},{purged:'500'}]) {
    const test = harness({maintenanceResult:result});
    await rejects(()=>maintainCourseChats(test.db,{fetcher:test.fetcher,storage}),'Invalid course maintenance result');
    equal(test.deleted,[]);equal(test.acknowledged,[]);
  }
  const queueHTTP = harness({queueStatus:503});
  await rejects(()=>maintainCourseChats(queueHTTP.db,{fetcher:queueHTTP.fetcher,storage}),'Course media cleanup pending');
  equal(queueHTTP.deleted,[]);equal(queueHTTP.acknowledged,[]);
});

Deno.test('generated private MP4 paths delete and acknowledge with image paths', async () => {
  const video=path(7).replace(/\.png$/,'.mp4').replace(/\.jpg$/,'.mp4');
  const test=harness({paths:[path(1),video]});
  await maintainCourseChats(test.db,{fetcher:test.fetcher,storage});
  equal(test.deleted,[[path(1),video]]);equal(test.acknowledged,test.deleted);equal(test.queue(),[]);
});
