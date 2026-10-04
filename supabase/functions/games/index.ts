import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
import { wakePushWorker } from '../_shared/push-wake.ts';
import { initialState, resolveTurn, RULES_VERSION } from './engine.js';
const base=Deno.env.get('SUPABASE_URL')!;
const secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const headers={apikey:secret,Authorization:`Bearer ${secret}`,'Content-Type':'application/json'};
class GameError extends Error{constructor(message:string,public code='invalid'){super(message)}}
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
async function rpc(action:string,hash:string,input:unknown){
 const res=await fetch(base+'/rest/v1/rpc/'+(action.startsWith('match.')?'games_matchmaking':'games_gateway'),{method:'POST',headers,body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(12000)});
 if(!res.ok)throw new GameError('The game service is temporarily unavailable. Retry your turn.','unavailable');
 const value=await res.json();if(value.error)throw new GameError(value.error,value.code);
 if(['invite','accept','commit','match.join'].includes(action))wakePushWorker();
 return value;
}
Deno.serve(async request=>{
 if(request.method!=='POST')return reply({error:'Use POST.'},405);
 try{
  const raw=await request.text();if(raw.length>4096)throw new GameError('Game request too large.');
  const body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))throw new GameError('Invalid game request.');
  const hash=await socialHash(request);
  const action=body.action;
  if(!['invite','get','list','card','accept','decline','cancel','forfeit','turn','match.join','match.status','match.cancel'].includes(action))throw new GameError('Unknown game action.');
  if(action.startsWith('match.')){
   const state=initialState(body.kind);
   return reply(await rpc(action,hash,{kind:body.kind,nonce:body.nonce,rules:RULES_VERSION,state}));
  }
  if(action==='invite'){
   const state=initialState(body.kind);
   return reply(await rpc('invite',hash,{room:body.room,kind:body.kind,nonce:body.nonce,opponent_member_key:body.opponent_member_key,rules:RULES_VERSION,state}));
  }
  if(action==='turn'){
   if(!Number.isSafeInteger(body.version)||body.version<0||!body.input||typeof body.input!=='object')throw new GameError('Invalid turn.');
   const payload={id:body.id,nonce:body.nonce,version:body.version,input:body.input};
   const read=await rpc('prepare',hash,payload);if(read.duplicate)return reply(read);
   const outcome=resolveTurn(read.game.kind,read.game.state,body.input);
   return reply(await rpc('commit',hash,{...payload,...outcome}));
  }
  return reply(await rpc(action,hash,{id:body.id}));
 }catch(error){if(error instanceof SocialAuthError)return reply(authFailure(error),error.status);const code=error instanceof GameError?error.code:'invalid';const message=error instanceof Error?error.message:'Invalid game request.';return reply({error:message,code},code==='unauthorized'?401:code==='forbidden'?403:code==='rate_limit'?429:code==='unavailable'?503:400)}
});
