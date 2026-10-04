import {APNSProvider,notificationPayload} from '../supabase/functions/_shared/apns.ts';
import {callTransport,callIceServers} from '../supabase/functions/_shared/call-relay.ts';
import {webOrigin,webHeaders} from '../supabase/functions/_shared/random-web.ts';
function assert(value:unknown,message='Assertion failed'):asserts value{if(!value)throw Error(message)}
const item={job:'11111111-1111-4111-8111-111111111111',device:'22222222-2222-4222-8222-222222222222',lease:'33333333-3333-4333-8333-333333333333',token:'a'.repeat(64),environment:'sandbox' as const,kind:'game_turn',room_id:'room',reference:'44444444-4444-4444-8444-444444444444',expires_at:2000000000};
Deno.test('APNs ES256 token validates cryptographically; payload and endpoint are private and scoped',async()=>{
 const key=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
 const bytes=new Uint8Array(await crypto.subtle.exportKey('pkcs8',key.privateKey));const pem='-----BEGIN PRIVATE KEY-----\n'+btoa(String.fromCharCode(...bytes))+'\n-----END PRIVATE KEY-----';let calls=0;
 const provider=new APNSProvider({teamID:'TESTTEAMID',keyID:'TESTKEY123',privateKey:pem,topic:'app.test'},async(input,init)=>{
  calls++;assert(String(input)==='https://api.sandbox.push.apple.com/3/device/'+item.token);
  const headers=new Headers(init?.headers);assert(headers.get('apns-topic')==='app.test');assert(headers.get('apns-push-type')==='alert');
  const jwt=headers.get('authorization')!.slice(7).split('.');const decode=(s:string)=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')),x=>x.charCodeAt(0));
  assert(await crypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},key.publicKey,decode(jwt[2]),new TextEncoder().encode(jwt.slice(0,2).join('.'))));
  const payload=JSON.parse(String(init?.body));assert(payload.aps.alert.body==='Your turn');assert(!('token'in payload)&&!('member'in payload));
  return new Response(null,{status:200});
 },()=>1800000000);
 assert((await provider.send(item)).status===200);assert(calls===1);
 const token=await provider.token();assert(await provider.token()===token);
});
Deno.test('Invalid APNs device token never makes an outbound request',async()=>{
 const provider=new APNSProvider({teamID:'x',keyID:'x',privateKey:'',topic:'x'},()=>{throw Error('Network must not run')});assert((await provider.send({...item,token:'bad/path'})).reason==='BadDeviceToken');
});
Deno.test('APNs provider failures are sanitized and returned for queue retries',async()=>{
 const keys=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);const pem=btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.exportKey('pkcs8',keys.privateKey))));
 const provider=new APNSProvider({teamID:'x',keyID:'x',privateKey:pem,topic:'x'},async()=>new Response(JSON.stringify({reason:'BadDeviceToken',untrusted:'hidden'}),{status:400}));const result=await provider.send(item);assert(result.status===400&&result.reason==='BadDeviceToken');assert(Object.keys(result).length===2);
});
Deno.test('No relay is activated just by installing provider secrets',async()=>{
 Deno.env.set('TURN_KEY_ID','test');Deno.env.set('TURN_API_TOKEN','test');Deno.env.delete('CALL_RELAY_ENABLED');assert(callTransport()==='direct');
 assert((await callIceServers('direct',1200))[0].urls[0].startsWith('stun:'));
 let failed=false;try{await callIceServers('relay',1200,()=>{throw Error('No request')})}catch{failed=true}assert(failed);
});
Deno.test('Opt-in relay bounds lifetime and strips unexpected provider destinations',async()=>{
 Deno.env.set('CALL_RELAY_ENABLED','true');Deno.env.set('TURN_KEY_ID','test');Deno.env.set('TURN_API_TOKEN','test');
 try{const servers=await callIceServers('relay',90000,async(_input,init)=>{assert(JSON.parse(String(init?.body)).ttl===7200);return new Response(JSON.stringify({iceServers:[{urls:['turn:turn.cloudflare.com:3478?transport=udp','turn:evil.test:443','stun:stun.cloudflare.com:3478'],username:'short',credential:'temporary'}]}))});assert(servers.length===1&&servers[0].urls.length===1)}finally{Deno.env.delete('CALL_RELAY_ENABLED')}
});
Deno.test('Browser CORS accepts exact owner origins and rejects lookalikes',()=>{
 assert(webOrigin(new Request('https://backend.invalid',{headers:{Origin:'https://maroonsocial.chat'}}))==='https://maroonsocial.chat');let failed=false;try{webOrigin(new Request('https://backend.invalid',{headers:{Origin:'https://maroonsocial.chat.evil.test'}}))}catch{failed=true}assert(failed);assert(!('Access-Control-Allow-Origin'in webHeaders(null)));assert(notificationPayload(item).maroon.reference===item.reference);
});

Deno.test('Sandbox-only credentials never send to production APNs',async()=>{
 const provider=new APNSProvider({teamID:'x',keyID:'x',privateKey:'',topic:'x'},()=>{throw Error('Network must not run')});
 const result=await provider.send({...item,environment:'production'});assert(result.status===403&&result.reason==='EnvironmentNotConfigured');
});
