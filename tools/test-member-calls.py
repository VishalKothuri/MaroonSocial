#!/usr/bin/env python3
"""Real API checks with isolated temporary accounts; no camera, push provider, or tokens logged."""
import json,urllib.request,urllib.error,pathlib,time,uuid
import runner_backend
cfg=runner_backend.load();base=cfg['url'];key=cfg['publishableKey'];accounts=[]
def req(endpoint,action,token=None,web=None,origin=None,**payload):
 h={'Content-Type':'application/json','apikey':key}
 if token:h['X-Social-Token']=token
 if web:h['X-Maroon-Web-Session']=web
 if origin:h['Origin']=origin
 request=urllib.request.Request(base+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers=h)
 try:
  with urllib.request.urlopen(request,timeout=35)as r:return r.status,json.load(r),r.headers
 except urllib.error.HTTPError as e:return e.code,json.load(e),e.headers
def ok(endpoint,action,token=None,**payload):
 status,value,headers=req(endpoint,action,token,**payload);assert status==200,(endpoint,action,status,value);return value
try:
 suffix=str(int(time.time()))[-8:]
 for x in 'abc':accounts.append(runner_backend.accept_guidelines(cfg,ok('social','register',username='callqa'+suffix+x,adult=True))['token'])
 a,b,c=accounts
 code=ok('random-browser','pair.create',a)['code'];web=ok('random-browser','pair.claim',code=code,origin='https://maroonsocial.chat')['token']
 assert req('random-browser','pair.claim',code=code)[0]==400
 assert req('random-chat','poll',web=web,origin='https://evil.invalid')[0]==403
 instancea=str(uuid.uuid4());instanceb=str(uuid.uuid4())
 first=ok('random-chat','join',web=web,origin='https://maroonsocial.chat',mode='text',instance=instancea);assert first['state']=='waiting',first
 match=ok('random-chat','join',b,mode='text',instance=instanceb);room=match['room'];assert match['state']=='connected'
 ours=ok('random-chat','poll',web=web,instance=instancea);assert ours['room']==room
 ok('random-chat','send',web=web,room=room,instance=instancea,body='Synthetic member-bound hello',nonce=str(uuid.uuid4()))
 peer=ok('random-chat','poll',b,instance=instanceb);assert peer['messages'][-1]['body']=='Synthetic member-bound hello'
 continuation=ok('random-chat','continue',web=web,instance=instancea,room=room);dm=continuation['continue_room'];assert continuation['continue_status']=='pending'
 assert ok('random-chat','continue',web=web,instance=instancea,room=room)['continue_room']==dm
 snapshot=ok('social','snapshot',b)['snapshot'];conversation=next(x for x in snapshot['conversations']if x['id']==dm);assert conversation['request']and 'callqa'not in json.dumps(conversation)
 ok('social','dm.accept',b,room_id=dm);ok('social','room.send',b,room_id=dm,text='Continuing anonymously',nonce=str(uuid.uuid4()))
 snapshot=ok('social','snapshot',a)['snapshot'];conversation=next(x for x in snapshot['conversations']if x['id']==dm);assert conversation['messages'][-1]['author']=='Them'
 ok('random-browser','logout',web=web,instance=instancea);assert req('random-chat','poll',web=web)[0]==401
 print('PASS real browser pairing/CORS/expiry scope; two-client text, Continue request, explicit acceptance, anonymous persistent DM')
 group=ok('communities','create',a,title='Temporary call integration',description='Synthetic group call checks.',category='Friends',avatar='maroon',is_public=True,alias='Captain',member_avatar='gold',nonce=str(uuid.uuid4()))['room_id']
 ok('communities','join',b,room_id=group,alias='Comet',member_avatar='sage')
 assert req('group-calls','invite',a,room_id=group,mode='video',nonce=str(uuid.uuid4()))[0]==400
 call=ok('group-calls','invite',a,room_id=group,mode='video',allow_direct=True,nonce=str(uuid.uuid4()))['call'];callid=call['id']
 assert req('group-calls','poll',c,room_id=group)[0]==403
 peer=ok('group-calls','accept',b,room_id=group,call_id=callid,allow_direct=True)['call'];seat=peer['my_seat']
 assert 'callqa'not in json.dumps(peer) and len(peer['participants'])==2
 ok('group-calls','signal',a,room_id=group,call_id=callid,allow_direct=True,to=seat,kind='ice',payload={'candidate':'synthetic candidate contract'},nonce=str(uuid.uuid4()))
 peer=ok('group-calls','poll',b,room_id=group,call_id=callid)['call'];assert peer['signals'][-1]['kind']=='ice'
 media=ok('group-calls','media',b,room_id=group,call_id=callid,allow_direct=True);assert media['ice_servers'][0]['urls'][0].startswith('stun:')
 ok('group-calls','end',a,room_id=group,call_id=callid);assert len(ok('group-calls','poll',b,room_id=group)['call']['participants'])==1
 ok('group-calls','end',b,room_id=group,call_id=callid);assert ok('group-calls','poll',a,room_id=group)['call']is None
 print('PASS real group consent/join/scoped roster and recipient ICE/media/end; outsiders denied')
 status=ok('push-devices','status',a);assert isinstance(status['delivery_configured'],bool)
 assert req('push-delivery','anything')[0]==401
 print('PASS private push status and worker authentication (no provider delivery invoked)')
finally:
 failures=[]
 for token in accounts:
  try:ok('social','account.delete',token)
  except Exception as e:failures.append(str(e))
 assert not failures,failures
 print('CLEANUP: all temporary accounts and owned content deleted')
