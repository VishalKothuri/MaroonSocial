// Immediate best effort for timely call/message alerts; cron handles retries.
declare const EdgeRuntime: {waitUntil(promise:Promise<unknown>):void}|undefined;
export function wakePushWorker(){
 const secret=Deno.env.get('PUSH_WORKER_SECRET'),base=Deno.env.get('SUPABASE_URL');
 if(!secret||!base)return;
 const task=fetch(base+'/functions/v1/push-delivery',{method:'POST',headers:{'Content-Type':'application/json','x-worker-secret':secret},body:'{}',signal:AbortSignal.timeout(50000)}).then(response=>response.body?.cancel()).catch(()=>{});
 if(typeof EdgeRuntime!=='undefined')EdgeRuntime.waitUntil(task);
}
