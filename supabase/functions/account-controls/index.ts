import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
// Device credential authentication; only caller-owned account controls are exposed.
const base = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const allowed = new Set(['connections','connection.request','connection.accept','connection.remove','blocks','block.remove','export']);
const response=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async request=>{
 if(request.method!=='POST')return response({error:'Use POST.'},405);
 let input:Record<string,unknown>;
 try{const raw=await request.text();if(raw.length>8192)return response({error:'Request too large.'},413);input=JSON.parse(raw);if(!input||typeof input!=='object'||Array.isArray(input))throw new Error();}catch{return response({error:'Invalid request.'},400)}
 const {action,...payload}=input;
 if(typeof action!=='string'||!allowed.has(action))return response({error:'Unknown account control.'},400);
 try{
  const hash=await socialHash(request);
  const result=await fetch(base+'/rest/v1/rpc/account_controls',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:payload}),signal:AbortSignal.timeout(15000)});
  const data=await result.json();
  if(!result.ok){const message=String(data.message??'');const colon=message.indexOf(':');const code=message.slice(0,colon);if(['invalid','unavailable','unauthorized','forbidden','rate_limit','verification_required'].includes(code))return response({error:message.slice(colon+1),code},code==='unauthorized'?401:['forbidden','verification_required'].includes(code)?403:code==='rate_limit'?429:400);return response({error:'Account controls are temporarily unavailable.'},503)}
  return response(data);
 }catch(error){if(error instanceof SocialAuthError)return response(authFailure(error),error.status);return response({error:'Couldn’t reach account controls. Try again.'},503)}
});
