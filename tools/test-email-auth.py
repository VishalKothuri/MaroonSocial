#!/usr/bin/env python3
"""Real JWT transport regression; synthetic confirmed Auth fixtures only, no email delivery.

Run --prepare, execute its SQL with the operator connector, then --run <fixture>.
Execute --cleanup <fixture> SQL even after failures. Never enable the public gate.
Temporary credentials are private mode-0600 files and are never printed by --run.
"""
import argparse, hashlib, json, os, pathlib, secrets, tempfile, time, urllib.request, urllib.error, uuid
import runner_backend
ROOT=pathlib.Path(__file__).resolve().parents[1]
CONFIG=runner_backend.load()
def prepare():
    peers=[]
    for suffix in ('a','b'):
        uid=str(uuid.uuid4()); name='authqa_'+uuid.uuid4().hex[:10]+suffix
        peers.append(dict(id=uid, member=str(uuid.uuid4()), email=name+'@example.invalid', username=name,password=secrets.token_urlsafe(36),hash=secrets.token_hex(32),receipt=secrets.token_hex(32)))
    fd,path=tempfile.mkstemp(prefix='maroon-auth-qa-',suffix='.json');os.fchmod(fd,0o600)
    with os.fdopen(fd,'w')as f:json.dump(peers,f)
    statements=['begin;']
    for p in peers:
        statements.append(f"""insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,confirmation_token,recovery_token,email_change_token_new,email_change,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,is_anonymous)
values('00000000-0000-0000-0000-000000000000','{p['id']}','authenticated','authenticated','{p['email']}',extensions.crypt('{p['password']}',extensions.gen_salt('bf')),now(),'','','','','{{"provider":"email","providers":["email"]}}','{{"fixture":true}}',now(),now(),false);
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)values('{p['id']}','{p['id']}','{{"sub":"{p['id']}","email":"{p['email']}","email_verified":true}}','email',now(),now());
insert into social_private.members(id,token_hash,username,adult,network_hash)values('{p['member']}','{p['hash']}','{p['username']}',true,'{p['hash']}');
insert into social_auth_private.members(auth_id,member_id)values('{p['id']}','{p['member']}');""")
    statements.append("commit; select 'synthetic Auth fixtures created' as result;")
    print(json.dumps(dict(fixture=path,sql='\n'.join(statements))))
def cleanup(path):
    peers=json.loads(pathlib.Path(path).read_text());ids=','.join("'"+p['id']+"'"for p in peers);members=','.join("'"+p['member']+"'"for p in peers)
    print(f"begin; delete from social_private.members where id in({members}); delete from social_auth_private.deletion_receipts where auth_id in({ids}); delete from social_auth_private.deletion_outbox where auth_id in({ids}); delete from social_auth_private.revoked_sessions where auth_id in({ids}); delete from social_auth_private.members where auth_id in({ids}); delete from auth.users where id in({ids}); commit; select count(*) as remaining from auth.users where id in({ids});")
def http(path,body,token=None):
    headers={'Content-Type':'application/json','apikey':CONFIG['publishableKey']}
    if token:headers['Authorization']='Bearer '+token
    req=urllib.request.Request(CONFIG['url']+path,data=json.dumps(body).encode(),headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=30)as f:return f.status,json.load(f)
    except urllib.error.HTTPError as e:return e.code,json.load(e)
def call(peer,endpoint,action,**payload):return http('/functions/v1/'+endpoint,dict(action=action,**payload),peer.get('access_token'))
def ok(pair):
    status,body=pair
    assert status==200 and not body.get('error'),(status,body.get('code'),body.get('error'))
    return body

def run(path):
    peers=json.loads(pathlib.Path(path).read_text());a,b=peers
    assert ok(http('/functions/v1/auth-account',dict(action='capabilities')))['enabled'] is False
    for p in peers:
        login=ok(http('/auth/v1/token?grant_type=password',dict(email=p['email'],password=p['password'])))
        p.update(access_token=login['access_token'],refresh_token=login['refresh_token'])
        assert ok(call(p,'auth-account','register',username='',adult=False))['state']=='linked'
        snap=ok(call(p,'social','snapshot'))['snapshot'];assert snap['username']==p['username']
        for endpoint,action in [('games','list'),('tag-game','poll'),('account-controls','connections')]:ok(call(p,endpoint,action))
        status=ok(call(p,'verification','status'));assert not status['verified']
    post=ok(call(a,'social','post.create',text='Synthetic Auth isolation test',anonymous=True,community='Texas A&M',acceptsDM=True,nonce=str(uuid.uuid4())))
    view=ok(call(b,'social','snapshot'));encoded=json.dumps(view)
    for p in peers:assert p['id'] not in encoded and p['member'] not in encoded and p['email'] not in encoded
    room=ok(call(a,'social','dm.request',username=b['username'],text='Synthetic JWT DM request'))['resource_id']
    ok(call(b,'social','dm.accept',room_id=room))
    ok(call(a,'room-calls','poll',room_id=room))
    message=ok(call(a,'social','room.send',room_id=room,text='Real signed JWT message',nonce=str(uuid.uuid4())))
    peer=ok(call(b,'social','snapshot'))['snapshot']
    assert any(m['text']=='Real signed JWT message'for c in peer['conversations']if c['id']==room for m in c['messages'])
    print('PASS real signed JWTs: two-client snapshots, private mapping, messages, games, Tag, calls, controls; no university grant')
    old=a['access_token'];refreshed=ok(http('/auth/v1/token?grant_type=refresh_token',dict(refresh_token=a['refresh_token'])))
    a.update(access_token=refreshed['access_token'],refresh_token=refreshed['refresh_token'])
    ok(call(a,'auth-account','logout'))
    for jwt in [old,a['access_token']]:
        for endpoint,action in [('social','snapshot'),('games','list'),('tag-game','poll'),('account-controls','connections'),('verification','status'),('room-calls','poll')]:
            status,body=http('/functions/v1/'+endpoint,dict(action=action,room_id=room),jwt)
            assert status==401 and body.get('code')=='unauthorized',(endpoint,status,body.get('code'))
    status,_=http('/auth/v1/token?grant_type=refresh_token',dict(refresh_token=a['refresh_token']));assert status>=400
    print('PASS refresh rotation, logout and immediate denial of both cached JWTs across every private feature')
    login=ok(http('/auth/v1/token?grant_type=password',dict(email=a['email'],password=a['password'])));a['access_token']=login['access_token']
    for p in peers:
        ok(call(p,'social','account.delete',deletion_receipt=p['receipt']))
        assert ok(http('/functions/v1/auth-account',dict(action='deletion-status',receipt=p['receipt'])))['deleted'] is True
        assert ok(http('/functions/v1/auth-account',dict(action='deletion-status',receipt=secrets.token_hex(32))))['deleted'] is False
        for endpoint,action in [('social','snapshot'),('games','list'),('tag-game','poll'),('account-controls','connections'),('verification','status'),('room-calls','poll')]:
            status,body=call(p,endpoint,action,room_id=room);assert status==401,(endpoint,status,body.get('code'))
        status,_=http('/auth/v1/token?grant_type=password',dict(email=p['email'],password=p['password']));assert status>=400
    print('PASS account deletion, private receipt lost-response recovery, Auth-user removal and cached-JWT revocation')
    assert ok(http('/functions/v1/auth-account',dict(action='capabilities')))['enabled'] is False
if __name__=='__main__':
    parser=argparse.ArgumentParser();group=parser.add_mutually_exclusive_group(required=True);group.add_argument('--prepare',action='store_true');group.add_argument('--run');group.add_argument('--cleanup');args=parser.parse_args()
    if args.prepare:prepare()
    elif args.cleanup:cleanup(args.cleanup)
    else:run(args.run)
