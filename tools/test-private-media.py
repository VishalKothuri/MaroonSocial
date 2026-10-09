#!/usr/bin/env python3
"""Private video/avatar HTTP regression using provisioned synthetic accounts only.
Run make-synthetic-video.swift first. Credentials are a mode-0600 temporary file,
never printed; this script deletes only these synthetic accounts in finally.
"""
import base64,json,pathlib,sys,urllib.request,urllib.error,uuid
import runner_backend
config=runner_backend.load()
fixture=pathlib.Path(sys.argv[1]); people=json.loads(fixture.read_text()); rooms=[]
def call(endpoint,action,token,**payload):
 req=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers={'Content-Type':'application/json','apikey':config['publishableKey'],'X-Social-Token':token})
 try:
  with urllib.request.urlopen(req,timeout=45)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(endpoint,action,token,**payload):
 status,value=call(endpoint,action,token,**payload);assert status==200,(endpoint,action,status,value);return value
try:
 a,b,c=[x['token']for x in people]
 # The provisioned accounts accept the community guidelines (required before sending messages).
 for token in(a,b,c):runner_backend.accept_guidelines(config,ok('social','snapshot',token),token)
 payload=dict(title='Synthetic private media QA',description='Temporary video/avatar authorization test.',category='Friends',avatar='gold',is_public=False,alias='Captain',member_avatar='sage',nonce=str(uuid.uuid4()))
 room=ok('communities','create',a,**payload)['room_id'];rooms.append(room)
 path=pathlib.Path('build/synthetic-media');video=(path/'synthetic-upload.mp4').read_bytes();photo=(path/'synthetic-photo.jpg').read_bytes()
 att=ok('social','attachment.upload',a,room_id=room,kind='video',data=base64.b64encode(video).decode())['attachment_id']
 nonce=str(uuid.uuid4());message=ok('social','room.send',a,room_id=room,text='Synthetic video',attachment_id=att,nonce=nonce)['resource_id']
 assert ok('social','room.send',a,room_id=room,text='Synthetic video',attachment_id=att,nonce=nonce)['resource_id']==message
 assert call('social','attachment.read',c,attachment_id=att)[0]==403
 assert call('social','attachment.upload',a,room_id=room,kind='video',data=base64.b64encode(b'not video').decode())[0]==400
 ok('group-photos','upload',a,room_id=room,scope='group',data=base64.b64encode(photo).decode())
 assert call('group-photos','read',c,room_id=room,scope='group')[0]in(400,403)
 ok('communities','invite',a,room_id=room,username=people[1]['username'])
 assert ok('group-photos','read',b,room_id=room,scope='group')['has_photo']
 assert call('social','attachment.read',b,attachment_id=att)[0]==403
 assert call('group-photos','read',b,room_id=room,scope='member')[0]==403
 joined=ok('communities','accept',b,room_id=room,alias='Comet',member_avatar='sky');member_key=next(x['member_key']for x in joined['members']if x['is_me'])
 read=ok('social','attachment.read',b,attachment_id=att);download=base64.b64decode(read['media_data'])
 assert read['mime']=='video/mp4'and download[4:8]==b'ftyp'and b'+30.0000-096.0000/'not in download
 (path/'synthetic-downloaded.mp4').write_bytes(download)
 assert call('group-photos','upload',b,room_id=room,scope='group',data=base64.b64encode(photo).decode())[0]==403
 ok('group-photos','upload',b,room_id=room,scope='member',data=base64.b64encode(photo).decode())
 avatar=ok('group-photos','read',a,room_id=room,scope='member',member_key=member_key)
 assert base64.b64decode(avatar['media_data']).startswith(b'\xff\xd8')
 assert call('group-photos','remove',a,room_id=room,scope='member',member_key=member_key)[0]==403
 print('PASS real compressed MP4 private delivery, duplicate-send idempotence, metadata stripped, outsider/pending denial; private group/member JPEG upload/read and ownership')
 ok('room-preferences','set',b,room_id=room,hours=8);assert ok('room-preferences','get',b,room_id=room)['muted']
 ok('room-preferences','set',b,room_id=room,hours=0);assert not ok('room-preferences','get',b,room_id=room)['muted']
 assert call('room-preferences','get',c,room_id=room)[0]==403
 ok('communities','leave',b,room_id=room)
 assert call('social','attachment.read',b,attachment_id=att)[0]==403
 assert call('group-photos','read',a,room_id=room,scope='member',member_key=member_key)[0]==403
 assert call('room-preferences','set',b,room_id=room,hours=-1)[0]==403
 ok('group-photos','remove',a,room_id=room,scope='group');assert not ok('group-photos','read',a,room_id=room,scope='group')['has_photo']
 ok('communities','close',a,room_id=room)
 print('PASS mute/unmute access, immediate leave revocation for video/member photo/preferences, photo removal')
finally:
 runner_backend.receipt('build/synthetic-media/room-receipts.json').write_text(json.dumps(rooms))
 for person in people:
  status,result=call('social','account.delete',person['token']);assert status==200,result
 print('PASS synthetic accounts deleted; no credentials retained in repository or output')
 fixture.unlink(missing_ok=True)
