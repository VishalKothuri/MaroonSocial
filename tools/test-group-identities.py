#!/usr/bin/env python3
"""Live three-client scoped-group regression; owns and deletes its synthetic accounts only."""
import base64,json,os,pathlib,struct,time,urllib.request,urllib.error,uuid,zlib
import runner_backend
config=runner_backend.load();tokens=[];rooms=[]
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
 fd=os.open('/tmp/maroon-group-identity-test-rooms.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(rooms,f)
 return room
def png():
 def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\x00\x00'))+chunk(b'IEND',b'')
def meta(snapshot,room):return next(x for x in snapshot['conversationMeta']if x['id']==room)
def chat(snapshot,room):return next(x for x in snapshot['conversations']if x['id']==room)
def no_other_names(data,own):
 encoded=json.dumps(data)
 assert all(name not in encoded for name in names if name!=own),'Another account username was exposed'
label='qagid'+str(int(time.time()))[-7:];names=[label+x for x in'abc']
try:
 for name in names:tokens.append(ok('social','register',username=name,adult=True)['token'])
 a,b,c=tokens
 payload=dict(title=label+' Public',description='Synthetic scoped identity integration test.',category='Friends',avatar='gold',is_public=True,alias='Captain',member_avatar='sage',nonce=str(uuid.uuid4()))
 created=community('create',a,**payload);room=remember(created['room_id']);assert community('create',a,**payload)['room_id']==room
 private=community('create',a,**dict(payload,title=label+' Private',is_public=False,nonce=str(uuid.uuid4())));priv=remember(private['room_id']);code=private['community']['invite_code']
 directory=community('list',b,search=label)['communities'];assert [x['id']for x in directory]==[room];no_other_names(directory,names[1]);assert directory[0].get('invite_code')is None
 assert call('communities','detail',b,room_id=priv)[0]==400
 assert call('communities','join',b,room_id=room,alias='CAPTAIN',member_avatar='sky')[1]['code']=='alias_taken'
 joined=community('join',b,room_id=room,alias='Comet',member_avatar='sky');bkey=next(x['member_key']for x in joined['members']if x['is_me']);no_other_names(joined,names[1])
 no_other_names(community('detail',b,room_id=room),names[1])
 community('invite',a,room_id=room,username=names[2]);assert call('communities','invite',a,room_id=room,username='no_account_qagid')[0]==400
 owner=community('detail',a,room_id=room);assert owner['pending'][0]['username']==names[2];assert 'pending'not in community('detail',b,room_id=room)
 message=ok('social','room.send',a,room_id=room,text='Shared message from chosen group identity',nonce=str(uuid.uuid4()))['resource_id']
 ok('social','room.typing',a,room_id=room)
 attachment=ok('social','attachment.upload',a,room_id=room,kind='image',data=base64.b64encode(png()).decode())['attachment_id'];ok('social','room.send',a,room_id=room,text='',attachment_id=attachment,nonce=str(uuid.uuid4()))
 pending=ok('social','snapshot',c)['snapshot'];m=meta(pending,room)
 assert chat(pending,room)['request']and not chat(pending,room)['messages']and not m['canSend']and m['unread']==0 and m['typing']==[]and m['members']==[];no_other_names(pending,names[2])
 assert call('social','attachment.read',c,attachment_id=attachment)[0]==403
 assert call('social','group.accept',c,room_id=room)[0]==400
 community('accept',c,room_id=room,alias='Orbit',member_avatar='violet');again=community('accept',c,room_id=room,alias='ShouldNotChange',member_avatar='rose');assert again['community']['my_alias']=='Orbit'
 print('PASS public/private discovery, owner-only invitations, alias uniqueness, pending zero history/media/typing/unread, explicit identity acceptance and retry')
 snapshot=ok('social','snapshot',b)['snapshot'];no_other_names(snapshot,names[1]);messages=chat(snapshot,room)['messages'];assert next(x for x in messages if x['id']==message)['author']=='Captain'
 assert base64.b64decode(ok('social','attachment.read',c,attachment_id=attachment)['media_data'])
 community('profile',b,room_id=room,alias='CometTwo',member_avatar='rose');assert meta(ok('social','snapshot',b)['snapshot'],room)['myAlias']=='CometTwo'
 second=community('join_code',b,invite_code=code.lower(),alias='OtherComet',member_avatar='sky');otherkey=next(x['member_key']for x in second['members']if x['is_me']);assert otherkey!=bkey
 assert call('communities','remove',a,room_id=room,member_key=otherkey)[0]==400
 assert call('games','invite',a,room=room,kind='chess',nonce=str(uuid.uuid4()),opponent_member_key=otherkey)[0]==400
 game=ok('games','invite',a,room=room,kind='chess',nonce=str(uuid.uuid4()),opponent_member_key=bkey)['game'];assert game['players']==['Captain','CometTwo'];no_other_names(game,names[0]);assert ok('games','accept',b,id=game['id'])['game']['status']=='active'
 no_other_names(ok('social','snapshot',c)['snapshot'],names[2])
 print('PASS shared text/image, editable scoped profiles, different cross-room keys, foreign-key denial, alias-safe game cards and acceptance')
 community('ban',a,room_id=room,member_key=bkey)
 assert call('social','room.send',b,room_id=room,text='Revoked')[0]==403
 assert call('social','attachment.read',b,attachment_id=attachment)[0]==403
 assert call('games','get',b,id=game['id'])[0]in(400,403)
 assert call('communities','join',b,room_id=room,alias='CometTwo',member_avatar='rose')[0]==403
 community('unban',a,room_id=room,member_key=bkey);community('join',b,room_id=room,alias='CometTwo',member_avatar='rose')
 community('invite',a,room_id=priv,username=names[2]);pending=community('detail',a,room_id=priv)['pending'];inv=pending[0]['invitation_key']
 assert call('communities','revoke',b,room_id=priv,invitation_key=inv)[0]==403
 community('revoke',a,room_id=priv,invitation_key=inv);community('revoke',a,room_id=priv,invitation_key=inv)
 assert call('communities','accept',c,room_id=priv,alias='NoAccess',member_avatar='sage')[0]in(400,403)
 community('update',a,room_id=room,title=payload['title'],description=payload['description'],category='Study Group',avatar='coral',is_public=False)
 assert not community('list',c,search=label,joined_only=False)['communities'][0]['is_public'] # joined visibility retained
 community('transfer',a,room_id=priv,member_key=otherkey);community('leave',a,room_id=priv)
 assert call('communities','detail',a,room_id=priv)[0]==400
 community('close',a,room_id=room);assert call('social','room.send',c,room_id=room,text='Closed')[0]==403
 export=ok('account-controls','export',b,section='communities');assert any(x['my_alias']=='OtherComet'for x in export['data'])
 print('PASS ban/unban immediately revokes chat/media/game, private pending revoke retry, metadata/avatar/visibility edit, transfer/leave/close and own profile export')
finally:
 for token in tokens:
  status,result=call('social','account.delete',token);assert status==200,result;print('Synthetic account deletion: PASS')
 print('Synthetic room cleanup receipt:',len(rooms),'rooms saved locally; no credentials retained')
