import {CallSignalBuffer} from './call-signals.js';
const $=id=>document.getElementById(id),API='https://myxbghfbapbfffkpndwo.supabase.co/functions/v1/';
const callSignals=new CallSignalBuffer();
const instance=crypto.randomUUID(),seenMessages=new Set(),tags=new Set(),suggestions=['music','gaming','football','coffee','gym','engineering','art','movies','study','food','outdoors','pets'];
let token=sessionStorage.getItem('maroon.browser.session'),snapshot=null,generation=0,busy=false,timer,pollFailures=0,tail=Promise.resolve(),selectedPerson=null,callSession=null,lastSignal=0,ackSession=null,pendingMessage=null,pendingRequest=null,continued=false,editing=false;
function feedback(text){$('feedback').textContent=text||'';$('feedback').hidden=!text;}
function node(tag,text,className){const element=document.createElement(tag);if(text!==undefined)element.textContent=text;if(className)element.className=className;return element;}
function renderTags(parent,values){parent.replaceChildren(...values.slice(0,6).map(value=>node('span','#'+value,'tag')));}
function renderSelection(){
 $('selected-tags').replaceChildren(...Array.from(tags).map(value=>{const button=node('button','#'+value+' ×','tag');button.type='button';button.setAttribute('aria-label','Remove '+value);button.onclick=()=>{tags.delete(value);renderSelection();};return button;}));
 $('tag-count').textContent=tags.size+' / 6';$('interest-input').disabled=tags.size>=6;$('add-tag').disabled=tags.size>=6;
 $('suggested-tags').replaceChildren(...suggestions.map(value=>{const button=node('button','#'+value);button.type='button';button.setAttribute('aria-pressed',String(tags.has(value)));button.disabled=!tags.has(value)&&tags.size>=6;button.onclick=()=>{tags.has(value)?tags.delete(value):tags.add(value);renderSelection();};return button;}));
}
function update(){
 const state=snapshot?.state||'idle',waiting=state==='waiting',session=['connecting','connected'].includes(state),profileSetup=!!token&&!!snapshot&&(!snapshot?.profile||editing||(!waiting&&!session));
 $('pair-screen').hidden=!!token;$('resume-screen').hidden=!token||!!snapshot;$('profile-screen').hidden=!profileSetup;$('lobby-screen').hidden=!waiting;$('session-screen').hidden=!session;
 $('disconnect').hidden=!token;$('edit-profile').hidden=!token||session||profileSetup;$('leave').hidden=!waiting&&!session;
 $('leave').textContent=session?'End conversation':'Leave lobby';$('leave').disabled=busy;
 $('connection-status').textContent=!token?'Connect your account to begin':session?(state==='connected'?'Connected with '+snapshot.session.peer.username:'Confirming you’re both here…'):waiting?'You’re visible in the waiting lobby':'Choose how people see you';
 $('presence').className='presence '+(state==='connected'?'connected':waiting||state==='connecting'?'waiting':'');
 $('message').disabled=state!=='connected';$('message-form').querySelector('button').disabled=busy||state!=='connected'||!$('message').value.trim();
 $('continue-chat').disabled=busy||state!=='connected'||continued;$('continue-chat').textContent=continued?'Request sent to Inbox':'Keep chatting in Inbox';
 $('report').disabled=busy||state!=='connected';$('block').disabled=busy||state!=='connected';
 $('pair-form').querySelector('button').disabled=busy;$('profile-form').querySelector('[type=submit]').disabled=busy;
 $('incoming').querySelectorAll('button').forEach(button=>button.disabled=busy);
 $('outgoing').querySelectorAll('button').forEach(button=>button.disabled=busy);
 if(session){$('peer-name').textContent=snapshot.session.peer.username;renderTags($('peer-tags'),snapshot.session.peer.tags);$('session-state').textContent=state==='connecting'?'Confirming…':'Connected';$('connecting-note').hidden=state==='connected';}
}
async function request(endpoint,action,payload={},options={}){
 const sentToken=token;
 const response=await fetch(API+endpoint,{method:'POST',headers:{'Content-Type':'application/json',...(sentToken?{'X-Maroon-Web-Session':sentToken}:{})},body:JSON.stringify({action,...payload}),signal:AbortSignal.timeout(15000),...options});
 let value;try{value=await response.json();}catch{throw new Error('The service did not respond. Please try again.');}
 if(!response.ok||value.error){if(response.status===401&&sentToken&&token===sentToken)clearSession();throw new Error(value.error||'Couldn’t complete that request. Please retry.');}return value;
}
function discovery(action,payload={}){const epoch=generation,body={instance,after_signal:lastSignal,...payload};const next=tail.catch(()=>{}).then(async()=>{if(epoch!==generation||document.hidden)throw new DOMException('Request cancelled','AbortError');const value=await request('discovery',action,body);if(epoch!==generation||document.hidden)throw new DOMException('Request cancelled','AbortError');return value;});tail=next;return next;}
function stopCall(){callSession=null;callSignals.reset();try{$('call-frame').contentWindow.MaroonCall?.stop();}catch{}}
function endLocally(){generation++;clearTimeout(timer);stopCall();resetConversation();if(snapshot)snapshot={...snapshot,state:'ended',session:null,people:[],incoming:[],outgoing:null};update();}
function clearSession(){generation++;clearTimeout(timer);token=null;sessionStorage.removeItem('maroon.browser.session');snapshot=null;stopCall();resetConversation();update();}
function resetConversation(){seenMessages.clear();lastSignal=0;pendingMessage=null;ackSession=null;continued=false;$('messages').replaceChildren();$('message').value='';}
function fillProfile(){if(!snapshot?.profile)return;$('username').value=snapshot.profile.username;tags.clear();snapshot.profile.tags.forEach(tag=>tags.add(tag));renderSelection();}
function renderLobby(){
 const people=snapshot.people||[];$('people-count').textContent=people.length+' waiting';$('empty-lobby').hidden=people.length>0;
 $('people-grid').replaceChildren(...people.map(person=>{const button=node('button',undefined,'person-card');button.append(node('div',person.username.slice(0,1).toUpperCase(),'person-avatar'),node('h3',person.username));const interests=node('div',undefined,'tags');renderTags(interests,person.tags);button.append(interests,node('span','● Waiting now','waiting-label'));button.onclick=()=>openProfile(person);return button;}));
 $('incoming').replaceChildren(...(snapshot.incoming||[]).map(invite=>{const card=node('div',undefined,'incoming-card'),info=node('div');info.append(node('strong',invite.from.username+' wants to connect'));const interests=node('div',undefined,'tags');renderTags(interests,invite.from.tags);info.append(interests);card.append(info);const accept=node('button','Accept','primary'),decline=node('button','Decline','quiet');accept.disabled=decline.disabled=busy;accept.onclick=()=>perform(async()=>apply(await discovery('accept',{request_id:invite.id}),generation));decline.onclick=()=>perform(async()=>apply(await discovery('decline',{request_id:invite.id}),generation));card.append(accept,decline);return card;}));
 const outgoing=snapshot.outgoing;$('outgoing').hidden=!outgoing;
 if(outgoing){const cancel=node('button','Cancel request','quiet');cancel.disabled=busy;cancel.onclick=()=>perform(async()=>apply(await discovery('cancel',{request_id:outgoing.id}),generation));$('outgoing').replaceChildren(node('span','Waiting for '+outgoing.to.username+' to accept…'),cancel);}
 if(selectedPerson&&!people.some(person=>person.id===selectedPerson.id)){$('send-request').disabled=true;$('send-request').textContent='No longer waiting';}
}
async function startCall(session,epoch){
 if(callSession===session.id)return;callSession=session.id;
 try{const media=await discovery('media',{session_id:session.id,allow_direct:$('allow-direct').checked});if(epoch!==generation||snapshot?.session?.id!==session.id||snapshot.state!=='connected')return;
  const frame=$('call-frame');if(!frame.contentWindow.MaroonCall)throw new Error('Video controls did not load. Reload this page.');
  // Do not stop presence heartbeats while the permission prompt is open.
  const version=callSignals.version;
  void frame.contentWindow.MaroonCall.start({initiator:session.initiator,video:true,iceServers:media.ice_servers||[],transport:media.media_transport||'direct'}).then(()=>{
   if(epoch===generation&&callSession===session.id)callSignals.ready(version,item=>frame.contentWindow.MaroonCall.receive(item));
  }).catch(error=>{if(epoch===generation)feedback(error.message);});
 }catch(error){if(epoch===generation){feedback(error.message);stopCall();}}
}
async function apply(value,epoch){
 if(epoch!==generation||document.hidden)return;
 const previous=snapshot;if(previous?.session?.id!==value.session?.id){stopCall();resetConversation();}
 snapshot=value;
 if(!previous?.profile&&value.profile)fillProfile();
 if(['idle','ended'].includes(value.state)){stopCall();if(previous?.state==='connected'||previous?.state==='connecting'){fillProfile();feedback('The conversation ended. Choose Start waiting when you’re ready to meet someone else.');}}
 if(value.state==='waiting'){renderLobby();}
 if(value.state==='connecting'&&value.session&&ackSession!==value.session.id){ackSession=value.session.id;update();try{await apply(await discovery('ack',{session_id:value.session.id}),epoch);}catch(error){ackSession=null;throw error;}return;}
 const list=$('messages'),nearBottom=list.scrollHeight-list.scrollTop-list.clientHeight<70;
 if(value.state==='connected'){
  for(const message of value.messages||[]){if(seenMessages.has(message.id))continue;seenMessages.add(message.id);const bubble=node('div',undefined,'bubble'+(message.mine?' mine':''));bubble.append(node('small',message.mine?value.profile.username:value.session.peer.username),document.createTextNode(message.body));list.append(bubble);}
  if(nearBottom)list.scrollTop=list.scrollHeight;
  void startCall(value.session,epoch);
  for(const signal of value.signals||[]){if(signal.id<=lastSignal)continue;callSignals.add(signal);lastSignal=signal.id;}
 }
 if(value.continue_room)continued=true;
 update();
}
async function poll(){clearTimeout(timer);if(!token||document.hidden)return;const epoch=generation;try{await apply(await discovery(['idle','ended'].includes(snapshot?.state)?'list':'heartbeat'),epoch);pollFailures=0;}catch(error){if(epoch===generation&&error.name!=='AbortError'){feedback(error.message);if(++pollFailures>=2&&['waiting','connecting','connected'].includes(snapshot?.state)){endLocally();request('discovery','leave',{instance},{keepalive:true}).catch(()=>{});feedback('Connection lost. You’ve left the lobby and your camera is off. Try again when your connection returns.');if(token&&!document.hidden)timer=setTimeout(poll,10000);}}}if(epoch===generation&&token&&!document.hidden)timer=setTimeout(poll,['waiting','connecting','connected'].includes(snapshot?.state)?2000:10000);}
async function perform(work){if(busy)return;busy=true;feedback('');update();try{await work();}catch(error){if(error.name!=='AbortError')feedback(error.message);}finally{busy=false;update();}}
function openProfile(person){selectedPerson=person;$('profile-name').textContent=person.username;$('profile-avatar').textContent=person.username.slice(0,1).toUpperCase();renderTags($('profile-tags'),person.tags);$('send-request').disabled=!!snapshot.outgoing||busy;$('send-request').textContent=snapshot.outgoing?'A request is pending':'Send request';$('person-dialog').showModal();}
$('pair-form').onsubmit=event=>{event.preventDefault();perform(async()=>{const result=await request('random-browser','pair.claim',{code:$('pair-code').value.trim()});if(!result.token)throw new Error('Get a fresh browser code in the app and try again.');token=result.token;sessionStorage.setItem('maroon.browser.session',token);$('pair-code').value='';generation++;await poll();});};
function addTag(){const value=$('interest-input').value.trim().replace(/^#/,'').toLowerCase();if(!/^[a-z0-9_]{1,24}$/.test(value)){feedback('Use 1–24 letters, numbers, or underscores for an interest.');return;}if(tags.size<6)tags.add(value);$('interest-input').value='';feedback('');renderSelection();}
$('add-tag').onclick=addTag;$('interest-input').onkeydown=event=>{if(event.key==='Enter'){event.preventDefault();addTag();}};
$('profile-form').onsubmit=event=>{event.preventDefault();perform(async()=>{if(!$('allow-direct').checked)throw new Error('Choose whether to allow direct video connections first.');await apply(await discovery('profile',{username:$('username').value.trim(),tags:[...tags]}),generation);editing=false;await apply(await discovery('enter',{allow_direct:true}),generation);await poll();});};
$('edit-profile').onclick=()=>perform(async()=>{endLocally();editing=true;fillProfile();await apply(await discovery('leave'),generation);await poll();});
$('leave').onclick=()=>perform(async()=>{endLocally();fillProfile();await apply(await discovery('leave'),generation);await poll();});
$('close-person').onclick=()=>$('person-dialog').close();
$('send-request').onclick=()=>perform(async()=>{if(!selectedPerson)return;if(pendingRequest?.target!==selectedPerson.id)pendingRequest={target:selectedPerson.id,nonce:crypto.randomUUID()};await apply(await discovery('request',pendingRequest),generation);pendingRequest=null;$('person-dialog').close();});
$('message').oninput=update;$('message-form').onsubmit=event=>{event.preventDefault();const body=$('message').value.trim(),sessionID=snapshot?.session?.id;if(!body||snapshot?.state!=='connected')return;perform(async()=>{if(!pendingMessage||pendingMessage.body!==body||pendingMessage.session_id!==sessionID)pendingMessage={session_id:sessionID,body,nonce:crypto.randomUUID()};const value=await discovery('send',pendingMessage);if(snapshot?.session?.id===sessionID){$('message').value='';pendingMessage=null;await apply(value,generation);}});};
$('continue-chat').onclick=()=>perform(async()=>{await apply(await discovery('continue',{session_id:snapshot.session.id}),generation);feedback('Request sent to Inbox. They can accept it to keep chatting after this call.');});
$('disconnect').onclick=()=>perform(async()=>{endLocally();await discovery('leave');await request('random-browser','logout');clearSession();});
$('report').onclick=()=>$('report-dialog').showModal();$('cancel-report').onclick=()=>$('report-dialog').close();$('report-form').onsubmit=event=>{event.preventDefault();perform(async()=>{const sessionID=snapshot?.session?.id;if(!sessionID)throw new Error('This conversation has ended.');endLocally();await apply(await discovery('report',{session_id:sessionID,reason:$('report-reason').value}),generation);$('report-dialog').close();feedback('Report sent for review.');await poll();});};
$('block').onclick=()=>perform(async()=>{const sessionID=snapshot?.session?.id;if(!sessionID)return;endLocally();await apply(await discovery('block',{session_id:sessionID}),generation);feedback('Blocked. This person will no longer appear in your lobby.');await poll();});
window.addEventListener('message',event=>{if(event.origin!==location.origin||event.source!==$('call-frame').contentWindow||!event.data?.maroonCall)return;const value=event.data.maroonCall;if(value.type==='signal'&&snapshot?.state==='connected')discovery('signal',{session_id:snapshot.session.id,kind:value.kind,payload:value.payload,nonce:crypto.randomUUID()}).catch(error=>feedback(error.message));if(value.type==='status'&&/could not|timed out|unavailable|denied|interrupted/i.test(value.value||''))feedback(value.value);});
function leaveOnExit(){const wasActive=['waiting','connecting','connected'].includes(snapshot?.state);endLocally();if(token&&wasActive)request('discovery','leave',{instance},{keepalive:true}).catch(()=>{});}
window.addEventListener('pagehide',leaveOnExit);document.addEventListener('visibilitychange',()=>{if(document.hidden)leaveOnExit();else if(token){fillProfile();poll();}});
renderSelection();update();if(token)poll();
