// Standard APNs provider-token authentication. No notification text or tokens are logged.
export type PushDelivery={job:string;device:string;lease:string;token:string;environment:'sandbox'|'production';kind:string;room_id?:string;reference:string;expires_at:number};
export type APNSConfig={teamID:string;keyID:string;privateKey:string;topic:string;environments?:Array<'sandbox'|'production'>};
export const providerEnvironments=():Array<'sandbox'|'production'>=>(Deno.env.get('APNS_ALLOWED_ENVIRONMENTS')??'sandbox').split(',').map(x=>x.trim()).filter((x):x is 'sandbox'|'production'=>x==='sandbox'||x==='production');
const encoder=new TextEncoder();
const base64url=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
export const providerConfigured=()=>['APNS_TEAM_ID','APNS_KEY_ID','APNS_PRIVATE_KEY','APNS_TOPIC'].every(name=>Boolean(Deno.env.get(name)));
export function notificationPayload(item:PushDelivery){
 const titles:Record<string,string>={message:'New message',request:'New request',game_invite:'Game invitation',game_turn:'Your turn',call:'Incoming call',group_call:'Group call',activity:'New activity'};
 return {aps:{alert:{title:'Maroon Social',body:titles[item.kind]??'New activity'},sound:'default'},maroon:{kind:item.kind,room_id:item.room_id??null,reference:item.reference}};
}
export class APNSProvider{
 private cached?:{token:string;at:number};
 constructor(private config:APNSConfig,private request:typeof fetch=fetch,private now:()=>number=()=>Date.now()/1000){}
 async token(){
  const now=Math.floor(this.now());if(this.cached&&now-this.cached.at<2700&&now>=this.cached.at)return this.cached.token;
  const header=base64url(encoder.encode(JSON.stringify({alg:'ES256',kid:this.config.keyID}))),claims=base64url(encoder.encode(JSON.stringify({iss:this.config.teamID,iat:now})));
  const body=header+'.'+claims;
  const pem=this.config.privateKey.replace(/-----[^-]+-----/g,'').replace(/\s/g,'');
  const key=await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),x=>x.charCodeAt(0)),{name:'ECDSA',namedCurve:'P-256'},false,['sign']);
  const signature=new Uint8Array(await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,encoder.encode(body)));
  this.cached={token:body+'.'+base64url(signature),at:now};return this.cached.token;
 }
 async send(item:PushDelivery):Promise<{status:number;reason?:string}>{
  if(!/^[a-f0-9]{32,512}$/.test(item.token)||!['sandbox','production'].includes(item.environment))return{status:400,reason:'BadDeviceToken'};
  if(!(this.config.environments??['sandbox']).includes(item.environment))return{status:403,reason:'EnvironmentNotConfigured'};
  const host=item.environment==='sandbox'?'api.sandbox.push.apple.com':'api.push.apple.com';
  const response=await this.request(`https://${host}/3/device/${item.token}`,{method:'POST',headers:{authorization:'bearer '+await this.token(),'apns-topic':this.config.topic,'apns-push-type':'alert','apns-priority':'10','apns-expiration':String(Math.floor(item.expires_at)),'apns-collapse-id':item.job,'content-type':'application/json'},body:JSON.stringify(notificationPayload(item)),signal:AbortSignal.timeout(12000),redirect:'error'});
  if(response.status===200)return{status:200};
  const data=await response.json().catch(()=>({}));
  const reason=typeof data.reason==='string'&&/^[A-Za-z]{1,64}$/.test(data.reason)?data.reason:'ProviderError';
  if(reason==='ExpiredProviderToken'||reason==='InvalidProviderToken')this.cached=undefined;
  return{status:response.status,reason};
 }
}
