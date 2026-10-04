import {socialHash,SocialAuthError,authFailure} from '../_shared/social-auth.ts';
import {fetchSports} from './provider.ts';
const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const reply=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
async function rpc(action:string,hash:string,input:Record<string,unknown>={}){
 const r=await fetch(base+'/rest/v1/rpc/sports_cache',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(10000)});
 const v=await r.json();if(!r.ok){const code=String(v.message??'').split(':')[0];throw new SocialAuthError(code==='unauthorized'?'Sign in again to view scores.':'Sports scores are temporarily unavailable.',code,code==='unauthorized'?401:code==='forbidden'?403:code==='rate_limit'?429:503)}return v;
}
Deno.serve(async request=>{
 if(request.method!=='POST')return reply({error:'Use POST.'},405);
 try{
  const hash=await socialHash(request);
  const cached=await rpc('read',hash);
  if(cached.fresh&&cached.payload)return reply(cached.payload);
  const {lease}=await rpc('claim',hash);
  if(lease){try{const payload=await fetchSports();const saved=await rpc('publish',hash,{lease,payload});if(saved.published)return reply(payload)}catch{/* retain the last factual snapshot on provider outage */}}
  if(cached.payload)return reply({...cached.payload,warnings:[...(cached.payload.warnings??[]),'Showing the last saved official results.']});
  return reply({error:'Official scores are unavailable right now. Try again shortly.',code:'unavailable'},503);
 }catch(error){return error instanceof SocialAuthError?reply(authFailure(error),error.status):reply({error:'Couldn’t load sports scores.',code:'unavailable'},503)}
});
