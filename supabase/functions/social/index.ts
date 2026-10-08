import { cleanupDeletedAuthUsers } from '../_shared/social-auth-cleanup.ts';
import { wakePushWorker } from '../_shared/push-wake.ts';
import { socialIdentity, SocialAuthError, authFailure, authBridge, sha256 } from '../_shared/social-auth.ts';
import { Image, GIF } from 'jsr:@matmen/imagescript@1.3.1';
import { sanitizeVideo, VideoMediaError } from '../_shared/video-media.ts';
import { mediaStore, newMediaPath, groupByBackend, MediaStoreError, type MediaRead } from '../_shared/media-store.ts';
import { mintRealtimeToken } from '../_shared/realtime-token.ts';
// A device credential is server-authenticated; it does not assert university enrollment.
const base = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const headers = {'Content-Type':'application/json','Cache-Control':'no-store'};
const respond=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers});
const sha=async(value:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))).map(v=>v.toString(16).padStart(2,'0')).join('');
const authHeaders={'apikey':secret,'Authorization':'Bearer '+secret};
// Supabase Storage unless MEDIA_BACKEND=r2 with complete R2 credentials (see _shared/media-store.ts).
const store=mediaStore();
// A URL-capable store answers with {url,expires}; Supabase Storage keeps today's inline media_data.
const mediaReply=(media:MediaRead)=>'url' in media?{url:media.url,expires:media.expires}:{media_data:encodeBase64(media.bytes)};
async function readMedia(path:string,mime:string,missing:string){try{return await store.read(path,{mime})}catch(error){if(error instanceof MediaStoreError&&error.kind==='not_found')throw new ClientError(missing,'not_found',404);if(error instanceof MediaStoreError)console.error('social_media_read_failed',error.kind);throw error}}
const activityActions=new Set(['notifications','notification.read','notifications.read_all','library']);
// Private administrator access: client action -> organization_access RPC action, forwarding only documented input keys.
const organizationActions:Record<string,string>={'organization.admins':'get','organization.invitations':'incoming','organization.invite':'invite','organization.revoke':'revoke','organization.remove':'remove','organization.leave':'leave','organization.accept':'accept','organization.decline':'decline'};
const organizationInputs:Record<string,string[]>={get:['organization_id'],incoming:[],invite:['organization_id','username','kind','nonce'],revoke:['organization_id','invitation_id'],remove:['organization_id','administrator_key'],leave:['organization_id'],accept:['invitation_id'],decline:['invitation_id']};
const memeActions:Record<string,string[]>={'meme.publish':['data','title'],'meme.list':['page','query'],'meme.read':['meme_id'],'meme.report':['meme_id','reason'],'meme.remove':['meme_id']};
const clientActions=new Set([...activityActions,...Object.keys(organizationActions),...Object.keys(memeActions),'snapshot','feed.page','feed.delta','feed.posts','topics.list','comments.page','room.messages','profile.update','community.join','community.leave','posts.tag','post.create','post.topic','post.delete','post.vote','poll.vote','post.save','post.attach','comment.create','comment.delete','comment.vote','course.join','course.leave','activity.create','activity.join','activity.leave','activity.cancel','activity.edit','activity.approve','dm.request','dm.accept','dm.decline','room.send','room.delete','room.react','room.read','room.typing','room.leave','group.create','group.invite','group.accept','group.decline','group.remove','group.transfer','group.leave','join_sports','sports.join','save_event','organization.apply','organization.follow','organization.update','organization.publish','organization.message','report','block','account.delete','attachment.upload','attachment.read','attachment.external','realtime.token']);
class ClientError extends Error {constructor(message:string,public code='invalid',public status=400){super(message)}}
async function rpc(action:string,hash:string,input:Record<string,unknown>,name='social_gateway'){
 const response=await fetch(base+'/rest/v1/rpc/'+name,{method:'POST',headers:{...authHeaders,'Content-Type':'application/json'},body:JSON.stringify({p_action:action,p_hash:hash,p_input:input}),signal:AbortSignal.timeout(18000)});
 if(!response.ok){console.error('social_rpc_status',response.status);throw new ClientError('The community service is temporarily unavailable. Please retry.','unavailable',503)}
 const value=await response.json();
 if(value.error)throw new ClientError(value.error,value.code,value.code==='unauthorized'?401:value.code==='forbidden'?403:value.code==='not_found'?404:value.code==='rate_limit'?429:400);
 return value;
}
function dimensions(bytes:Uint8Array){
 const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 if(bytes.length>24&&bytes[0]===137&&String.fromCharCode(...bytes.slice(1,4))==='PNG')return {kind:'image',mime:'image/png',width:v.getUint32(16),height:v.getUint32(20)};
 if(bytes.length>13&&['GIF87a','GIF89a'].includes(String.fromCharCode(...bytes.slice(0,6)))){
  const width=v.getUint16(6,true),height=v.getUint16(8,true);let pos=13+((bytes[10]&128)?3*(1<<((bytes[10]&7)+1)):0),frames=0,pixels=0;
  const blocks=()=>{while(pos<bytes.length){const n=bytes[pos++];if(!n)return;pos+=n;if(pos>bytes.length)throw new ClientError('That GIF is damaged.')}};
  while(pos<bytes.length){const tag=bytes[pos++];if(tag===0x3b)break;if(tag===0x21){pos++;blocks()}else if(tag===0x2c){if(pos+9>bytes.length)throw new ClientError('That GIF is damaged.');pixels+=v.getUint16(pos+4,true)*v.getUint16(pos+6,true);frames++;if(frames>80||pixels>12000000||frames*width*height>12000000)throw new ClientError('Choose a shorter or smaller GIF (up to 80 frames).');const packed=bytes[pos+8];pos+=9+((packed&128)?3*(1<<((packed&7)+1)):0);pos++;blocks()}else throw new ClientError('That GIF is damaged.')}
  if(!frames)throw new ClientError('That GIF has no frames.');return {kind:'gif',mime:'image/gif',width,height};
 }
 if(bytes.length>10&&bytes[0]===255&&bytes[1]===216){let pos=2;while(pos+4<bytes.length){if(bytes[pos++]!==255)continue;while(bytes[pos]===255)pos++;const marker=bytes[pos++];if(marker===0xd9||marker===0xda)break;if(marker>=0xd0&&marker<=0xd7)continue;const size=v.getUint16(pos);if(size<2||pos+size>bytes.length)break;if(size>=8&&[0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker))return{kind:'image',mime:'image/jpeg',width:v.getUint16(pos+5),height:v.getUint16(pos+3)};pos+=size}}
 throw new ClientError('Choose a valid JPEG, PNG, or GIF.');
}
async function sanitize(input:string){
 if(typeof input!=='string'||input.length>6700000)throw new ClientError('Choose media smaller than 5 MB.');
 let bytes:Uint8Array;try{bytes=Uint8Array.from(atob(input),c=>c.charCodeAt(0))}catch{throw new ClientError('The attachment could not be read.')}
 if(!bytes.length||bytes.length>5000000)throw new ClientError('Choose media smaller than 5 MB.');
 const info=dimensions(bytes);
 if(!info.width||!info.height||info.width>8192||info.height>8192||info.width*info.height>12000000)throw new ClientError('Choose a smaller image (up to 12 megapixels).');
 try{
  if(info.kind==='gif'){
   const gif=await GIF.decode(bytes);
   if(gif.duration>15000)throw new ClientError('Choose a GIF shorter than 15 seconds.');
   bytes=await gif.encode(80);
  }else{
   const image=await Image.decode(bytes);
   const scale=Math.min(1,1600/Math.max(image.width,image.height));
   if(scale<1)image.resize(Math.max(1,Math.round(image.width*scale)),Math.max(1,Math.round(image.height*scale)));
   bytes=info.mime==='image/jpeg'?await image.encodeJPEG(85):await image.encode();
  }
 }catch(error){if(error instanceof ClientError)throw error;throw new ClientError('That image could not be decoded. Choose another photo or GIF.')}
 if(bytes.length>5000000)throw new ClientError('The processed image is too large. Choose smaller media.');
 return {...info,bytes};
}
// Realtime pokes (caching phase 3). Without REALTIME_JWT_SECRET, or before the
// realtime_pokes migration adds public.social_realtime, the app is told to keep polling.
// The token is returned to its own member only and is never logged.
async function realtimeGrant(hash:string){
 const key=Deno.env.get('REALTIME_JWT_SECRET');
 if(!key)return {realtime:false};
 const response=await fetch(base+'/rest/v1/rpc/social_realtime',{method:'POST',headers:{...authHeaders,'Content-Type':'application/json'},body:JSON.stringify({p_action:'member',p_hash:hash,p_input:{}}),signal:AbortSignal.timeout(8000)});
 if(response.status===404){await response.body?.cancel();return {realtime:false}}
 if(!response.ok){console.error('realtime_member_status',response.status);await response.body?.cancel();return {realtime:false}}
 const value=await response.json();
 if(value.error)throw new ClientError(value.error,value.code,value.code==='unauthorized'?401:value.code==='forbidden'?403:value.code==='rate_limit'?429:400);
 if(typeof value.member!=='string')return {realtime:false};
 const grant=await mintRealtimeToken(key,value.member);
 // expires_in lets the app time its refresh on its own clock (a skewed device clock cannot let the token lapse first).
 return {realtime:true,token:grant.token,expires_at:grant.expiresAt,expires_in:grant.claims.exp-grant.claims.iat,member:grant.claims.sub};
}
function encodeBase64(bytes:Uint8Array){let result='';for(let i=0;i<bytes.length;i+=32768)result+=String.fromCharCode(...bytes.subarray(i,i+32768));return btoa(result)}
Deno.serve(async req=>{
 if(req.method!=='POST')return respond({error:'Use POST.'},405);
 try{
  if(Number(req.headers.get('content-length')??0)>7100000)throw new ClientError('Request too large.','invalid',413);
  const raw=await req.text();if(raw.length>7100000)throw new ClientError('Request too large.','invalid',413);
  let input;try{input=JSON.parse(raw)}catch{throw new ClientError('Invalid request.')}
  if(!input||typeof input!=='object'||Array.isArray(input))throw new ClientError('Invalid request.');
  const {action,...payload}=input;delete payload.network;
  if(action!=='register'&&!clientActions.has(action))throw new ClientError('Unknown social action.');
  let token=req.headers.get('X-Social-Token')??'';
  if(action==='register'){
   token=Array.from(crypto.getRandomValues(new Uint8Array(32))).map(v=>v.toString(16).padStart(2,'0')).join('');
   payload.network=await sha(secret+':social:'+String(req.headers.get('x-forwarded-for')?.split(',')[0]??'unknown'));
  }
  if(action==='register'&&req.headers.has('Authorization'))throw new ClientError('Finish email account setup.','not_linked',403);
  const identity=action==='register'?{hash:await sha(token),auth:null}:await socialIdentity(req);
  const hash=identity.hash;
  if(action==='account.delete'&&identity.auth){
   if(!/^[a-f0-9]{64}$/.test(payload.deletion_receipt??''))throw new ClientError('A secure deletion receipt is required. Please update the app.','invalid',400);
   await authBridge('prepare-deletion',identity.auth,{receipt_hash:await sha256(payload.deletion_receipt)});
  }
  delete payload.deletion_receipt;
  if(action==='realtime.token')return respond(await realtimeGrant(hash));
  if(activityActions.has(action))return respond(await rpc(action,hash,payload,'social_activity'));
  if(Object.hasOwn(organizationActions,action)){
   const name=organizationActions[action];const input:Record<string,unknown>={};
   for(const key of organizationInputs[name])if(payload[key]!==undefined)input[key]=payload[key];
   return respond(await rpc(name,hash,input,'organization_access'));
  }
  if(action==='attachment.external')return respond(await rpc('create',hash,payload,'social_external_media'));
  if(action==='attachment.upload'){
   await rpc('attachment.authorize',hash,payload);
   const file=payload.kind==='video'?sanitizeVideo(payload.data):await sanitize(payload.data);
   // Post media may be served from the CDN; room/DM media stays behind presigned or authenticated reads.
   const path=newMediaPath(({ 'image/png':'.png','image/jpeg':'.jpg','image/gif':'.gif','video/mp4':'.mp4'} as Record<string,string>)[file.mime]??'.img',payload.post_id!=null?'public':'private');
   const reserved=await rpc('attachment.reserve',hash,{room_id:payload.room_id,post_id:payload.post_id,path,kind:file.kind,mime:file.mime,size:file.bytes.length,feed_community:payload.feed_community});
   try{await store.put(path,file.bytes,file.mime)}catch{throw new ClientError('Your attachment could not upload. Please retry.','upload_failed',503)}
   const result=await rpc('attachment.commit',hash,{attachment_id:reserved.attachment_id,feed_community:payload.feed_community});
   return respond(result);
  }
  if(Object.hasOwn(memeActions,action)){
   // Shared memes: our own private bucket (KLIPY has no upload API). Only documented keys are forwarded.
   const input:Record<string,unknown>={};for(const key of memeActions[action])if(payload[key]!==undefined)input[key]=payload[key];
   const name=action.slice('meme.'.length);
   if(name==='publish'){
    const file=await sanitize(String(input.data??''));
    if(file.kind!=='image')throw new ClientError('Share a still image as a meme.');
    // shared_memes.path is CHECK-constrained to a bare <uuid>.<ext>, so memes stay on Supabase Storage until a migration relaxes it.
    const path=crypto.randomUUID()+(file.mime==='image/png'?'.png':'.jpg');
    try{await store.put(path,file.bytes,file.mime)}catch{throw new ClientError('Your meme could not upload. Please retry.','upload_failed',503)}
    try{return respond(await rpc('publish',hash,{path,mime:file.mime,size:file.bytes.length,width:file.width,height:file.height,title:typeof input.title==='string'?input.title.slice(0,80):''},'social_memes'));}
    catch(error){try{await store.remove([path],{timeoutMs:5000})}catch{console.error('shared_meme_cleanup_pending')}throw error;}
   }
   const result=await rpc(name,hash,input,'social_memes');
   if(name!=='read')return respond(result);
   const media=await readMedia(result.path,result.mime,'This meme is no longer available.');
   return respond({meme_id:result.meme_id,mime:result.mime,...mediaReply(media)});
  }
  if(action==='attachment.read'){
   const allowed=await rpc('read',hash,payload,'social_external_media');
   if(allowed.external_media)return respond({attachment_id:allowed.attachment_id,external_media:allowed.external_media});
   const media=await readMedia(allowed.path,allowed.mime,'This attachment is no longer available.');
   return respond({attachment_id:allowed.attachment_id,mime:allowed.mime,...mediaReply(media)});
  }
  const result=await rpc(action,hash,payload);
  if(['comment.create','comment.vote','post.vote','dm.request','room.send','group.invite','organization.message','organization.publish'].includes(action))wakePushWorker();
  if(action==='block'){
   // Decorate only after the original context permission check and block succeed.
   // Failure cannot undo or misreport the safety action.
   try{await fetch(base+'/rest/v1/rpc/account_controls',{method:'POST',headers:{...authHeaders,'Content-Type':'application/json'},body:JSON.stringify({p_action:'block.context',p_hash:hash,p_input:payload}),signal:AbortSignal.timeout(3000)})}catch{}
  }
  if(action==='account.delete'){
   try{await cleanupDeletedAuthUsers(2)}catch{console.error('auth_user_cleanup_pending')}
   const paths=result.storage_paths??[];delete result.storage_paths;
   // Each backend is removed and acknowledged on its own; anything unacknowledged stays queued for the worker.
   for(const group of Object.values(groupByBackend(paths)))if(group.length){
    try{
     await store.remove(group);
     await fetch(base+'/rest/v1/rpc/social_media_cleanup_complete',{method:'POST',headers:{...authHeaders,'Content-Type':'application/json'},body:JSON.stringify({p_paths:group}),signal:AbortSignal.timeout(5000)});
    }catch(error){if(error instanceof MediaStoreError&&error.status)console.error('social_media_cleanup_pending',error.status);else console.error('social_media_cleanup_pending')}
   }
  }
  if(action==='register')result.token=token;
  return respond(result);
 }catch(error){if(error instanceof SocialAuthError)return respond(authFailure(error),error.status);if(error instanceof VideoMediaError)return respond({error:error.message,code:'invalid'},400);if(error instanceof ClientError)return respond({error:error.message,code:error.code},error.status);console.error('social_request_failed',String(error));return respond({error:'The community service could not finish that request. Please retry.',code:'unavailable'},503)}
});
