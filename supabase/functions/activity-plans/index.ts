import { Image } from 'jsr:@matmen/imagescript@1.3.1';
import { socialHash, SocialAuthError, authFailure } from '../_shared/social-auth.ts';
const base=Deno.env.get('SUPABASE_URL')!,key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const auth={apikey:key,Authorization:'Bearer '+key};
const respond=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
class PhotoError extends Error{constructor(message:string,public status=400){super(message)}}
async function rpc(action:string,hash:string,input:Record<string,unknown>){const response=await fetch(base+'/rest/v1/rpc/activity_plans',{method:'POST',headers:{...auth,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(15000)});if(!response.ok)throw new PhotoError('Plans are temporarily unavailable.',503);const data=await response.json();if(data.error)throw new PhotoError(data.error,data.code==='forbidden'?403:400);return data}
function base64(data:Uint8Array){let result='';for(let i=0;i<data.length;i+=32768)result+=String.fromCharCode(...data.subarray(i,i+32768));return btoa(result)}
function jpegSize(bytes:Uint8Array):void{
 if(bytes.length<10||bytes[0]!==255||bytes[1]!==216)throw new PhotoError('Choose a JPEG photo.');const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);let p=2;
 while(p+4<bytes.length){if(bytes[p++]!==255)continue;while(bytes[p]===255)p++;const tag=bytes[p++];if(tag===0xda||tag===0xd9)break;const n=view.getUint16(p);if(n<2||p+n>bytes.length)break;if([0xc0,0xc1,0xc2].includes(tag)&&n>=8){const h=view.getUint16(p+3),w=view.getUint16(p+5);if(w>0&&h>0&&w<=4096&&h<=4096&&w*h<=12000000)return;break}p+=n}throw new PhotoError('Choose a smaller photo.');
}
Deno.serve(async request=>{
 if(request.method!=='POST')return respond({error:'Use POST.'},405);
 try{
  const raw=await request.text();if(raw.length>2800000)return respond({error:'Photo too large.'},413);const input=JSON.parse(raw);if(!input||typeof input!=='object'||Array.isArray(input)||!['series.create','series.info','series.cancel_future','promotion.create','poster.read','poster.upload','poster.remove'].includes(input.action))throw new PhotoError('Invalid poster request.');
  const hash=await socialHash(request);const {action,data,...scope}=input;
  if(!action.startsWith('poster.'))return respond(await rpc(action,hash,scope));
  if(action==='poster.remove')return respond(await rpc(action,hash,scope));
  if(action==='poster.read'){
   const result=await rpc('poster.read',hash,scope);if(!result.has_poster)return respond({has_poster:false});
   const media=await fetch(base+'/storage/v1/object/authenticated/social-media/'+result.path,{headers:auth,signal:AbortSignal.timeout(15000)});if(!media.ok)throw new PhotoError('This poster is unavailable.',404);
   const bytes=new Uint8Array(await media.arrayBuffer());if(bytes.length>2000000)throw new PhotoError('This poster is unavailable.',404);
   return respond({has_poster:true,attachment_id:result.attachment_id,media_data:base64(bytes)});
  }
  await rpc('poster.authorize',hash,scope);if(typeof data!=='string'||data.length>2700000)throw new PhotoError('Choose a smaller photo.');
  let bytes:Uint8Array;try{bytes=Uint8Array.from(atob(data),c=>c.charCodeAt(0))}catch{throw new PhotoError('Photo could not be read.')}
  if(bytes.length>2000000)throw new PhotoError('Choose a smaller photo.');jpegSize(bytes);
  const image=await Image.decode(bytes);const scale=Math.min(1,1600/Math.max(image.width,image.height));if(scale<1)image.resize(Math.max(1,Math.round(image.width*scale)),Math.max(1,Math.round(image.height*scale)));bytes=await image.encodeJPEG(85);
  const reservation=await rpc('poster.reserve',hash,{...scope,path:crypto.randomUUID()+'.jpg',size:bytes.length});
  const uploaded=await fetch(base+'/storage/v1/object/social-media/'+reservation.path,{method:'POST',headers:{...auth,'Content-Type':'image/jpeg','x-upsert':'false'},body:new Uint8Array(bytes).buffer,signal:AbortSignal.timeout(15000)});if(!uploaded.ok)throw new PhotoError('The photo could not upload. Retry.',503);
  return respond(await rpc('poster.commit',hash,{...scope,attachment_id:reservation.attachment_id}));
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);if(error instanceof PhotoError)return respond({error:error.message},error.status);return respond({error:'The poster could not be loaded or saved.'},503)}
});
