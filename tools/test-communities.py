#!/usr/bin/env python3
"""Live multi-client community regression. Creates synthetic accounts, never uses existing users.
Account cleanup is automatic. Synthetic closed room IDs are recorded for owner SQL cleanup.
"""
import base64,json,os,pathlib,struct,time,urllib.request,urllib.error,uuid,zlib
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text());tokens=[];rooms=[]
def call(endpoint,action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 request=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
 try:
  with urllib.request.urlopen(request,timeout=40)as response:return response.status,json.load(response)
 except urllib.error.HTTPError as error:return error.code,json.load(error)
def ok(endpoint,action,token=None,**payload):
 status,data=call(endpoint,action,token,**payload);assert status==200,(endpoint,action,status,data);return data
def community(action,token,**payload):return ok('communities',action,token,**payload)
def remember(room):
 rooms.append(room)
 fd=os.open('/tmp/maroon-community-test-rooms.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(rooms,f)
 return room
def png():
 def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\x00\x00'))+chunk(b'IEND',b'')
label='qacom'+str(int(time.time()))[-7:];names=[label+x for x in'abc']
try:
 for name in names:tokens.append(ok('social','register',username=name,adult=True)['token'])
 a,b,c=tokens
 assert call('communities','list','0'*64)[0]==401
 nonce=str(uuid.uuid4());public=community('create',a,title=label+' Public',description='Synthetic campus chat integration test',category='Friends',is_public=True,nonce=nonce,avatar='maroon',alias='Captain',member_avatar='gold');room=remember(public['room_id'])
 assert community('create',a,title=label+' Public',description='Synthetic campus chat integration test',category='Friends',is_public=True,nonce=nonce,avatar='maroon',alias='Captain',member_avatar='gold')['room_id']==room
 private=community('create',a,title=label+' Private',description='Synthetic private invitation integration test',category='Other',is_public=False,nonce=str(uuid.uuid4()),avatar='maroon',alias='Captain',member_avatar='gold');private_room=remember(private['room_id']);code=private['community']['invite_code']
 directory=community('list',b,search=label)['communities'];assert [x['id']for x in directory]==[room];assert 'members'not in directory[0]and directory[0].get('invite_code')is None
 assert call('communities','detail',b,room_id=private_room)[0]==400
 assert call('communities','join',b,room_id=private_room,alias='Comet',member_avatar='sky')[0]==400
 assert call('social','room.send',b,room_id=room,text='Not joined')[0]==403
 print('PASS authenticated directory, private metadata/code secrecy, outsider chat denial')
 assert call('communities','join',b,room_id=room)[0]==400
 community('join',b,room_id=room,alias='Comet',member_avatar='sky')
 assert community('join',b,room_id=room,alias='Comet',member_avatar='sky')['community']['member_count']==2
 bkey=next(x['member_key']for x in community('detail',b,room_id=room)['members']if x['is_me'])
 akey=next(x['member_key']for x in community('detail',a,room_id=room)['members']if x['is_me'])
 message=ok('social','room.send',b,room_id=room,text='Hello from the second client')['resource_id']
 snapshot=ok('social','snapshot',a)['snapshot'];chat=next(x for x in snapshot['conversations']if x['id']==room);assert any(x['id']==message for x in chat['messages'])
 attachment=ok('social','attachment.upload',a,room_id=room,kind='image',data=base64.b64encode(png()).decode())['attachment_id']
 ok('social','room.send',a,room_id=room,text='',attachment_id=attachment)
 assert base64.b64decode(ok('social','attachment.read',b,attachment_id=attachment)['media_data'])
 assert call('social','attachment.read',c,attachment_id=attachment)[0]==403
 game=ok('games','invite',a,room=room,kind='chess',nonce=str(uuid.uuid4()),opponent_member_key=bkey)['game'];accepted=ok('games','accept',b,id=game['id'])['game'];assert accepted['status']=='active'
 assert call('games','get',c,id=game['id'])[0]==400
 print('PASS explicit join, shared text, private image access and chosen-player game invitation/acceptance')
 assert call('communities','ban',b,room_id=room,member_key=akey)[0]==403
 community('ban',a,room_id=room,member_key=bkey)
 assert call('social','room.send',b,room_id=room,text='Banned')[0]==403
 assert call('social','attachment.read',b,attachment_id=attachment)[0]==403
 assert call('social','group.invite',a,room_id=room,username=names[1])[0]in(400,403)
 assert call('communities','join',b,room_id=room,alias='Comet',member_avatar='sky')[0]==403
 community('unban',a,room_id=room,member_key=bkey);community('join',b,room_id=room,alias='Comet',member_avatar='sky')
 community('join_code',b,invite_code=code.lower(),alias='Comet',member_avatar='sky')
 community('transfer',a,room_id=private_room,member_key=next(x['member_key']for x in community('detail',b,room_id=private_room)['members']if x['is_me']));community('leave',a,room_id=private_room)
 assert call('communities','detail',a,room_id=private_room)[0]==400
 community('report',c,room_id=room,reason='Synthetic report to test owner review')
 community('close',a,room_id=room)
 assert call('social','room.send',b,room_id=room,text='Closed')[0]==403
 assert not community('list',c,search=label)['communities']
 print('PASS owner authorization, ban/legacy-invite/media revocation, unban, private code, transfer, leave, report, close')
finally:
 for token in tokens:
  status,result=call('social','account.delete',token);print('Synthetic account cleanup:',status);assert status==200,result
