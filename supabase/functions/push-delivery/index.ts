import {APNSProvider,providerConfigured,providerEnvironments,PushDelivery} from '../_shared/apns.ts';
import {sha256} from '../_shared/social-auth.ts';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
let provider:APNSProvider|undefined;
async function rpc(action:string,input:Record<string,unknown>){const response=await fetch(base+'/rest/v1/rpc/push_delivery',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_input:input}),signal:AbortSignal.timeout(12000)});if(!response.ok)throw Error('Queue unavailable');return await response.json();}
Deno.serve(async request=>{
 if(request.method!=='POST')return respond({error:'Use POST.'},405);
 const configured=Deno.env.get('PUSH_WORKER_SECRET'),supplied=request.headers.get('x-worker-secret')??'';
 if(!configured||supplied.length>512||await sha256(supplied)!==await sha256(configured))return respond({error:'Unauthorized.'},401);
 if(!providerConfigured())return respond({configured:false,delivered:0},503);
 try{
  // APNs requires HTTP/2; failure to create an HTTP/2-only client stops delivery.
  if(!provider){const client=Deno.createHttpClient({http1:false,http2:true});const transport:typeof fetch=(input,init)=>fetch(input,{...init,client});provider=new APNSProvider({teamID:Deno.env.get('APNS_TEAM_ID')!,keyID:Deno.env.get('APNS_KEY_ID')!,privateKey:Deno.env.get('APNS_PRIVATE_KEY')!,topic:Deno.env.get('APNS_TOPIC')!,environments:providerEnvironments()},transport);}
  const items:PushDelivery[]=(await rpc('take',{limit:25,environments:providerEnvironments()})).items;let delivered=0;
  for(const item of items){let result:{status:number;reason?:string};try{result=await provider.send(item);}catch{result={status:503,reason:'TransportError'}}await rpc('complete',{job:item.job,device:item.device,lease:item.lease,...result});if(result.status===200)delivered++;}
  return respond({configured:true,processed:items.length,delivered});
 }catch{return respond({error:'Notification delivery is temporarily unavailable.'},503)}
});
