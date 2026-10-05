#!/usr/bin/env python3
"""Live check of the `realtime.token` action against the deployed `social` edge function.

Today (REALTIME_JWT_SECRET not set) a signed-in member must get exactly {"realtime": false}, so the
app keeps polling; an unauthenticated call must still be refused. Once the owner sets the secret and
applies the realtime_pokes migrations, run with EXPECT_REALTIME=1: the answer must then carry a
15-minute HS256 token for this member (claims checked, signature not: the secret never leaves the
server). The token itself is never printed. One synthetic account, deleted in `finally`.
"""
import base64, json, os, pathlib, time, urllib.request, urllib.error, uuid
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens=[]; label='rt'+uuid.uuid4().hex[:9]
def call(action,token=None,**payload):
    headers={'Content-Type':'application/json','apikey':config['publishableKey']}
    if token:headers['X-Social-Token']=token
    request=urllib.request.Request(config['url']+'/functions/v1/social',data=json.dumps({'action':action,**payload}).encode(),headers=headers)
    try:
        with urllib.request.urlopen(request,timeout=40)as response:return response.status,json.load(response)
    except urllib.error.HTTPError as error:return error.code,json.load(error)
def ok(action,token=None,**payload):
    status,result=call(action,token,**payload)
    assert status==200,(action,status,result.get('code'),result.get('error'))
    return result
def claims(token):
    part=token.split('.')[1]; return json.loads(base64.urlsafe_b64decode(part+'='*(-len(part)%4)))
try:
    status,result=call('realtime.token')
    assert status==401 and 'token' not in result,('unauthenticated realtime.token',status,result.get('code'))
    status,result=call('realtime.token',token='0'*64)
    assert 'token' not in result,'an unknown credential received a token'
    tokens.append(ok('register',username=label,adult=True)['token'])
    grant=ok('realtime.token',tokens[0])
    if os.environ.get('EXPECT_REALTIME')=='1':
        assert grant.get('realtime') is True and set(grant)=={'realtime','token','expires_at','expires_in','member'},sorted(grant)
        c=claims(grant['token']); now=time.time()
        assert c['role']=='authenticated' and c['aud']=='authenticated' and c['iss']=='maroon-social' and c['sub']==grant['member'],sorted(c)
        assert c['exp']-c['iat']==900==grant['expires_in'] and now-60<c['iat']<now+60 and grant['expires_at']==c['exp']
        print('PASS realtime.token mints a 15-minute member token (claims checked; token not printed)',flush=True)
    else:
        assert grant=={'realtime':False},('expected the polling fallback while REALTIME_JWT_SECRET is unset',sorted(grant))
        print('PASS realtime.token answers {"realtime": false} without the secret; unauthenticated calls are refused',flush=True)
finally:
    for token in tokens:
        status,result=call('account.delete',token)
        if status!=200:raise RuntimeError(('Synthetic account cleanup failed',status,result.get('code')))
    print('Synthetic account deleted.',flush=True)
