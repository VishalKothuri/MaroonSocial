import test from 'node:test';
import assert from 'node:assert/strict';
import * as CANNON from 'cannon-es';
import { initialState, resolveTurn } from '../src/engine.js';
import { initialState as v21State, resolveTurn as v21Resolve } from '../src/legacy-engine-v21.js';
import { initialState as oldState, resolveTurn as oldResolve } from '../src/legacy-engine-v2.js';
import { resolveTurn as edgeResolve } from '../../supabase/functions/games/engine.js';
import { addPongCup, CUP_MATERIALS } from '../src/pong-cups.js';

const isolatedPool=()=>{const state=initialState('pool');state.shots=1;state.balls.forEach(b=>{if(b.id)b.pocketed=true});return state;};
const position=(frame,id)=>{for(let i=0;i<frame.length;i+=4)if(frame[i]===id)return [frame[i+1],frame[i+2]];throw Error('Missing ball');};

test('a gentle pool stroke rolls with constant resistance and comes to a definite stop',()=>{
 const state=isolatedPool(),result=resolveTurn('pool',state,{aim:0,power:.1});
 const y=result.replay.frames.map(f=>position(f,0)[1]);
 const velocities=y.slice(1,10).map((value,i)=>(y[i]-value)*30/1000);
 const accelerations=velocities.slice(1).map((value,i)=>(velocities[i]-value)*30);
 assert(accelerations.every(a=>Math.abs(a-.22)<.003),JSON.stringify(accelerations));
 const distance=(y[0]-y.at(-1))/1000;
 assert(distance>.04&&distance<.09,`A 10% stroke should move centimetres, not launch the ball: ${distance}m`);
 assert(result.replay.duration<1.2);
 assert(Math.abs(y.at(-1)-y.at(-2))<.01,'No creeping at rest');
});
test('pool cushions absorb more energy than ball contacts and preserve reflection direction',()=>{
 const state=isolatedPool();state.balls[0].x=500;state.balls[0].y=1500;
 const result=resolveTurn('pool',state,{aim:Math.PI/2,power:.5});
 const x=result.replay.frames.map(f=>position(f,0)[0]);
 const contact=x.findIndex((value,i)=>i>0&&i<x.length-1&&value>x[i-1]&&value>x[i+1]);
 assert(contact>2);
 const incoming=(x[contact-1]-x[contact-2])*30;
 const outgoing=(x[contact+1]-x[contact+2])*30;
 const retained=outgoing/incoming;
 assert(retained>.76&&retained<.87,`Cushion must use its own restitution, not ball's .96: ${retained}`);
 assert(result.replay.frames.every(f=>Math.abs(position(f,0)[1]-1500)<.5),'A square cushion hit should reflect along the same line');
});
test('full-power pool breaks are strong while head-on equal balls transfer momentum without creating energy',()=>{
 const broken=resolveTurn('pool',initialState('pool'),{aim:0,power:1});
 const f=broken.replay.frames;
 const openingSpeed=(position(f[0],0)[1]-position(f[1],0)[1])*30/1000;
 assert(openingSpeed>4.8&&openingSpeed<5.1,`${openingSpeed}m/s`);
 assert(broken.state.balls.filter((b,i)=>Math.hypot(b.x-initialState('pool').balls[i].x,b.y-initialState('pool').balls[i].y)>100).length>=14);
 const state=isolatedPool();state.balls[0].y=1500;
 const object=state.balls.find(b=>b.id===1);object.pocketed=false;object.x=500;object.y=1350;
 const result=resolveTurn('pool',state,{aim:0,power:.3});
 const impact=result.replay.events.find(e=>e.type==='hit').t;
 const before=Math.max(1,Math.floor(impact*30)-1),after=Math.ceil(impact*30)+1;
 const speed=(id,i)=>Math.hypot(...position(result.replay.frames[i],id).map((v,j)=>(v-position(result.replay.frames[i-1],id)[j])*30));
 const incoming=speed(0,before),cue=speed(0,after),target=speed(1,after);
 assert(target>incoming*.80&&cue<incoming*.15,`Equal mass head-on transfer: ${JSON.stringify({incoming,cue,target})}`);
 assert(cue*cue+target*target<=incoming*incoming*1.02,'No kinetic energy created at impact');
});
test('a cup is hollow and tapered, scores on its physical bottom, and dissipates impact energy',()=>{
 const world=new CANNON.World({gravity:new CANNON.Vec3(0,-9.81,0)});
 const ballMaterial=new CANNON.Material('ball'),wallMaterial=new CANNON.Material('wall'),bottomMaterial=new CANNON.Material('bottom');
 world.addContactMaterial(new CANNON.ContactMaterial(ballMaterial,wallMaterial,{friction:.18,restitution:CUP_MATERIALS.wallRestitution}));
 world.addContactMaterial(new CANNON.ContactMaterial(ballMaterial,bottomMaterial,{friction:.3,restitution:CUP_MATERIALS.bottomRestitution}));
 const bottom=addPongCup(world,{x:0,z:0},wallMaterial,bottomMaterial);
 const ball=new CANNON.Body({mass:.0027,material:ballMaterial,shape:new CANNON.Sphere(.02),position:new CANNON.Vec3(0,.4,0)});
 world.addBody(ball);let touchedBottom=false,peakAfterContact=0;
 ball.addEventListener('collide',e=>{if(e.body===bottom)touchedBottom=true;});
 for(let i=0;i<480;i++){world.step(1/240);if(touchedBottom)peakAfterContact=Math.max(peakAfterContact,ball.position.y);}
 assert(touchedBottom,'The mouth must be open so a real body can reach the bottom');
 assert(ball.position.y>.025&&ball.position.y<.038,'The ball must rest on the bottom, not pass through it');
 assert(peakAfterContact<.05,'Cup bottom should absorb energy rather than eject the ball');
 assert(Math.hypot(ball.position.x,ball.position.z)<.01);
});
test('old 2.0 and 2.1 matches keep exact trajectories while 2.2 matches the server bundle',()=>{
 for(const kind of ['pool','pong','chess']){
  const input=kind==='chess'?{from:'e2',to:'e4'}:{aim:0,power:.4};
  const legacy=oldState(kind),expected=oldResolve(kind,legacy,input);
  assert.deepEqual(resolveTurn(kind,legacy,input),expected);
  assert.deepEqual(edgeResolve(kind,legacy,input),expected);
  const previous=v21State(kind),v21=v21Resolve(kind,previous,input);assert.deepEqual(resolveTurn(kind,previous,input),v21);assert.deepEqual(edgeResolve(kind,previous,input),v21);
  const fresh=initialState(kind);assert.equal(fresh.rules,'maroon-games-2.2.0');
  assert.deepEqual(edgeResolve(kind,fresh,input),resolveTurn(kind,fresh,input));
 }
});
