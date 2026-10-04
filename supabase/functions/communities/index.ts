import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
import { wakePushWorker } from '../_shared/push-wake.ts';
const base = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const allowed = new Set(['list','detail','create','join','join_code','leave','report','update','close','remove','ban','unban','transfer','rotate_code','invite','accept','decline','profile','revoke']);
const respond = (data: unknown,status=200) => new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async request => {
 if(request.method!=='POST')return respond({error:'Use POST.'},405);
 try {
  const raw=await request.text();if(raw.length>8192)return respond({error:'Request too large.'},413);
  let input;try{input=JSON.parse(raw);if(!input||typeof input!=='object'||Array.isArray(input))throw new Error();}catch{return respond({error:'Invalid request.'},400)}
  const {action,...payload}=input;if(!allowed.has(action))return respond({error:'Unknown community action.'},400);
  const hash=await socialHash(request);
  const result=await fetch(base+'/rest/v1/rpc/communities_gateway',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:payload}),signal:AbortSignal.timeout(15000)});
  if(!result.ok)return respond({error:'Communities are temporarily unavailable.'},503);
  const data=await result.json();
  if(data.error)return respond(data,data.code==='unauthorized'?401:['forbidden','verification_required'].includes(data.code)?403:data.code==='rate_limit'?429:400);
  if(action==='invite')wakePushWorker();
  return respond(data);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Couldn’t reach communities. Please try again.'},503)}
});
