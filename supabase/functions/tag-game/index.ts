import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
// Existing social credentials authenticate every Tag action. No coordinate logging.
const base = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const headers = {'Content-Type':'application/json','Cache-Control':'no-store'};
const respond=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers});
Deno.serve(async request=>{
 if(request.method!=='POST')return respond({error:'Use POST.'},405);
 let input:Record<string,unknown>;
 try{
  if(Number(request.headers.get('content-length')??0)>8192)return respond({error:'Request too large.'},413);
  const body=await request.text(); if(body.length>8192)return respond({error:'Request too large.'},413);
  input=JSON.parse(body);if(!input||typeof input!=='object'||Array.isArray(input))throw new Error();
 }catch{return respond({error:'Invalid Tag request.'},400)}
 const {action,...payload}=input;
 try{
  const hash=await socialHash(request);
  const result=await fetch(base+'/rest/v1/rpc/tag_gateway',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:payload}),signal:AbortSignal.timeout(12000)});
  const value=await result.json();
  if(!result.ok){
   const message=String(value.message??'');
   if(message.startsWith('unauthorized:'))return respond({error:'Your session expired. Sign in again.','code':'unauthorized'},401);
   if(message.startsWith('forbidden:'))return respond({error:'This account cannot play Tag.','code':'forbidden'},403);
   if(message.startsWith('rate_limit:'))return respond({error:'A little too fast. Try again in a minute.','code':'rate_limit'},429);
   return respond({error:'Tag is temporarily unavailable. Please try again.'},503);
  }
  if(!value.error&&(action==='block'||action==='report')){
   try{await fetch(base+'/rest/v1/rpc/account_controls',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:'block.tag_context',p_hash:hash,p_input:payload}),signal:AbortSignal.timeout(3000)})}catch{}
  }
  return respond(value,value.error?(value.code==='rate_limit'?429:400):200);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Couldn’t reach Tag. Please try again.'},503)}
});
