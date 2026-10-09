#!/usr/bin/env python3
"""Black-box tests against the real random-chat Edge Function. Never prints credentials."""
import json, pathlib, urllib.request, urllib.error, uuid, time, os
import runner_backend
config=runner_backend.load()
base=config['url']; key=config['publishableKey']
session_file=pathlib.Path('/tmp/maroon-random-chat-test-sessions.json')
def request(action,token=None,**payload):
    headers={'Content-Type':'application/json','apikey':key}
    if token: headers['X-Chat-Token']=token
    req=urllib.request.Request(base+'/functions/v1/random-chat',data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=20) as r: return r.status,json.load(r)
    except urllib.error.HTTPError as e: return e.code,json.load(e)
def ok(action,token=None,**payload):
    status,value=request(action,token,**payload)
    assert status==200,(action,status,value)
    return value
sessions=[ok('register')['token'] for _ in range(4)]
fd=os.open(session_file,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
with os.fdopen(fd,'w') as f: json.dump(sessions,f)
a,b,c,d=sessions
for token in sessions: ok('leave',token)
assert request('poll','0'*64)[0]==401
assert request('poll')[0]==401
print('PASS missing and invalid credentials denied')
assert ok('join',a)['state']=='waiting'
r=ok('join',b)
assert r['state']=='connected'
room=r['room']
a_state=ok('poll',a)
assert a_state['room']==room and a_state['initiator']!=r['initiator']
print('PASS two independent devices match into the same room')
nonce=str(uuid.uuid4())
sent=ok('send',a,room=room,nonce=nonce,body='Howdy from test device A 🤠')
assert sent['messages'][-1]['mine'] is True
received=ok('poll',b)
assert received['messages'][-1]['body']=='Howdy from test device A 🤠' and received['messages'][-1]['mine'] is False
repeated=ok('send',a,room=room,nonce=nonce,body='Howdy from test device A 🤠')
assert len(repeated['messages'])==len(sent['messages'])
assert ok('poll',c)['messages']==[]
assert request('send',c,room=room,nonce=str(uuid.uuid4()),body='intrusion')[0]==400
assert request('send',a,room=room,nonce=str(uuid.uuid4()),body=' '*3)[0]==400
assert request('send',a,room=room,nonce=str(uuid.uuid4()),body='a'*2001)[0]==400
print('PASS message delivery, idempotency, validation, and outsider isolation')
time.sleep(1.1)
next_state=ok('next',a,room=room)
assert next_state['state']=='waiting'
assert ok('poll',b)['state']=='ended'
assert request('send',b,room=room,nonce=str(uuid.uuid4()),body='late')[0]==400
assert ok('join',b)['state']=='waiting'
assert ok('poll',a)['state']=='waiting'
r=ok('join',c)
assert r['state']=='connected'
assert ok('poll',a)['room']==r['room']
blocked_room=r['room']
ok('block',a,room=blocked_room)
assert ok('poll',c)['state']=='ended'
print('PASS Next/end, no immediate rematch, late-send rejection, block')
ok('leave',b)
ok('leave',a)
time.sleep(1.1)
capabilities=ok('capabilities')
if capabilities['media_enabled']:
    direct=capabilities.get('media_transport')=='direct'
    if direct:
        assert request('join',c,mode='video')[1]['code']=='direct_consent_required'
        assert request('join',c,mode='voice',allow_direct=False)[1]['code']=='direct_consent_required'
        assert ok('poll',c)['state']!='waiting'
        print('PASS direct call consent required before entering media queue')
    assert ok('join',c,mode='video',allow_direct=direct)['state']=='waiting'
    r=ok('join',d,mode='video',allow_direct=direct)
    assert r['state']=='connected'
    video_room=r['room']
    ok('signal',c,room=video_room,nonce=str(uuid.uuid4()),kind='offer',payload={'type':'offer','sdp':'test only'})
    ok('signal',c,room=video_room,nonce=str(uuid.uuid4()),kind='ice',payload={'candidate':'candidate:test 1 UDP 1 192.0.2.1 12345 typ host','sdpMid':'0'})
    signals=ok('poll',d)['signals']
    assert [v['kind'] for v in signals]==['offer','ice']
    assert ok('poll',d,after_signal=signals[-1]['id'])['signals']==[]
    if direct:
        assert request('media',c,room=video_room)[1]['code']=='direct_consent_required'
        call=ok('media',c,room=video_room,allow_direct=True)['call']
        assert call['transport']=='direct' and call['ice_servers'][0]['urls']
        assert request('media',a,room=video_room,allow_direct=True)[0]==400
    assert ok('poll',a)['signals']==[]
    print('PASS participant-only offer/ICE signaling, cursor, and media configuration')
else:
    assert request('join',c,mode='video')[0]==400
    assert request('join',c,mode='voice')[0]==400
    assert request('media',c,room=str(uuid.uuid4()))[0]==400
    print('PASS unavailable media fails honestly without entering a queue')
    assert ok('join',c)['state']=='waiting'
    r=ok('join',d)
    assert r['state']=='connected'
reported=ok('report',d,room=r['room'],reason='Integration test: report evidence and blocking')
assert reported['report_id'] and reported['state']=='ended'
print('PASS report receipt and peer disconnection')
# An old screen must not cancel a newer screen using the same guest identity.
time.sleep(1.1)
old_instance=str(uuid.uuid4()); new_instance=str(uuid.uuid4())
assert ok('join',a,instance=old_instance)['state']=='waiting'
ok('leave',a,instance=old_instance)
time.sleep(1.1)
assert ok('join',a,instance=new_instance)['state']=='waiting'
assert request('leave',a,instance=old_instance)[0]==400
assert ok('poll',a)['state']=='waiting'
ok('leave',a,instance=new_instance)
print('PASS stale-screen cleanup cannot clear newer matching')
for token in sessions: ok('leave',token)
req=urllib.request.Request(base+'/rest/v1/rpc/random_chat_gateway',data=json.dumps({'p_action':'poll','p_hash':'0'*64,'p_input':{}}).encode(),headers={'apikey':key,'Content-Type':'application/json'})
try:
    urllib.request.urlopen(req)
    raise AssertionError('public RPC access should fail')
except urllib.error.HTTPError as e: assert e.code in (401,403,404)
print('PASS public client cannot bypass gateway via database RPC')
print('All live integration tests passed. Test credentials are in a private /tmp file for targeted cleanup.')
