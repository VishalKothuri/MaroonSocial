// Presentation only: the existing upstream cue controls still own shot inputs.
import {Vector3} from 'three'
import type {Container} from '../upstream/src/container/container'

export function installShotControls(container:Container) {
 const open=document.getElementById('openSpin') as HTMLButtonElement
 const dialog=document.getElementById('spinDialog') as HTMLDialogElement
 const hit=document.getElementById('cueHit') as HTMLButtonElement
 const close=document.getElementById('closeSpin') as HTMLButtonElement
 if(!open||!dialog||!hit||!close){console.warn('Spin controls missing from this page; shot inputs stay available.');return ()=>{}}
 const sync=()=>{open.disabled=hit.disabled;if(hit.disabled&&dialog.open)dialog.close()}
 const observer=new MutationObserver(sync);observer.observe(hit,{attributes:true,attributeFilter:['disabled']});sync()
 open.addEventListener('click',()=>{if(!hit.disabled)dialog.showModal()})
 close.addEventListener('click',()=>dialog.close())
 dialog.addEventListener('click',event=>{if(event.target!==dialog)return;const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close()})
 dialog.querySelectorAll<HTMLButtonElement>('[data-spin]').forEach(button=>button.addEventListener('click',()=>{
  if(hit.disabled)return
  const [x,y]=button.dataset.spin!.split(',').map(Number)
  container.table.cue.setSpin(new Vector3(x,y,0),container.table)
  container.lastEventTime=performance.now()
 }))
 return ()=>observer.disconnect()
}
