#!/usr/bin/env python3
"""Live HTTP regression for private organization administrator access.
Registers three synthetic accounts, lets A apply for a synthetic organization, waits for an
operator to verify it (the exact social_private.operator SQL is printed; run it through the
database connector), then exercises every organization.* administrator action through the
deployed social function. All three accounts are deleted in finally; the receipt records the
exact organization and invitation IDs for the operator's scoped SQL cleanup.
"""
import hashlib,json,os,pathlib,sys,time,urllib.error,urllib.request,uuid
import runner_backend
config=runner_backend.load()
receipt=runner_backend.receipt('build/oct4-organization-admins-receipt.json');tokens=[];org=None;invitations=[]
def save(extra=None):
 data={'test':'organization-admins','token_hashes':[hashlib.sha256(t.encode()).hexdigest()for t in tokens],'organization':org,'invitations':invitations}
 if extra:data.update(extra)
 fd=os.open(receipt,os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(data,f,indent=1)
def call(action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 req=urllib.request.Request(config['url']+'/functions/v1/social',headers=headers,data=json.dumps(dict(action=action,**payload)).encode())
 try:
  with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(*args,**kwargs):
 status,result=call(*args,**kwargs);assert status==200,(args[:1],status,result);return result
def rejected(expected_status,*args,**kwargs):
 status,result=call(*args,**kwargs);assert status==expected_status,(args[:1],status,result);return result
def uid():return str(uuid.uuid4())
def admins(token):return ok('organization.admins',token,organization_id=org)
def incoming(token):return ok('organization.invitations',token)['invitations']
def organization_card(token):return next((o for o in ok('snapshot',token)['snapshot']['organizations']if o['id']==org),None)
def log(*parts):print(*parts,flush=True)
label='qaorg'+str(int(time.time()))[-7:];names={s:label+s for s in'abc'}
try:
 for suffix in'abc':tokens.append(ok('register',username=names[suffix],adult=True)['token']);save()
 a,b,c=tokens
 org=ok('organization.apply',a,name='Synthetic Org '+label,about='Automated administrator-access regression. Not a real organization.',contact='qa-automation@example.invalid',evidence='Synthetic test; verified by qa-automation for tools/test-organization-admins.py')['resource_id'];save()
 pending=admins(a);assert pending['myRole']=='owner'and pending['status']=='pending'and pending['hasOwner']and[x['username']for x in pending['administrators']]==[names['a']],pending
 assert rejected(403,'organization.invite',a,organization_id=org,username=names['b'],kind='admin',nonce=uid())['code']=='forbidden'
 log('PASS applicant is owner before review; inviting is refused until the organization is verified')
 note='Synthetic test organization created by tools/test-organization-admins.py; approve for automated administrator checks only.'
 operator_sql="select social_private.operator('organizations.review','"+json.dumps({'id':org,'decision':'verified','note':note,'evidence_checked':True}).replace("'","''")+"'::jsonb,'qa-automation') as result;"
 log('WAITING for operator verification. Run through the database connector:\n'+operator_sql)
 deadline=time.time()+float(os.environ.get('MAROON_ORG_REVIEW_TIMEOUT','900'))
 while True:
  card=organization_card(a)
  if card and card['status']=='verified':break
  assert time.time()<deadline,'Operator verification did not arrive in time'
  time.sleep(5)
 log('PASS organization verified by operator; owner card canManage =',card['canManage'])
 assert rejected(403,'organization.admins',b,organization_id=org)['code']=='forbidden'
 assert rejected(403,'organization.invite',b,organization_id=org,username=names['c'],kind='admin',nonce=uid())['code']=='forbidden'
 nonce=uid();first=ok('organization.invite',a,organization_id=org,username=names['b'],kind='admin',nonce=nonce);invitations.append(first['invitationID']);save()
 assert first['changed']and ok('organization.invite',a,organization_id=org,username=names['b'],kind='admin',nonce=nonce)==first,'Same nonce must return the same invitation'
 assert rejected(400,'organization.invite',a,organization_id=org,username=names['c'],kind='admin',nonce=nonce)['code']=='invalid','A used nonce cannot change its target'
 assert rejected(400,'organization.invite',a,organization_id=org,username=names['b'],kind='admin',nonce=uid())['code']=='invalid','Duplicate pending invitation must be rejected'
 assert rejected(400,'organization.invite',a,organization_id=org,username='no such user',kind='admin',nonce=uid())['code']=='invalid'
 mine=incoming(b);assert len(mine)==1 and mine[0]['id']==first['invitationID']and mine[0]['organizationID']==org and mine[0]['organizationName']=='Synthetic Org '+label and mine[0]['kind']=='admin'and mine[0]['expiresAt']>time.time(),mine
 assert incoming(c)==[]
 listed=admins(a)['pending'];assert[(p['id'],p['username'],p['kind'])for p in listed]==[(first['invitationID'],names['b'],'admin')],listed
 log('PASS non-admin forbidden; owner invitation idempotent per nonce; duplicate pending and unknown usernames rejected; recipient sees it incoming')
 assert ok('organization.accept',b,invitation_id=first['invitationID'])['changed']
 roster=admins(a);assert[(x['username'],x['role'])for x in roster['administrators']]==[(names['a'],'owner'),(names['b'],'admin')]and roster['pending']==[],roster
 assert all(len(x['id'])==36 for x in roster['administrators'])and not any(x['id']==org for x in roster['administrators'])
 as_admin=admins(b);assert as_admin['myRole']=='admin'and as_admin['administrators']==[]and as_admin['pending']==[],'Non-owner must not see the roster'
 assert incoming(b)==[]and organization_card(b)['canManage']and organization_card(a)['canManage']and not organization_card(c)['canManage']
 log('PASS accepted administrator appears in the owner roster with opaque keys; roster hidden from admins; snapshots show canManage for both')
 assert rejected(400,'organization.invite',a,organization_id=org,username=names['c'],kind='ownership',nonce=uid())['code']=='invalid','Ownership only to an accepted administrator'
 handoff=ok('organization.invite',a,organization_id=org,username=names['b'],kind='ownership',nonce=uid());invitations.append(handoff['invitationID']);save()
 assert[x['kind']for x in incoming(b)]==['ownership']
 assert rejected(403,'organization.accept',c,invitation_id=handoff['invitationID'])['code']=='forbidden','Only the addressee can accept'
 assert ok('organization.accept',b,invitation_id=handoff['invitationID'])['changed']
 swapped=admins(b);assert swapped['myRole']=='owner'and[(x['username'],x['role'])for x in swapped['administrators']]==[(names['b'],'owner'),(names['a'],'admin')],swapped
 assert admins(a)['myRole']=='admin'
 assert rejected(400,'organization.leave',b,organization_id=org)['code']=='invalid','Owner must transfer before leaving'
 assert rejected(403,'organization.invite',a,organization_id=org,username=names['c'],kind='admin',nonce=uid())['code']=='forbidden','Former owner can no longer invite'
 log('PASS ownership refused for non-admin, accepted by admin: roles swapped; new owner cannot leave; former owner lost management')
 assert ok('organization.leave',a,organization_id=org)['changed']
 assert rejected(403,'organization.admins',a,organization_id=org)['code']=='forbidden'and not organization_card(a)['canManage']
 assert[x['username']for x in admins(b)['administrators']]==[names['b']]
 assert rejected(400,'organization.remove',b,organization_id=org,administrator_key=uid())['code']=='invalid','Unknown administrator key'
 assert rejected(400,'organization.remove',b,organization_id=org,administrator_key='not-a-uuid')['code']=='invalid'
 own_key=admins(b)['administrators'][0]['id'];assert rejected(400,'organization.remove',b,organization_id=org,administrator_key=own_key)['code']=='invalid','Owner cannot remove themselves'
 log('PASS former owner left; unknown, malformed and self administrator keys rejected')
 fresh=ok('organization.invite',b,organization_id=org,username=names['c'],kind='admin',nonce=uid());invitations.append(fresh['invitationID']);save()
 assert[x['id']for x in incoming(c)]==[fresh['invitationID']]
 assert ok('organization.revoke',b,organization_id=org,invitation_id=fresh['invitationID'])['changed']
 assert incoming(c)==[]and admins(b)['pending']==[]
 assert rejected(400,'organization.revoke',b,organization_id=org,invitation_id=fresh['invitationID'])['code']=='invalid','Revoking twice is not a change'
 assert rejected(403,'organization.accept',c,invitation_id=fresh['invitationID'])['code']=='forbidden','Revoked invitations cannot be accepted'
 again=ok('organization.invite',b,organization_id=org,username=names['c'],kind='admin',nonce=uid());invitations.append(again['invitationID']);save()
 assert ok('organization.decline',c,invitation_id=again['invitationID'])['changed']and ok('organization.decline',c,invitation_id=again['invitationID'])['changed']
 assert incoming(c)==[]and admins(b)['pending']==[]and not organization_card(c)['canManage']
 assert rejected(403,'organization.accept',c,invitation_id=again['invitationID'])['code']=='forbidden'
 log('PASS owner revoked a pending invitation; recipient declined another (idempotent); neither can be accepted afterwards')
 log('PASS organization administrator live regression complete; organization',org,'invitations',invitations)
finally:
 failures=[]
 for t in tokens:
  try:
   status,result=call('account.delete',t)
   if status!=200:failures.append(hashlib.sha256(t.encode()).hexdigest())
  except Exception:failures.append(hashlib.sha256(t.encode()).hexdigest())
 save({'account_delete_failures':failures,'operator_cleanup':"delete from social_private.organizations where id='"+str(org)+"' and name like 'Synthetic Org qaorg%';"})
 log('Cleanup account failures:',len(failures),'receipt',receipt)
