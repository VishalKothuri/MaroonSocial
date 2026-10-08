#!/usr/bin/env python3
"""Live cross-device social regression. Uses only synthetic data and keeps bearer tokens out of stdout."""
import atexit,json,urllib.request,urllib.error,pathlib,time,uuid,os,base64,struct,zlib
import runner_backend
config=runner_backend.load();base=config['url'];key=config['publishableKey']
def request(action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':key}
 if token:headers['X-Social-Token']=token
 req=urllib.request.Request(base+'/functions/v1/social',data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
 try:
  with urllib.request.urlopen(req,timeout=50)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
fixtures=[]
def ok(action,token=None,**payload):
 status,result=request(action,token,**payload)
 assert status==200,(action,status,result)
 if result.get('resource_id'):fixtures.append({'action':action,'id':result['resource_id']})
 if result.get('attachment_id'):fixtures.append({'action':action,'id':result['attachment_id']})
 fd=os.open('/tmp/maroon-social-test-fixtures.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(fixtures,f)
 return result
def snapshot(token):return ok('snapshot',token)['snapshot']
def find(items,id):return next(x for x in items if x['id']==id)
def png():
 def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\x00\x00'*0+b'\x00\xff\x00\x00\x00\xff\x00'+b'\x00\x00\x00\xff\xff\xff\x00'))+chunk(b'IEND',b'')
def animated_gif():
 data=b'GIF89a'+struct.pack('<HHBBB',1,1,0x80,0,0)+b'\xff\x00\x00\x00\x00\xff'+b'\x21\xfe\x0ePrivateComment\x00'
 for pixel in[0,1]:data+=b'\x21\xf9\x04\x00\x14\x00\x00\x00'+b'\x2c'+struct.pack('<HHHHB',0,0,1,1,0)+b'\x02\x02'+(b'\x44\x01'if pixel==0 else b'\x4c\x01')+b'\x00'
 return data+b'\x3b'
label='qa'+str(int(time.time()))[-8:];names=[label+x for x in 'abcd']
sessions=[runner_backend.accept_guidelines(config,ok('register',username=name,adult=True))['token']for name in names]
fd=os.open('/tmp/maroon-social-test-sessions.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
with os.fdopen(fd,'w')as f:json.dump(sessions,f)
a,b,c,d=sessions
def cleanup():
 # Runs on success (accounts already deleted, 401s ignored) and after a failed assertion.
 left=[token for token in sessions if request('account.delete',token)[0]==200]
 if left:print('Synthetic accounts deleted after an early exit:',len(left))
atexit.register(cleanup)
assert request('snapshot','0'*64)[0]==401
assert request('register',username='underage_'+label,adult=False)[0]==403
print('PASS private device identity and adult access gate')
post=ok('post.create',a,text='Anonymous integration post',anonymous=True,community='Texas A&M',acceptsDM=True,nonce=str(uuid.uuid4()))['resource_id']
bpost=find(snapshot(b)['posts'],post)
assert bpost['author']=='Anonymous' and names[0]not in json.dumps(bpost)
reply=ok('comment.create',b,post_id=post,text='Reply from another device',anonymous=False)['resource_id']
# Members may reply by name under an anonymous post (see tools/test-comment-votes.py); only the post author stays anonymous.
seen_reply=find(find(snapshot(a)['posts'],post)['comments'],reply)
assert seen_reply['anonymous']is False and seen_reply['author']==names[1],seen_reply
ok('post.vote',b,post_id=post,value=1);ok('post.save',b,post_id=post,saved=True)
assert find(snapshot(a)['posts'],post)['score']==2 # the author's own upvote plus b's
assert find(snapshot(b)['posts'],post)['saved']is True
assert find(snapshot(c)['posts'],post)['saved']is False
assert request('post.delete',b,post_id=post)[0]==403
print('PASS shared anonymous feed/replies/votes/private bookmarks/ownership')
assert request('post.create',b,text='Hidden discussion',community='NSFW')[0]==403
ok('community.join',a,community='NSFW');secretpost=ok('post.create',a,text='Adult community test',community='NSFW')['resource_id']
assert not any(p['id']==secretpost for p in snapshot(b)['posts'])
assert request('comment.create',b,post_id=secretpost,text='forbidden')[0]==403
print('PASS NSFW access enforced on writes and snapshot reads')
course=dict(code='CHEM 107',title='General Chemistry for Engineering',term='Fall 2026',icon='flask')
room=ok('course.join',a,**course)['resource_id'];assert ok('course.join',b,**course)['resource_id']==room
nonce=str(uuid.uuid4());message=ok('room.send',a,room_id=room,text='Shared course hello',nonce=nonce)['resource_id']
assert ok('room.send',a,room_id=room,text='Shared course hello',nonce=nonce)['resource_id']==message
assert len([m for m in find(snapshot(b)['conversations'],room)['messages']if m['id']==message])==1
assert request('room.send',c,room_id=room,text='intrusion')[0]==403
ok('room.react',b,message_id=message,emoji='👍')
assert find(find(snapshot(a)['conversations'],room)['messages'],message)['reactions']['👍']==1
reply_message=ok('room.send',b,room_id=room,text='Replying here',reply_to=message)['resource_id']
assert find(find(snapshot(a)['conversations'],room)['messages'],reply_message)['replyTo']==message
ok('room.read',b,room_id=room);assert find(snapshot(b)['conversationMeta'],room)['unread']==0
print('PASS one shared course room, reliable messages/replies/reactions/read state, outsider denial')
dm=ok('dm.request',b,post_id=post,text='Can we talk?')['resource_id']
assert find(snapshot(a)['conversations'],dm)['request']is True
assert find(snapshot(b)['conversationMeta'],dm)['pendingOutgoing']is True
assert request('room.send',b,room_id=dm,text='before acceptance')[0]==403
assert request('dm.accept',b,room_id=dm)[0]==403
ok('dm.accept',a,room_id=dm)
ok('room.send',a,room_id=dm,text='Yes, welcome')
assert names[0]not in json.dumps(find(snapshot(b)['conversations'],dm))
assert names[1]not in json.dumps(find(snapshot(a)['conversations'],dm))
print('PASS anonymous DM request/accept lifecycle without username disclosure')
image=base64.b64encode(png()).decode()
attachment=ok('attachment.upload',a,room_id=dm,data=image,kind='image')['attachment_id']
assert request('attachment.read',c,attachment_id=attachment)[0]==403
media_message=ok('room.send',a,room_id=dm,text='A small test image',attachment_id=attachment,nonce=str(uuid.uuid4()))['resource_id']
assert ok('attachment.read',b,attachment_id=attachment)['media_data']
assert request('room.send',b,room_id=dm,text='reuse stolen attachment',attachment_id=attachment)[0]==403
assert request('room.send',a,room_id=dm,text='',attachments=[attachment,attachment])[0]==400
assert request('attachment.upload',c,room_id=dm,data=image,kind='image')[0]==403
assert request('attachment.upload',a,room_id=dm,data=base64.b64encode(b'<script>bad</script>').decode(),kind='image')[0]==400
assert request('room.send',a,room_id=dm,text='Changed original',nonce=nonce)[0]==400
assert request('room.send',a,room_id=room,text='Shared course hello',attachment_id=attachment,nonce=nonce)[0]==400
post_media=ok('attachment.upload',a,post_id=post,data=image,kind='image')['attachment_id']
assert ok('attachment.read',b,attachment_id=post_media)['media_data']
assert request('attachment.upload',a,post_id=post,data=image,kind='image')[0]==400
assert find(snapshot(b)['posts'],post)['attachmentID']==post_media
print('PASS message nonce immutable across rooms/content/media and one attachment per post')
gif_attachment=ok('attachment.upload',a,room_id=dm,data=base64.b64encode(animated_gif()).decode())['attachment_id']
ok('room.send',a,room_id=dm,text='Synthetic animated GIF',attachment_id=gif_attachment)
gif_bytes=base64.b64decode(ok('attachment.read',b,attachment_id=gif_attachment)['media_data'])
assert gif_bytes.startswith(b'GIF') and b'PrivateComment'not in gif_bytes
print('PASS actual GIF decoding/reencoding strips metadata and supports private delivery')
print('PASS private sanitized media, attachment ownership/cardinality, fake image rejection')
activity=ok('activity.create',a,title='Integration coffee',kind='Hangouts',place='MSC',starts=time.time()+7200,capacity=2,details='Synthetic test')['resource_id']
ok('activity.join',b,activity_id=activity);ok('activity.join',c,activity_id=activity)
assert find(snapshot(c)['activities'],activity)['waitlisted']is True
assert request('room.send',c,room_id=activity,text='waitlisted intrusion')[0]==403
ok('activity.leave',b,activity_id=activity)
assert find(snapshot(c)['conversationMeta'],activity)['canSend']is True
assert request('activity.cancel',c,activity_id=activity)[0]==403
ok('activity.cancel',a,activity_id=activity)
assert request('room.send',c,room_id=activity,text='after cancellation')[0]==403
approval=ok('activity.create',a,title='Integration approval',kind='Study',place='Evans',starts=time.time()+7200,capacity=4,details='Synthetic approval test',approval_required=True)['resource_id']
ok('activity.join',b,activity_id=approval)
assert find(snapshot(b)['activities'],approval)['membershipStatus']=='pending'
assert find(snapshot(a)['activities'],approval)['joinRequests']==[names[1]]
assert find(snapshot(c)['activities'],approval)['joinRequests']==[]
assert request('activity.approve',c,activity_id=approval,username=names[1])[0]==403
ok('activity.approve',a,activity_id=approval,username=names[1])
assert find(snapshot(b)['conversationMeta'],approval)['canSend']is True
print('PASS host-only activity approval and private request roster')
print('PASS capacity enforcement, waitlist promotion, host-only cancellation')
group=ok('group.create',a,title='Private test group',description='Synthetic private chat testing.',category='Friends',is_public=False,avatar='maroon',alias='Captain',member_avatar='gold',nonce=str(uuid.uuid4()))['resource_id']
ok('group.invite',a,room_id=group,username=names[1])
ok('room.send',a,room_id=group,text='Private before invitation accepted')
assert find(snapshot(b)['conversations'],group)['messages']==[]
assert request('room.send',b,room_id=group,text='pending')[0]==403
assert find(snapshot(b)['conversationMeta'],group)['members']==[]
ok('group.accept',b,room_id=group,alias='Comet',member_avatar='sky')
assert len(find(snapshot(b)['conversationMeta'],group)['members'])==2
assert request('block',b,room_id=group)[0]==400
assert len(find(snapshot(b)['conversations'],group)['messages'])==1
roster=find(snapshot(a)['conversationMeta'],group)['members'];ak=next(x['memberKey']for x in roster if x['isMe']);bk=next(x['memberKey']for x in roster if not x['isMe'])
ok('group.transfer',a,room_id=group,member_key=bk);ok('group.remove',b,room_id=group,member_key=ak)
assert request('room.send',a,room_id=group,text='removed member')[0]==403
print('PASS group invite acceptance, ownership transfer and removal revocation')
org=ok('organization.apply',a,name='Synthetic '+label,about='Test application',contact='No external delivery')['resource_id']
assert find(snapshot(a)['organizations'],org)['status']=='pending'
assert not any(o['id']==org for o in snapshot(c)['organizations'])
assert request('organization.publish',a,organization_id=org,title='Unverified promotion',kind='Organizations',place='MSC',starts=time.time()+7200,capacity=10)[0]==403
report=ok('report',b,target_type='post',target_id=post,reason='Integration test: synthetic report')['resource_id'];assert report
ok('block',b,room_id=dm)
assert request('room.send',a,room_id=dm,text='after block')[0]==403
assert request('attachment.read',b,attachment_id=attachment)[0]==403
assert not any(p['id']==post for p in snapshot(b)['posts'])
print('PASS verified-org publishing gate, real report receipt, persistent block revocation')
delete_dm=ok('dm.request',c,username=names[3],text='Deletion revocation test')['resource_id'];ok('dm.accept',d,room_id=delete_dm)
ok('account.delete',c)
assert request('room.send',d,room_id=delete_dm,text='Cannot send to deleted account')[0]==403
for token in [a,b,d]:ok('account.delete',token);assert request('snapshot',token)[0]==401
print('PASS account deletion revokes credentials immediately')
print('All live social integration tests passed; only synthetic test data was used.')
