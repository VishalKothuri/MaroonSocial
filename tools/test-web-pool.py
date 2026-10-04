#!/usr/bin/env python3
"""Actual pool-only session, queue, canonical 3D physics and two-member turn API.
Only generated QA accounts are created and deleted. No service secret required.
"""
import concurrent.futures,hashlib,json,pathlib,subprocess,time,urllib.request,urllib.error,uuid
cfg=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text());tokens=[];scopes=[]
def call(endpoint,action,credential=None,scope=None,origin=None,**data):
 h={'Content-Type':'application/json','apikey':cfg['publishableKey']}
 if credential:h['X-Social-Token']=credential
 if scope:h['X-Maroon-Pool-Session']=scope
 if origin:h['Origin']=origin
 req=urllib.request.Request(cfg['url']+'/functions/v1/'+endpoint,data=json.dumps({'action':action,**data}).encode(),headers=h)
 try:
  with urllib.request.urlopen(req,timeout=35)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(action,index=0,**data):
 status,v=call('web-pool',action,scope=scopes[index],origin='https://games.maroonsocial.chat',**data);assert status==200,(action,status,v);return v
try:
 for i in range(3):
  status,v=call('social','register',username='wpqa'+str(int(time.time()))[-7:]+str(i),adult=True);assert status==200,(status,v);tokens.append(v['token'])
  status,v=call('web-pool','session',credential=tokens[-1]);assert status==200,(status,v);scopes.append(v['token']);assert v['rules']=='maroon-web-pool-3.0.0'
 assert call('web-pool','active',scope=scopes[0],origin='https://evil.example')[0]==403
 assert call('web-pool','active',scope='0'*64)[0]==401
 assert call('social','snapshot',credential=scopes[0])[0]==401
 assert call('web-pool','commit',scope=scopes[0],state={'winner':0})[0]==400
 print('PASS scope isolation, exact Origin and private commit boundary')
 na,nb=str(uuid.uuid4()),str(uuid.uuid4());ok('cancel',nonce=na);assert ok('join',nonce=na)['queue']=='cancelled';na=str(uuid.uuid4())
 def join(i):return ok('join',i,nonce=[na,nb][i])
 with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:results=list(pool.map(join,range(2)))
 a=ok('poll_queue',nonce=na)['game'];b=ok('poll_queue',1,nonce=nb)['game'];assert a['id']==b['id']and a['yourSeat']!=b['yourSeat'];assert a['players']==['Player 1','Player 2'];gid=a['id']
 assert ok('cancel',nonce=na)['game']['id']==gid
 assert call('web-pool','get',scope=scopes[2],id=gid)[0]==404
 first=0 if a['yourSeat']==0 else 1;other=1-first;shot={'angle':0,'power':1,'offset':{'x':0,'y':0}}
 assert call('web-pool','turn',scope=scopes[other],id=gid,nonce=str(uuid.uuid4()),version=0,input=shot)[0]==409
 assert call('web-pool','turn',scope=scopes[first],id=gid,nonce=str(uuid.uuid4()),version=0,input={**shot,'power':20})[0]==400
 print('PASS simultaneous pairing, cancel race, outsider read and opponent turn denial')
 nonce=str(uuid.uuid4());payload=dict(id=gid,nonce=nonce,version=0,input=shot)
 def turn(_):return call('web-pool','turn',scope=scopes[first],**{**payload,'nonce':str(uuid.uuid4())})
 with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:results=list(pool.map(turn,range(2)))
 assert sorted(r[0]for r in results)==[200,409],[(r[0],r[1].get('error'))for r in results]
 played=next(r[1]['game']for r in results if r[0]==200);peer=ok('get',other,id=gid)['game'];assert played['state']==peer['state']and played['replay']==peer['replay'];assert len(peer['replay']['frames'])>50
 module=(pathlib.Path('games/web-pool-prototype/server/engine.mjs').resolve()).as_uri()
 script=f"import{{initialState,resolveTurn}}from'{module}';console.log(JSON.stringify(resolveTurn(initialState(),{json.dumps(shot)})));"
 local=json.loads(subprocess.check_output(['node','--input-type=module','-e',script]));assert local['state']==peer['state']and local['replay']==peer['replay']
 actor=first if played['state']['turn']==0 else other
 payload.update(version=1,nonce=str(uuid.uuid4()),input={**shot,'power':.2})
 result=ok('turn',actor,**payload);retry=ok('turn',actor,**payload);assert retry['duplicate']and retry['game']['version']==2
 assert call('web-pool','turn',scope=scopes[actor],**{**payload,'input':shot})[0]==409
 assert ok('active')['game']['id']==gid
 ended=ok('forfeit',other,id=gid)['game'];assert ended['status']=='finished'
 print('PASS server/Web3 engine parity, concurrent CAS, canonical peer replay, idempotent shot, recovery and resignation')
 status,_=call('web-pool','revoke',credential=tokens[0],**{'token':scopes[0]})
 assert status==200;assert call('web-pool','active',scope=scopes[0])[0]==401
 print('PASS explicit browser scope revocation')
finally:
 for token in tokens:
  status,v=call('social','account.delete',credential=token);assert status==200,(status,v)
 print('PASS exact synthetic account cleanup')
