import { wakePushWorker } from '../_shared/push-wake.ts';
import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
import { callIceServers, callTransport, admitRelay } from '../_shared/call-relay.ts';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async req=>{
 if(req.method!=='POST')return respond({error:'Use POST.'},405);
 try{
  const raw=await req.text();if(raw.length>32768)return respond({error:'Request too large.'},413);
  const body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))return respond({error:'Invalid request.'},400);
  const {action,...input}=body;if(!['invite','accept','end','decline','poll','signal','media'].includes(action))return respond({error:'Unknown call action.'},400);
  const hash=await socialHash(req);input.transport=callTransport();
  const response=await fetch(base+'/rest/v1/rpc/group_call_gateway',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(12000)});
  if(!response.ok)return respond({error:'Group calling is temporarily unavailable.',code:'unavailable'},503);
  const result=await response.json();if(result.error)return respond(result,result.code==='unauthorized'?401:['forbidden','verification_required'].includes(result.code)?403:result.code==='rate_limit'?429:400);
  if(action==='media'){
   if(!result.call?.joined)return respond({error:'Join this call before starting media.',code:'consent'},400);
   try{result.ice_servers=await callIceServers(result.call.transport,result.call.transport==='relay'?await admitRelay(hash,'group',result.call.id):1200);}catch{return respond({error:'The relay is unavailable. Please retry later.',code:'media_unavailable'},503)}
  }
  if(action==='invite')wakePushWorker();
  return respond(result);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Couldn’t reach group calling. Please retry.',code:'unavailable'},503)}
});
