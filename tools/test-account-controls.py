#!/usr/bin/env python3
"""Live caller-private account controls regression, synthetic identities only."""
import json,pathlib,time,uuid,urllib.request,urllib.error
ROOT=pathlib.Path(__file__).resolve().parents[1]
CONFIG=json.loads((ROOT/'MaroonSocial/Resources/Backend.json').read_text())
accounts=[]
resources=[]
def request(endpoint,action,token=None,**payload):
    headers={'Content-Type':'application/json','apikey':CONFIG['publishableKey']}
    if token: headers['X-Social-Token']=token
    req=urllib.request.Request(CONFIG['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=30) as r:return r.status,json.load(r)
    except urllib.error.HTTPError as e:return e.code,json.load(e)
def ok(endpoint,action,token=None,**payload):
    code,result=request(endpoint,action,token,**payload)
    assert code==200,(action,code,result.get('error'))
    if result.get('resource_id'):
        resources.append({'action':action,'id':result['resource_id']})
        (ROOT/'build/account-controls-test-fixtures.json').write_text(json.dumps(resources))
    return result
def main():
    suffix=uuid.uuid4().hex[:8]
    for n in range(3):
        name='controlqa'+str(n)+suffix
        data=ok('social','register',username=name,adult=True)
        accounts.append((name,data['token']))
    (an,a),(bn,b),(cn,c)=accounts
    ctl=lambda action,token,**kw:ok('account-controls',action,token,**kw)
    assert request('account-controls','connections','0'*64)[0]==401
    outgoing=ctl('connection.request',a,username=bn)['connections'];assert len(outgoing)==1 and outgoing[0]['status']=='outgoing'
    relation=outgoing[0]['id']
    assert len(ctl('connection.request',a,username=bn)['connections'])==1
    incoming=ctl('connection.request',b,username=an)['connections'];assert len(incoming)==1 and incoming[0]['status']=='incoming'
    assert request('account-controls','connection.accept',a,id=relation)[0]==403
    assert request('account-controls','connection.accept',c,id=relation)[0]!=200
    assert ctl('connections',c)['connections']==[]
    accepted=ctl('connection.accept',b,id=relation)['connections'];assert accepted[0]['status']=='accepted'
    assert ctl('connections',a)['connections'][0]['username']==bn
    print('PASS named consent, idempotent requests, recipient-only accept and outsider isolation',flush=True)
    post=ok('social','post.create',a,text='Anonymous account-controls test',anonymous=True,acceptsDM=True)['resource_id']
    reply=ok('social','comment.create',b,post_id=post,text='Another person private export exclusion')['resource_id']
    room=ok('social','dm.request',b,post_id=post,text='Synthetic initial message')['resource_id']
    ok('social','dm.accept',a,room_id=room)
    ok('social','room.send',a,room_id=room,text='My export text',nonce=str(uuid.uuid4()))
    ok('social','room.send',b,room_id=room,text='Someone else must not be exported',nonce=str(uuid.uuid4()))
    account=ctl('export',a,section='account')['data'];assert account['username']==an
    assert not any(key in json.dumps(account) for key in ['token_hash','network_hash','member_id'])
    assert len(ctl('export',a,section='posts')['data'])==1
    assert ctl('export',a,section='replies')['data']==[]
    messages=ctl('export',a,section='messages')['data'];assert len(messages)==1 and messages[0]['body']=='My export text'
    assert messages[0]['context']=='Anonymous conversation' and bn not in json.dumps(messages)
    assert ctl('export',c,section='posts',member_id=an)['data']==[]
    assert request('account-controls','export',a,section='credentials')[0]==400
    assert request('account-controls','export',a,section='posts',offset=-1)[0]==400
    print('PASS self-only JSON export, anonymous conversation labels, no peer messages or credentials',flush=True)
    ok('social','block',b,post_id=post)
    blocks=ctl('blocks',b)['blocks'];assert len(blocks)==1
    assert blocks[0]['label'].startswith('Anonymous post') and an not in json.dumps(blocks)
    assert ctl('connections',a)['connections']==[] and ctl('connections',b)['connections']==[]
    assert request('account-controls','connection.request',a,username=bn)[0]!=200
    assert request('account-controls','block.context',b,post_id=post)[0]==400
    ctl('block.remove',c,id=blocks[0]['id'])
    assert len(ctl('blocks',b)['blocks'])==1
    ctl('block.remove',b,id=blocks[0]['id'])
    assert ctl('blocks',b)['blocks']==[] and ctl('connections',a)['connections']==[]
    assert request('account-controls','connection.request',a,username=bn)[0]==429
    # Explicit removal/decline on a different pair, with no accidental mutual acceptance.
    rel=ctl('connection.request',a,username=cn)['connections'][0]['id']
    ctl('connection.remove',c,id=rel)
    assert ctl('connections',a)['connections']==[]
    print('PASS scoped anonymous block labels, owner-only unblock, connection revocation and re-request cooldown',flush=True)
    print('All account-controls checks passed.',flush=True)
if __name__=='__main__':
    try:main()
    finally:
        for _,token in accounts:request('social','account.delete',token)
