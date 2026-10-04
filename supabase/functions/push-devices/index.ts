import {socialIdentity,SocialAuthError,authFailure,sha256} from '../_shared/social-auth.ts';
import {providerConfigured,providerEnvironments} from '../_shared/apns.ts';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async request=>{
 if(request.method!=='POST')return respond({error:'Use POST.'},405);
 try{
  const raw=await request.text();if(raw.length>8192)return respond({error:'Request too large.'},413);
  const body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))return respond({error:'Invalid request.'},400);
  const {action,...input}=body;if(!['status','register','unregister','preferences.set','resolve','inbox','read'].includes(action))return respond({error:'Unknown notification action.'},400);
  let hash:null|string=null;delete input.auth_session;delete input.secret_hash;delete input.network_hash;
  if(action!=='unregister'){const identity=await socialIdentity(request);hash=identity.hash;input.auth_session=identity.auth?.sessionID??null;}
  if(action==='unregister')input.network_hash=await sha256(secret+':push-unlink:'+(request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()??'unknown'));
  if(action==='register'||action==='unregister'){
   if(typeof input.installation_secret!=='string'||!/^[a-f0-9]{64}$/.test(input.installation_secret))return respond({error:'This installation could not be verified.',code:'invalid'},400);
   input.secret_hash=await sha256(input.installation_secret);delete input.installation_secret;
  }
  const response=await fetch(base+'/rest/v1/rpc/push_devices',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(12000)});
  if(!response.ok)return respond({error:'Notifications are temporarily unavailable.',code:'unavailable'},503);
  const result=await response.json();if(result.error)return respond(result,result.code==='unauthorized'?401:result.code==='forbidden'?403:400);
  return respond({...result,delivery_configured:providerConfigured()&&Boolean(Deno.env.get('PUSH_WORKER_SECRET'))&&providerEnvironments().includes(input.environment)});
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Could not update notifications.',code:'unavailable'},503)}
});
