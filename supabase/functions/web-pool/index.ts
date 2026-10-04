import {socialIdentity,sha256,SocialAuthError,authFailure} from '../_shared/social-auth.ts';
import {wakePushWorker} from '../_shared/push-wake.ts';
import {initialState,resolveTurn} from './engine.js';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const origins=new Set(['https://maroon-social-games.vercel.app','https://games.maroonsocial.chat','http://localhost:4173','http://127.0.0.1:4173']);
const statuses:Record<string,number>={unauthorized:401,verification_required:403,forbidden:403,not_found:404,invalid:400,conflict:409,rate_limit:429,turn:409};
async function rpc(name:string,input:Record<string,unknown>){
 const r=await fetch(base+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify(input),signal:AbortSignal.timeout(12000)});
 const v=await r.json();if(!r.ok||v.error){const raw=String(v.error??v.message??'');const code=String(v.code??raw.split(':')[0]);throw new SocialAuthError(statuses[code]?(v.error??raw.slice(raw.indexOf(':')+1)):'Pool is temporarily unavailable.',statuses[code]?code:'unavailable',statuses[code]??503)}return v;
}
Deno.serve(async request=>{
 const origin=request.headers.get('Origin');const cors:Record<string,string>={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin'};
 const reply=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:cors});
 if(origin&&!origins.has(origin))return reply({error:'This website cannot access pool.',code:'forbidden'},403);
 if(origin){cors['Access-Control-Allow-Origin']=origin;cors['Access-Control-Allow-Headers']='Content-Type,X-Maroon-Pool-Session';cors['Access-Control-Allow-Methods']='POST,OPTIONS'}
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
 if(request.method!=='POST')return reply({error:'Use POST.'},405);
 try{
  const raw=await request.text();if(raw.length>12000)throw new SocialAuthError('This request is too large.','invalid',400);
  let body;try{body=JSON.parse(raw)}catch{throw new SocialAuthError('Invalid request.','invalid',400)}
  const action=body.action;
  if(action==='close'){
   const token=request.headers.get('X-Maroon-Pool-Session')??'';
   if(!/^[a-f0-9]{64}$/.test(token))throw new SocialAuthError('Invalid pool session.','invalid',400);
   return reply(await rpc('web_pool_close',{p_scope_hash:await sha256(token)}));
  }
  if(['session','revoke'].includes(action)){
   // Native-only full identity path. Website CORS never permits social headers.
   if(origin)throw new SocialAuthError('Open pool from the app.','forbidden',403);
   const identity=await socialIdentity(request);
   if(action==='revoke'){const token=String(body.token??'');if(!/^[a-f0-9]{64}$/.test(token))throw new SocialAuthError('Invalid pool session.','invalid',400);return reply(await rpc('web_pool_session',{p_hash:identity.hash,p_scope_hash:await sha256(token),p_action:'revoke'}))}
   const token=Array.from(crypto.getRandomValues(new Uint8Array(32))).map(x=>x.toString(16).padStart(2,'0')).join('');
   const value=await rpc('web_pool_session',{p_hash:identity.hash,p_scope_hash:await sha256(token),p_action:'create',p_auth_id:identity.auth?.userID??null,p_auth_session:identity.auth?.sessionID??null});
   return reply({...value,token,endpoint:base+'/functions/v1/web-pool',rules:'maroon-web-pool-3.0.0'});
  }
  if(!origin&&!request.headers.has('X-Maroon-Pool-Session')){
   if(!['list','invite','card','get','accept','decline','cancel','rematch','forfeit'].includes(action))throw new SocialAuthError('Unknown pool action.','invalid',400);
   const identity=await socialIdentity(request);const input:Record<string,unknown>={};
   for(const key of ['id','room','nonce','opponent_member_key'])if(body[key]!==undefined)input[key]=body[key];
   if(action==='invite'&&body.kind!=='pool')throw new SocialAuthError('This table supports pool.','invalid',400);
   if(['invite','rematch'].includes(action))input.state=initialState();
   const value=await rpc('web_pool_social',{p_action:action==='cancel'?'cancel_invite':action,p_hash:identity.hash,p_input:input});
   if(['invite','rematch','accept'].includes(action))wakePushWorker();return reply(value);
  }
  const token=request.headers.get('X-Maroon-Pool-Session')??'';
  if(!/^[a-f0-9]{64}$/.test(token))throw new SocialAuthError('Open pool in Maroon Social to play an opponent.');
  if(!['active','join','poll_queue','cancel','get','turn','forfeit','accept','decline','cancel_invite','rematch'].includes(action))throw new SocialAuthError('Unknown pool action.','invalid',400);
  const hash=await sha256(token);const input:Record<string,unknown>={};
  for(const key of ['id','nonce','version'])if(body[key]!==undefined)input[key]=body[key];
  if(['join','poll_queue','rematch'].includes(action))input.state=initialState();
  if(action==='turn'){
   input.input=body.input;
   const prepared=await rpc('web_pool_gateway',{p_action:'prepare',p_scope_hash:hash,p_input:input});
   if(prepared.duplicate)return reply(prepared);
   let resolved;try{resolved=resolveTurn(prepared.game.state,body.input)}catch(error){throw new SocialAuthError(error instanceof Error?error.message:'Choose a valid shot.','invalid',400)}
   const committed=await rpc('web_pool_gateway',{p_action:'commit',p_scope_hash:hash,p_input:{...input,...resolved}});wakePushWorker();return reply(committed);
  }
  const value=await rpc('web_pool_gateway',{p_action:action,p_scope_hash:hash,p_input:input});if(['rematch','accept'].includes(action)||(['join','poll_queue'].includes(action)&&value.game))wakePushWorker();return reply(value);
 }catch(error){return error instanceof SocialAuthError?reply(authFailure(error),error.status):reply({error:'Pool is temporarily unavailable. Try again.','code':'unavailable'},503)}
});
