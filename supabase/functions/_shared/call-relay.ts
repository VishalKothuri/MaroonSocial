// Provider secrets stay server-side. Only active, authorized call participants
// receive bounded credentials; direct transport remains an explicit consent mode.
export type IceServer = {urls:string[];username?:string;credential?:string};
export const callTransport = () => Deno.env.get('CALL_RELAY_ENABLED') === 'true' && Deno.env.get('TURN_KEY_ID') && Deno.env.get('TURN_API_TOKEN') ? 'relay' : 'direct';
export async function callIceServers(transport:string, ttlSeconds:number, request:typeof fetch=fetch):Promise<IceServer[]> {
 if(transport==='direct')return[{urls:['stun:stun.cloudflare.com:3478']}];
 const id=Deno.env.get('TURN_KEY_ID'),secret=Deno.env.get('TURN_API_TOKEN');
 if(Deno.env.get('CALL_RELAY_ENABLED')!=='true'||!id||!secret)throw new Error('relay_unavailable');
 const response=await request('https://rtc.live.cloudflare.com/v1/turn/keys/'+encodeURIComponent(id)+'/credentials/generate-ice-servers',{
  method:'POST',headers:{Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({ttl:Math.max(60,Math.min(7200,Math.ceil(ttlSeconds)))}),signal:AbortSignal.timeout(8000),redirect:'error'});
 if(!response.ok)throw new Error('relay_unavailable');
 const raw=await response.json();
 const servers:IceServer[]=[];
 for(const row of Array.isArray(raw.iceServers)?raw.iceServers:[]){
  const urls=(Array.isArray(row.urls)?row.urls:[row.urls]).filter((u:unknown)=>typeof u==='string'&&/^turns?:turn\.cloudflare\.com:\d+(?:\?transport=(?:udp|tcp))?$/.test(u));
  if(urls.length&&typeof row.username==='string'&&typeof row.credential==='string')servers.push({urls,username:row.username,credential:row.credential});
 }
 if(!servers.length)throw new Error('relay_unavailable');return servers;
}
export async function admitRelay(hash:string,kind:'random'|'group'|'dm',reference:string):Promise<number>{
 const base=Deno.env.get('SUPABASE_URL')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
 const r=await fetch(base+'/rest/v1/rpc/call_media_admit',{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify({p_hash:hash,p_kind:kind,p_reference:reference}),signal:AbortSignal.timeout(8000)});
 if(!r.ok)throw new Error('relay_unavailable');const result=await r.json();if(result.error||!Number.isFinite(result.ttl))throw new Error('relay_unavailable');return result.ttl;
}
