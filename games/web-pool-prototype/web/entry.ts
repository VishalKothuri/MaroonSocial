// Maroon Social standalone preview, GPL-3.0. Upstream physics is unmodified.
import {BrowserContainer} from '../upstream/src/container/browsercontainer'
import {AngleInput} from '../upstream/src/view/dom/angleinput'
import {OnlinePool} from './online'
import {installShotControls} from './controls'
import {installPresentation,styleTable} from './branding'
installPresentation()
import {Session} from '../upstream/src/network/client/session'
customElements.define('angle-input', AngleInput)
const requested=new URLSearchParams(location.search)
const params=new URLSearchParams({ruletype:requested.get('game')==='nineball'?'nineball':'eightball',practice:'true',lod:'3',userName:'Practice',userId:'local-practice'})
let online:OnlinePool|undefined;let pendingConfig:any
Object.assign(globalThis,{MaroonPool:{connect:async(config:any)=>{if(online)await online.connect(config);else pendingConfig=config},disconnect:async()=>{pendingConfig=undefined;await online?.disconnect()}}})
const view=document.getElementById('viewP1')!
const loading=document.getElementById('previewLoading')!
const failure=document.getElementById('previewFailure')!
const reportFailure=()=>{loading.hidden=true;failure.hidden=false}
try {
 const container=new BrowserContainer(view,params)
 const original=container.onAssetsReady.bind(container)
 container.onAssetsReady=()=>{
  try{original();styleTable(container.container);installShotControls(container.container);loading.hidden=true;online=new OnlinePool(container.container);if(pendingConfig){const config=pendingConfig;pendingConfig=undefined;void online.connect(config).catch(reportFailure)}}
  catch(error){console.error('Pool preview failed',error);reportFailure()}
 }
 container.start()
 document.getElementById('resetTable')!.addEventListener('click',()=>location.reload())
 document.getElementById('showInstructions')!.addEventListener('click',()=>{(document.getElementById('instructions') as HTMLDialogElement).showModal()})
 document.getElementById('closeInstructions')!.addEventListener('click',()=>{(document.getElementById('instructions') as HTMLDialogElement).close()})
 document.addEventListener('visibilitychange',()=>{
  // Rendering pauses naturally with requestAnimationFrame in hidden tabs; no
  // online presence or location is collected by this standalone practice page.
  if(!document.hidden)window.dispatchEvent(new Event('resize'))
 })
 // Native app integration must use a new versioned authoritative resolver. This
 // handle is local diagnostics only, never a network or trusted score endpoint.
 Object.assign(globalThis,{maroonPoolPreview:{container,session:()=>Session.getInstance()}})
 window.setTimeout(()=>{if(!loading.hidden)reportFailure()},20000)
}catch(error){console.error('Pool preview failed',error);reportFailure()}
