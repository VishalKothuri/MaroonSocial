#!/usr/bin/env python3
"""Synthetic live matching test. No existing users or posts are touched."""
import concurrent.futures, json, pathlib, time, urllib.request, urllib.error, uuid
import runner_backend
config=runner_backend.load()
tokens=[]
def call(endpoint, action, token=None, **payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token: headers['X-Social-Token']=token
 req=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps({'action':action,**payload}).encode(),headers=headers)
 try:
  with urllib.request.urlopen(req,timeout=35) as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(action,token,**payload):
 status,value=call('games',action,token,**payload)
 assert status==200,(action,status,value)
 return value
try:
 for letter in 'abcd':
  status,value=call('social','register',username='qamm'+str(int(time.time()))+letter,adult=True)
  assert status==200,(status,value);tokens.append(value['token'])
 a,b,c,d=tokens
 for kind in ['pool','pong','chess']:
  na,nb=str(uuid.uuid4()),str(uuid.uuid4())
  queued=ok('match.join',a,kind=kind,nonce=na);assert queued['queue']['status']=='waiting' and 'game' not in queued
  assert ok('match.status',a,kind=kind,nonce=na)['queue']['status']=='waiting'
  match=ok('match.join',b,kind=kind,nonce=nb)['game']
  peer=ok('match.status',a,kind=kind,nonce=na)['game']
  assert match['id']==peer['id'] and match['yourSeat']==1 and peer['yourSeat']==0 and match['status']=='active'
  assert match['players']==['Player 1','Player 2']
  assert ok('match.join',b,kind=kind,nonce=nb)['game']['id']==match['id']
  assert ok('match.join',a,kind=kind,nonce=str(uuid.uuid4()))['game']['id']==match['id']
  shot={'from':'e2','to':'e4'} if kind=='chess' else {'aim':0,'power':.5}
  assert call('games','turn',b,id=match['id'],version=0,nonce=str(uuid.uuid4()),input=shot)[0]==400
  assert call('games','get',c,id=match['id'])[0]==400
  played=ok('turn',a,id=match['id'],version=0,nonce=str(uuid.uuid4()),input=shot)['game']
  assert played['version']==1
  synced=ok('get',b,id=match['id'])['game'];assert synced['state']==played['state'] and synced['replay']==played['replay']
  ended=ok('forfeit',b,id=match['id'])['game'];assert ended['status']=='finished'
  print('PASS',kind,'queue, real peer, seat lock, wrong-turn rejection, shared replay, resume and resignation')
 # Cancelled searches cannot be revived by late status/join retries.
 na=str(uuid.uuid4());ok('match.join',a,kind='pool',nonce=na)
 assert ok('match.cancel',a,kind='pool',nonce=na)['queue']['status']=='cancelled'
 assert ok('match.status',a,kind='pool',nonce=na)['queue']['status']=='expired'
 assert ok('match.join',a,kind='pool',nonce=na)['queue']['status']=='cancelled'
 late=str(uuid.uuid4());ok('match.cancel',a,kind='pool',nonce=late)
 assert ok('match.join',a,kind='pool',nonce=late)['queue']['status']=='cancelled'
 # Concurrent joins: each account receives only one match, never its own seat twice.
 ids=[str(uuid.uuid4()) for _ in tokens]
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
  list(pool.map(lambda pair:ok('match.join',pair[0],kind='pong',nonce=pair[1]),zip(tokens,ids)))
 results=[ok('match.status',token,kind='pong',nonce=nonce)['game'] for token,nonce in zip(tokens,ids)]
 sessions={g['id'] for g in results};assert len(sessions)==2
 for sid in sessions:assert sorted(g['yourSeat'] for g in results if g['id']==sid)==[0,1]
 for token,g in zip(tokens,results):
  if g['yourSeat']==0:ok('forfeit',token,id=g['id'])
 print('PASS cancel/late retry and four-player concurrent seat assignment')
 # A blocked pair remains unmatched, even when both are searching.
 room=results[0]['roomID'];other=next(i for i,g in enumerate(results) if i!=0 and g['id']==results[0]['id'])
 assert call('social','block',a,room_id=room)[0]==200
 na,nb=str(uuid.uuid4()),str(uuid.uuid4())
 assert ok('match.join',a,kind='chess',nonce=na)['queue']['status']=='waiting'
 assert ok('match.join',tokens[other],kind='chess',nonce=nb)['queue']['status']=='waiting'
 ok('match.cancel',a,kind='chess',nonce=na);ok('match.cancel',tokens[other],kind='chess',nonce=nb)
 print('PASS blocked-player exclusion')
finally:
 for token in tokens:
  status,value=call('social','account.delete',token);print('Synthetic account cleanup:',status);assert status==200,value
