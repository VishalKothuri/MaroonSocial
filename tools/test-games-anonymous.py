#!/usr/bin/env python3
"""Prove that anonymous post-origin DMs retain anonymity in game snapshots."""
import json,pathlib,time,urllib.request,urllib.error,uuid
import runner_backend
config=runner_backend.load()
def call(endpoint,action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 req=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
 with urllib.request.urlopen(req,timeout=35)as r:return json.load(r)
names=['qaganon'+str(int(time.time()))[-7:]+x for x in 'ab'];tokens=[]
def private(response):
 serialized=json.dumps(response)
 assert not any(name in serialized for name in names), 'Anonymous username leaked'
 if 'game' in response:assert response['game']['players']==['Player 1','Player 2']
 for g in response.get('games',[]):assert g['players']==['Player 1','Player 2']
 return response
try:
 for name in names:tokens.append(call('social','register',username=name,adult=True)['token'])
 a,b=tokens
 post=call('social','post.create',a,text='Synthetic anonymous game privacy verification',anonymous=True,community='Texas A&M',acceptsDM=True,nonce=str(uuid.uuid4()))['resource_id']
 room=call('social','dm.request',b,post_id=post,text='Synthetic private game invitation')['resource_id']
 call('social','dm.accept',a,room_id=room)
 g=private(call('games','invite',b,room=room,kind='pool',nonce=str(uuid.uuid4())))['game']
 private(call('games','get',a,id=g['id']))
 g=private(call('games','accept',a,id=g['id']))['game']
 private(call('games','turn',b,id=g['id'],version=g['version'],nonce=str(uuid.uuid4()),input={'aim':0,'power':1}))
 for token in tokens:
  private(call('games','get',token,id=g['id']));private(call('games','list',token))
 print('PASS anonymous post-origin DM: invite, accept, get, list and canonical turn all preserve Player1/Player2 aliases; neither username appears')
finally:
 for token in tokens:call('social','account.delete',token)
 print('Synthetic anonymous game accounts deleted')
