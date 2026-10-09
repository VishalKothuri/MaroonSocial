#!/usr/bin/env python3
"""HTTP tests for provisioned synthetic members + one synthetic verified org.
Never alters a real organization or account; both accounts deleted in finally.
"""
import base64,json,pathlib,sys,time,urllib.request,urllib.error,uuid
import runner_backend
config=runner_backend.load();fixture=pathlib.Path(sys.argv[1]);data=json.loads(fixture.read_text());people=data['people'];org=data['organization'];ids=[]
def call(endpoint,action,token,**payload):
 request=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers={'Content-Type':'application/json','apikey':config['publishableKey'],'X-Social-Token':token})
 try:
  with urllib.request.urlopen(request,timeout=45)as response:return response.status,json.load(response)
 except urllib.error.HTTPError as error:return error.code,json.load(error)
def ok(endpoint,action,token,**payload):
 status,result=call(endpoint,action,token,**payload);assert status==200,(action,status,result);return result
try:
 a,b=[p['token']for p in people]
 # A new series needs the community guidelines accepted (does nothing on a server without them).
 for token in(a,b):runner_backend.accept_guidelines(config,ok('social','snapshot',token),token)
 payload=dict(nonce=str(uuid.uuid4()),title='Synthetic weekly study',place='MSC test only',starts=int(time.time()+86400),weeks=3,capacity=6,details='Synthetic API validation',approval_required=True,course='CHEM 107')
 result=ok('activity-plans','series.create',a,**payload);ids.extend(result['activity_ids']);assert len(ids)==3
 assert ok('activity-plans','series.create',a,**payload)==result
 assert call('activity-plans','series.create',a,**dict(payload,title='Different'))[0]==400
 snap=ok('social','snapshot',b)['snapshot'];assert all(any(p['id']==i and p['approvalRequired']for p in snap['activities'])for i in ids)
 info=ok('activity-plans','series.info',b,activity_id=ids[0]);assert info['is_series']and not info['can_manage']and len(info['occurrences'])==3
 assert call('activity-plans','series.cancel_future',b,activity_id=ids[0])[0]==403
 cancelled=ok('activity-plans','series.cancel_future',a,activity_id=ids[0]);assert all(x['cancelled']for x in cancelled['occurrences'])
 print('PASS shared weekly creation, immutable nonce retry, approval per occurrence, host-only series cancellation')
 payload=dict(nonce=str(uuid.uuid4()),organization_id=org,title='Synthetic organization promotion',place='MSC test only',starts=int(time.time()+86400),capacity=20,details='Synthetic poster publication')
 assert call('activity-plans','promotion.create',b,**payload)[0]==403
 publication=ok('activity-plans','promotion.create',a,**payload);event=publication['activity_id'];ids.append(event)
 assert ok('activity-plans','promotion.create',a,**payload)==publication
 photo=base64.b64encode(pathlib.Path('build/synthetic-media/synthetic-photo.jpg').read_bytes()).decode()
 assert call('activity-plans','poster.upload',b,activity_id=event,data=photo)[0]==403
 ok('activity-plans','poster.upload',a,activity_id=event,data=photo)
 poster=ok('activity-plans','poster.read',b,activity_id=event);assert poster['has_poster']and base64.b64decode(poster['media_data']).startswith(b'\xff\xd8')
 snapshot=ok('social','snapshot',b)['snapshot'];visible=next(x for x in snapshot['activities']if x['id']==event);assert visible['host'].startswith('Synthetic Org')
 assert all(p['username']not in json.dumps(visible)for p in people)
 ok('activity-plans','poster.remove',a,activity_id=event);assert not ok('activity-plans','poster.read',b,activity_id=event)['has_poster']
 print('PASS verified admin publication, nonadmin denial, same promotion on retry, real sanitized JPEG poster read/removal, organization byline hides admin usernames')
finally:
 runner_backend.receipt('build/synthetic-media/plan-receipts.json').write_text(json.dumps({'activities':ids,'organization':org}))
 for person in people:
  status,result=call('social','account.delete',person['token']);assert status==200,result
 fixture.unlink(missing_ok=True)
 print('PASS synthetic accounts deleted; targeted synthetic organization/room cleanup receipt saved')
