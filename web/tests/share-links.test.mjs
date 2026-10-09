import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, mkdtemp, rm, stat} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {JSDOM} from 'jsdom';
// Share links: the /p/<post id> landing page, its rewrite, and the apple-app-site-association file.
const web=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const page=await readFile(path.join(web,'public/post.html'),'utf8');
const script=await readFile(path.join(web,'public/post.js'),'utf8');
const vercel=JSON.parse(await readFile(path.join(web,'vercel.json'),'utf8'));
const aasaText=await readFile(path.join(web,'public/.well-known/apple-app-site-association'),'utf8');
const id='3f2b8c1e-9a4d-4e7f-8b21-0c5d6e7f8a9b';

function load(url){
 const dom=new JSDOM(page,{url,runScripts:'outside-only'});
 dom.window.eval(script);
 return dom;
}

test('/p/<id> is rewritten to the landing page and the association file is served as JSON',()=>{
 assert.deepEqual(vercel.rewrites,[{source:'/p/:id',destination:'/post.html'}]);
 const aasa=vercel.headers.find(rule=>rule.source==='/.well-known/apple-app-site-association');
 assert.ok(aasa,'header rule for the association file');
 assert.deepEqual(aasa.headers,[{key:'Content-Type',value:'application/json'}]);
 // The site-wide security headers still apply to every path.
 const all=vercel.headers.find(rule=>rule.source==='/(.*)');
 assert.ok(all.headers.some(h=>h.key==='Content-Security-Policy'&&h.value.includes("script-src 'self'")));
});

test('the association file names the app and only shared-post paths',()=>{
 const aasa=JSON.parse(aasaText);
 assert.deepEqual(Object.keys(aasa),['applinks']);
 assert.equal(aasa.applinks.details.length,1);
 const detail=aasa.applinks.details[0];
 assert.deepEqual(detail.appIDs,['259BRQX9UQ.app.maroonsocial.MaroonSocial']);
 assert.equal(detail.appID,'259BRQX9UQ.app.maroonsocial.MaroonSocial');
 assert.deepEqual(detail.components.map(c=>c['/']),['/p/*']);
 assert.deepEqual(detail.paths,['/p/*']);
});

test('the landing page shows no post content and uses nothing the CSP blocks',()=>{
 const dom=new JSDOM(page);
 const document=dom.window.document;
 assert.equal(document.title,'A post on Maroon Social');
 assert.equal(document.querySelector('meta[name="robots"]').getAttribute('content'),'noindex,nofollow');
 // Absolute paths: the page is served at /p/<id>.
 assert.equal(document.querySelector('link[rel="stylesheet"]').getAttribute('href'),'/style.css');
 assert.deepEqual([...document.querySelectorAll('script')].map(s=>s.getAttribute('src')),['/post.js']);
 assert.equal(document.querySelectorAll('style,[style],script:not([src])').length,0);
 assert.equal(document.querySelectorAll('[onclick],[onload]').length,0);
 assert.equal(document.querySelector('h1').textContent,'See this on Maroon Social');
 assert.ok(document.querySelector('main a[href="/privacy.html"]'),'links to privacy');
 assert.ok(document.querySelector('main a[href="/guidelines.html"]'),'links to the guidelines');
 assert.equal(document.getElementById('open-app').textContent,'Open in Maroon Social');
 // Nothing on the page fetches anything about the post.
 assert.ok(!/fetch|XMLHttpRequest|supabase|functions\/v1/.test(script));
 dom.window.close();
});

test('the button opens the post in the app through the custom scheme',()=>{
 for(const pathname of['/p/'+id,'/p/'+id+'/','/p/'+id.toUpperCase()]){
  const dom=load('https://maroonsocial.chat'+pathname);
  const open=dom.window.document.getElementById('open-app');
  assert.equal(open.hidden,false,pathname);
  assert.equal(open.getAttribute('href'),'maroonsocial://post/'+id,pathname);
  assert.equal(dom.window.document.getElementById('invalid-link').hidden,true);
  dom.window.close();
 }
});

test('an incomplete or malformed link shows a message instead of the button',()=>{
 for(const pathname of['/p/','/p/nope','/p/'+id.slice(0,35),'/p/'+id+'/extra','/p/'+id+'x','/post.html','/p/%3Cscript%3E']){
  const dom=load('https://maroonsocial.chat'+pathname);
  const document=dom.window.document;
  assert.equal(document.getElementById('open-app').hidden,true,pathname);
  assert.equal(document.getElementById('open-app').hasAttribute('href'),false,pathname);
  assert.equal(document.getElementById('invalid-link').hidden,false,pathname);
  dom.window.close();
 }
});

test('the build keeps the rewrite, the JSON header and the association file',async()=>{
 const out=await mkdtemp(path.join(tmpdir(),'maroon-web-build-'));
 try{
  await promisify(execFile)(process.execPath,[path.join(web,'scripts/build.mjs')],{env:{...process.env,WEB_BUILD_OUT:out}});
  const built=JSON.parse(await readFile(path.join(out,'vercel.json'),'utf8'));
  assert.deepEqual(built.rewrites,vercel.rewrites);
  assert.deepEqual(built.headers,vercel.headers);
  assert.equal(await readFile(path.join(out,'.well-known/apple-app-site-association'),'utf8'),aasaText);
  assert.ok((await stat(path.join(out,'post.html'))).isFile());
  assert.ok((await stat(path.join(out,'post.js'))).isFile());
 }finally{await rm(out,{recursive:true,force:true})}
});
