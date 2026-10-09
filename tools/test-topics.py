#!/usr/bin/env python3
"""Topic feeds through the edge function with three synthetic accounts.
Proves topics.list (catalog order, shape, readable 7-day counts), topic validation on post.create
and the feed reads, nonce conflicts on the topic, topic pages, post.topic (author only), deltas and
resyncs that drop retagged-away posts, deleted posts losing their topic and the 5-posts-per-15-minutes
limit. Skips with a message (exit 0) when the server predates topics (no topics.list).
Base URL and publishable key come from MAROON_API_URL / MAROON_API_KEY (tools/runner_backend.py),
defaulting to the app's backend (MaroonSocial/Resources/Backend.json, the live project).
Credentials stay in memory and every account is deleted in `finally`.
"""
import json, sys, urllib.request, urllib.error, uuid
import runner_backend
config=runner_backend.load()
base=config['url']; key=config['publishableKey']
tokens={}; label='tp'+uuid.uuid4().hex[:9]; community='Seniors'
def call(action,token=None,**payload):
    headers={'Content-Type':'application/json','apikey':key}
    if token:headers['X-Social-Token']=token
    request=urllib.request.Request(base+'/functions/v1/social',data=json.dumps({'action':action,**payload}).encode(),headers=headers)
    try:
        with urllib.request.urlopen(request,timeout=40)as response:return response.status,json.load(response)
    except urllib.error.HTTPError as error:return error.code,json.load(error)
def ok(action,token=None,**payload):
    status,result=call(action,token,**payload)
    assert status==200,(action,status,result.get('code'),result.get('error'))
    return result
def refused(code,message,action,token,**payload):
    status,result=call(action,token,**payload)
    assert status!=200 and result.get('code')==code and (message is None or result.get('error')==message),(action,status,result.get('code'),result.get('error'))
def ids(items):return [item['id'] for item in items]
def counts(token):return {topic['slug']:topic['recent_count'] for topic in ok('topics.list',token,community=community)['topics']}
def clock(token):return ok('feed.delta',token,community=community,since=0,known_ids=[])['now']
def lacks_topics(status,result):return status!=200 and result.get('error')=='Unknown social action.'
# A server without topics answers "Unknown social action." (the edge function before any account,
# or the database gateway once one exists).
status,result=call('topics.list',community=community)
if lacks_topics(status,result):
    print('SKIP this server has no topics.list (topic migrations or edge function not deployed); nothing was created.',flush=True);sys.exit(0)
try:
    for name in 'abc':tokens[name]=runner_backend.accept_guidelines(config,ok('register',username=label+name,adult=True))['token']
    a,b,c=tokens['a'],tokens['b'],tokens['c']
    status,result=call('topics.list',b,community=community)
    if lacks_topics(status,result):
        print('SKIP the database gateway has no topics.list (topic migrations not applied).',flush=True);sys.exit(0)
    assert status==200,(status,result)
    catalog=result['topics']
    assert catalog and all(set(topic)=={'slug','title','emoji','text_hex','fill_hex','sort_order','recent_count'} for topic in catalog), catalog[:1]
    assert [topic['sort_order'] for topic in catalog]==sorted(topic['sort_order'] for topic in catalog)
    slugs=[topic['slug'] for topic in catalog]
    assert {'academics','housing','sports','memes'}<=set(slugs), slugs
    refused('invalid',None,'topics.list',b,community='Elsewhere')
    print('PASS topics.list returns the active catalog in sort_order with the documented keys',flush=True)

    before=counts(b)
    for bad in ['nope','Sports',5,['sports']]:
        refused('invalid','Choose an available topic.','post.create',a,text='Synthetic topic check',community=community,topic=bad)
    nonce=str(uuid.uuid4())
    sports=ok('post.create',a,text='Synthetic sports post',community=community,topic='sports',nonce=nonce)['resource_id']
    assert ok('post.create',a,text='Synthetic sports post',community=community,topic='sports',nonce=nonce)['resource_id']==sports
    refused('conflict',None,'post.create',a,text='Synthetic sports post',community=community,topic='memes',nonce=nonce)
    refused('conflict',None,'post.create',a,text='Synthetic sports post',community=community,nonce=nonce)
    housing=ok('post.create',a,text='Synthetic housing post',community=community,topic='housing')['resource_id']
    plain=ok('post.create',a,text='Synthetic post without a topic',community=community)['resource_id']
    page=ok('feed.page',b,community=community,topic='sports',limit=50)
    assert sports in ids(page['posts']) and all(post['topic']=='sports' or post['deleted'] for post in page['posts'])
    assert housing not in ids(page['posts']) and plain not in ids(page['posts'])
    everything=ok('feed.page',b,community=community,limit=50)['posts']
    shown={post['id']:post for post in everything}
    assert shown[housing]['topic']=='housing' and shown[plain]['topic'] is None and 'topic' in shown[plain]
    for read,extra in [('feed.page',{}),('feed.delta',{'since':0,'known_ids':[]}),('feed.posts',{'ids':[sports]})]:
        refused('invalid','Choose an available topic.',read,b,community=community,topic='nope',**extra)
    after=counts(b)
    assert after['sports']-before['sports']==1 and after['housing']-before['housing']==1, (before,after)
    print('PASS topic validation, nonce conflicts on the topic, topic pages and topic JSON (null without one), readable counts',flush=True)

    since=clock(b)
    refused('forbidden',None,'post.topic',b,post_id=housing,topic='sports')
    refused('invalid','Choose an available topic.','post.topic',a,post_id=housing,topic='nope')
    ok('post.topic',a,post_id=housing,topic='sports')
    delta=ok('feed.delta',b,community=community,topic='housing',since=since,known_ids=[housing,plain])
    assert housing in delta['removed'] and plain in delta['removed'], delta
    delta=ok('feed.delta',b,community=community,topic='sports',since=since,known_ids=[housing])
    assert any(post['id']==housing and post['topic']=='sports' for post in delta['changed']), delta
    resync=ok('feed.posts',b,community=community,topic='housing',ids=[housing,sports])
    assert resync['posts']==[] and set(resync['removed'])=={housing,sports}, resync
    resync=ok('feed.posts',b,community=community,topic='sports',ids=[housing,sports,plain])
    assert set(ids(resync['posts']))=={housing,sports} and resync['removed']==[plain], resync
    ok('post.topic',a,post_id=housing,topic=None)
    assert housing in ok('feed.delta',b,community=community,topic='sports',since=since,known_ids=[housing])['removed']
    print('PASS post.topic is author-only and validated; deltas and resyncs drop retagged-away posts',flush=True)

    ok('report',b,target_type='post',target_id=sports,reason='Wrong topic')
    assert counts(b)['sports']==after['sports']-1, 'a post the reader hid is still counted'
    since=clock(c)
    ok('post.delete',a,post_id=sports)
    # A deleted post loses its topic: topic pages no longer return it, a topic tab holding it gets
    # it in "removed", and All shows the placeholder with topic:null.
    assert sports not in ids(ok('feed.page',c,community=community,topic='sports',limit=50)['posts']), 'deleted post still on its topic page'
    assert sports in ok('feed.delta',c,community=community,topic='sports',since=since,known_ids=[sports])['removed']
    deleted=ok('feed.posts',c,community=community,ids=[sports])['posts'][0]
    assert deleted['deleted'] and deleted['topic'] is None
    print('PASS hidden posts leave the reader\'s counts; deleted posts lose their topic',flush=True)

    for n in range(5):ok('post.create',c,text=f'Synthetic pacing post {n}',community=community,topic='memes')
    refused('rate_limit','Take a moment before posting again.','post.create',c,text='Synthetic pacing post 6',community=community,topic='memes')
    print('PASS a sixth post within 15 minutes is refused',flush=True)
finally:
    for token in tokens.values():
        status,result=call('account.delete',token)
        if status!=200:raise RuntimeError(('Synthetic account cleanup failed',status,result.get('code')))
    if tokens:print('Synthetic account credentials deleted.',flush=True)
