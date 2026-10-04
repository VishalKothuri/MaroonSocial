import { wakePushWorker } from '../_shared/push-wake.ts';
import { callIceServers, admitRelay, callTransport } from '../_shared/call-relay.ts';
import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const turnID=Deno.env.get('TURN_KEY_ID'),turnToken=Deno.env.get('TURN_API_TOKEN');
const transport=callTransport();
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
const hash=async(v:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v)))).map(x=>x.toString(16).padStart(2,'0')).join('');
Deno.serve(async req=>{
 if(req.method!=='POST')return respond({error:'Use POST.'},405);
 try{
  const raw=await req.text();if(raw.length>32768)return respond({error:'Request too large.'},413);
  const {action,...input}=JSON.parse(raw);
  if(!['capabilities','invite','accept','decline','end','poll','signal','media'].includes(action))return respond({error:'Unknown call action.'},400);
  const memberHash=await socialHash(req);
  input.transport=transport;
  const response=await fetch(base+'/rest/v1/rpc/social_call_gateway',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action==='capabilities'?'poll':action,p_hash:memberHash,p_input:input}),signal:AbortSignal.timeout(12000)});
  if(!response.ok)return respond({error:'Calls are temporarily unavailable.',code:'unavailable'},503);
  const result=await response.json();if(result.error)return respond(result,result.code==='unauthorized'?401:result.code==='forbidden'?403:result.code==='rate_limit'?429:400);
  result.transport=transport;
  if(action==='media'){
   if(result.call?.state!=='connected')return respond({error:'This call has ended.',code:'ended'},400);
   if(result.call.transport==='direct'){
    if(input.allow_direct!==true)return respond({error:'Direct calls require your consent.',code:'consent'},400);
    result.ice_servers=[{urls:['stun:stun.l.google.com:19302']}];
   }else{
    if(!turnID||!turnToken)return respond({error:'The relay is unavailable. Please retry later.',code:'media_unavailable'},503);
    try{result.ice_servers=await callIceServers('relay',await admitRelay(memberHash,'dm',result.call.id));}catch{return respond({error:'The relay is unavailable. Please retry later.',code:'media_unavailable'},503)}
   }
  }
  if(action==='invite')wakePushWorker();
  return respond(result);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Could not reach calling. Please try again.',code:'unavailable'},503)}
});
