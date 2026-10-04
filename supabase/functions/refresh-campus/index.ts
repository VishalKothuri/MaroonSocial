import { cleanupDeletedAuthUsers } from '../_shared/social-auth-cleanup.ts';
import { maintainCourseChats } from '../_shared/course-retention.ts';
declare const EdgeRuntime: { waitUntil(task: Promise<unknown>): void };
// Public university facts only; writes use the function's server-side credential.
const feeds = [
  ['Campus', 'https://calendar.tamu.edu/live/json/events/group/*%20Main%20University%20Calendar'],
  ['Rec', 'https://calendar.tamu.edu/live/json/events/group/Rec%20Sports'],
  ['Sports', 'https://calendar.tamu.edu/live/json/events/group/Aggie%20Athletics'],
];
const clean = (value: unknown) => String(value ?? '').replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/&nbsp;/g, ' ').replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim();
const feedFlag = (value: unknown) => value === true || value === 1 || value === '1' || value === 'true';
const cancelledTitle = (title: string) => /(?:^\s*cancel(?:l)?ed(?:\s*[:–—-]|\s*$)|[\[(]\s*cancel(?:l)?ed\s*[\])]|[–—-]\s*cancel(?:l)?ed\s*$)/i.test(title);
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('Use POST', {status:405});
  const origin = Deno.env.get('SUPABASE_URL')!;
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const headers = {'apikey':secret,'Authorization':`Bearer ${secret}`,'Content-Type':'application/json'};
  const db = async (path: string, init: RequestInit = {}) => {
    const response = await fetch(`${origin}/rest/v1/${path}`, {...init,headers:{...headers,...init.headers},signal:AbortSignal.timeout(15000)});
    if (!response.ok) throw new Error(`Cache operation failed: ${response.status}`);
    return response;
  };
  try {
    const claimed = await (await db('rpc/claim_campus_refresh',{method:'POST',body:'{}'})).json();
    if (!claimed) return Response.json({status:'cached',message:'Refresh is limited to once per 55 minutes.'});
    EdgeRuntime.waitUntil(cleanupDeletedAuthUsers(20).catch(() => console.error('auth_cleanup_retry_pending')));
    EdgeRuntime.waitUntil(maintainCourseChats(db).catch(() => console.error('course_retention_retry_pending')));
    const now = Date.now()/1000;
    const read = async (url:string) => {const r=await fetch(url,{signal:AbortSignal.timeout(20000)});if(!r.ok)throw new Error(`Source failed: ${r.status}`);return await r.json();};
    const previousRows=await (await db('campus_cache?id=eq.current&select=payload')).json();
    const previous=previousRows[0]?.payload;
    const events=new Map<string,unknown>();
    const warnings:string[]=[];
    for(const [category,url] of feeds){
      try {
        const rows=await read(url);
        if(!Array.isArray(rows))throw new Error('Unexpected calendar format');
        for(const row of rows){
          const starts=Number(row.date_ts);
          if(!Number.isFinite(starts)||starts<now-86400||starts>now+31*86400)continue;
          const id=`${row.id}-${starts}`;
          const title=clean(row.title);
          const event:Record<string,unknown>={id,title,category,starts,allDay:feedFlag(row.is_all_day),location:clean(row.location_title||row.location),details:clean(row.description).slice(0,1200),url:row.url,source:url,fetchedAt:now,cancelled:feedFlag(row.is_canceled)||feedFlag(row.is_cancelled)||cancelledTitle(title)};
          if(row.date2_ts)event.ends=Number(row.date2_ts);
          if(typeof row.thumbnailURL==='string' && row.thumbnailURL.startsWith('https://'))event.imageURL=row.thumbnailURL;
          events.set(id,event);
        }
      }catch{warnings.push(category);for(const event of previous?.events??[]){if(event.category===category&&event.starts>=now-86400&&event.starts<=now+31*86400)events.set(event.id,event);}}
    }
    let routes=previous?.routes??[],stops=previous?.stops??[];
    let transitFetchedAt=previous?.transitFetchedAt??previous?.fetchedAt??now;
    try{routes=(await read('https://aggiespirit.ts.tamu.edu/News/GetRoutes')).map((r:Record<string,string>)=>({id:r.routeNumber,name:r.routeName,color:'500000',stops:[]}));}catch{warnings.push('Routes');}
    try{const mapped=(await read('https://aggiespirit.ts.tamu.edu/Home/GetAllBusStops')).map((s:Record<string,unknown>)=>[s.stopCode,{id:s.stopCode,name:s.stopName,latitude:s.latitude,longitude:s.longitude}]);stops=[...new Map(mapped).values()];}catch{warnings.push('Stops');}
    if(warnings.length===5)throw new Error('All sources unavailable; existing cache preserved');
    if(!warnings.includes('Routes')&&!warnings.includes('Stops'))transitFetchedAt=now;
    const payload={transitFetchedAt,events:[...events.values()].sort((a:any,b:any)=>a.starts-b.starts),routes,stops,fetchedAt:now,warnings};
    await db('campus_cache?on_conflict=id',{method:'POST',headers:{Prefer:'resolution=merge-duplicates'},body:JSON.stringify({id:'current',payload,refreshed_at:new Date().toISOString()})});
    return Response.json({status:'refreshed',events:events.size,routes:routes.length,stops:stops.length,warnings});
  }catch(error){console.error(error instanceof Error?error.message:'Campus refresh failed');return Response.json({error:'Campus refresh failed; last snapshot preserved'},{status:502});}
});
