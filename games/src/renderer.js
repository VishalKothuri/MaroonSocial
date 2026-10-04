import * as THREE from 'three';
import { initialState,resolveTurn,POOL,CUPS } from './engine.js';
import { pongPull,pongGuide } from './controls.js';
const $=id=>document.getElementById(id),emit=value=>window.webkit?.messageHandlers.game.postMessage(value);
let kind='pool',state=initialState('pool'),online=false,yourSeat=0,players=['Player 1','Player 2'],interactive=true,version=-1;
let aim=0,power=.65,busy=false,replay=null,lastShot=null,replayStart=0,eventsPlayed=0,muted=true,audio,drag=null,placing=false,cuePlacement=null,selected=null,overhead=false;
let meshes=new Map(),cups=new Map(),ball,cue,aimLine,ghost,landingRing,scene,camera,renderer,root,lights,pongGuideTimer=null,pongGuideKey=null;
const colors=[0xf5f0df,0xedb62b,0x1746a0,0xc4282d,0x62338a,0xd87922,0x256747,0x7b2023,0x151415];
const ray=new THREE.Raycaster(),plane=new THREE.Plane(new THREE.Vector3(0,1,0),0),pointer=new THREE.Vector2();
function material(color,extra={}){return new THREE.MeshStandardMaterial({color,roughness:.5,...extra})}
function add(geo,mat,x=0,y=0,z=0,parent=root){let m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=true;m.receiveShadow=true;parent.add(m);return m}
function box(w,h,d,color,x=0,y=0,z=0,extra){return add(new THREE.BoxGeometry(w,h,d),material(color,extra),x,y,z)}
function texture(draw,size=256){let c=document.createElement('canvas');c.width=c.height=size;draw(c.getContext('2d'),size);const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;return t}
const felt=texture((c,n)=>{c.fillStyle='#155c4e';c.fillRect(0,0,n,n);for(let i=0;i<8500;i++){let x=(i*137.508)%n,y=(i*73.31)%n;c.fillStyle=i%2?'#ffffff07':'#00000008';c.fillRect(x,y,1,1)}});felt.wrapS=felt.wrapT=THREE.RepeatWrapping;felt.repeat.set(5,10);
const wood=texture((c,n)=>{c.fillStyle='#512c1e';c.fillRect(0,0,n,n);for(let i=0;i<160;i++){c.strokeStyle=i%2?'#bc795f28':'#170e092c';c.lineWidth=.4+i%3*.3;c.beginPath();for(let y=0;y<=n;y+=8){let x=i*n/160+Math.sin(y*.012+i)*2;y?c.lineTo(x,y):c.moveTo(x,y)}c.stroke()}});
function setup(){
 if(renderer)return;
 renderer=new THREE.WebGLRenderer({canvas:$('table'),antialias:true,alpha:true,powerPreference:'high-performance'});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.0;
 scene=new THREE.Scene();camera=new THREE.PerspectiveCamera(38,1,.01,30);scene.add(new THREE.HemisphereLight(0xfff3d7,0x223f48,1.15));let light=new THREE.DirectionalLight(0xffedc7,2.1);light.position.set(-2,5,2);light.castShadow=true;light.shadow.mapSize.set(1024,1024);light.shadow.camera.left=-2;light.shadow.camera.right=2;light.shadow.camera.top=2;light.shadow.camera.bottom=-2;light.shadow.normalBias=.005;scene.add(light);let fill=new THREE.DirectionalLight(0xa8d1e6,.8);fill.position.set(2,2,-2);scene.add(fill);
 new ResizeObserver(resize).observe($('stage'));requestAnimationFrame(frame);
}
function resize(){if(!renderer)return;let r=$('stage').getBoundingClientRect();renderer.setSize(r.width,r.height,false);camera.aspect=r.width/r.height;camera.updateProjectionMatrix();positionCamera()}
function positionCamera(){
 if(!camera)return;
 const flat=(kind==='pool'&&!replay)||overhead;
 camera.up.set(0,flat?0:1,flat?-1:0);
 const direction=flat?new THREE.Vector3(0,1,0):kind==='chess'?new THREE.Vector3(0,2.2,1.5):new THREE.Vector3(0,2.1,2.4);
 direction.normalize();const target=new THREE.Vector3(0,0,kind==='pool'&&!flat?.16:kind==='pong'?-.02:0);let distance=2;
 // Fit the actual table bounding box in both dimensions for every iPhone/WebView size.
 const halfWidth=kind==='chess'?.6:.6,halfDepth=kind==='chess'?.6:kind==='pool'?1.10:1.175;
 const corners=[];for(const x of [-halfWidth,halfWidth])for(const z of [-halfDepth,halfDepth])for(const y of [0,kind==='pool'?.06:kind==='chess'?.20:.17])corners.push(new THREE.Vector3(x,y,z));
 for(let step=0;step<110;step++){camera.position.copy(direction).multiplyScalar(distance).add(target);camera.lookAt(target);camera.updateMatrixWorld();const projected=corners.map(p=>p.clone().project(camera));if(projected.every(p=>Math.abs(p.x)<.94&&p.y<.94&&p.y>-.88))break;distance*=1.025;}
 $('camera').textContent=flat?'Perspective':'Overhead';
 $('table').setAttribute('aria-label',kind==='pool'&&flat?'Game table, flat overhead pool. Touch to aim; pull back and release to shoot.':'Game table. Pull down for power and sideways to steer; release to throw.');
}
function numberTexture(id){return texture((c,n)=>{let color='#'+new THREE.Color(colors[id>8?id-8:id]).getHexString();c.fillStyle=id>8?'#f5f0df':color;c.fillRect(0,0,n,n);if(id>8){c.fillStyle=color;c.fillRect(0,n*.28,n,n*.44)}if(id){for(let x of [n*.25,n*.75]){c.fillStyle='#fff8e7';c.beginPath();c.arc(x,n*.5,n*.16,0,Math.PI*2);c.fill();c.fillStyle='#161413';c.font=`bold ${n*.19}px Arial`;c.textAlign='center';c.textBaseline='middle';c.fillText(String(id),x,n*.508)}}},256)}
function build(){
 drag=null;clearTimeout(pongGuideTimer);pongGuideTimer=null;pongGuideKey=null;
 if(root){root.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){const mats=Array.isArray(o.material)?o.material:[o.material];for(const m of mats){if(m.map&&m.map!==felt&&m.map!==wood)m.map.dispose();m.dispose()}}});scene.remove(root)}root=new THREE.Group();scene.add(root);meshes=new Map();cups=new Map();cue=null;aimLine=null;ghost=null;landingRing=null;ball=null;selected=null;cuePlacement=null;
 if(kind==='pool'){
  box(1.18,.17,2.18,0x633c28,0,-.095,0,{map:wood,roughness:.35});box(1.06,.01,2.06,0x172522,0,-.004,0);box(1,.007,2,0xffffff,0,.002,0,{map:felt,roughness:.92});
  for(let x of [-.524,.524])for(let z of [-.5,.5])box(.048,.045,.85,0x23765c,x,.022,z);
  for(let z of [-1.024,1.024])box(.85,.045,.048,0x23765c,0,.022,z);
  for(let [x,y]of POOL.pockets){let px=x/1000-.5,pz=y/1000-1;add(new THREE.CylinderGeometry(.061,.054,.07,32),material(0x090b0b),px,-.006,pz);let rim=add(new THREE.TorusGeometry(.061,.007,8,32),material(0xb18a51,{metalness:.65}),px,.025,pz);rim.rotation.x=Math.PI/2;}
  for(let side of [-1,1])for(let z of [-.75,-.25,.25,.75]){let d=box(.01,.002,.01,0xd8c8a0,side*.563,.005,z);d.rotation.y=Math.PI/4;}
  for(let b of state.balls){let m=add(new THREE.SphereGeometry(.027,24,16),material(0xffffff,{map:numberTexture(b.id),roughness:.18,metalness:.04}),b.x/1000-.5,.029,b.y/1000-1);meshes.set(b.id,m)}
  cue=new THREE.Group();root.add(cue);let shaft=add(new THREE.CylinderGeometry(.003,.006,.65,12),material(0xcba477),0,0,0,cue);shaft.rotation.x=Math.PI/2;shaft.position.z=.355;let handle=add(new THREE.CylinderGeometry(.006,.008,.25,12),material(0x3b1818),0,0,.805,cue);handle.rotation.x=Math.PI/2;let tip=add(new THREE.CylinderGeometry(.0033,.0033,.006,12),material(0x70afb4),0,0,.029,cue);tip.rotation.x=Math.PI/2;
  ghost=add(new THREE.SphereGeometry(.027,18,12),material(0xffe9a0,{transparent:true,opacity:.3,depthWrite:false}));
 }else if(kind==='pong'){
  box(1.08,.1,2.34,0x673e29,0,-.08,0,{map:wood});box(1,.035,2.26,0xeadbbd,0,-.0175,0,{roughness:.5});box(.008,.001,2.2,0x651d2c,0,.001,0);for(let z of [-1.03,1.03])box(.85,.002,.018,0x651d2c,0,.002,z);let logo=texture((c,n)=>{c.clearRect(0,0,n,n);c.fillStyle='#5a1c2bcc';c.textAlign='center';c.font='bold 80px Georgia';c.fillText('M',n/2,160)});let mark=add(new THREE.PlaneGeometry(.35,.35),new THREE.MeshStandardMaterial({map:logo,transparent:true,roughness:1}),0,.003,.05);mark.rotation.x=-Math.PI/2;
  for(const c of CUPS){let group=new THREE.Group();root.add(group);group.position.set(c.x,0,c.z);let pts=[[.047,0],[.049,.01],[.071,.145],[.074,.149],[.069,.151],[.065,.143],[.044,.012],[0,.012]].map(([x,y])=>new THREE.Vector2(x,y));let cup=add(new THREE.LatheGeometry(pts,40),material(0x861f33,{side:THREE.DoubleSide,roughness:.3}),0,0,0,group);let ring=add(new THREE.TorusGeometry(.07,.003,8,40),material(0xf3e6d5),0,.15,0,group);ring.rotation.x=Math.PI/2;let drink=add(new THREE.CircleGeometry(.051,32),material(0x9c5421,{roughness:.14,transparent:true,opacity:.88}),0,.06,0,group);drink.rotation.x=-Math.PI/2;cups.set(c.id,group)}ball=add(new THREE.SphereGeometry(.02,24,18),material(0xfff6e2,{roughness:.6}),0,.23,1.02);
  landingRing=add(new THREE.RingGeometry(.042,.051,40),new THREE.MeshBasicMaterial({color:0x500000,side:THREE.DoubleSide,transparent:true,opacity:.9,depthWrite:false}),0,.006,0);landingRing.rotation.x=-Math.PI/2;
 }else buildChess();
 if(kind!=='chess'){let geo=new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(),new THREE.Vector3()]);aimLine=new THREE.Line(geo,new THREE.LineDashedMaterial({color:0xffefb4,dashSize:.03,gapSize:.025,transparent:true,opacity:.75}));root.add(aimLine)}
 sync();resize();
}
function buildChess(){
 box(1.18,.09,1.18,0x4b291f,0,-.057,0,{map:wood});let ranks=state.fen.split(' ')[0].split('/');
 for(let row=0;row<8;row++){let col=0;for(let char of ranks[row]){if(/\d/.test(char)){col+=Number(char);continue}let x=(col-3.5)*.135,z=(row-3.5)*.135,square=String.fromCharCode(97+col)+(8-row);let white=char===char.toUpperCase(),m=material(white?0xeddfbd:0x4d1824,{roughness:.3});let type=char.toLowerCase();let points=[[.035,0],[.04,.01],[.035,.019],[.028,.025],[.014,.048],[.012,.068],[.026,.073],[.023,.08]];
 let height=type==='p'?1:type==='k'?1.6:1.35;let mesh=add(new THREE.LatheGeometry(points.map(([x,y])=>new THREE.Vector2(x,y*height)),24),m,x,.011,z);mesh.userData.square=square;
 let cap=add(type==='r'?new THREE.CylinderGeometry(.027,.027,.023,8):type==='n'?new THREE.ConeGeometry(.027,.052,4):new THREE.SphereGeometry(type==='p'?.019:.023,16,12),m,x,.095*height,z);cap.userData.square=square;if(type==='n'){cap.rotation.z=-.3;cap.rotation.y=Math.PI/4}if(type==='k'){let cross=box(.038,.01,.009,white?0xeddfbd:0x4d1824,x,.185,z);cross.userData.square=square;let vertical=box(.01,.039,.009,white?0xeddfbd:0x4d1824,x,.182,z);vertical.userData.square=square}col++}}
 for(let r=0;r<8;r++)for(let c=0;c<8;c++){let m=box(.135,.012,.135,(r+c)%2?0x6d4536:0xded0ab,(c-3.5)*.135,0,(r-3.5)*.135);m.userData.square=String.fromCharCode(97+c)+(8-r);meshes.set(m.userData.square,m)}
}
function canAct(){return interactive&&!busy&&state.winner===null&&!state.finished&&(!online||state.turn===yourSeat)}
function sync(){
 if(kind==='pool')for(let b of state.balls){let m=meshes.get(b.id);m.visible=!b.pocketed;m.position.set(b.x/1000-.5,.029,b.y/1000-1)}
 if(kind==='pong'){for(let c of CUPS)cups.get(c.id).visible=!state.removed[state.turn].includes(c.id);ball.position.set(0,.23,1.02);ball.visible=true}
 hud();updateAim();positionCamera();
}
function hud(){
 $('turn').textContent=state.winner!==null?`${players[state.winner]} wins`:state.finished?'Draw':online?`${state.turn===yourSeat?'Your turn':players[state.turn]+"’s turn"}`:`${players[state.turn]} · ${state.shots===0?'ready':'your turn'}`;
 $('score').textContent=kind==='pool'?state.groups.map((g,i)=>`${i===yourSeat&&online?'You':players[i]}: ${g||'open table'}${g?' · '+state.balls.filter(b=>!b.pocketed&&(g==='solids'?b.id>0&&b.id<8:b.id>8)).length+' left':''}`).join('  /  '):kind==='pong'?`${players[0]}  ${state.removed[0].length}/6     ·     ${players[1]}  ${state.removed[1].length}/6`:'White · '+players[0]+'   /   Black · '+players[1];
 $('replayShot').disabled=busy||!lastShot||kind==='chess';$('status').textContent=state.status;$('toast').textContent=busy?'Watching the shot…':placing?'Tap an empty spot on the felt':kind==='chess'?(selected?'Choose a highlighted square':'Choose a piece'):'';$('toast').style.display=$('toast').textContent?'block':'none';
 $('hint').textContent=kind==='pool'?'Tap to aim · pull back and release':kind==='pong'?'Pull down for power · sideways to steer · release':'Tap a piece, then its destination';
 $('camera').style.display=kind==='pool'&&!replay?'none':'block';
 $('shoot').textContent=busy?'Shot in motion…':!canAct()&&online?'Waiting for opponent':kind==='pool'?'Take shot':kind==='pong'?'Throw ball':'Choose a move';
 $('shoot').disabled=!canAct()||kind==='chess';$('power').disabled=$('aim').disabled=!canAct();$('left').disabled=$('right').disabled=!canAct();
 $('aimrow').style.display=$('powerrow').style.display=kind==='chess'?'none':'flex';$('throwType').style.display=kind==='pong'?'block':'none';$('promotion').style.display=kind==='chess'?'block':'none';$('shoot').style.display=kind==='chess'?'none':'block';$('reset').style.display=online?'none':'block';$('ballInHand').style.display=kind==='pool'&&state.ballInHand&&canAct()?'block':'none';
 $('legal').style.display=kind==='chess'&&canAct()?'flex':'none';$('legal').replaceChildren();if(kind==='chess'&&canAct())for(let m of state.legal.filter(m=>!selected||m.from===selected)){if(m.promotion&&m.promotion!==$('promotion').value)continue;let b=document.createElement('button');b.textContent=m.from+' → '+m.to;b.onclick=()=>shoot(m);$('legal').append(b)}
 $('aim').min=kind==='pong'?-13.75:-180;$('aim').max=kind==='pong'?13.75:180;
}
function updateAim(){if(!root||kind==='chess')return;let active=canAct();if(cue){let b=cuePlacement||state.balls[0];cue.visible=active&&!placing;cue.position.set(b.x/1000-.5,.03,b.y/1000-1);cue.rotation.y=-aim;cue.translateZ(power*.10);if(cuePlacement)meshes.get(0).position.set(b.x/1000-.5,.029,b.y/1000-1)}
 let points=[];if(kind==='pool'){let b=cuePlacement||state.balls[0],x=b.x/1000-.5,z=b.y/1000-1,dx=Math.sin(aim),dz=-Math.cos(aim),distance=.65;for(let other of state.balls){if(!other.id||other.pocketed)continue;let ox=other.x/1000-.5-x,oz=other.y/1000-1-z,dot=ox*dx+oz*dz,perp=ox*ox+oz*oz-dot*dot;if(dot>0&&perp<.054*.054)distance=Math.min(distance,dot-Math.sqrt(.054*.054-perp))}distance=Math.max(0,distance);points=[new THREE.Vector3(x,.03,z),new THREE.Vector3(x+dx*distance,.03,z+dz*distance)];ghost.visible=active&&!placing;ghost.position.copy(points[1]);}
 else if(active&&!pongGuideTimer){pongGuideTimer=setTimeout(()=>{pongGuideTimer=null;if(kind!=='pong'||!canAct())return;const key=[state.shots,state.turn,aim.toFixed(4),power.toFixed(3),$('throwType').value].join(':');if(key===pongGuideKey)return;pongGuideKey=key;const guide=pongGuide(state,{aim,power,bounce:$('throwType').value==='bounce'});aimLine.geometry.dispose();aimLine.geometry=new THREE.BufferGeometry().setFromPoints(guide.points.map(p=>new THREE.Vector3(...p)));aimLine.computeLineDistances();aimLine.visible=true;if(landingRing&&guide.target){landingRing.position.set(guide.target[0],.006,guide.target[2]);landingRing.visible=Math.abs(guide.target[0])<.5&&Math.abs(guide.target[2])<1.13}},80)}
 if(kind==='pool'){aimLine.geometry.dispose();aimLine.geometry=new THREE.BufferGeometry().setFromPoints(points);aimLine.computeLineDistances()}aimLine.visible=active&&!placing;if(landingRing&&!active)landingRing.visible=false;
 $('aim').value=aim*180/Math.PI;$('power').value=power*100;$('powerValue').textContent=Math.round(power*100)+'%';
}
function sound(type){if(muted)return;try{audio??=new (window.AudioContext||window.webkitAudioContext)();audio.resume();let osc=audio.createOscillator(),gain=audio.createGain();osc.connect(gain);gain.connect(audio.destination);osc.type=type==='cup'?'sine':'triangle';osc.frequency.setValueAtTime(type==='cup'?760:type==='pocket'?140:920,audio.currentTime);osc.frequency.exponentialRampToValueAtTime(80,audio.currentTime+.09);gain.gain.setValueAtTime(.10,audio.currentTime);gain.gain.exponentialRampToValueAtTime(.001,audio.currentTime+.13);osc.start();osc.stop(audio.currentTime+.14)}catch{}}
function play(data,next){lastShot={data,next};busy=true;replay={...data,next};replayStart=performance.now();eventsPlayed=0;if(kind==='pool')overhead=!(online&&state.turn!==yourSeat);hud();positionCamera();if(cue)cue.visible=false;if(ghost)ghost.visible=false;if(aimLine)aimLine.visible=false;if(landingRing)landingRing.visible=false;emit({type:'haptic',style:'shot'});}
async function shoot(action){if(!canAct())return;const input=action||{aim,power,...(kind==='pool'?{spin:0,...(cuePlacement?{cue:cuePlacement}:{})}:{bounce:$('throwType').value==='bounce'})};placing=false;if(online){busy=true;hud();emit({type:'shot',input});return}try{const outcome=resolveTurn(kind,state,input);if(kind==='chess'){state=outcome.state;build();sound('hit')}else play(outcome.replay,outcome.state)}catch(e){$('status').textContent=e.message;busy=false;hud()}}
function frame(time){requestAnimationFrame(frame);if(!renderer)return;if(replay){let elapsed=(time-replayStart)/1000,frames=replay.frames||[],idx=Math.min(frames.length-1,Math.floor(elapsed*replay.fps)),fraction=Math.min(1,elapsed*replay.fps-idx),a=frames[idx],b=frames[Math.min(idx+1,frames.length-1)];if(a&&b){if(kind==='pool'){for(let i=0;i<a.length;i+=4){let m=meshes.get(a[i]);if(!m)continue;let nx=(a[i+1]+(b[i+1]-a[i+1])*fraction)/1000-.5,nz=(a[i+2]+(b[i+2]-a[i+2])*fraction)/1000-1;m.rotation.x+=(nz-m.position.z)/.027;m.rotation.z-=(nx-m.position.x)/.027;m.position.set(nx,.029,nz);m.visible=Boolean(a[i+3]);}}else if(kind==='pong'){ball.position.set(...a.map((v,i)=>v+(b[i]-v)*fraction));ball.rotation.x+=.08;}}
 while(eventsPlayed<(replay.events?.length||0)&&replay.events[eventsPlayed].t<=elapsed){let event=replay.events[eventsPlayed++];sound(event.type);if(['cup','pocket'].includes(event.type))emit({type:'haptic',style:'score'})}
 if(elapsed>=Math.max(replay.duration||0,(frames.length-1)/(replay.fps||30))+.22){state=replay.next;replay=null;busy=false;cuePlacement=null;sync();emit({type:'settled'})}}
 renderer.render(scene,camera);}
function worldPoint(event){let r=$('table').getBoundingClientRect();if(!r.width||!r.height||!Number.isFinite(event.clientX)||!Number.isFinite(event.clientY))return null;pointer.set((event.clientX-r.left)/r.width*2-1,-(event.clientY-r.top)/r.height*2+1);ray.setFromCamera(pointer,camera);return ray.ray.intersectPlane(plane,new THREE.Vector3())}
function updatePull(event){
 if(!drag||event.pointerId!==drag.pointerId||!canAct())return;
 const p=worldPoint(event);if(p)drag.last=p;
 if(kind==='pong'){
  const end={x:event.clientX,y:event.clientY};drag.pull=pongPull(drag.screen,end,$('table').getBoundingClientRect(),drag.aim);
  if(Math.hypot(end.x-drag.screen.x,end.y-drag.screen.y)>4){aim=drag.pull.aim;if(end.y-drag.screen.y>4)power=drag.pull.power;updateAim()}return;
 }
 if(!p)return;
 const dx=p.x-drag.start.x,dz=p.z-drag.start.z,distance=Math.hypot(dx,dz);
 if(distance>.04){aim=Math.atan2(-dx,dz);if(kind==='pong')aim=Math.max(-.42,Math.min(.42,aim));power=Math.max(.03,Math.min(1,distance/.65));updateAim()}
}
$('table').addEventListener('pointerdown',e=>{if(drag||!canAct()||e.isPrimary===false||e.button!==0)return;let p=worldPoint(e);if(!p)return;if(kind==='chess'){let hits=ray.intersectObjects(root.children,true),square=hits.find(h=>h.object.userData.square)?.object.userData.square;if(!square)return;if(selected&&state.legal.some(m=>m.from===selected&&m.to===square)){shoot({from:selected,to:square,promotion:$('promotion').value});selected=null;return}selected=state.legal.some(m=>m.from===square)?square:null;for(let [s,m]of meshes)m.material.emissive.setHex(s===selected?0x98713b:state.legal.some(l=>l.from===selected&&l.to===s)?0x25492a:0x000000);hud();return}
 if(placing){let candidate={x:Math.round((p.x+.5)*1000),y:Math.round((p.z+1)*1000)};if(candidate.x>35&&candidate.x<965&&candidate.y>35&&candidate.y<1965&&!state.balls.some(b=>b.id&&!b.pocketed&&Math.hypot(b.x-candidate.x,b.y-candidate.y)<56)&&!POOL.pockets.some(([x,y])=>Math.hypot(x-candidate.x,y-candidate.y)<80)){cuePlacement=candidate;placing=false;hud();updateAim()}return}
 drag={start:p,last:p,pointerId:e.pointerId,screen:{x:e.clientX,y:e.clientY},aim};
 // WebKit can decline capture after a system gesture or for a synthetic input.
 // The originating pointer still has a valid release path on the canvas.
 try{$('table').setPointerCapture(e.pointerId)}catch{}
});
$('table').addEventListener('pointermove',updatePull);
$('table').addEventListener('pointerup',e=>{
 if(!drag||e.pointerId!==drag.pointerId)return;
 // Release coordinates are authoritative: browsers may coalesce or omit the
 // final pointermove. Recompute BOTH power and aim before deciding to shoot.
 updatePull(e);const d=drag;drag=null;
 try{if($('table').hasPointerCapture(e.pointerId))$('table').releasePointerCapture(e.pointerId)}catch{}
 if(!canAct())return;
 if(kind==='pong'?d.pull?.releases:Math.hypot(d.last.x-d.start.x,d.last.z-d.start.z)>.09){shoot();return}
 if(kind==='pool'){let b=cuePlacement||state.balls[0];aim=Math.atan2(d.last.x-(b.x/1000-.5),-(d.last.z-(b.y/1000-1)))}else aim=Math.max(-.24,Math.min(.24,Math.atan2(d.last.x,1.02-d.last.z)));updateAim()
});
for(const name of ['pointercancel','lostpointercapture'])$('table').addEventListener(name,e=>{if(drag?.pointerId===e.pointerId)drag=null});
$('replayShot').onclick=()=>{if(busy||!lastShot)return;if(kind==='pong'){for(const c of CUPS)cups.get(c.id).visible=!lastShot.next.removed[lastShot.data.player].includes(c.id)||c.id===lastShot.data.hit;ball.visible=true}play(lastShot.data,lastShot.next)};
$('shoot').onclick=()=>shoot();$('aim').oninput=()=>{aim=Number($('aim').value)*Math.PI/180;updateAim()};$('power').oninput=()=>{power=Number($('power').value)/100;updateAim()};$('left').onclick=()=>{aim=Math.max(kind==='pong'?-.24:-Math.PI,aim-Math.PI/180);updateAim()};$('right').onclick=()=>{aim=Math.min(kind==='pong'?.24:Math.PI,aim+Math.PI/180);updateAim()};$('throwType').onchange=updateAim;$('promotion').onchange=hud;$('ballInHand').onclick=()=>{placing=!placing;hud();updateAim()};$('sound').onclick=()=>{muted=!muted;$('sound').textContent=muted?'Sound off':'Sound on';sound('hit')};$('camera').onclick=()=>{overhead=!overhead;$('camera').textContent=overhead?'Perspective':'Overhead';positionCamera()};$('reset').onclick=()=>{if(state.shots&&!window.confirm('Start a new local game?'))return;state=initialState(kind);replay=null;lastShot=null;busy=false;aim=0;build()};$('ruleButton').onclick=()=>{$('rules').style.display='block';$('rulesTitle').textContent=kind==='pool'?'Eight-ball · house rules':kind==='pong'?'Six-cup pong':'Classic chess';$('rulesText').textContent=kind==='pool'?'Break the rack, then claim solids or stripes with your first legal pocket. Sink your group before the eight. A scratch, no object contact, wrong first ball, or no cushion/pocket after contact gives your opponent ball in hand. Sink your own ball to continue. The eight is respotted on the break; an early eight loses. Call-pocket and three-point break rules are not used. Tap to aim or pull backwards and release. Use Place cue after a foul.':kind==='pong'?'Two players take alternating throws at their own six-cup rack. Clear all six to win. Choose an arc or a table bounce. The ball can bounce off the table, rim, and cup walls; a miss passes the turn. There is no redemption round. Pull down for power. Pull sideways to steer away from your finger. The arc and landing ring follow the physics up to the first cup contact. Use the fine controls below for precision.':'Classic legal chess including castling, en passant, promotion, checkmate, stalemate, repetition, fifty-move and insufficient-material draws. White moves first. Tap a piece and a highlighted destination, or use the accessible move buttons below.'};$('closeRules').onclick=()=>{$('rules').style.display='none'};
window.MaroonGame={configure(config){setup();let changed=kind!==config.kind;if(changed){lastShot=null;aim=0;power=config.kind==='pong'?.3:.65;overhead=config.kind==='pool'}kind=config.kind;online=!!config.online;yourSeat=config.yourSeat??0;players=config.players||['Player 1','Player 2'];interactive=config.interactive!==false;let newVersion=config.version??0;if(config.error){busy=false;hud();$('status').textContent=config.error;return}if(config.state){let next=config.state;if(config.replay?.frames)lastShot={data:config.replay,next};if(!changed&&version>=0&&newVersion>version&&config.replay?.frames&&root){play(config.replay,next)}else if(changed||version!==newVersion||!root){state=next;busy=false;replay=null;build()}else{if(!replay)busy=false;hud();updateAim()}}else if(changed||!root){state=initialState(kind);busy=false;build()}version=newVersion;hud()},pause(){audio?.suspend();},resume(){if(!muted)audio?.resume();}};
try{setup();emit({type:'ready'});if(!window.webkit)window.MaroonGame.configure({kind:new URLSearchParams(location.search).get('kind')||'pool'});}catch(error){$('turn').textContent='The table could not load';$('status').textContent=error.message;emit({type:'error',message:error.message})}
