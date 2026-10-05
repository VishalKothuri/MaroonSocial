/** Real upstream model/controller/DOM integration; only the GPU and HTTP are absent. */
import fs from 'node:fs'
import path from 'node:path'
import {Container} from '../upstream/src/container/container'
import {Assets} from '../upstream/src/view/assets'
import {Session} from '../upstream/src/network/client/session'
import {OnlinePool} from './online'
import {AngleInput} from '../upstream/src/view/dom/angleinput'

test('the published DOM can enter online waiting using real upstream controller and cue inputs',async()=>{
 jest.spyOn(HTMLCanvasElement.prototype,'getContext').mockReturnValue(null)
 document.body.innerHTML=fs.readFileSync(path.resolve(__dirname,'index.html'),'utf8')
 if(!customElements.get('angle-input'))customElements.define('angle-input',AngleInput)
 Session.init('test-client','Practice','test-table',false)
 const c=new Container({element:document.getElementById('viewP1'),log:()=>{},assets:Assets.localAssets('eightball'),ruletype:'eightball',isSinglePlayer:true})
 globalThis.fetch=jest.fn(async()=>({ok:true,json:async()=>({})}))as any
 const online=new OnlinePool(c)
 await online.connect({endpoint:'https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/web-pool',token:'a'.repeat(64),expiresAt:Date.now()/1000+3600})
 expect(document.querySelector('.preview-pill')?.textContent).toBe('Pool · online')
 expect((document.getElementById('cueHit')as HTMLButtonElement).disabled).toBe(true)
 expect(document.getElementById('onlineAction')?.textContent).toBe('Find opponent')
 expect(c.table.balls).toHaveLength(16)
 await online.disconnect()
 jest.restoreAllMocks()
})

test('spin presets map to the upstream cue offsets with the correct signs and follow the hit button state',async()=>{
 jest.spyOn(HTMLCanvasElement.prototype,'getContext').mockReturnValue(null)
 document.body.innerHTML=fs.readFileSync(path.resolve(__dirname,'index.html'),'utf8')
 if(!customElements.get('angle-input'))customElements.define('angle-input',AngleInput)
 ;(HTMLDialogElement.prototype as any).showModal??=function(){this.open=true}
 ;(HTMLDialogElement.prototype as any).close??=function(){this.open=false}
 Session.init('test-client','Practice','test-table',false)
 const c=new Container({element:document.getElementById('viewP1'),log:()=>{},assets:Assets.localAssets('eightball'),ruletype:'eightball',isSinglePlayer:true})
 const {installShotControls}=await import('./controls')
 const dispose=installShotControls(c)
 const hit=document.getElementById('cueHit')as HTMLButtonElement,open=document.getElementById('openSpin')as HTMLButtonElement
 c.table.cue.aimInputs.setDisabled(false);await new Promise(r=>setTimeout(r,0))
 expect(hit.disabled).toBe(false);expect(open.disabled).toBe(false)
 const expected:Record<string,[number,number]>={'Topspin':[0,0.25],'Backspin':[0,-0.25],'Left':[0.25,0],'Right':[-0.25,0],'Center':[0,0]}
 for(const button of Array.from(document.querySelectorAll<HTMLButtonElement>('[data-spin]'))){
  button.click();const [x,y]=expected[button.textContent!.trim()]
  expect(c.table.cue.aim.offset.x).toBeCloseTo(x,5);expect(c.table.cue.aim.offset.y).toBeCloseTo(y,5)
 }
 c.table.cue.aimInputs.setDisabled(true);await new Promise(r=>setTimeout(r,0))
 expect(hit.disabled).toBe(true);expect(open.disabled).toBe(true)
 dispose();jest.restoreAllMocks()
})
