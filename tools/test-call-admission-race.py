#!/usr/bin/env python3
"""Live simultaneous HTTP admissions across discovery/DM/group calls, including a
member's own poll/heartbeat/leave racing its own admission (the production pattern:
the apps poll every 1.3 s during a call). Any response carrying the deadlock backstop
(code 'retry' / 'Please try again.') fails the run. Temporary development identities
only; no media/device use. Accounts are deleted in finally; the closed DM/group rooms
remain as tombstones by design and are recorded with one-way credential hashes in the
receipt for scoped operator cleanup (tools/social-admin.py).
"""
import concurrent.futures,hashlib,json,os,pathlib,threading,time,urllib.error,urllib.request,uuid
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens=[];rooms=[];receipt=pathlib.Path('/tmp/maroon-call-admission-race-receipt.json');instance={}
def save():
 data={'test':'cross-call-admission-race','token_hashes':[hashlib.sha256(t.encode()).hexdigest()for t in tokens],'rooms':rooms}
 fd=os.open(receipt,os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(data,f)
def call(endpoint,action,token=None,**payload):
 headers={'Content-Type':'application/json','apikey':config['publishableKey']}
 if token:headers['X-Social-Token']=token
 req=urllib.request.Request(config['url']+'/functions/v1/'+endpoint,headers=headers,data=json.dumps(dict(action=action,**payload)).encode())
 started=time.time()
 try:
  with urllib.request.urlopen(req,timeout=30)as r:status,result=r.status,json.load(r)
 except urllib.error.HTTPError as e:status,result=e.code,json.load(e)
 with stats_lock:
  elapsed=time.time()-started;stats['calls']+=1;stats['slowest']=max(stats['slowest'],elapsed)
  if elapsed>=0.95:stats['slow']+=1
  if result.get('code')=='retry'or result.get('error')=='Please try again.':stats['retry'].append((endpoint,action,status,result))
 return status,result
stats={'calls':0,'slow':0,'slowest':0.0,'retry':[]};stats_lock=threading.Lock()
def ok(*args,**kwargs):
 status,result=call(*args,**kwargs);assert status==200,(args[:2],status,result);return result
def no_retry(label):assert not stats['retry'],(label,stats['retry'])
def race(left,right,label,same=False,either=False):
 barrier=threading.Barrier(2)
 def run(fn):barrier.wait();return fn()
 with concurrent.futures.ThreadPoolExecutor(2)as pool:
  f1=pool.submit(run,left);f2=pool.submit(run,right);values=[f1.result(),f2.result()]
 no_retry(label)
 if same:
  assert all(v[0]==200 for v in values),(label,values)
  assert values[0][1]['call']['id']==values[1][1]['call']['id'],(label,values)
 elif either:
  assert all(s==200 or v.get('code')=='busy'for s,v in values),(label,values)
 else:
  assert sum(s==200 for s,_ in values)==1,(label,values)
  assert all(s==200 or v.get('code')=='busy'for s,v in values),(label,values)
 print('PASS',label,flush=True);return values
def poll_storm(label,poll,admissions,expect_call):
 """Several concurrent poll loops for one member while that member repeats its own admissions."""
 stop=threading.Event();counts={'polls':0}
 def poller():
  while not stop.is_set():
   status,result=poll();assert status==200,(label,'poll',status,result)
   with stats_lock:counts['polls']+=1
 with concurrent.futures.ThreadPoolExecutor(4)as pool:
  pollers=[pool.submit(poller)for _ in range(4)]
  try:
   for admit in admissions:
    status,result=admit();assert status==200 and result['call']['id']==expect_call and result['call']['joined']is True,(label,status,result)
  finally:stop.set()
  for f in pollers:f.result()
 no_retry(label);print('PASS',label,'admissions',len(admissions),'polls',counts['polls'],flush=True)
label='qarace'+str(int(time.time()))[-7:]
def uid():return str(uuid.uuid4())
try:
 for suffix in'ab':
  tokens.append(ok('social','register',username=label+suffix,adult=True)['token']);save()
 a,b=tokens;instance={a:uid(),b:uid()}
 dm=ok('social','dm.request',a,username=label+'b',text='Synthetic call admission test',nonce=uid())['resource_id'];rooms.append(dm);save();ok('social','dm.accept',b,room_id=dm)
 group=ok('communities','create',a,title=label,description='Synthetic concurrent call admission test.',category='Friends',avatar='gold',is_public=True,alias='Copper',member_avatar='sage',nonce=uid())['room_id'];rooms.append(group);save();ok('communities','join',b,room_id=group,alias='Silver',member_avatar='sky')
 for t,suffix in[(a,'a'),(b,'b')]:ok('discovery','profile',t,instance=instance[t],username=label+suffix,tags=['testing'])
 def enter(t):return call('discovery','enter',t,instance=instance[t],allow_direct=True)
 def dm_invite(t,nonce=None):return call('room-calls','invite',t,room_id=dm,mode='video',allow_direct=True,nonce=nonce or uid())
 def group_invite(t,nonce=None):return call('group-calls','invite',t,room_id=group,mode='video',allow_direct=True,nonce=nonce or uid())
 def clean():
  for t in tokens:
   ok('discovery','leave',t,instance=instance[t])
   value=ok('room-calls','poll',t,room_id=dm).get('call')
   if value:ok('room-calls','end',t,room_id=dm,call_id=value['id'])
   value=ok('group-calls','poll',t,room_id=group).get('call')
   if value:ok('group-calls','end',t,room_id=group,call_id=value['id'])
 for i in range(3):race(lambda:dm_invite(a),lambda:enter(b),'DM vs recipient discovery '+str(i+1));clean()
 for i in range(3):race(lambda:group_invite(a),lambda:enter(a),'Group vs same-member discovery '+str(i+1));clean()
 race(lambda:dm_invite(a),lambda:group_invite(b),'DM vs recipient group join');clean()
 race(lambda:dm_invite(a),lambda:dm_invite(b),'Opposite-direction DM invitations');clean()
 nonce=uid();race(lambda:group_invite(a,nonce),lambda:group_invite(a,nonce),'Concurrent identical group nonce retry',same=True);clean()
 # Same member: unwrapped poll loop against its own wrapped accept / invite retry (members-row-first lock order).
 nonce=uid();group_call=ok('group-calls','invite',a,room_id=group,mode='video',allow_direct=True,nonce=nonce)['call']['id']
 def group_accept(t):return call('group-calls','accept',t,room_id=group,call_id=group_call,allow_direct=True)
 poll_storm('Same-member group poll loop vs accept/invite retries',lambda:call('group-calls','poll',a,room_id=group),[(lambda:group_accept(a))if i%2 else(lambda:group_invite(a,nonce))for i in range(40)],group_call)
 poll_storm('Co-member group poll loop vs its own accept retries',lambda:call('group-calls','poll',b,room_id=group),[lambda:group_accept(b)for i in range(20)],group_call);clean()
 # Same member: unwrapped discovery leave / heartbeat against its own wrapped DM invite / re-entry.
 for i in range(3):
  ok('discovery','enter',a,instance=instance[a],allow_direct=True)
  race(lambda:call('discovery','leave',a,instance=instance[a]),lambda:dm_invite(a),'Same-member discovery leave vs DM invite '+str(i+1),either=True);clean()
 ok('discovery','enter',a,instance=instance[a],allow_direct=True);time.sleep(16)
 values=race(lambda:call('discovery','heartbeat',a,instance=instance[a]),lambda:enter(a),'Same-member heartbeat vs re-entry after stale presence',either=True);assert all(s==200 for s,_ in values),values;clean()
 no_retry('final');print('PASS 14 simultaneous HTTP scenarios; no capture or Apple delivery invoked',flush=True)
finally:
 failures=[]
 for t in tokens:
  try:
   if t in instance:call('discovery','leave',t,instance=instance[t])
   status,result=call('social','account.delete',t)
   if status!=200:failures.append(hashlib.sha256(t.encode()).hexdigest())
  except Exception:failures.append(hashlib.sha256(t.encode()).hexdigest())
 save();data=json.loads(receipt.read_text());data['account_delete_failures']=failures;receipt.write_text(json.dumps(data,indent=2)+'\n')
 print('Cleanup account failures:',len(failures),flush=True)
 print('Calls:',stats['calls'],'deadlock-backstop responses:',len(stats['retry']),'slow(>=0.95s):',stats['slow'],'slowest: %.2fs'%stats['slowest'],flush=True)
 print('Tombstones by design: closed rooms',rooms,'remain after member deletion; receipt',str(receipt),flush=True)
