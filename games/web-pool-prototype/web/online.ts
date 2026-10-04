// GPL-3.0. Scoped, authoritative multiplayer adapter around unmodified upstream controls.
import {Session} from '../upstream/src/network/client/session'
import {Aim} from '../upstream/src/controller/aim'
import {PlaceBall} from '../upstream/src/controller/placeball'
import {Controller} from '../upstream/src/controller/controller'
import {State} from '../upstream/src/model/ball'
import {TableGeometry} from '../upstream/src/view/tablegeometry'
import {R,maxPower} from '../upstream/src/model/physics/constants'
import type {Container} from '../upstream/src/container/container'
type Config={endpoint:string,token:string,expiresAt:number,gameID?:string}
type Game={id:string,version:number,yourSeat:number,status:string,state:any,replay?:any,players?:string[],rematch?:{id:string,status:string,yourSeat:number}}
class Waiting extends Controller {onFirst(){this.container.table.cue.aimInputs.setDisabled(true);this.container.table.cue.showHelper(false)}}
class ServerAim extends Aim {
 constructor(container:Container,private submit:()=>void){super(container)}
 playShot(){this.container.inputQueue.length=0;this.container.table.cue.aimInputs.setDisabled(true);queueMicrotask(this.submit);return new Waiting(this.container)}
}
class ServerPlace extends PlaceBall {
 constructor(container:Container,private aim:()=>Controller){super(container)}
 onFirst(){const t=this.container.table;t.cueball.setStationary();t.cue.placeBallMode();t.cue.moveTo(t.cueball.pos);t.cue.showHelper(false);t.cue.aimInputs.setButtonText('Place Ball');t.cue.aimInputs.setDisabled(false)}
 moveTo(dx:number,dy:number){const b=this.container.table.cueball;b.pos.x=Math.max(-TableGeometry.tableX+R*1.2,Math.min(TableGeometry.tableX-R*1.2,b.pos.x+dx));b.pos.y=Math.max(-TableGeometry.tableY+R*1.2,Math.min(TableGeometry.tableY-R*1.2,b.pos.y+dy))}
 placed(){if(this.container.table.overlapsAny(this.container.table.cueball.pos))return this;return this.aim()}
}
export class OnlinePool {
 private connection=0;private config?:Config;private game?:Game;private nonce?:string;private timer?:number;private busy=false;private replaying=false;private replayGeneration=0;private pending?:any;private rematchNonce?:{id:string,nonce:string}
 private another=document.getElementById('newOpponent') as HTMLButtonElement
 private action=document.getElementById('onlineAction') as HTMLButtonElement;private status=document.getElementById('onlineStatus')!;private resign=document.getElementById('resignGame') as HTMLButtonElement
 constructor(private c:Container){
  this.action.addEventListener('click',()=>void this.primary());this.resign.addEventListener('click',()=>{if(this.game?.status==='pending')void this.respond(this.game.yourSeat===1?'decline':'cancel_invite');else if(confirm('Resign this match? Your opponent wins.'))void this.forfeit()});this.another.addEventListener('click',()=>void this.findAnother())
  document.addEventListener('visibilitychange',()=>{if(document.hidden){this.stopTimer();if(this.nonce&&!this.game){void this.call('cancel',{nonce:this.nonce},true).catch(()=>{});this.nonce=undefined;this.render()}}else if(this.config){void this.refresh();this.schedule()}})
 }
 async connect(config:Config){
  if(config.endpoint!=='https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool'||!/^[a-f0-9]{64}$/.test(config.token)||config.expiresAt*1000<Date.now())throw Error('Invalid pool session.')
  if(config.gameID&&!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(config.gameID))throw Error('Invalid match.');
  document.body.classList.add('embedded');
  this.connection++;this.busy=false;this.replaying=false;this.replayGeneration++;this.nonce=undefined;this.config=config;this.c.table.advance=()=>{};this.game=undefined;this.pending=undefined;this.freeze();document.getElementById('resetTable')!.hidden=true;document.getElementById('onlineBar')!.hidden=false;document.querySelector('.preview-pill')!.textContent='Pool · online';this.status.textContent='Loading your match…';await this.refresh();this.schedule()
 }
 async disconnect(){
  const config=this.config,nonce=this.nonce,waiting=!!nonce&&!this.game;
  this.connection++;this.stopTimer();this.replayGeneration++;this.config=undefined;this.nonce=undefined;this.pending=undefined;this.busy=false;this.replaying=false;this.freeze();
  // Invalidate locally before awaiting cancellation. A slow old request must
  // never clear a newer foreground connection or revive its previous search.
  if(waiting&&config)await this.call('cancel',{nonce},true,config).catch(()=>{})
 }
 private async call(action:string,payload:any={},keepalive=false,config=this.config){if(!config)throw Error('Open pool in the app to connect.');const r=await fetch(config.endpoint,{method:'POST',headers:{'Content-Type':'application/json','X-Maroon-Pool-Session':config.token},body:JSON.stringify({action,...payload}),signal:AbortSignal.timeout(18000),keepalive});const v=await r.json();if(!r.ok||v.error)throw Object.assign(Error(v.error??'Couldn’t connect to pool.'),{code:v.code});return v}
 private freeze(){this.c.eventQueue.length=0;this.c.inputQueue.length=0;this.c.table.balls.forEach(b=>{if(b.state!==State.InPocket)b.setStationary()});this.c.updateController(new Waiting(this.c))}
 private schedule(){this.stopTimer();if(!document.hidden&&this.config)this.timer=window.setTimeout(async()=>{await this.refresh();this.schedule()},1800)}
 private stopTimer(){if(this.timer)clearTimeout(this.timer);this.timer=undefined}
 private async refresh(){if(!this.config||this.busy||this.replaying)return;const connection=this.connection;try{const selected=this.game?.id??this.config.gameID;const v=await this.call(selected?'get':this.nonce?'poll_queue':'active',selected?{id:selected}:this.nonce?{nonce:this.nonce}:{});if(connection!==this.connection)return;if(v.game)await this.receive(v.game);else if(v.queue==='expired'||v.queue==='cancelled')this.nonce=undefined;this.render()}catch(e){if(connection===this.connection)this.error(e)}}
 private async primary(){if(!this.config||this.busy||this.replaying)return;const connection=this.connection;this.busy=true;let failed=false;this.render();try{
  if(this.pending){const response=await this.call('turn',this.pending);if(connection!==this.connection)return;this.pending=undefined;await this.receive(response.game)}
  else if(this.game?.status==='pending'){if(this.game.yourSeat!==1)return;const response=await this.call('accept',{id:this.game.id});if(connection!==this.connection)return;await this.receive(response.game)}
  else if(this.game?.status==='finished'){
   const rematch=this.game.rematch;let response;
   if(rematch){response=await this.call(rematch.status==='pending'&&rematch.yourSeat===1?'accept':'get',{id:rematch.id})}
   else{if(this.rematchNonce?.id!==this.game.id)this.rematchNonce={id:this.game.id,nonce:crypto.randomUUID()};response=await this.call('rematch',this.rematchNonce)}
   if(connection!==this.connection)return;await this.receive(response.game)
  }
  else if(this.nonce&&!this.game){const response=await this.call('cancel',{nonce:this.nonce});if(connection!==this.connection)return;this.nonce=undefined;if(response.game)await this.receive(response.game)}
  else{this.game=undefined;this.config.gameID=undefined;this.nonce=crypto.randomUUID();this.freeze();const response=await this.call('join',{nonce:this.nonce});if(connection!==this.connection)return;if(response.game)await this.receive(response.game)}
 }catch(e){if(connection!==this.connection)return;failed=true;if((e as any)?.code==='invalid'&&this.pending){this.pending=undefined;this.arm()}this.error(e)}finally{if(connection===this.connection){this.busy=false;this.render(!failed)}}}
 private async findAnother(){if(this.busy||this.replaying||this.game?.status==='active'||this.game?.status==='pending')return;this.game=undefined;if(this.config)this.config.gameID=undefined;this.pending=undefined;await this.primary()}
 private async respond(action:'decline'|'cancel_invite'){if(!this.game||this.busy)return;const connection=this.connection;this.busy=true;this.render();let failed=false;try{const response=await this.call(action,{id:this.game.id});if(connection!==this.connection)return;await this.receive(response.game)}catch(e){if(connection!==this.connection)return;failed=true;this.error(e)}finally{if(connection===this.connection){this.busy=false;this.render(!failed)}}}
 private async forfeit(){if(!this.game||this.busy||this.replaying)return;const connection=this.connection;this.busy=true;let failed=false;this.freeze();try{const response=await this.call('forfeit',{id:this.game.id});if(connection!==this.connection)return;await this.receive(response.game)}catch(e){if(connection!==this.connection)return;failed=true;this.arm();this.error(e)}finally{if(connection===this.connection){this.busy=false;this.render(!failed)}}}
 private async shoot(){if(!this.game||this.busy||this.replaying||this.game.state.turn!==this.game.yourSeat)return;
  const aim=this.c.table.cue.aim;const input:any={angle:Math.atan2(Math.sin(aim.angle),Math.cos(aim.angle)),power:Math.max(.03,Math.min(1,aim.power/maxPower)),offset:{x:aim.offset.x,y:aim.offset.y},elevation:aim.elevation};if(this.game.state.ballInHand)input.cue={x:this.c.table.cueball.pos.x,y:this.c.table.cueball.pos.y};
  this.pending={id:this.game.id,version:this.game.version,nonce:crypto.randomUUID(),input};this.freeze();await this.primary()
 }
 private error(error:unknown){this.status.textContent=error instanceof Error?error.message:'Pool could not connect.';this.status.setAttribute('role','alert')}
 private render(clear=true){
  const g=this.game,pending=g?.status==='pending',finished=g?.status==='finished',closed=!!g&&['declined','expired'].includes(g.status),rematch=g?.rematch;
  this.action.disabled=this.busy||this.replaying||(pending&&g!.yourSeat===0)||(finished&&!!rematch&&['declined','expired'].includes(rematch.status));
  this.resign.hidden=!g||!['active','pending'].includes(g.status);this.resign.disabled=this.busy||this.replaying;
  this.resign.textContent=pending?(g!.yourSeat===1?'Decline':'Cancel invitation'):'Resign';
  this.another.hidden=!finished&&!closed;this.another.disabled=this.busy||this.replaying;
  this.action.hidden=!!g&&g.status==='active'&&!this.pending;
  this.action.textContent=this.pending?'Retry shot':pending?(g!.yourSeat===1?'Accept & play':'Waiting for acceptance'):finished?(rematch?(rematch.status==='pending'?(rematch.yourSeat===1?'Accept rematch':'View invitation'):rematch.status==='active'?'Open rematch':`Rematch ${rematch.status}`):'Invite to rematch'):this.nonce&&!g?'Cancel search':closed?'Find opponent':'Find opponent';
  if(!clear)return;this.status.setAttribute('role','status');
  const opponent=g?.players?.[1-g.yourSeat]??'Your opponent';
  this.status.textContent=this.replaying?'Replaying shot…':this.busy?'Connecting…':pending?(g!.yourSeat===1?`${opponent} invited you to play.`:`Waiting for ${opponent} to accept.`):closed?`Invitation ${g!.status}.`:g?`${g.state.status}${g.status==='active'?(g.state.turn===g.yourSeat?` Your turn${g.state.groups?.[g.yourSeat]?' · '+g.state.groups[g.yourSeat]:''}.`:` ${opponent}’s turn.`):rematch?.status==='pending'?' A rematch invitation is waiting.':''}`:this.nonce?'Finding another player…':'Play another Maroon Social member.'
 }
 private async receive(next:Game){
  if(this.game&&next.id===this.game.id&&next.version<this.game.version)return;
  const changed=this.game?.id!==next.id||this.game.version!==next.version;const shouldReplay=changed&&!!this.game&&this.game.id===next.id&&next.replay?.frames?.length>1;if(!changed){this.game=next;this.render();return;}
  this.freeze();this.game=next;if(this.config)this.config.gameID=next.id;this.nonce=undefined;if(this.pending&&next.version>this.pending.version)this.pending=undefined;
  const connection=this.connection;if(shouldReplay)await this.playReplay(next.replay);
  if(!this.config||connection!==this.connection)return;this.arm();this.render()
 }
 private arm(){const next=this.game;if(!next)return;this.applyState(next.state);const group=next.state.groups?.[next.yourSeat];Session.getInstance().p1type=group==='solids'?1:group==='stripes'?2:0;if(next.status==='active'&&next.state.turn===next.yourSeat){const aim=()=>new ServerAim(this.c,()=>void this.shoot());this.c.updateController(next.state.ballInHand?new ServerPlace(this.c,aim):aim())}}
 private mapBalls(){return new Map(this.c.table.balls.map(b=>[b===this.c.table.cueball?0:b.label??b.id,b]))}
 private applyState(state:any){const balls=this.mapBalls();for(const saved of state.balls){const b=balls.get(saved.id);if(!b)continue;b.pos.set(saved.x,saved.y,0);b.setStationary();if(saved.pocketed)b.state=State.InPocket;b.updateMesh(0);b.ballmesh.mesh.visible=!saved.pocketed;b.ballmesh.shadow.visible=!saved.pocketed}this.c.table.outcome.length=0;this.c.lastEventTime=performance.now();this.c.view.render()}
 private async playReplay(replay:any){
  const generation=++this.replayGeneration;this.replaying=true;this.render();const balls=this.mapBalls();const frames=replay.frames;const duration=(frames.length-1)/replay.fps;const start=performance.now();let nextSound=0;const sounds=replay.events??[];
  await new Promise<void>(resolve=>{const tick=(now:number)=>{if(generation!==this.replayGeneration){resolve();return}const seconds=Math.min(duration,(now-start)/1000);const frame=Math.min(frames.length-2,Math.floor(seconds*replay.fps));const mix=Math.min(1,seconds*replay.fps-frame);const a=frames[frame],b=frames[frame+1];while(nextSound<sounds.length&&sounds[nextSound].t<=seconds){const event=sounds[nextSound++];this.c.sound?.outcomeToSound({type:event.type,incidentSpeed:event.strength})}for(let j=0;j<a.length;j+=4){const ball=balls.get(a[j]);if(!ball)continue;ball.pos.set(a[j+1]+(b[j+1]-a[j+1])*mix,a[j+2]+(b[j+2]-a[j+2])*mix,0);ball.updateMesh(0);ball.ballmesh.mesh.visible=!!a[j+3];ball.ballmesh.shadow.visible=!!a[j+3]}this.c.lastEventTime=now;this.c.view.render();if(seconds>=duration)resolve();else requestAnimationFrame(tick)};requestAnimationFrame(tick)});if(generation===this.replayGeneration)this.replaying=false
 }
}
