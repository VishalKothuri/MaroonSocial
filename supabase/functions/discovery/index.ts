import {randomMemberHash,webOrigin,webHeaders} from '../_shared/random-web.ts';
import {SocialAuthError,authFailure} from '../_shared/social-auth.ts';
import {callTransport,callIceServers,admitRelay} from '../_shared/call-relay.ts';
import {wakePushWorker} from '../_shared/push-wake.ts';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
Deno.serve(async request=>{
 let origin:string|null=null;const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:webHeaders(origin)});
 try{
  origin=webOrigin(request);if(request.method==='OPTIONS')return new Response(null,{status:204,headers:webHeaders(origin)});
  if(request.method!=='POST')return respond({error:'Use POST.'},405);
  const raw=await request.text();if(raw.length>32768)return respond({error:'Request too large.'},413);
  const body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))return respond({error:'Invalid request.'},400);
  const {action,...input}=body;if(!['profile','enter','heartbeat','list','request','accept','decline','cancel','leave','ack','send','signal','media','continue','block','report'].includes(action))return respond({error:'Unknown discovery action.'},400);
  const hash=await randomMemberHash(request);input.transport=callTransport();
  const response=await fetch(base+'/rest/v1/rpc/discovery_gateway',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(12000)});
  if(!response.ok)return respond({error:'Discovery is temporarily unavailable.',code:'unavailable'},503);
  const result=await response.json();if(result.error)return respond(result,result.code==='unauthorized'?401:['forbidden','verification_required'].includes(result.code)?403:result.code==='rate_limit'?429:400);
  if(action==='media'){
   if(result.state!=='connected'||!result.session?.room)return respond({error:'Both people must confirm before connecting.',code:'consent'},400);
   result.ice_servers=await callIceServers(result.media_transport,result.media_transport==='relay'?await admitRelay(hash,'random',result.session.room):1200);
  }
  if(action==='continue')wakePushWorker();
  return respond(result);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Could not reach discovery. Please retry.',code:'unavailable'},503)}
});
