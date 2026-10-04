#!/usr/bin/env python3
"""Three independent clients prove named group-game binding and observer boundaries."""
import json,pathlib,time,urllib.request,urllib.error,uuid,os
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text());tokens=[];room=None
def call(endpoint,action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 request=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
 try:
  with urllib.request.urlopen(request,timeout=40)as response:return response.status,json.load(response)
 except urllib.error.HTTPError as error:return error.code,json.load(error)
def ok(endpoint,action,token=None,**payload):
 status,data=call(endpoint,action,token,**payload);assert status==200,(endpoint,action,status,data);return data
label='qagrp'+str(int(time.time()))[-7:];names=[label+x for x in'abc']
try:
 for name in names:tokens.append(ok('social','register',username=name,adult=True)['token'])
 a,b,c=tokens
 room=ok('communities','create',a,title=label,description='Synthetic chosen-opponent group game test',category='Friends',is_public=False,avatar='maroon',alias='Captain',member_avatar='gold',nonce=str(uuid.uuid4()))
 code=room['community']['invite_code'];room=room['room_id']
 fd=os.open('/tmp/maroon-group-game-test-room.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump([room],f)
 keys=[]
 for index,token in enumerate([b,c]):
  joined=ok('communities','join_code',token,invite_code=code,alias=['Comet','Orbit'][index],member_avatar='sky');keys.append(next(x['member_key']for x in joined['members']if x['is_me']))
 assert call('games','invite',a,room=room,kind='chess',nonce=str(uuid.uuid4()))[0]==400
 nonce=str(uuid.uuid4());payload=dict(room=room,kind='chess',nonce=nonce,opponent_member_key=keys[0])
 game=ok('games','invite',a,**payload)['game'];assert game['status']=='pending'and game['rules']=='maroon-games-2.1.0'
 assert ok('games','invite',a,**payload)['game']['id']==game['id']
 changed=dict(payload);changed['opponent_member_key']=keys[1];assert call('games','invite',a,**changed)[0]==400
 card=ok('games','card',c,id=game['id'])['invitation'];assert card['status']=='pending'and card['canOpen']is False and 'state'not in card and 'replay'not in card
 assert call('games','accept',c,id=game['id'])[0]==400
 assert call('games','get',c,id=game['id'])[0]==400
 assert not ok('games','list',c)['games']
 assert ok('games','get',a,id=game['id'])['game']['status']=='pending'
 accepted=ok('games','accept',b,id=game['id'])['game'];assert accepted['status']=='active'and accepted['yourSeat']==1
 committed=ok('games','turn',a,id=game['id'],version=accepted['version'],nonce=str(uuid.uuid4()),input={'from':'e2','to':'e4'})['game']
 assert ok('games','get',b,id=game['id'])['game']['state']==committed['state']
 print('PASS explicit recipient, idempotent binding, spectator card/no Accept/no private state, chosen-player accept and shared authoritative move')
 ok('communities','leave',b,room_id=room)
 for token in[a,b]:assert call('games','get',token,id=game['id'])[0]==403
 assert call('games','invite',a,**payload)[0]==403
 assert not ok('games','list',a)['games']
 assert ok('games','card',c,id=game['id'])['invitation']['status']=='unavailable'
 print('PASS left-member and original-nonce revocation; no orphan match in inviter list')
finally:
 for token in tokens:
  status,result=call('social','account.delete',token);assert status==200,result
 print('Synthetic group-game accounts removed')
