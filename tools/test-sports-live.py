#!/usr/bin/env python3
"""One synthetic account, read-only official sports fetch; delete the account afterward."""
import json,pathlib,urllib.request,urllib.error,uuid
root=pathlib.Path(__file__).resolve().parents[1]
cfg=json.loads((root/'MaroonSocial/Resources/Backend.json').read_text())
def call(endpoint,action,token=None,**payload):
    request=urllib.request.Request(cfg['url']+'/functions/v1/'+endpoint,data=json.dumps(dict(action=action,**payload)).encode(),headers={'Content-Type':'application/json','apikey':cfg['publishableKey'],**({'X-Social-Token':token} if token else {})})
    try:
        with urllib.request.urlopen(request,timeout=30) as response:return response.status,json.load(response)
    except urllib.error.HTTPError as error:return error.code,json.load(error)
token=None
try:
    code,value=call('sports','snapshot');assert code==401
    code,value=call('sports','snapshot','0'*64);assert code==401
    code,value=call('social','register',username='scoreqa_'+uuid.uuid4().hex[:10],adult=True);token=value.get('token');assert token
    code,value=call('sports','snapshot',token);assert code==200,value
    assert value['games'] and value['livePlayAvailable'] is False
    assert all(g['status'] in ['scheduled','final','cancelled','postponed'] for g in value['games'])
    finals=[g for g in value['games'] if g['status']=='final' and g['aggieScore'] is not None]
    quotes=[g for g in value['games'] if g.get('quote')]
    assert finals,'Official results were not available'
    assert all(g['sportSlug']=='football' and g['quote']['title']=='Texas A&M wins' for g in quotes)
    code,second=call('sports','snapshot',token);assert code==200 and second['fetchedAt']==value['fetchedAt'],'Shared cache did not hold'
    print(json.dumps({'passed':True,'official_games':len(value['games']),'final_scores':len(finals),'market_quotes':len(quotes),'shared_cache':True}))
finally:
    if token:code,value=call('social','account.delete',token);assert code==200,'Synthetic account cleanup failed'
