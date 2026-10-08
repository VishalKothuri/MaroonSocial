#!/usr/bin/env python3
"""Live authoritative match regression. Creates and deletes three synthetic accounts only.
Run from the repository root. Public config is bundled; no service-role key is used.
"""
import concurrent.futures,hashlib,json,pathlib,time,urllib.request,urllib.error,uuid,os
import runner_backend
config=runner_backend.load()
fixtures=[]
def call(endpoint,action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 req=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps({'action':action,**payload}).encode(),headers=headers)
 try:
  with urllib.request.urlopen(req,timeout=35)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(endpoint,action,token=None,**payload):
 status,data=call(endpoint,action,token,**payload)
 assert status==200,(endpoint,action,status,data)
 return data
label='qagame'+str(int(time.time()))[-7:];names=[label+x for x in 'abc'];tokens=[]
try:
 for name in names:
  token=runner_backend.accept_guidelines(config,ok('social','register',username=name,adult=True))['token'];tokens.append(token)
  fixtures.append({'username':name,'hash':hashlib.sha256(token.encode()).hexdigest()})
 fd=os.open('/tmp/maroon-game-test-fixtures.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(fixtures,f)
 a,b,c=tokens
 assert call('games','list','0'*64)[0]==401
 room=ok('social','dm.request',a,username=names[1],text='Synthetic games integration')['resource_id']
 assert call('games','invite',a,room=room,kind='pool',nonce=str(uuid.uuid4()))[0]==403
 ok('social','dm.accept',b,room_id=room)
 print('PASS identity and accepted-DM invitation gate')
 for kind in ['pool','pong','chess']:
  nonce=str(uuid.uuid4());game=ok('games','invite',a,room=room,kind=kind,nonce=nonce)['game'];id=game['id']
  assert game['status']=='pending' and game['yourSeat']==0
  assert ok('games','invite',a,room=room,kind=kind,nonce=nonce)['game']['id']==id
  assert call('games','get',c,id=id)[0]==400
  assert call('games','accept',a,id=id)[0]==403
  assert call('games','commit',a,id=id,state={'winner':0})[0]==400
  game=ok('games','accept',b,id=id)['game'];assert game['status']=='active' and game['yourSeat']==1
  version=game['version'];shot={'from':'e2','to':'e4'}if kind=='chess'else{'aim':0,'power':1 if kind=='pool'else .4}
  assert call('games','turn',b,id=id,version=version,nonce=str(uuid.uuid4()),input=shot)[0]==400
  invalid={'from':'e2','to':'e5'}if kind=='chess'else{'aim':0,'power':100}
  assert call('games','turn',a,id=id,version=version,nonce=str(uuid.uuid4()),input=invalid)[0]==400
  def turn(_):return call('games','turn',a,id=id,version=version,nonce=str(uuid.uuid4()),input=shot)
  with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:results=list(pool.map(turn,range(2)))
  assert sorted(x[0]for x in results)==[200,400],[(x[0],x[1].get('error'))for x in results]
  server=next(x[1]['game']for x in results if x[0]==200)
  assert server['version']==version+1 and server['state']['shots']==1
  peer=ok('games','get',b,id=id)['game'];assert peer['state']==server['state'] and peer['replay']==server['replay'];assert peer['yourSeat']==1
  if kind!='chess':assert len(server['replay']['frames'])>10
  current=peer['state']['turn'];actor=[a,b][current]
  shot2={'from':'e7','to':'e5'}if kind=='chess'else{'aim':0,'power':.4}
  nonce=str(uuid.uuid4());payload=dict(id=id,version=peer['version'],nonce=nonce,input=shot2)
  committed=ok('games','turn',actor,**payload)['game']
  retried=ok('games','turn',actor,**payload)
  assert retried['duplicate'] and retried['game']['version']==committed['version']
  assert call('games','turn',actor,id=id,version=peer['version'],nonce=nonce,input={'aim':.1,'power':.5})[0]==400
  persisted=ok('games','list',a)['games'];assert any(g['id']==id and g['state']==committed['state']for g in persisted)
  ended=ok('games','forfeit',b,id=id)['game'];assert ended['status']=='finished' and ended['state']['winner']==0
  assert call('games','turn',a,id=id,version=ended['version'],nonce=str(uuid.uuid4()),input=shot)[0]==400
  print('PASS',kind,'invite/accept, participant and turn authorization, CAS race, canonical replay, idempotent retry, persistence, resignation')
 snapshot=ok('social','snapshot',a)['snapshot'];conversation=next(c for c in snapshot['conversations']if c['id']==room)
 assert len([m for m in conversation['messages']if m.get('gameSessionID')])==3
 invite=ok('games','invite',a,room=room,kind='pong',nonce=str(uuid.uuid4()))['game']
 assert ok('games','decline',b,id=invite['id'])['game']['status']=='declined'
 invite=ok('games','invite',a,room=room,kind='pong',nonce=str(uuid.uuid4()))['game']
 ok('social','block',b,room_id=room)
 assert call('games','accept',b,id=invite['id'])[0]==403
 assert call('games','get',a,id=invite['id'])[0]==403
 assert not ok('games','list',a)['games']
 assert call('games','invite',a,room=room,kind='pool',nonce=str(uuid.uuid4()))[0]==403
 print('PASS real invitation cards, decline and block enforcement')
finally:
 for token in tokens:
  status,result=call('social','account.delete',token)
  print('Synthetic account cleanup:',status)
  assert status==200,result
