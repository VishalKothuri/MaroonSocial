#!/usr/bin/env python3
"""Three real synthetic clients: quote posts (reposts) through the deployed social function.
Credentials stay in memory; only generated post IDs are retained for fixture cleanup.
"""
import json, pathlib, urllib.request, urllib.error, uuid, os
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens=[]; resources={'posts':[]}; label='rp'+uuid.uuid4().hex[:9]
def call(action,token=None,**payload):
    headers={'Content-Type':'application/json','apikey':config['publishableKey']}
    if token:headers['X-Social-Token']=token
    request=urllib.request.Request(config['url']+'/functions/v1/social',data=json.dumps({'action':action,**payload}).encode(),headers=headers)
    try:
        with urllib.request.urlopen(request,timeout=40)as response:return response.status,json.load(response)
    except urllib.error.HTTPError as error:return error.code,json.load(error)
def ok(action,token=None,**payload):
    status,result=call(action,token,**payload)
    assert status==200,(action,status,result)
    return result
def find(items,id):return next(item for item in items if item['id']==id)
def snapshot(token,**payload):return ok('snapshot',token,**payload)['snapshot']
def post(token,id,**payload):return find(snapshot(token,**payload)['posts'],id)
def remember(id):
    resources['posts'].append(id)
    fd=os.open('/tmp/maroon-repost-test-resources.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
    with os.fdopen(fd,'w')as file:json.dump(resources,file)
    return id
try:
    names=[label+suffix for suffix in 'abc']
    for name in names:tokens.append(ok('register',username=name,adult=True)['token'])
    a,b,c=tokens
    named=remember(ok('post.create',a,text='Synthetic named source for reposts',anonymous=False,acceptsDM=False)['resource_id'])
    anonymous=remember(ok('post.create',c,text='Synthetic anonymous source for reposts',anonymous=True)['resource_id'])
    assert call('post.create',b,text='')[0]==400, 'an empty post with nothing quoted is still refused'
    nonce=str(uuid.uuid4()); payload=dict(text='',anonymous=False,nonce=nonce,quoted_post_id=named)
    quote=remember(ok('post.create',b,**payload)['resource_id'])
    assert ok('post.create',b,**payload)['resource_id']==quote, 'exact retry returns the same quote post'
    assert call('post.create',b,**dict(payload,quoted_post_id=anonymous))[0]==400, 'a changed quote on the same nonce conflicts'
    assert call('post.create',b,text='ghost',quoted_post_id=str(uuid.uuid4()))[0]==400
    assert call('post.create',b,text='ghost',quoted_post_id='not-a-uuid')[0]==400
    view=post(a,quote)
    assert view['text']=='' and view['repostCount']==0
    assert view['quote']['id']==named and view['quote']['unavailable'] is False and view['quote']['author']==names[0] and view['quote']['anonymous'] is False
    assert view['quote']['text']=='Synthetic named source for reposts' and isinstance(view['quote']['created'],(int,float))
    assert not {'vote','score','karma'}&set(view['quote'])
    assert view['quote']['quotes'] is False, 'a plain source does not quote anything'
    assert post(b,named)['repostCount']==1 and post(b,named)['quote'] is None
    print('PASS empty-body quote creation, exact retry, conflict on a changed quote, unknown targets refused and projected quote/repostCount',flush=True)
    second=remember(ok('post.create',b,text='Quoting an anonymous post',quoted_post_id=anonymous)['resource_id'])
    seen=post(a,second)
    assert seen['quote']['author']=='Anonymous' and seen['quote']['anonymous'] is True and names[2] not in json.dumps(seen)
    assert post(c,second)['quote']['author']==names[2], 'the anonymous author sees their own quoted post by name'
    chain=remember(ok('post.create',c,text='Quote of a quote',quoted_post_id=quote)['resource_id'])
    nested=post(a,chain)['quote']
    assert nested['id']==quote and 'quote' not in nested and 'repostCount' not in nested, 'only one level is projected'
    assert nested['quotes'] is True, 'a quote of a quote says the quoted post itself quotes another'
    assert post(a,named)['repostCount']==1
    own=remember(ok('post.create',a,text='Quoting myself',quoted_post_id=named)['resource_id'])
    assert post(b,named)['repostCount']==2
    print('PASS anonymous source stays anonymous to others, one-level nesting and self quotes',flush=True)
    ok('post.delete',a,post_id=named)
    gone=post(b,quote)
    assert gone['deleted'] is False and gone['quote']=={'id':named,'unavailable':True}, gone['quote']
    assert post(b,own)['quote']['unavailable'] is True
    assert call('post.create',b,text='Late quote',quoted_post_id=named)[0]==400
    ok('block',b,target_type='post',target_id=anonymous)
    blocked=post(b,second)['quote']
    assert blocked['unavailable'] is True and 'text' not in blocked
    assert call('post.create',b,text='Blocked quote',quoted_post_id=anonymous)[0]==400
    print('PASS deleted and blocked sources collapse to unavailable and cannot be quoted again',flush=True)
    # b and c are now a blocked pair, so the adult source comes from a; c stays outside the adult community.
    ok('community.join',a,community='NSFW'); ok('community.join',b,community='NSFW')
    adult=remember(ok('post.create',a,text='Adult source',community='NSFW')['resource_id'])
    status,result=call('post.create',b,text='Leak',community='Texas A&M',quoted_post_id=adult)
    assert status==400 and result['error']=='Keep adult discussions in the adult community.',(status,result)
    assert call('post.create',c,text='Outsider',community='Texas A&M',quoted_post_id=adult)[0]==400
    kept=remember(ok('post.create',b,text='Adult quote stays adult',community='NSFW',quoted_post_id=adult)['resource_id'])
    assert post(b,kept,feed_community='NSFW')['quote']['unavailable'] is False
    print('PASS NSFW sources may only be quoted into NSFW by members who can read them',flush=True)
    # a and c are not blocked: c reports a's post, which hides it from c everywhere, quote cards included.
    reported=remember(ok('post.create',a,text='Source the viewer reports')['resource_id'])
    ok('report',c,target_type='post',target_id=reported,reason='Synthetic report for quote visibility')
    relay=remember(ok('post.create',a,text='Quoting the reported post',quoted_post_id=reported)['resource_id'])
    hidden=post(c,relay)['quote']
    assert hidden=={'id':reported,'unavailable':True}, hidden
    assert post(a,relay)['quote']['unavailable'] is False, 'the report only hides the source from the reporter'
    print('PASS a reported source collapses to unavailable for the reporter only',flush=True)
finally:
    for token in tokens:
        status,result=call('account.delete',token)
        if status!=200:raise RuntimeError(('Synthetic account cleanup failed',status,result))
    print('Synthetic account credentials deleted; recorded post IDs retained for physical test cleanup.',flush=True)
