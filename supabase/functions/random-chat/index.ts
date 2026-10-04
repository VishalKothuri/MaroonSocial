// Automatic random/anonymous matching was removed at the owner's request.
// Existing private signaling tables now serve accepted interest discovery only.
import {webOrigin,webHeaders} from '../_shared/random-web.ts';
Deno.serve(request=>{
 let origin:string|null=null;
 try{origin=webOrigin(request);}catch{return new Response(JSON.stringify({error:'Origin unavailable.'}),{status:403,headers:webHeaders(null)})}
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers:webHeaders(origin)});
 return new Response(JSON.stringify({error:'Random chat was replaced by interest discovery. Update the app or use maroonsocial.chat.',code:'removed'}),{status:410,headers:webHeaders(origin)});
});
