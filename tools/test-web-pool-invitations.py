#!/usr/bin/env python3
"""Real 3.0 DM/group invitation, scoped play and explicit same-opponent rematch.
Creates/deletes only exact synthetic accounts; no private credentials logged.
"""
import concurrent.futures,json,pathlib,time,urllib.request,urllib.error,uuid
import runner_backend
cfg=runner_backend.load();tokens=[];scopes=[]
def call(endpoint,action,index=0,scoped=False,**data):
 h={'Content-Type':'application/json','apikey':cfg['publishableKey']}
 if tokens:
  h['X-Maroon-Pool-Session'if scoped else'X-Social-Token']=(scopes if scoped else tokens)[index]
 if scoped:h['Origin']='https://maroon-social-games.vercel.app'
 req=urllib.request.Request(cfg['url']+'/functions/v1/'+endpoint,data=json.dumps({'action':action,**data}).encode(),headers=h)
 try:
  with urllib.request.urlopen(req,timeout=35)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(endpoint,action,index=0,**data):
 status,v=call(endpoint,action,index,**data);assert status==200,(endpoint,action,status,v);return v
label='wpiv'+str(int(time.time()))[-7:];names=[label+x for x in'abc']
try:
 for name in names:
  tokens.append(ok('social','register',username=name,adult=True)['token'])
  scopes.append(ok('web-pool','session',len(tokens)-1)['token'])
 room=ok('social','dm.request',username=names[1],text='Synthetic pool invitation test')['resource_id']
 assert call('web-pool','invite',room=room,kind='pool',nonce=str(uuid.uuid4()))[0]==403
 ok('social','dm.accept',1,room_id=room)
 nonce=str(uuid.uuid4());invite=dict(room=room,kind='pool',nonce=nonce)
 game=ok('web-pool','invite',**invite)['game'];gid=game['id'];assert game['rules']=='maroon-web-pool-3.0.0'and game['status']=='pending'
 assert ok('web-pool','invite',**invite)['game']['id']==gid
 assert call('web-pool','accept',id=gid)[0]==403
 assert call('web-pool','get',2,id=gid)[0]==404
 assert call('web-pool','turn',scoped=True,id=gid,version=0,nonce=str(uuid.uuid4()),input={'angle':0,'power':1,'offset':{'x':0,'y':0}})[0]==409
 # Accept while both recipients issue queue operations. Any already-paired
 # independent match remains valid, but no deadlock or waiting ghost persists.
 qa,qb=str(uuid.uuid4()),str(uuid.uuid4())
 def operation(i):
  if i==0:return call('web-pool','accept',1,id=gid)
  return call('web-pool','join',i-1,scoped=True,nonce=[qa,qb][i-1])
 with concurrent.futures.ThreadPoolExecutor(max_workers=3)as pool:results=list(pool.map(operation,range(3)))
 assert all(s==200 for s,_ in results),[(s,v.get('error'))for s,v in results]
 for i,n in enumerate([qa,qb]):ok('web-pool','cancel',i,scoped=True,nonce=n)
 accepted=ok('web-pool','accept',1,id=gid)['game'];assert accepted['status']=='active'and accepted['version']==1
 played=ok('web-pool','turn',scoped=True,id=gid,version=1,nonce=str(uuid.uuid4()),input={'angle':0,'power':1,'offset':{'x':0,'y':0}})['game']
 assert played['state']==ok('web-pool','get',1,scoped=True,id=gid)['game']['state']and len(played['replay']['frames'])>50
 ok('web-pool','forfeit',1,scoped=True,id=gid)
 def rematch(i):return ok('web-pool','rematch',i,scoped=True,id=gid,nonce=str(uuid.uuid4()))['game']
 with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:children=list(pool.map(rematch,range(2)))
 assert children[0]['id']==children[1]['id']and all(g['status']=='pending'for g in children)
 child=children[0]['id'];receiver=0 if children[0]['yourSeat']==1 else 1
 assert ok('web-pool','get',receiver,scoped=True,id=gid)['game']['rematch']['id']==child
 assert ok('web-pool','accept',receiver,scoped=True,id=child)['game']['status']=='active'
 snapshot=ok('social','snapshot')['snapshot'];messages=next(c for c in snapshot['conversations']if c['id']==room)['messages']
 assert {gid,child}.issubset({m.get('gameSessionID')for m in messages})
 assert any(g['id']==child for g in ok('web-pool','list')['games'])
 print('PASS real DM card/acceptance, queue-accept overlap, canonical scoped shot, simultaneous same-opponent rematch, explicit consent and saved list')
 group=ok('communities','create',title=label,description='Synthetic scoped pool group test',category='Friends',is_public=False,avatar='maroon',alias='Captain',member_avatar='gold',nonce=str(uuid.uuid4()))
 room=group['room_id'];keys=[]
 for i,alias in [(1,'Comet'),(2,'Orbit')]:
  joined=ok('communities','join_code',i,invite_code=group['community']['invite_code'],alias=alias,member_avatar='sky');keys.append(next(m['member_key']for m in joined['members']if m['is_me']))
 invitation=dict(room=room,kind='pool',nonce=str(uuid.uuid4()),opponent_member_key=keys[0])
 game=ok('web-pool','invite',**invitation)['game'];gid=game['id'];assert game['players']==['Captain','Comet']
 assert call('web-pool','invite',**{**invitation,'opponent_member_key':keys[1]})[0]==409
 card=ok('web-pool','card',2,id=gid)['invitation'];assert not card['canOpen']and card['players']==['Captain','Comet']and 'state'not in card
 assert call('web-pool','accept',2,id=gid)[0]==404
 ok('web-pool','accept',1,id=gid);ok('communities','leave',1,room_id=room)
 assert call('web-pool','get',scoped=True,id=gid)[0]==403
 assert ok('web-pool','card',2,id=gid)['invitation']['status']=='unavailable'
 print('PASS explicit group recipient, alias-only card, observer isolation and removed-member access revocation')
 assert ok('web-pool','close',scoped=True)['revoked']
 assert call('web-pool','active',scoped=True)[0]==401
 assert ok('web-pool','close',scoped=True)['revoked']
 assert ok('web-pool','get',1,scoped=True,id=child)['game']['id']==child
 print('PASS pool-only self-close is idempotent and cannot revoke the other player scope')
finally:
 for i in range(len(tokens)):
  status,v=call('social','account.delete',i);assert status==200,(status,v)
 print('PASS exact synthetic fixture cleanup')
