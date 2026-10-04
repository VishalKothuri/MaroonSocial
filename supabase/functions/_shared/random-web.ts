import {socialHash,sha256,SocialAuthError} from './social-auth.ts';
const base=()=>Deno.env.get('SUPABASE_URL')!,secret=()=>Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
export function webOrigin(request:Request){
 const origin=request.headers.get('Origin');if(!origin)return null;
 const allowed=new Set(['https://maroonsocial.chat','https://www.maroonsocial.chat',...(Deno.env.get('RANDOM_WEB_ORIGINS')??'').split(',').map(x=>x.trim()).filter(Boolean)]);
 if(!allowed.has(origin))throw new SocialAuthError('This browser origin is not enabled.','forbidden',403);return origin;
}
export function webHeaders(origin:string|null){return{'Content-Type':'application/json','Cache-Control':'no-store',...(origin?{'Access-Control-Allow-Origin':origin,'Vary':'Origin','Access-Control-Allow-Headers':'content-type, apikey, x-maroon-web-session','Access-Control-Allow-Methods':'POST, OPTIONS','Access-Control-Max-Age':'600'}:{})};}
export async function browserRPC(action:string,hash:string|null,input:Record<string,unknown>={}){
 const response=await fetch(base()+'/rest/v1/rpc/random_browser_gateway',{method:'POST',headers:{apikey:secret(),Authorization:'Bearer '+secret(),'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(12000)});
 if(!response.ok)throw new SocialAuthError('Browser chat is temporarily unavailable.','unavailable',503);
 const result=await response.json();if(result.error)throw new SocialAuthError(result.error,result.code,result.code==='unauthorized'?401:result.code==='forbidden'?403:result.code==='rate_limit'?429:400);return result;
}
export async function randomMemberHash(request:Request){
 if(request.headers.has('X-Maroon-Web-Session')){
  const token=request.headers.get('X-Maroon-Web-Session')??'';if(!/^[a-f0-9]{64}$/.test(token))throw new SocialAuthError('Pair this browser again.');
  const result=await browserRPC('resolve',await sha256(token));if(!/^[a-f0-9]{64}$/.test(result.token_hash??''))throw new SocialAuthError('Pair this browser again.');return result.token_hash;
 }
 return await socialHash(request);
}
