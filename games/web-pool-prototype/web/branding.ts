// Local presentation adapter; upstream physics and geometry remain unmodified.
import {Camera} from '../upstream/src/view/camera'
import {Room} from '../upstream/src/view/room'
import {Grid} from '../upstream/src/view/grid'
export function installPresentation(){
 const grid=Grid.prototype.generateLineSegments
 Grid.prototype.generateLineSegments=function(isSnooker=false){const lines=grid.call(this,isSnooker);lines.visible=false;return lines}
 // Automatic controller transitions must never turn the shooter's flat table.
 // The UI omits the upstream camera toggle while the shooter is kept flat.
 Camera.prototype.suggestMode=function(){}
 const force=Camera.prototype.forceMode
 Camera.prototype.forceMode=function(mode){return force.call(this,this.topView)}
 const room=Room.prototype.generateRoom
 Room.prototype.generateRoom=function(){const group=room.call(this);group.traverse((mesh:any)=>{if(!mesh.isMesh)return;mesh.material.color.setHex(0x181416);mesh.material.vertexColors=false;mesh.material.needsUpdate=true});return group}
}
export function styleTable(container:any){
 // Upstream LOD 3 deliberately uses a 1x render buffer. Keep its geometry and
 // antialiasing, but render at native scale up to 2x for crisp phone-sized balls.
 container.view.renderer?.setPixelRatio(Math.min(2,Math.max(1,globalThis.devicePixelRatio||1)))
 container.view.assets.table.traverse((mesh:any)=>{if(!mesh.isMesh)return;const list=Array.isArray(mesh.material)?mesh.material:[mesh.material];for(const m of list){const name=String(m.name??'').toLowerCase();if(!m.color)continue;if(name.includes('cloth')||name.includes('cushion')){m.map=null;m.color.setHex(name.includes('shade')?0x123627:0x1c6248)}else if(name.includes('wood')||name.includes('rail')||name.includes('frame')){m.map=null;m.color.setHex(0x500000)}m.needsUpdate=true}})
 container.view.camera.forceMode(container.view.camera.topView)
}
