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
