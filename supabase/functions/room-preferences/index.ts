import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
const respond = (value: unknown, status = 200) => new Response(JSON.stringify(value), {status, headers: {'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async request => {
 if(request.method !== 'POST') return respond({error:'Use POST.'},405);
 try {
  const raw=await request.text(); if(raw.length>2048)return respond({error:'Request too large.'},413);
  const input=JSON.parse(raw); if(!input || typeof input!=='object'||Array.isArray(input)||!['get','set'].includes(input.action))return respond({error:'Invalid notification preference.'},400);
  const hash=await socialHash(request);const {action,...payload}=input;
  const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const response=await fetch(Deno.env.get('SUPABASE_URL')+'/rest/v1/rpc/room_preferences',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:payload}),signal:AbortSignal.timeout(15000)});
  if(!response.ok)return respond({error:'Notification preferences are temporarily unavailable.'},503);
  const value=await response.json();return respond(value,value.error?(value.code==='forbidden'?403:value.code==='unauthorized'?401:400):200);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Notification preferences could not be loaded.'},503)}
});
