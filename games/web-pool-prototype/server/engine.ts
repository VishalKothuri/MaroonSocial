// GPL-3.0: versioned authoritative adapter around tailuge/billiards 9cd48c5.
import {Vector3} from 'three'
import {Ball,State} from '../upstream/src/model/ball'
import {Table} from '../upstream/src/model/table'
import {TableConfig} from '../upstream/src/view/tableconfig'
import {TableGeometry} from '../upstream/src/view/tablegeometry'
import {R,maxPower,offCenterLimit} from '../upstream/src/model/physics/constants'
import {cueStrike,mathavanAdapter} from '../upstream/src/model/physics/physics'
export const RULES_VERSION='maroon-web-pool-3.0.0'
type BallState={id:number,x:number,y:number,pocketed:boolean}
export type PoolState={kind:'pool',rules:string,turn:number,winner:number|null,finished?:boolean,shots:number,status:string,balls:BallState[],groups:(string|null)[],ballInHand:boolean}
export type Shot={angle:number,power:number,offset:{x:number,y:number},elevation?:number,cue?:{x:number,y:number}}
const round=(n:number)=>Math.round(n*1e6)/1e6
const valid=(n:unknown,lo:number,hi:number)=>typeof n==='number'&&Number.isFinite(n)&&n>=lo&&n<=hi
const group=(id:number)=>id>=1&&id<=7?'solids':id>=9&&id<=15?'stripes':null
const fail=(message:string):never=>{throw Error(message)}
function geometry(){TableConfig.apply('eightball',10)}
export function initialState():PoolState {
 geometry();const balls:BallState[]=[{id:0,x:-TableGeometry.X*.52,y:0,pocketed:false}]
 const rack=[1,10,2,3,8,11,12,4,13,5,6,14,7,15,9];let i=0;const gap=2*R+.0016
 for(let row=0;row<5;row++)for(let col=0;col<=row;col++)balls.push({id:rack[i++],x:round(TableGeometry.X*.40+row*gap*Math.sqrt(3)/2),y:round((col-row/2)*gap),pocketed:false})
 balls.sort((a,b)=>a.id-b.id)
 return {kind:'pool',rules:RULES_VERSION,turn:0,winner:null,shots:0,status:'Player 1 breaks.',balls,groups:[null,null],ballInHand:false}
}
export function validateShot(state:PoolState,shot:Shot){
 geometry()
 if(state.rules!==RULES_VERSION||state.kind!=='pool')fail('Unsupported pool version.')
 if(state.winner!==null||state.finished)fail('This match has finished.')
 if(!shot||typeof shot!=='object'||Object.keys(shot).some(k=>!['angle','power','offset','elevation','cue'].includes(k)))fail('Unsupported shot input.')
 if(!valid(shot.angle,-Math.PI,Math.PI)||!valid(shot.power,.03,1))fail('Choose an aim and power within the table controls.')
 if(!shot.offset||Object.keys(shot.offset).some(k=>!['x','y'].includes(k))||!valid(shot.offset.x,-offCenterLimit,offCenterLimit)||!valid(shot.offset.y,-offCenterLimit,offCenterLimit)||Math.hypot(shot.offset.x,shot.offset.y)>offCenterLimit+.00001)fail('Cue spin is outside the allowed circle.')
 if(!valid(shot.elevation??0,0,Math.PI*.4))fail('Cue elevation is outside the allowed range.')
 if(shot.cue){
  if(!state.ballInHand||Object.keys(shot.cue).some(k=>!['x','y'].includes(k)))fail('The cue ball cannot be moved now.')
  if(!valid(shot.cue.x,-TableGeometry.tableX+R,TableGeometry.tableX-R)||!valid(shot.cue.y,-TableGeometry.tableY+R,TableGeometry.tableY-R))fail('Place the cue ball on the felt.')
  if(state.balls.some(b=>b.id!==0&&!b.pocketed&&Math.hypot(b.x-shot.cue!.x,b.y-shot.cue!.y)<2*R+.002))fail('The cue ball overlaps another ball.')
 }
}
export function resolveTurn(before:PoolState,shot:Shot){
 validateShot(before,shot)
 const state:PoolState=structuredClone(before);if(shot.cue)Object.assign(state.balls[0],shot.cue)
 Ball.id=0
 const balls=state.balls.map(b=>{const ball=new Ball(new Vector3(b.x,b.y,0),0xffffff,b.id);if(b.pocketed)ball.state=State.InPocket;return ball})
 const table=new Table(balls);table.cushionModel=mathavanAdapter
 const strike=cueStrike(shot.angle,shot.power*maxPower,new Vector3(shot.offset.x,shot.offset.y,0),shot.elevation??0)
 table.cueball.state=State.Sliding;table.cueball.vel.copy(strike.vel);table.cueball.rvel.copy(strike.rvel)
 const frames:number[][]=[];const snapshot=()=>frames.push(balls.flatMap(b=>[b.id,round(b.pos.x),round(b.pos.y),b.onTable()?1:0]));snapshot()
 const step=1/512;let steps=0
 while(!table.allStationary()&&steps<512*60){table.advance(step);steps++;if(steps%32===0)snapshot()}
 if(!table.allStationary())fail('The shot did not settle safely. Please use a gentler shot.')
 snapshot()
 for(const ball of balls){const saved=state.balls[ball.id];saved.x=round(ball.pos.x);saved.y=round(ball.pos.y);saved.pocketed=!ball.onTable();if(!Number.isFinite(saved.x)||!Number.isFinite(saved.y))fail('Invalid physics outcome.')}
 const sunk=table.outcome.filter(o=>o.type==='Pot').map(o=>o.ballA!.id)
 const contact=table.outcome.find(o=>o.type==='Collision'&&(o.ballA?.id===0||o.ballB?.id===0));const first=contact?(contact.ballA?.id===0?contact.ballB!.id:contact.ballA!.id):null
 const railAfter=!!contact&&table.outcome.some(o=>o.type==='Cushion'&&o.timestamp>=contact.timestamp)
 const own=before.groups[before.turn],remaining=before.balls.filter(b=>!b.pocketed&&own!==null&&group(b.id)===own).map(b=>b.id)
 const legal=own?(remaining.length?remaining:[8]):before.balls.filter(b=>!b.pocketed&&b.id!==0&&b.id!==8).map(b=>b.id)
 const scratch=sunk.includes(0),wrong=first===null||!legal.includes(first),foul=scratch||wrong||(!railAfter&&sunk.length===0)
 state.shots++;state.ballInHand=false
 if(sunk.includes(8)){
  if(before.shots===0)spot(state,8,TableGeometry.X*.4,0)
  else{state.winner=!foul&&legal.length===1&&legal[0]===8?before.turn:1-before.turn;state.status=`Player ${state.winner+1} wins ${state.winner===before.turn?'with the 8 ball.':'after an illegal 8 ball.'}`}
 }
 if(state.winner===null){
  if(!own&&!foul){const assigned=sunk.map(group).find(Boolean);if(assigned){state.groups[state.turn]=assigned;state.groups[1-state.turn]=assigned==='solids'?'stripes':'solids'}}
  const ownSink=sunk.some(id=>group(id)&&group(id)===state.groups[state.turn])
  if(foul){state.turn=1-state.turn;state.ballInHand=true;spot(state,0,-TableGeometry.X*.52,0);state.status=`${scratch?'Scratch':wrong?(first===null?'No ball contacted':'Wrong ball hit first'):'No ball reached a cushion'}. Player ${state.turn+1} has ball in hand.`}
  else if(ownSink)state.status=`Player ${state.turn+1} shoots again.`
  else{state.turn=1-state.turn;state.status=`Player ${state.turn+1} to shoot.`}
 }
 return {state,replay:{kind:'pool',rules:RULES_VERSION,fps:16,duration:round(steps*step),frames,sunk,firstContact:first,
 events:table.outcome.slice(0,120).map(o=>({type:o.type,t:round(o.timestamp/1000),id:o.ballA?.id,other:o.ballB?.id,strength:round(o.incidentSpeed)}))}}
}
function spot(state:PoolState,id:number,x:number,y:number){
 const ball=state.balls[id]
 for(let i=0;i<600;i++){
  const px=i===0?x:-TableGeometry.tableX+R*3+(i%30)*R*2.6,py=i===0?y:-TableGeometry.tableY+R*3+Math.floor(i/30)*R*2.6
  if(Math.abs(px)<TableGeometry.tableX-R*2&&Math.abs(py)<TableGeometry.tableY-R*2&&state.balls.every(b=>b.id===id||b.pocketed||Math.hypot(b.x-px,b.y-py)>R*2+.002)){Object.assign(ball,{x:round(px),y:round(py),pocketed:false});return}
 }
 fail('The ball could not be spotted safely.')
}
