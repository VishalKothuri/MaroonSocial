import {cp, mkdir, readFile, writeFile, rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const projectFile=await readFile(path.join(root,'dist/.vercel/project.json'),'utf8').catch(()=>null);
await rm(path.join(root,'dist'),{recursive:true,force:true});
await mkdir(path.join(root,'dist'),{recursive:true});
await cp(path.join(root,'public'),path.join(root,'dist'),{recursive:true});
let call=await readFile(path.join(root,'../MaroonSocial/Resources/video-call.html'),'utf8');
// Same first-party WebRTC engine as the native build. Only the transport bridge differs.
call=call.replace("window.webkit?.messageHandlers.maroonCall.postMessage(body)","window.parent.postMessage({maroonCall:body},window.location.origin)");
const script=call.match(/<script>([\s\S]*?)<\/script>/)[1];
const style=call.match(/<style>([\s\S]*?)<\/style>/)[1]+'\nmain{height:100dvh!important;border-radius:12px}';
call=call.replace(/<meta http-equiv="Content-Security-Policy"[^>]*>/,'').replace(/<style>[\s\S]*?<\/style>/,'<link rel="stylesheet" href="/call.css">').replace(/<script>[\s\S]*?<\/script>/,'<script src="/call.js"></script>');
await writeFile(path.join(root,'dist/call.html'),call);
await writeFile(path.join(root,'dist/call.js'),script);
await writeFile(path.join(root,'dist/call.css'),style);
// Deploy this generated directory directly. The shared iOS media engine is copied
// above, so Vercel never needs files outside its selected project directory.
const {headers}=JSON.parse(await readFile(path.join(root,'vercel.json'),'utf8'));
await writeFile(path.join(root,'dist/vercel.json'),JSON.stringify({headers},null,2)+'\n');
if(projectFile){await mkdir(path.join(root,'dist/.vercel'),{recursive:true});await writeFile(path.join(root,'dist/.vercel/project.json'),projectFile);}
console.log('Built static web client and shared call engine.');
