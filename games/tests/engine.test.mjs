import test from 'node:test';
import assert from 'node:assert/strict';
import {initialState,resolveTurn,validateAction,POOL,CUPS} from '../src/engine.js';
import {resolveTurn as edgeResolve} from '../../supabase/functions/games/engine.js';
test('pool break is repeatable across client and bundled server, with genuine rack collisions',()=>{
 const start=initialState('pool'),input={aim:0,power:1,spin:0},a=resolveTurn('pool',start,input),b=resolveTurn('pool',start,input);
 assert.deepEqual(a,b);assert.deepEqual(edgeResolve('pool',start,input),a);assert.equal(start.shots,0);assert.equal(a.replay.firstContact,1);
 assert(a.replay.frames.length>50);assert(a.replay.events.some(x=>x.type==='hit'));assert(a.state.balls.filter((b,i)=>Math.hypot(b.x-start.balls[i].x,b.y-start.balls[i].y)>10).length>5);
});
test('pool miss changes turn, grants safe ball in hand, rejects cheating placement',()=>{
 const s=initialState('pool'),out=resolveTurn('pool',s,{aim:Math.PI/2,power:.1});assert.equal(out.state.turn,1);assert.equal(out.state.ballInHand,true);
 assert.throws(()=>resolveTurn('pool',s,{aim:0,power:1,cue:{x:400,y:1400}}));
 assert.throws(()=>resolveTurn('pool',out.state,{aim:0,power:1,cue:{x:s.balls[1].x,y:s.balls[1].y}}));
 assert.throws(()=>resolveTurn('pool',out.state,{aim:0,power:1,cue:{x:3,y:3}}));
 assert.doesNotThrow(()=>resolveTurn('pool',out.state,{aim:0,power:.3,cue:{x:450,y:1500}}));
});
test('pool canonical positions and replay remain finite for a multi-turn match',()=>{
 let s=initialState('pool');for(let i=0;i<18&&s.winner===null;i++){let r=resolveTurn('pool',s,{aim:(i*2.39996323)%(2*Math.PI)-Math.PI,power:.3+(i%7)/10});s=r.state;
  assert(r.replay.frames.flat().every(Number.isFinite));for(let b of s.balls.filter(b=>!b.pocketed)){assert(b.x>=POOL.radius&&b.x<=POOL.width-POOL.radius);assert(b.y>=POOL.radius&&b.y<=POOL.height-POOL.radius);}
 }
});
test('every cup is physically reachable with bounded aim and power',()=>{
 const found=new Map();for(let ai=-12;ai<=12&&found.size<6;ai++)for(let pi=3;pi<=95&&found.size<6;pi+=2){let aim=ai/100,power=pi/100,result=resolveTurn('pong',initialState('pong'),{aim,power});if(result.replay.hit!==null)found.set(result.replay.hit,{aim,power});}
 assert.equal(found.size,CUPS.length,JSON.stringify([...found.keys()]));
 for(let [cup,input]of found){let result=resolveTurn('pong',initialState('pong'),input);assert.deepEqual(edgeResolve('pong',initialState('pong'),input),result);assert.equal(result.replay.hit,cup);assert.deepEqual(result.state.removed[0],[cup]);assert.equal(result.state.turn,1);assert(result.replay.frames.length>15);assert(result.replay.events.some(e=>e.type==='cup'));}
});
test('pong six cups wins, removed cups cannot score again, floor collisions are real',()=>{
 let state=initialState('pong');state.removed[0]=[0,1,2,3,5];let result;for(let power=.03;power<=1;power+=.01){let r=resolveTurn('pong',state,{aim:0,power});if(r.state.winner===0){result=r;break}}assert(result,'The final center cup must remain reachable without the front cups');assert.equal(result.state.winner,0);assert.equal(result.state.removed[0].length,6);
 assert.throws(()=>resolveTurn('pong',result.state,{aim:0,power:.35}));
 let bounce=resolveTurn('pong',initialState('pong'),{aim:.3,power:.4,bounce:true});assert(bounce.replay.bounces>0);assert(bounce.replay.frames.flat().every(Number.isFinite));
});
test('all untrusted shot inputs are bounded, illegal chess moves rejected',()=>{
 for(let kind of ['pool','pong'])for(let input of [{aim:NaN,power:.4},{aim:0,power:0},{aim:0,power:1.01},{aim:4,power:.4},{aim:'0',power:.5}])assert.throws(()=>validateAction(kind,initialState(kind),input));
 assert.throws(()=>resolveTurn('pool',initialState('pool'),{aim:0,power:.5,winner:0}));
 assert.throws(()=>resolveTurn('pong',initialState('pong'),{aim:.5,power:.5}));assert.throws(()=>resolveTurn('chess',initialState('chess'),{from:'e2',to:'e5'}));
});
test('chess legal moves, checkmate and game over are server authoritative',()=>{
 let state=initialState('chess');for(let [from,to]of [['f2','f3'],['e7','e5'],['g2','g4'],['d8','h4']])state=resolveTurn('chess',state,{from,to}).state;
 assert.equal(state.winner,1);assert.equal(state.finished,true);assert.match(state.status,/checkmate/);assert.equal(state.legal.length,0);assert.throws(()=>resolveTurn('chess',state,{from:'a2',to:'a3'}));
});
