import Matter from 'matter-js';
import * as CANNON from 'cannon-es';
import { Chess } from 'chess.js';
import { resolveTurn as legacyResolve, validateAction as legacyValidate } from './legacy-engine-v2.js';
import { resolveTurn as previousResolve, validateAction as previousValidate } from './legacy-engine-v21.js';
import { applyPongDrag,pongLaunch } from './pong-flight.js';
import { addPongCup, CUP_MATERIALS } from './pong-cups.js';

export const RULES_VERSION = 'maroon-games-2.2.0';
export const POOL = { width: 1000, height: 2000, radius: 27, pockets: [[0,0],[1000,0],[0,1000],[1000,1000],[0,2000],[1000,2000]] };
export const CUPS = [{id:0,x:0,z:-.45},{id:1,x:-.083,z:-.62},{id:2,x:.083,z:-.62},{id:3,x:-.166,z:-.79},{id:4,x:0,z:-.79},{id:5,x:.166,z:-.79}];
const clone = value => JSON.parse(JSON.stringify(value));
const round = value => Math.round(value * 10000) / 10000;
const group = id => id >= 1 && id <= 7 ? 'solids' : id >= 9 && id <= 15 ? 'stripes' : null;
const inRange = (v,low,high) => typeof v === 'number' && Number.isFinite(v) && v >= low && v <= high;
const fail = message => { throw new Error(message); };

export function initialState(kind) {
  const base={kind,rules:RULES_VERSION,turn:0,winner:null,shots:0,status:'Player 1 to play.'};
  if(kind==='pool') {
    const balls=[{id:0,x:500,y:1510,pocketed:false}];
    const rack=[1,10,2,3,8,11,12,4,13,5,6,14,7,15,9];let i=0;
    for(let row=0;row<5;row++)for(let col=0;col<=row;col++)balls.push({id:rack[i++],x:500+(col-row/2)*55.2,y:570-row*47.85,pocketed:false});
    return {...base,balls,groups:[null,null],ballInHand:false,status:'Player 1 breaks. Pull the cue back for a strong shot.'};
  }
  if(kind==='pong') return {...base,removed:[[],[]],status:'Player 1 · aim, pull back, and release.'};
  if(kind==='chess') return chessState(new Chess(),base);
  fail('Unknown game.');
}
function chessState(chess,base) {
  const finished=chess.isGameOver();
  const turn=chess.turn()==='w'?0:1;
  const winner=chess.isCheckmate()?1-turn:null;
  return {...base,fen:chess.fen(),pgn:chess.pgn(),turn,winner,finished,
    legal:chess.moves({verbose:true}).map(m=>({from:m.from,to:m.to,promotion:m.promotion})),
    status:winner!==null?`Player ${winner+1} wins by checkmate.`:finished?'Draw.':`Player ${turn+1} to move${chess.isCheck()?' · check':''}.`};
}
export function validateAction(kind,state,action) {
  if(state?.rules==='maroon-games-2.1.0')return previousValidate(kind,state,action);
  if(state?.rules==='maroon-games-2.0.0')return legacyValidate(kind,state,action);
  if(!state||state.kind!==kind||state.rules!==RULES_VERSION)fail('Unsupported game version.');
  if(state.winner!==null||state.finished)fail('This game has finished.');
  if(!action||typeof action!=='object')fail('Missing turn.');
  const keys=kind==='chess'?['from','to','promotion']:kind==='pool'?['aim','power','spin','cue']:['aim','power','bounce'];
  if(Object.keys(action).some(key=>!keys.includes(key)))fail('Unsupported turn input.');
  if(action.cue&&(typeof action.cue!=='object'||Object.keys(action.cue).some(key=>!['x','y'].includes(key))))fail('Invalid cue position.');
  if(kind==='chess') {
    if(!/^[a-h][1-8]$/.test(action.from)||!/^[a-h][1-8]$/.test(action.to)||!['q','r','b','n'].includes(action.promotion||'q'))fail('Choose a legal chess move.');
    return;
  }
  if(!inRange(action.aim,-Math.PI,Math.PI)||!inRange(action.power,.03,1))fail('Aim or power is outside the allowed range.');
  if(kind==='pool') {
    if(!inRange(action.spin??0,-1,1))fail('Spin is outside the allowed range.');
    if(action.cue) {
      if(!state.ballInHand)fail('The cue ball cannot be moved now.');
      if(!inRange(action.cue.x,POOL.radius+8,POOL.width-POOL.radius-8)||!inRange(action.cue.y,POOL.radius+8,POOL.height-POOL.radius-8))fail('Place the cue ball on the felt.');
      if(state.balls.some(b=>b.id!==0&&!b.pocketed&&Math.hypot(b.x-action.cue.x,b.y-action.cue.y)<POOL.radius*2+1))fail('The cue ball overlaps another ball.');
      if(POOL.pockets.some(([x,y])=>Math.hypot(x-action.cue.x,y-action.cue.y)<80))fail('Place the cue ball away from a pocket.');
    }
  } else if(kind==='pong') {
    if(Math.abs(action.aim)>.42)fail('Aim at the table.');
    if(action.bounce!==undefined&&typeof action.bounce!=='boolean')fail('Invalid throw type.');
  }
}

export function resolveTurn(kind,before,action) {
  if(before?.rules==='maroon-games-2.1.0')return previousResolve(kind,before,action);
  if(before?.rules==='maroon-games-2.0.0')return legacyResolve(kind,before,action);
  validateAction(kind,before,action);
  if(kind==='pool')return poolTurn(before,action);
  if(kind==='pong')return pongTurn(before,action);
  const chess=new Chess();
  if(before.pgn)chess.loadPgn(before.pgn);else chess.load(before.fen);
  let moved;try{moved=chess.move({from:action.from,to:action.to,promotion:action.promotion||'q'});}catch{fail('That chess move is not legal.');}
  if(!moved)fail('That chess move is not legal.');
  return {state:chessState(chess,{...before,shots:before.shots+1}),replay:{kind:'chess',move:{from:action.from,to:action.to},notation:moved.san}};
}

function poolTurn(before,action) {
  const {Engine,Bodies,Body,Composite,Events}=Matter;
  // Engine-owned body IDs must start in the same order for stable collision ordering.
  Matter.Common._nextId=0;
  const engine=Engine.create({gravity:{x:0,y:0,scale:0},positionIterations:10,velocityIterations:10,enableSleeping:false});
  const state=clone(before),R=POOL.radius;
  if(action.cue){state.balls[0].x=action.cue.x;state.balls[0].y=action.cue.y;}
  const bodies=new Map();
  const cushions=[];
  const rail=(x,y,w,h,angle=0)=>{const b=Bodies.rectangle(x,y,w,h,{isStatic:true,restitution:.82,friction:.035,angle,label:'cushion',chamfer:{radius:8}});cushions.push(b);return b;};
  // Six open pockets, segmented cushions and angled jaws: no invisible rails across pockets.
  for(const x of [-24,1024])for(const y of [500,1500])rail(x,y,48,850);
  for(const y of [-24,2024])rail(500,y,850,48);
  for(const [x,y,sx,sy] of [[30,40,1,1],[970,40,-1,1],[30,1960,1,-1],[970,1960,-1,-1]])rail(x,y,42,18,sx*sy*Math.PI/4);
  Composite.add(engine.world,cushions);
  for(const ball of state.balls)if(!ball.pocketed){
    const b=Bodies.circle(ball.x,ball.y,R,{restitution:.96,friction:.008,frictionStatic:0,frictionAir:0,density:.002,label:`ball:${ball.id}`},64);
    bodies.set(ball.id,b);Composite.add(engine.world,b);
  }
  const cue=bodies.get(0);if(!cue)fail('Cue ball missing.');
  // Table coordinates are millimetres; Matter velocities are units per 1/60s.
  // A low stroke rolls gently; full draw produces a 5 m/s break.
  const speed=(.055+4.945*Math.pow(action.power,1.65))*1000/60;
  Body.setVelocity(cue,{x:Math.sin(action.aim)*speed,y:-Math.cos(action.aim)*speed});
  Body.setAngularVelocity(cue,(action.spin||0)*.25);
  const sunk=[],events=[],frames=[];let first=null,railAfter=false,t=0,settled=0;
  Events.on(engine,'collisionStart',event=>{
    for(const pair of event.pairs){
      const labels=[pair.bodyA.label,pair.bodyB.label];
      // Matter combines restitution with max(), which would otherwise make
      // a rubber cushion as elastic as a phenolic ball. Set the impact pair.
      if(labels.includes('cushion'))pair.restitution=.82;
      if(first===null&&labels.includes('ball:0')){const other=labels.find(l=>l.startsWith('ball:')&&l!=='ball:0');if(other)first=Number(other.split(':')[1]);}
    }
    for(const pair of event.pairs){
      if(pair.bodyA.label==='cushion'||pair.bodyB.label==='cushion'){if(first!==null)railAfter=true;}
      const strength=Math.hypot(pair.bodyA.velocity.x-pair.bodyB.velocity.x,pair.bodyA.velocity.y-pair.bodyB.velocity.y);
      if(strength>.25&&events.length<80)events.push({t:round(t),type:'hit',strength:Math.min(1,strength/20)});
    }
  });
  function snapshot(){frames.push(state.balls.flatMap(ball=>{const b=bodies.get(ball.id);return [ball.id,b?round(b.position.x):ball.x,b?round(b.position.y):ball.y,b?1:0];}));}
  snapshot();
  for(let step=0;step<240*30;step++){
    t=(step+1)/240;
    Engine.update(engine,1000/240);
    for(const [id,b] of bodies){
      const v=Math.hypot(b.velocity.x,b.velocity.y);
      // Rolling resistance is nearly constant, rather than air-like exponential drag.
      // 0.22 m/s² gives a controlled roll and a definite stop without creeping.
      if(v>0){const factor=Math.max(0,v-(.22*1000/60/240))/v;Body.setVelocity(b,{x:b.velocity.x*factor,y:b.velocity.y*factor});}
      const pocket=POOL.pockets.some(([x,y])=>Math.hypot(b.position.x-x,b.position.y-y)<58);
      if(pocket){
        const ball=state.balls.find(ball=>ball.id===id);ball.x=round(b.position.x);ball.y=round(b.position.y);ball.pocketed=true;
        sunk.push(id);events.push({t:round(t),type:'pocket',id});Composite.remove(engine.world,b);bodies.delete(id);
      }
    }
    if(step%8===7)snapshot();
    const moving=[...bodies.values()].some(b=>Math.hypot(b.velocity.x,b.velocity.y)>.07);
    settled=moving?0:settled+1;
    if(settled>=36&&step>24)break;
  }
  for(const [id,b]of bodies){const ball=state.balls.find(ball=>ball.id===id);ball.x=round(Math.min(1000-R,Math.max(R,b.position.x)));ball.y=round(Math.min(2000-R,Math.max(R,b.position.y)));}
  Engine.clear(engine);Composite.clear(engine.world,false);
  const own=before.groups[before.turn];
  const remaining=before.balls.filter(b=>!b.pocketed&&group(b.id)===own&&own!==null).map(b=>b.id);
  const legalTargets=own?(remaining.length?remaining:[8]):before.balls.filter(b=>!b.pocketed&&b.id!==0&&b.id!==8).map(b=>b.id);
  const scratch=sunk.includes(0),wrong=first===null||!legalTargets.includes(first),noRail=!railAfter&&sunk.length===0;
  const foul=scratch||wrong||noRail;
  state.shots++;
  state.ballInHand=false;
  if(sunk.includes(8)){
    if(before.shots===0){spotBall(state,8,500,570);events.push({t:round(t),type:'spot',id:8});}
    else{state.winner=!foul&&legalTargets.length===1&&legalTargets[0]===8?before.turn:1-before.turn;state.status=state.winner===before.turn?`Player ${state.winner+1} wins. Clean finish!`:`Player ${state.winner+1} wins · ${scratch?'scratch on the 8':'8 ball pocketed too early or illegally'}.`;}
  }
  if(state.winner===null){
    if(!own&&!foul){const assigned=sunk.map(group).find(Boolean);if(assigned){state.groups[state.turn]=assigned;state.groups[1-state.turn]=assigned==='solids'?'stripes':'solids';}}
    const ownSink=sunk.some(id=>group(id)&&group(id)===state.groups[state.turn]);
    if(foul){state.turn=1-state.turn;state.ballInHand=true;spotBall(state,0,500,1500);state.status=`${scratch?'Scratch':wrong?(first===null?'No ball contacted':'Wrong ball hit first'):'No ball reached a cushion'}. Player ${state.turn+1} has ball in hand.`;}
    else if(ownSink)state.status=`Nice shot. Player ${state.turn+1} goes again.`;
    else{state.turn=1-state.turn;state.status=`Player ${state.turn+1} to shoot.`;}
  }
  return {state,replay:{kind:'pool',fps:30,frames,events,duration:round(t),sunk,firstContact:first}};
}
function spotBall(state,id,x,y){
  const ball=state.balls.find(b=>b.id===id);if(!ball)return;
  for(let attempt=0;attempt<400;attempt++){
    const px=attempt===0?x:80+(attempt%15)*60,py=attempt===0?y:100+Math.floor(attempt/15)*65;
    if(py<1920&&state.balls.every(b=>b.id===id||b.pocketed||Math.hypot(b.x-px,b.y-py)>POOL.radius*2+2)){
      ball.x=px;ball.y=py;ball.pocketed=false;return;
    }
  }
  fail('Unable to place the ball.');
}

// Preview stops at the first relevant contact, rather than simulating a miss
// until it leaves the table on every touch update. It uses the same integration.
export function previewPongFlight(state,action){
 validateAction('pong',state,action);
 if(state.rules!==RULES_VERSION)return resolveTurn('pong',state,action).replay;
 return pongTurn(state,action,true).replay;
}
function pongTurn(before,action,preview=false){
  const state=clone(before);
  const world=new CANNON.World({gravity:new CANNON.Vec3(0,-9.81,0)});
  world.broadphase=new CANNON.SAPBroadphase(world);
  world.solver.iterations=12;
  const ballMaterial=new CANNON.Material('pingpong'),tableMaterial=new CANNON.Material('table'),cupMaterial=new CANNON.Material('cup');
  world.addContactMaterial(new CANNON.ContactMaterial(ballMaterial,tableMaterial,{friction:.12,restitution:.78}));
  world.addContactMaterial(new CANNON.ContactMaterial(ballMaterial,cupMaterial,{friction:.18,restitution:CUP_MATERIALS.wallRestitution}));
  const table=new CANNON.Body({mass:0,material:tableMaterial,shape:new CANNON.Box(new CANNON.Vec3(.5,.04,1.13)),position:new CANNON.Vec3(0,-.04,0)});world.addBody(table);
  const targets=CUPS.filter(c=>!state.removed[state.turn].includes(c.id));
  const bottomMaterial=new CANNON.Material('cup-bottom');
  world.addContactMaterial(new CANNON.ContactMaterial(ballMaterial,bottomMaterial,{friction:.3,restitution:CUP_MATERIALS.bottomRestitution}));
  const cupBottoms=new Map();
  for(const cup of targets){
    const bottom=addPongCup(world,cup,cupMaterial,bottomMaterial);
    cupBottoms.set(bottom.id,cup.id);
  }
  const ball=new CANNON.Body({mass:.0027,material:ballMaterial,shape:new CANNON.Sphere(.02),position:new CANNON.Vec3(0,.23,1.02),linearDamping:0,angularDamping:.1});
  const {forward:vz,up:vy}=pongLaunch(action.power,action.bounce);
  ball.velocity.set(Math.sin(action.aim)*vz,vy,-Math.cos(action.aim)*vz);world.addBody(ball);
  const frames=[],events=[];let hit=null,t=0,bounces=0;
  ball.addEventListener('collide',event=>{
    if(cupBottoms.has(event.body.id)&&hit===null){
      hit=cupBottoms.get(event.body.id);events.push({t:round(t),type:'cup',id:hit});
    }else if(event.body===table){bounces++;events.push({t:round(t),type:'bounce'});}
    else if(events.length<20)events.push({t:round(t),type:'rim'});
  });
  frames.push([0,.23,1.02]);
  for(let step=0;step<240*4;step++){
    t=(step+1)/240;applyPongDrag(ball);world.step(1/240);
    if(step%4===3)frames.push([round(ball.position.x),round(ball.position.y),round(ball.position.z)]);
    if(preview&&events.some((event,index)=>event.type!=='bounce'||(!action.bounce||events.slice(0,index+1).filter(e=>e.type==='bounce').length>=2))){frames.push([round(ball.position.x),round(ball.position.y),round(ball.position.z)]);break;}
    if(hit!==null){frames.push([round(ball.position.x),round(ball.position.y),round(ball.position.z)]);break;}
    if(ball.position.y<-.6||Math.abs(ball.position.z)>2||Math.abs(ball.position.x)>1.2||t>1.8&&ball.velocity.length()<.035)break;
  }
  const player=state.turn;state.shots++;
  if(hit!==null)state.removed[player].push(hit);
  if(state.removed[player].length===6){state.winner=player;state.status=`Player ${player+1} wins. Six cups cleared!`;}
  else{state.turn=1-player;state.status=hit!==null?`Cup sunk! Player ${state.turn+1}, your throw.`:`${bounces?'Off the table.':'Just missed.'} Player ${state.turn+1}, your throw.`;}
  return {state,replay:{kind:'pong',fps:60,frames,events,duration:round(t),hit,bounces,player}};
}
