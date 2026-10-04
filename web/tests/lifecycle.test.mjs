import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {setImmediate as turn} from 'node:timers/promises';
import {JSDOM} from 'jsdom';
import {CallSignalBuffer} from '../public/call-signals.js';
const html=await readFile(new URL('../public/index.html',import.meta.url),'utf8');
const source=await readFile(new URL('../public/app.js',import.meta.url),'utf8');
const oldToken='a'.repeat(64),newToken='b'.repeat(64),profile={username:'CopperOwl',tags:['music']};
function state(value='idle'){return {state:value,profile,people:[],incoming:[],outgoing:null,messages:[],signals:[],media_transport:'direct',session:value==='connected'?{id:'session-a',room:'media-a',peer:{username:'SilverOtter',tags:['music']},initiator:true,ends_at:2000000000}:null};}
const json=(value,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json'}});
function deferred(){let resolve;const promise=new Promise(yes=>{resolve=yes;});return{promise,resolve};}
async function until(predicate,label){for(let i=0;i<150;i++){if(predicate())return;await turn();}assert.fail('Timed out: '+label);}
function page(t,fetchHandler){
 const dom=new JSDOM(html,{url:'https://maroonsocial.chat/',runScripts:'outside-only',pretendToBeVisual:true});t.after(()=>dom.window.close());
 const w=dom.window,calls=[],media={started:0,stopped:0,received:[]},timers=new Map();let nextTimer=0,hidden=false;
 // No browser resource loading or real network is permitted in this fixture.
 Object.defineProperty(w.document,'hidden',{get:()=>hidden,configurable:true});
 w.setTimeout=(callback,delay)=>{const id=++nextTimer;timers.set(id,{callback,delay});return id;};w.clearTimeout=id=>timers.delete(id);
 w.AbortSignal=AbortSignal;w.CallSignalBuffer=CallSignalBuffer;w.sessionStorage.setItem('maroon.browser.session',oldToken);
 w.document.getElementById('call-frame').contentWindow.MaroonCall={async start(){media.started++;},stop(){media.stopped++;},async receive(value){media.received.push(value);}};
 w.fetch=async(url,options)=>{const record={endpoint:new URL(url).pathname.split('/').at(-1),...JSON.parse(options.body),token:options.headers['X-Maroon-Web-Session'],keepalive:options.keepalive===true};calls.push(record);return fetchHandler(record);};
 // Run the actual production page. Replace only its import with the real module
 // above; inspect closures are read-only except invoking the actual poll entry.
 assert.match(source,/^import \{CallSignalBuffer\} from '\.\/call-signals\.js';/);
 w.eval(source.replace(/^import \{CallSignalBuffer\} from '\.\/call-signals\.js';\n/,'')+'\nwindow.__inspect={state:()=>snapshot?.state,token:()=>token,busy:()=>busy,poll};');
 return {w,calls,media,$:id=>w.document.getElementById(id),inspect:w.__inspect,
  visibility(value){hidden=value;w.document.dispatchEvent(new w.Event('visibilitychange'));},
  submit(id){w.document.getElementById(id).dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));}};
}
test('actual page: a delayed media response after End cannot restart capture',async t=>{
 const held=deferred();let ended=false;
 const p=page(t,r=>{if(r.action==='media')return held.promise;if(r.action==='leave'){ended=true;return json(state('ended'));}return json(state(ended?'ended':'connected'));});
 await until(()=>p.calls.some(c=>c.action==='media'),'media request');assert.equal(p.inspect.state(),'connected');assert.equal(p.media.started,0);
 p.$('message').value='Unsent old conversation';const leave=p.$('leave').onclick();
 assert.equal(p.inspect.state(),'ended');assert.equal(p.$('message').value,'');assert.ok(p.media.stopped>0);
 held.resolve(json({...state('connected'),ice_servers:[{urls:['stun:stun.example.invalid:3478']}]}));await leave;await turn();
 assert.equal(p.media.started,0,'End must invalidate media before its response');assert.equal(p.inspect.state(),'ended');assert.ok(p.calls.some(c=>c.action==='leave'));
});
test('actual page: backgrounding during profile save never queues Enter afterward',async t=>{
 const held=deferred(),p=page(t,r=>r.action==='profile'?held.promise:json(state()));
 await until(()=>p.inspect.state()==='idle','initial profile');p.$('username').value='NewProfile';p.$('allow-direct').checked=true;p.submit('profile-form');
 await until(()=>p.calls.some(c=>c.action==='profile'),'profile request');p.visibility(true);
 held.resolve(json({...state(),profile:{username:'NewProfile',tags:['art']}}));await until(()=>!p.inspect.busy(),'save cancellation');
 assert.equal(p.calls.filter(c=>c.action==='enter').length,0);assert.equal(p.media.started,0);assert.equal(p.inspect.state(),'ended');
});
test('actual page: late401 from an old keepalive cannot clear a newly paired account',async t=>{
 const held=deferred();let oldEnded=false;
 const p=page(t,r=>{if(r.action==='leave'&&r.keepalive)return held.promise;if(r.action==='leave'){oldEnded=true;return json(state('ended'));}if(r.action==='logout')return json({signed_out:true});if(r.action==='pair.claim')return json({token:newToken,expires_at:2000000000});return json(state(r.token===oldToken&&!oldEnded?'waiting':'idle'));});
 await until(()=>p.inspect.state()==='waiting','original waiting');p.visibility(true);await until(()=>p.calls.some(c=>c.keepalive),'keepalive request');p.visibility(false);await turn();
 await p.$('disconnect').onclick();assert.equal(p.inspect.token(),null);
 p.$('pair-code').value='ABCDEF123456';p.submit('pair-form');await until(()=>p.inspect.token()===newToken&&!p.inspect.busy(),'new pairing');assert.equal(p.$('pair-screen').hidden,true);
 held.resolve(json({error:'Expired browser grant.'},401));for(let i=0;i<10;i++)await turn();
 assert.equal(p.inspect.token(),newToken);assert.equal(p.w.sessionStorage.getItem('maroon.browser.session'),newToken);assert.equal(p.$('pair-screen').hidden,true);
});
test('actual page: repeated verification polling failures stop an existing media session',async t=>{
 let fail=false;
 const p=page(t,r=>{if(r.action==='leave')return json(state('ended'));if(r.action==='media')return json({...state('connected'),ice_servers:[{urls:['stun:stun.example.invalid:3478']}]});if(fail)throw new TypeError('Offline');return json(state('connected'));});
 await until(()=>p.media.started===1,'media started');const previousStops=p.media.stopped;fail=true;
 await p.inspect.poll();assert.equal(p.inspect.state(),'connected');await p.inspect.poll();
 assert.equal(p.inspect.state(),'ended');assert.ok(p.media.stopped>previousStops);assert.match(p.$('feedback').textContent,/camera is off/i);assert.ok(p.calls.some(c=>c.action==='leave'));
});
test('actual page: restoring a browser session keeps profile setup hidden until the saved profile arrives',async t=>{
 const held=deferred(),p=page(t,()=>held.promise);
 assert.equal(p.$('resume-screen').hidden,false);assert.equal(p.$('profile-screen').hidden,true);assert.equal(p.$('pair-screen').hidden,true);
 held.resolve(json(state()));await until(()=>p.inspect.state()==='idle','saved profile arrival');
 assert.equal(p.$('resume-screen').hidden,true);assert.equal(p.$('profile-screen').hidden,false);assert.equal(p.$('username').value,profile.username);
});
