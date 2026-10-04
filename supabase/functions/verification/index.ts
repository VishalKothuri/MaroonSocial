import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
// Raw mailbox addresses and OTPs exist only in request memory and the delivery provider.
// The database receives domain-scoped HMACs; this is mailbox verification, not enrollment proof.
const base=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const provider=Deno.env.get('EMAIL_PROVIDER')??'brevo';
const apiKey=Deno.env.get(provider==='resend'?'RESEND_API_KEY':'BREVO_API_KEY'),sender=Deno.env.get('EMAIL_SENDER')??Deno.env.get('BREVO_SENDER_EMAIL'),pepper=Deno.env.get('VERIFICATION_HMAC_SECRET');
const enabled=Boolean(['brevo','resend'].includes(provider)&&apiKey&&sender&&pepper&&pepper.length>=32);
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
const hex=(bytes:ArrayBuffer)=>Array.from(new Uint8Array(bytes)).map(v=>v.toString(16).padStart(2,'0')).join('');
const sha=async(value:string)=>hex(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)));
const hmac=async(value:string)=>{const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(pepper!),{name:'HMAC',hash:'SHA-256'},false,['sign']);return hex(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(value)))};
function otp(){const n=new Uint32Array(1);do{crypto.getRandomValues(n)}while(n[0]>=4294000000);return String(n[0]%1000000).padStart(6,'0')}
class Failure extends Error{constructor(message:string,public code:string,public status=400){super(message)}}
async function rpc(action:string,hash:string,input:Record<string,unknown>={}){
 const r=await fetch(base+'/rest/v1/rpc/verification_gateway',{method:'POST',headers:{apikey:service,Authorization:'Bearer '+service,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(12000)});
 if(!r.ok)throw new Failure('Verification is temporarily unavailable.','unavailable',503);
 const data=await r.json();if(data.error)throw new Failure(data.error,data.code,data.code==='unauthorized'?401:data.code==='forbidden'?403:data.code==='rate_limit'?429:400);return data;
}
Deno.serve(async req=>{
 if(req.method!=='POST')return respond({error:'Use POST.'},405);
 try{
  const raw=await req.text();if(raw.length>4096)throw new Failure('Request too large.','invalid',413);
  const input=JSON.parse(raw);if(!input||typeof input!=='object'||Array.isArray(input)||!['status','request','confirm','cancel'].includes(input.action))throw new Failure('Invalid verification request.','invalid');
  const hash=await socialHash(req);
  if(input.action==='status')return respond({...await rpc('status',hash),enabled,message:enabled?undefined:'Email delivery is not configured yet. The app owner must connect an email provider and verify a sender.'});
  if(input.action==='cancel')return respond({...await rpc('cancel',hash,{challenge_id:input.challenge_id}),enabled});
  let email='';
  if(input.action==='request'){
   email=String(input.email??'').trim().toLowerCase();
   if(!/^[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?@tamu\.edu$/.test(email))throw new Failure('Use your exact @tamu.edu address. Other domains and aliases are not accepted.','invalid_domain');
  }
  if(!enabled)throw new Failure('The app owner has not configured email delivery yet.','not_configured',503);
  if(input.action==='confirm'){
   const code=String(input.code??'').trim();if(!/^\d{6}$/.test(code))throw new Failure('Enter the six-digit code from your email.','invalid_code');
   const result=await rpc('confirm',hash,{challenge_id:input.challenge_id,code_hash:await hmac('otp:'+input.challenge_id+':'+hash+':'+code)});
   return respond({...result,enabled});
  }
  const challenge=crypto.randomUUID(),code=otp();
  await rpc('prepare',hash,{domain:'tamu.edu',daily_limit:provider==='resend'?90:250,challenge_id:challenge,email_hash:await hmac('mailbox:'+email),code_hash:await hmac('otp:'+challenge+':'+hash+':'+code),network_hash:await hmac('network:'+(req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()??'unknown'))});
  try{
   const text='Your Maroon Social code is '+code+'. It expires in 10 minutes and can be used once.\n\nThis verifies access to your @tamu.edu mailbox, not current enrollment. If you did not request this code, ignore this email. Never share the code with anyone.';
   const brevo=provider==='brevo';
   const delivery=await fetch(brevo?'https://api.brevo.com/v3/smtp/email':'https://api.resend.com/emails',{method:'POST',headers:brevo?{'api-key':apiKey!,'Content-Type':'application/json','accept':'application/json'}:{Authorization:'Bearer '+apiKey!,'Content-Type':'application/json','Idempotency-Key':challenge},body:JSON.stringify(brevo?{sender:{name:'Maroon Social',email:sender},to:[{email}],subject:'Your Maroon Social mailbox code',textContent:text,tags:['mailbox-verification']}:{from:'Maroon Social <'+sender+'>',to:[email],subject:'Your Maroon Social mailbox code',text}),signal:AbortSignal.timeout(10000)});
   if(!delivery.ok)throw new Error('delivery_unavailable');
   const receipt=await delivery.json();if(typeof receipt[brevo?'messageId':'id']!=='string')throw new Error('delivery_not_accepted');
  }catch{
   await rpc('failed',hash,{challenge_id:challenge});throw new Failure('The verification email could not be sent. Please wait a minute and try again.','delivery_failed',503);
  }
  return respond({...await rpc('sent',hash,{challenge_id:challenge}),enabled});
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);if(error instanceof Failure)return respond({error:error.message,code:error.code},error.status);return respond({error:'Verification could not finish. Please try again.',code:'unavailable'},503)}
});
