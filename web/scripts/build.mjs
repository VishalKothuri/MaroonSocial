import {cp, mkdir, readFile, writeFile, rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
// WEB_BUILD_OUT builds somewhere else (the web tests build into a temporary directory).
const out=process.env.WEB_BUILD_OUT?path.resolve(process.env.WEB_BUILD_OUT):path.join(root,'dist');
const projectFile=await readFile(path.join(out,'.vercel/project.json'),'utf8').catch(()=>null);
await rm(out,{recursive:true,force:true});
await mkdir(out,{recursive:true});
await cp(path.join(root,'public'),out,{recursive:true});
let call=await readFile(path.join(root,'../MaroonSocial/Resources/video-call.html'),'utf8');
// Same first-party WebRTC engine as the native build. Only the transport bridge differs.
call=call.replace("window.webkit?.messageHandlers.maroonCall.postMessage(body)","window.parent.postMessage({maroonCall:body},window.location.origin)");
const script=call.match(/<script>([\s\S]*?)<\/script>/)[1];
const style=call.match(/<style>([\s\S]*?)<\/style>/)[1]+'\nmain{height:100dvh!important;border-radius:12px}';
call=call.replace(/<meta http-equiv="Content-Security-Policy"[^>]*>/,'').replace(/<style>[\s\S]*?<\/style>/,'<link rel="stylesheet" href="/call.css">').replace(/<script>[\s\S]*?<\/script>/,'<script src="/call.js"></script>');
await writeFile(path.join(out,'call.html'),call);
await writeFile(path.join(out,'call.js'),script);
await writeFile(path.join(out,'call.css'),style);
// Deploy this generated directory directly. The shared iOS media engine is copied
// above, so Vercel never needs files outside its selected project directory.
// The rewrite serves the shared-post landing page for /p/<id>; the headers include the JSON type
// of /.well-known/apple-app-site-association.
const {headers,rewrites}=JSON.parse(await readFile(path.join(root,'vercel.json'),'utf8'));
await writeFile(path.join(out,'vercel.json'),JSON.stringify({headers,rewrites},null,2)+'\n');
if(projectFile){await mkdir(path.join(out,'.vercel'),{recursive:true});await writeFile(path.join(out,'.vercel/project.json'),projectFile);}
console.log('Built static web client and shared call engine.');
