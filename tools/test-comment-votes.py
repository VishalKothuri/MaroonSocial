#!/usr/bin/env python3
"""Three real synthetic clients: reply hierarchy/votes/karma and anonymous source DMs.
Credentials stay in memory; only generated resource IDs are retained for fixture cleanup.
"""
import json, pathlib, urllib.request, urllib.error, uuid, os
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens=[]; resources={'posts':[], 'rooms':[]}; label='rq'+uuid.uuid4().hex[:9]
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
def snapshot(token):return ok('snapshot',token)['snapshot']
def post(token,id):return find(snapshot(token)['posts'],id)
def reply(token,post_id,reply_id):return find(post(token,post_id)['comments'],reply_id)
def remember(kind,id):
    resources[kind].append(id)
    fd=os.open('/tmp/maroon-reply-test-resources.json',os.O_CREAT|os.O_TRUNC|os.O_WRONLY,0o600)
    with os.fdopen(fd,'w')as file:json.dump(resources,file)
    return id
try:
    names=[label+suffix for suffix in 'abc']
    for name in names:tokens.append(ok('register',username=name,adult=True)['token'])
    a,b,c=tokens
    p=remember('posts',ok('post.create',a,text='Synthetic nested reply verification',anonymous=True)['resource_id'])
    named=remember('posts',ok('post.create',a,text='Synthetic named context verification',anonymous=False,acceptsDM=False)['resource_id'])
    root=ok('comment.create',b,post_id=p,text='Parent reply')['resource_id']
    nonce=str(uuid.uuid4()); payload=dict(post_id=p,parent_id=root,text='Nested child reply',anonymous=False,nonce=nonce)
    child=ok('comment.create',c,**payload)['resource_id']
    assert ok('comment.create',c,**payload)['resource_id']==child
    assert call('comment.create',c,**dict(payload,text='Changed retry'))[0]==400
    assert call('comment.create',c,post_id=named,parent_id=root,text='Wrong post')[0]==403
    child_view=reply(a,p,child)
    assert child_view['parentID']==root and child_view['anonymous'] is False, 'members may reply by name under an anonymous post'
    assert child_view['score']==1 and reply(c,p,child)['vote']==1, 'a reply starts with its author\'s upvote'
    assert post(a,p)['vote']==1 and post(a,p)['score']==1 and snapshot(a)['karma']==0, 'a post starts with its author\'s upvote, not karma'
    opnamed=ok('comment.create',a,post_id=p,text='OP stays anonymous',anonymous=False)['resource_id']
    assert reply(b,p,opnamed)['anonymous'] is True and reply(b,p,opnamed)['author']=='OP'
    assert names[1] not in json.dumps(post(a,p)) and names[2] not in json.dumps(post(a,p))
    print('PASS three-client nested hierarchy, exact retry and anonymous source projection',flush=True)
    ok('comment.vote',b,comment_id=root,value=0); assert reply(b,p,root)['score']==0 and reply(b,p,root)['vote']==0
    ok('comment.vote',b,comment_id=root,value=1); assert reply(b,p,root)['score']==1 and reply(b,p,root)['vote']==1
    ok('post.vote',a,post_id=p,value=0); assert post(a,p)['score']==0
    ok('post.vote',a,post_id=p,value=1); assert post(a,p)['score']==1 and snapshot(a)['karma']==0
    ok('comment.vote',a,comment_id=root,value=1)
    ok('comment.vote',c,comment_id=root,value=1)
    ok('comment.vote',c,comment_id=root,value=1)
    assert snapshot(b)['karma']==2 and reply(a,p,root)['score']==3
    ok('comment.vote',c,comment_id=root,value=-1)
    assert snapshot(b)['karma']==0 and reply(c,p,root)['vote']==-1
    ok('comment.vote',c,comment_id=root,value=0)
    assert snapshot(b)['karma']==1
    ok('post.vote',c,post_id=p,value=1)
    ownreply=ok('comment.create',a,post_id=p,text='Original poster reply')['resource_id']
    ok('comment.vote',b,comment_id=ownreply,value=1)
    assert snapshot(a)['karma']==2
    assert not any('karma'in item for item in post(c,p)['comments'])
    print('PASS independent vote net, repeated-vote idempotency, own combined karma and author self-vote toggling',flush=True)
    assert call('dm.request',c,post_id=named)[0]==403
    namedreply=ok('comment.create',b,post_id=named,text='A named commenter',anonymous=False)['resource_id']
    room=remember('rooms',ok('dm.request',c,comment_id=namedreply,text='Private reply request',anonymous=False)['resource_id'])
    assert ok('dm.request',c,comment_id=namedreply)['resource_id']==room
    assert call('room.send',c,room_id=room,text='Not accepted')[0]==403
    assert call('dm.accept',a,room_id=room)[0]==403
    assert call('dm.accept',c,room_id=room)[0]==403
    request=find(snapshot(b)['conversations'],room)
    assert request['anonymous'] is True and request['request'] is True
    assert names[2] not in json.dumps(request)
    ok('dm.accept',b,room_id=room)
    ok('room.send',b,room_id=room,text='Accepted anonymously')
    conversation=find(snapshot(c)['conversations'],room)
    assert {message['author'] for message in conversation['messages']}=={'You','Them'}
    assert names[1] not in json.dumps(conversation) and names[2] not in json.dumps(conversation)
    namedopen=remember('posts',ok('post.create',a,text='Named source open to requests',anonymous=False)['resource_id'])
    source_room=remember('rooms',ok('dm.request',c,post_id=namedopen,text='Anonymous even for named source',anonymous=False)['resource_id'])
    assert find(snapshot(a)['conversations'],source_room)['anonymous'] is True
    print('PASS comment/post message buttons resolve server-side, keep source DMs anonymous and require recipient acceptance',flush=True)
    ok('comment.delete',b,comment_id=root)
    parent=reply(a,p,root)
    assert parent['deleted'] is True and parent['score']==0
    assert reply(a,p,child)['parentID']==root
    assert snapshot(b)['karma']==0
    assert call('comment.vote',c,comment_id=root,value=1)[0]==403
    ok('block',a,target_type='comment',target_id=namedreply)
    assert call('comment.vote',a,comment_id=namedreply,value=1)[0]==403
    assert call('comment.create',a,post_id=named,parent_id=namedreply,text='Blocked target')[0]==403
    assert call('dm.request',a,comment_id=namedreply)[0]==403
    assert not any(item['id']==namedreply for item in post(a,named)['comments'])
    ok('post.delete',a,post_id=p)
    assert snapshot(a)['karma']==0
    print('PASS deleted-parent child preservation, deleted/blocked vote+reply+DM denial and karma cleanup',flush=True)
finally:
    for token in tokens:
        status,result=call('account.delete',token)
        if status!=200:raise RuntimeError(('Synthetic account cleanup failed',status,result))
    print('Synthetic account credentials deleted; recorded content resource IDs retained for physical test cleanup.',flush=True)
