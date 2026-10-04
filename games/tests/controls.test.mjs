import test from 'node:test';
import assert from 'node:assert/strict';
import { pongPull,pongGuide } from '../src/controls.js';
import { initialState,resolveTurn,CUPS } from '../src/engine.js';

test('pong pull has independent, stable screen-space aim and power',()=>{
 const size={width:366,height:438},start={x:183,y:260};
 const short=pongPull(start,{x:163,y:300},size),long=pongPull(start,{x:163,y:370},size);
 assert.equal(short.aim,long.aim,'Pulling farther down must not unpredictably swing the direction');
 assert(long.power>short.power);assert(short.aim>0);assert(short.aim<.04);
 assert(pongPull(start,{x:181,y:262},size).aim<.005,'Tiny lateral jitter stays small');
 assert.equal(pongPull(start,{x:183,y:330},size,.08).aim,.08,'Straight pull preserves a previously aimed direction');
 const scaled=pongPull({x:366,y:520},{x:326,y:600},{width:732,height:876});
 assert.equal(scaled.aim,short.aim);assert.equal(scaled.power,short.power);
});
test('pong release requires deliberate backward pull and keeps server bounds',()=>{
 const size={width:366,height:438},start={x:183,y:260};
 for(const end of [{x:183,y:260},{x:100,y:261},{x:183,y:230}])assert.equal(pongPull(start,end,size).releases,false);
 assert.equal(pongPull(start,{x:183,y:272},size).releases,true);
 const extreme=pongPull(start,{x:-1000,y:1500},size);assert.equal(extreme.aim,.24);assert.equal(extreme.power,1);
 assert.doesNotThrow(()=>resolveTurn('pong',initialState('pong'),extremeInput(extreme)));
});
const extremeInput=({aim,power})=>({aim,power});
test('screen pull gestures can physically reach every cup without assigning scores',()=>{
 const size={width:366,height:438},start={x:183,y:260},found=new Set();
 for(let x=-.12;x<=.1201&&found.size<6;x+=.01)for(let p=.03;p<=.95&&found.size<6;p+=.02){
  const gesture=pongPull(start,{x:start.x-x*size.width/.52,y:start.y+p*size.height*.33},size);
  if(!gesture.releases)continue;
  const outcome=resolveTurn('pong',initialState('pong'),extremeInput(gesture));
  if(outcome.replay.hit!==null)found.add(outcome.replay.hit);
 }
 assert.equal(found.size,CUPS.length,'All cups must be reachable through the same control mapping users get');
});
test('pong guide follows real flight/contact while leaving the live game unchanged',()=>{
 const state=initialState('pong'),saved=JSON.stringify(state),input={aim:0,power:.3};
 const guide=pongGuide(state,input);
 assert.equal(JSON.stringify(state),saved,'Preview never consumes a turn or awards a point');
 assert(guide.points.length>15);assert(guide.points.flat().every(Number.isFinite));
 assert(guide.points.some(p=>p[1]>.5),'Arc must show the actual raised flight');
 assert(guide.target[2]<-.3&&guide.target[2]>-.9,'Contact marker must reach the target rack');
 assert(['rim','cup'].includes(guide.contact));
 const bounced=pongGuide(state,{aim:.07,power:.4,bounce:true});
 assert(bounced.points.some((p,i)=>i>0&&p[1]>bounced.points[i-1][1]&&p[2]<.1),'Bounce guide includes the rebound toward the cups');
});
