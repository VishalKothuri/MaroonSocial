import {socialHash,SocialAuthError,authFailure,sha256} from '../_shared/social-auth.ts';
import {browserRPC,webOrigin,webHeaders} from '../_shared/random-web.ts';
const random=(bytes:number)=>Array.from(crypto.getRandomValues(new Uint8Array(bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');
Deno.serve(async request=>{
 let origin:string|null=null;
 const respond=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:webHeaders(origin)});
 try{
  origin=webOrigin(request);if(request.method==='OPTIONS')return new Response(null,{status:204,headers:webHeaders(origin)});
  if(request.method!=='POST')return respond({error:'Use POST.'},405);
  const raw=await request.text();if(raw.length>2048)return respond({error:'Request too large.'},413);
  const input=JSON.parse(raw);
  if(input.action==='pair.create'){
   const hash=await socialHash(request),code=random(6).toUpperCase();const result=await browserRPC('pair.create',hash,{code_hash:await sha256(code)});return respond({...result,code});
  }
  if(input.action==='pair.claim'){
   const code=typeof input.code==='string'?input.code.toUpperCase().replace(/[-\s]/g,''):'';
   if(!/^[A-F0-9]{12}$/.test(code))return respond({error:'Enter the12-character code from your app.',code:'invalid'},400);
   const token=random(32),network=request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()??'unknown';
   const result=await browserRPC('pair.claim',null,{code_hash:await sha256(code),token_hash:await sha256(token),network_hash:await sha256(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')+':random-browser:'+network)});return respond({...result,token});
  }
  if(input.action==='logout'){
   const token=request.headers.get('X-Maroon-Web-Session')??'';if(!/^[a-f0-9]{64}$/.test(token))return respond({signed_out:true});
   const hash=await sha256(token);
   // End this browser's current instance before revoking its limited session.
   try{if(typeof input.instance!=='string'||!/^[a-f0-9-]{36}$/i.test(input.instance))throw Error('No active instance');const member=await browserRPC('resolve',hash);const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;await fetch(base+'/rest/v1/rpc/discovery_gateway',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_action:'leave',p_hash:member.token_hash,p_input:{instance:input.instance}}),signal:AbortSignal.timeout(10000)});}catch{}
   return respond(await browserRPC('logout',hash));
  }
  return respond({error:'Unknown browser action.'},400);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);return respond({error:'Could not pair this browser.',code:'unavailable'},503)}
});
