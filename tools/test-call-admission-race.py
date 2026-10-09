#!/usr/bin/env python3
"""Live simultaneous HTTP admissions across discovery/DM/group calls, including a
member's own poll/heartbeat/list/leave loops racing its own admission (the production
pattern: GroupCallService/RoomCallService poll every 1.3 s during a call and
DiscoveryService heartbeats). Any response anywhere carrying the admission wrappers'
deadlock backstop (code 'retry' / 'Please try again.') fails the run. Temporary
development identities only; no media/device use. Accounts are deleted in finally; the
closed DM/group rooms remain as tombstones by design and are recorded with one-way
credential hashes in the receipt for scoped operator cleanup (tools/social-admin.py).
"""
import concurrent.futures,hashlib,json,os,pathlib,threading,time,urllib.error,urllib.request,uuid
import runner_backend
config=runner_backend.load()
tokens=[];rooms=[];receipt=pathlib.Path('/tmp/maroon-call-admission-race-receipt.json');instance={}
def save():
 data={'test':'cross-call-admission-race','token_hashes':[hashlib.sha256(t.encode()).hexdigest()for t in tokens],'rooms':rooms}
 fd=os.open(receipt,os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w')as f:json.dump(data,f)
budget={};budget_lock=threading.Lock()
def pace(token,per_second=9):
 """Keep each synthetic member under require_account's 600/minute budget whatever the latency, so a 429 never masquerades as a lock-order failure."""
 if not token:return
 while True:
  with budget_lock:
   now=time.time();recent=[t for t in budget.get(token,[])if t>now-1]
   if len(recent)<per_second:recent.append(now);budget[token]=recent;return
   wait=recent[0]+1-now
  time.sleep(max(wait,0.01))
def call(endpoint,action,token=None,**payload):
 pace(token)
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
def storm(label,loops,admissions,accept,rounds=1,extras=()):
 """Concurrent unwrapped loops (group poll, discovery heartbeat/list) plus one-off extras (discovery leave) for one member
 while that member repeats its own wrapped admission. Every loop and extra response must be 200 and every admission must
 satisfy accept(); a legitimate refusal keeps its own code and message, the deadlock backstop ('retry') fails the run."""
 responses=0
 for r in range(rounds):
  stop=threading.Event();counts={}
  def loop(name,fn):
   while not stop.is_set():
    status,result=fn();assert status==200,(label,'round',r+1,name,status,result)
    with stats_lock:counts[name]=counts.get(name,0)+1
  with concurrent.futures.ThreadPoolExecutor(len(loops)+len(extras)+1)as pool:
   running=[pool.submit(loop,name,fn)for name,fn in loops]
   try:
    once=[pool.submit(fn)for fn in extras]
    for admit in admissions:
     status,result=admit();assert accept(status,result),(label,'round',r+1,status,result)
    for f in once:status,result=f.result();assert status==200,(label,'round',r+1,'extra',status,result)
   finally:stop.set()
   for f in running:f.result()
  responses+=sum(counts.values())
 no_retry(label);print('PASS',label,'rounds',rounds,'admissions',len(admissions)*rounds,'loop responses',responses,flush=True)
def joined(call_id):return lambda s,r:s==200 and(r.get('call')or{}).get('id')==call_id and r['call'].get('joined')is True
def waiting(s,r):return s==200 and r.get('state')=='waiting'
label='qarace'+str(int(time.time()))[-7:]
def uid():return str(uuid.uuid4())
try:
 for suffix in'ab':
  tokens.append(runner_backend.accept_guidelines(config,ok('social','register',username=label+suffix,adult=True))['token']);save()
 a,b=tokens;instance={a:uid(),b:uid()}
 dm=ok('social','dm.request',a,username=label+'b',text='Synthetic call admission test',nonce=uid())['resource_id'];rooms.append(dm);save();ok('social','dm.accept',b,room_id=dm)
 group=ok('communities','create',a,title=label,description='Synthetic concurrent call admission test.',category='Friends',avatar='gold',is_public=True,alias='Copper',member_avatar='sage',nonce=uid())['room_id'];rooms.append(group);save();ok('communities','join',b,room_id=group,alias='Silver',member_avatar='sky')
 for t,suffix in[(a,'a'),(b,'b')]:ok('discovery','profile',t,instance=instance[t],username=label+suffix,tags=['testing'])
 def enter(t):return call('discovery','enter',t,instance=instance[t],allow_direct=True)
 def dm_invite(t,nonce=None):return call('room-calls','invite',t,room_id=dm,mode='video',allow_direct=True,nonce=nonce or uid())
 def group_invite(t,nonce=None):return call('group-calls','invite',t,room_id=group,mode='video',allow_direct=True,nonce=nonce or uid())
 def group_poll(t):return call('group-calls','poll',t,room_id=group)
 def heartbeat(t):return call('discovery','heartbeat',t,instance=instance[t])
 def listing(t):return call('discovery','list',t,instance=instance[t])
 def leave(t):return call('discovery','leave',t,instance=instance[t])
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
 # Same member: unwrapped group poll loops against its own wrapped accept / invite retry (members-row-first lock order).
 nonce=uid();group_call=ok('group-calls','invite',a,room_id=group,mode='video',allow_direct=True,nonce=nonce)['call']['id']
 def group_accept(t):return call('group-calls','accept',t,room_id=group,call_id=group_call,allow_direct=True)
 storm('Same-member group poll loop vs accept/invite retries',[('group poll',lambda:group_poll(a))]*4,[(lambda:group_accept(a))if i%2 else(lambda:group_invite(a,nonce))for i in range(24)],joined(group_call))
 storm('Co-member group poll loop vs its own accept retries',[('group poll',lambda:group_poll(b))]*4,[lambda:group_accept(b)for i in range(12)],joined(group_call))
 # The production mix for one member: 4 group poll loops + 4 discovery heartbeat/list loops + one discovery leave, several rounds,
 # while that member repeats its own group invite (same nonce) and, separately, its own discovery entry.
 mix=[('group poll',lambda:group_poll(a))]*4+[('discovery heartbeat',lambda:heartbeat(a))]*2+[('discovery list',lambda:listing(a))]*2
 storm('Member poll/heartbeat/list/leave storm vs own group invite retries',mix,[lambda:group_invite(a,nonce)for i in range(6)],joined(group_call),rounds=3,extras=[lambda:leave(a)]);clean()
 storm('Member poll/heartbeat/list/leave storm vs own discovery re-entry',mix,[lambda:enter(a)for i in range(6)],waiting,rounds=3,extras=[lambda:leave(a)]);clean()
 # Same member: unwrapped discovery leave / heartbeat against its own wrapped DM invite / re-entry.
 for i in range(3):
  ok('discovery','enter',a,instance=instance[a],allow_direct=True)
  race(lambda:leave(a),lambda:dm_invite(a),'Same-member discovery leave vs DM invite '+str(i+1),either=True);clean()
 ok('discovery','enter',a,instance=instance[a],allow_direct=True);time.sleep(16)
 values=race(lambda:heartbeat(a),lambda:enter(a),'Same-member heartbeat vs re-entry after stale presence',either=True);assert all(s==200 for s,_ in values),values;clean()
 no_retry('final');print('PASS 17 simultaneous HTTP scenarios; no capture or Apple delivery invoked',flush=True)
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
