#!/usr/bin/env python3
"""Exercise live Tag with synthetic identities and synthetic coordinates only."""
import json,pathlib,time,uuid,urllib.request,urllib.error
ROOT=pathlib.Path(__file__).resolve().parents[1]
CONFIG=json.loads((ROOT/'MaroonSocial/Resources/Backend.json').read_text())
fixtures=[]
def request(endpoint,action,token=None,**payload):
    req=urllib.request.Request(CONFIG['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers={'Content-Type':'application/json','apikey':CONFIG['publishableKey'],**({'X-Social-Token':token} if token else {})})
    try:
        with urllib.request.urlopen(req,timeout=25) as response: result=json.load(response)
    except urllib.error.HTTPError as error:
        result=json.load(error)
    return result

def main():
    suffix=uuid.uuid4().hex[:9]
    for role in ('seek','hide'):
        name='tagqa_'+role+suffix
        result=request('social','register',username=name,adult=True)
        assert result.get('token'), result
        fixtures.append((name,result['token']))
    seeker,hider=[x[1] for x in fixtures]
    assert request('tag-game','poll',token='0'*64).get('error')
    nonce=str(uuid.uuid4())
    lobby=request('tag-game','create',seeker,nonce=nonce,title='Synthetic QA lobby',area='Synthetic test coordinates only',capacity=2,duration_seconds=300,hide_seconds=30,radius_m=300)
    assert lobby.get('state')=='lobby',lobby
    lid=lobby['lobby']['id'];code=lobby['lobby']['code']
    (ROOT/'build/tag-test-fixtures.json').write_text(json.dumps({'lobby':lid,'names':[x[0] for x in fixtures]}))
    def call(token,action,**kw): return request('tag-game',action,token,lobby=lid,**kw)
    joined=request('tag-game','join',hider,code=code)
    assert len(joined['players'])==2,joined
    assert call(seeker,'start').get('error')
    assert call(hider,'ready',ready=True,consent=False).get('error')
    location=dict(latitude=30.6123,longitude=-96.3412,accuracy=8,captured_at=time.time())
    assert call(seeker,'location',**location).get('error')
    assert call(seeker,'ready',ready=True,consent=True)['me']['ready']
    assert call(hider,'ready',ready=True,consent=True)['me']['ready']
    assert call(hider,'start').get('error')
    game=call(seeker,'start');assert game['state']=='hiding',game
    assert call(hider,'role',role='seeker').get('error')
    for token in (seeker,hider):
        result=call(token,'location',**dict(location,captured_at=time.time()))
        assert result['me']['location_fresh'],result
    target=next(x['id'] for x in game['players'] if x['role']=='hider')
    assert call(seeker,'catch',target=target).get('error')
    private=call(seeker,'message',body='Synthetic team message',nonce=str(uuid.uuid4()),team=True)
    assert any(x['body']=='Synthetic team message' for x in private['messages'])
    assert not any(x['body']=='Synthetic team message' for x in call(hider,'poll')['messages'])
    public_nonce=str(uuid.uuid4())
    for _ in range(2):call(seeker,'message',body='Meet at the synthetic area',nonce=public_nonce,team=False)
    assert len([x for x in call(hider,'poll')['messages'] if x['body']=='Meet at the synthetic area'])==1
    print('PASS create/join, role/readiness authorization, no location before consent/start, team privacy, message idempotency',flush=True)
    time.sleep(31)
    for token in (seeker,hider):call(token,'location',**dict(location,captured_at=time.time()))
    seek=call(seeker,'poll');hide=call(hider,'poll')
    assert seek['state']=='seeking',seek
    assert seek['hints'] and seek['hints'][0]['distance']=='Within 50 m',seek
    assert hide['hints']==[],hide
    assert call(hider,'confirm',catch=str(uuid.uuid4()),accept=True).get('error')
    assert all('latitude' not in str(x) and 'longitude' not in str(x) for x in (seek,hide))
    assert call(hider,'catch',target=target).get('error')
    attempt=call(seeker,'catch',target=target)
    assert attempt['catches'],attempt
    cid=attempt['catches'][0]['id']
    assert call(seeker,'confirm',catch=cid,accept=True).get('error')
    declined=call(hider,'confirm',catch=cid,accept=False)
    assert not declined['me']['caught']
    attempt=call(seeker,'catch',target=target);cid=attempt['catches'][0]['id']
    result=call(hider,'confirm',catch=cid,accept=True)
    assert result['state']=='finished' and result['lobby']['winner']=='seekers',result
    assert not result['me']['location_fresh'] and result['hints']==[]
    assert call(seeker,'location',**dict(location,captured_at=time.time())).get('error')
    print('PASS server clock, coarse seeker hints, mutual catch/decline, repeated catch protection, finish clears locations',flush=True)
    call(seeker,'leave');call(hider,'leave')
    safety=request('tag-game','create',seeker,nonce=str(uuid.uuid4()),title='Synthetic safety test',area='Synthetic area',capacity=2,duration_seconds=300,hide_seconds=30,radius_m=300)
    safety_id=safety['lobby']['id']
    joined=request('tag-game','join',hider,code=safety['lobby']['code'])
    target=next(x['id'] for x in joined['players'] if x['role']=='seeker')
    reason='QA synthetic safety test '+suffix
    reported=request('tag-game','report',hider,lobby=safety_id,target=target,reason=reason)
    assert reported.get('state')=='idle',reported
    blocked=request('tag-game','join',hider,code=safety['lobby']['code'])
    assert blocked.get('code')=='blocked',blocked
    (ROOT/'build/tag-test-fixtures.json').write_text(json.dumps({'lobby':lid,'report_lobby':safety_id,'report_reason':reason,'names':[x[0] for x in fixtures]}))
    print('PASS context-bound report, immediate leave, persistent block rejects rejoin',flush=True)
    print(json.dumps({'passed':True,'fixture_lobby':lid,'fixture_users':[x[0] for x in fixtures]}),flush=True)
if __name__=='__main__':
    try: main()
    finally:
        for _,token in fixtures: request('social','account.delete',token)
