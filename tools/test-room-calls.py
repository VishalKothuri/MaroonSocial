#!/usr/bin/env python3
"""Accepted-DM call authorization plus actual synthetic video/data over its signaling API."""
import asyncio,json,pathlib,urllib.request,urllib.error,time,uuid,runpy,os
w=runpy.run_path(str(pathlib.Path(__file__).with_name('test-webrtc.py')))
RTCConfiguration=w['RTCConfiguration'];RTCIceServer=w['RTCIceServer'];RTCPeerConnection=w['RTCPeerConnection'];SyntheticVideo=w['SyntheticVideo'];transmit=w['transmit_description'];receive=w['receive_description'];APIError=w['APIError']
class Peer:
 def __init__(self,config):self.config=config;self.token=None;self.room=None;self.call=None;self.after=0
 async def request(self,action,**payload):
  social=action in('register','dm.request','dm.accept','account.delete','snapshot','block')
  body=dict(action=action,**payload)
  if not social:
   body.update(room_id=self.room,after=self.after)
   if self.call and action!='invite':body['call_id']=self.call
  headers={'Content-Type':'application/json','apikey':self.config['publishableKey']}
  if self.token:headers['X-Social-Token']=self.token
  req=urllib.request.Request(self.config['url']+'/functions/v1/'+('social'if social else'room-calls'),data=json.dumps(body).encode(),headers=headers)
  def send():
   try:
    with urllib.request.urlopen(req,timeout=25)as f:return json.load(f)
   except urllib.error.HTTPError as e:raise APIError(e.code,json.load(e))from None
  result=await asyncio.to_thread(send)
  if result.get('token'):self.token=result['token']
  if result.get('call'):self.call=result['call']['id'];result.update(result['call'])
  return result
 async def signal(self,kind,payload):return await self.request('signal',kind=kind,payload=payload)
async def denied(peer,action,code,**payload):
 try:await peer.request(action,**payload);raise AssertionError(action+' unexpectedly accepted')
 except APIError as e:assert e.code==code,(action,e.code,str(e))
async def main():
 config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text());a,b,c=[Peer(config)for _ in range(3)];pcs=[];consumers=[];frames=[0,0];names=['callqa_'+uuid.uuid4().hex[:10]for _ in range(3)]
 try:
  for peer,name in zip([a,b,c],names):await peer.request('register',username=name,adult=True)
  room=(await a.request('dm.request',username=names[1],text='Synthetic call invitation test'))['resource_id']
  for peer in[a,b,c]:peer.room=room
  await denied(a,'invite','forbidden',mode='video',nonce=str(uuid.uuid4()),allow_direct=True)
  await b.request('dm.accept',room_id=room)
  await denied(c,'poll','forbidden')
  await denied(a,'invite','consent',mode='video',nonce=str(uuid.uuid4()))
  call=await a.request('invite',mode='video',nonce=str(uuid.uuid4()),allow_direct=True)
  assert call['state']=='ringing';incoming=await b.request('poll');assert incoming['incoming']
  await denied(a,'media','consent',allow_direct=True)
  await denied(b,'accept','consent')
  await b.request('accept',allow_direct=True)
  for peer in[a,b]:
   cfg=await peer.request('media',allow_direct=True);assert cfg['transport']=='direct'
   pcs.append(RTCPeerConnection(RTCConfiguration(iceServers=[RTCIceServer(**s)for s in cfg['ice_servers']])))
  print('PASS accepted DM access, outsider rejection, two-party consent, private call config',flush=True)
  echoed=asyncio.Event()
  for index,pc in enumerate(pcs):
   pc.addTrack(SyntheticVideo(index*50))
   @pc.on('track')
   def ontrack(track,index=index):
    async def consume():
     try:
      while True:await track.recv();frames[index]+=1
     except Exception:pass
    consumers.append(asyncio.create_task(consume()))
  @pcs[1].on('datachannel')
  def ondata(channel):
   @channel.on('message')
   def message(data):channel.send(data)
  channel=pcs[0].createDataChannel('synthetic')
  @channel.on('open')
  def opened():channel.send('room-call-echo')
  @channel.on('message')
  def message(data):
   if data=='room-call-echo':echoed.set()
  await pcs[0].setLocalDescription(await pcs[0].createOffer());count=await transmit(a,pcs[0].localDescription);await receive(b,pcs[1],'offer',count)
  await pcs[1].setLocalDescription(await pcs[1].createAnswer());count+=await transmit(b,pcs[1].localDescription);await receive(a,pcs[0],'answer',count//2)
  await asyncio.wait_for(echoed.wait(),15);await asyncio.sleep(2.1)
  assert min(frames)>20,frames
  print(f'PASS actual two-way synthetic video frames {frames} + data echo; {count} ICE signals',flush=True)
  await a.request('end');assert(await b.request('poll'))['state']=='ended'
  await denied(b,'media','consent',allow_direct=True)
  print('PASS end revokes call media and propagates to the other client',flush=True)
  fd=os.open('/tmp/maroon-room-call-fixtures.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
  with os.fdopen(fd,'w')as f:json.dump({'room_id':room},f)
 finally:
  for pc in pcs:await pc.close()
  for t in consumers:t.cancel()
  for peer in[a,b,c]:
   if peer.token:
    try:await peer.request('account.delete')
    except Exception:print('Synthetic account cleanup requires operator retry',flush=True)
if __name__=='__main__':asyncio.run(main())
