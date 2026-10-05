#!/usr/bin/env python3
"""Incremental sync against the deployed edge function with four synthetic accounts.
Proves keyset pages under inserts, deltas for votes/replies/deletes, that renames, blocks and
bookmarks move nothing a third party could use to link anonymous posts, per-member resync,
feed.posts, removals for hidden and blocked posts, room.messages after_seq with changes to held
messages, input ranges, account deletion, anonymity and clamped limits.
Credentials stay in memory and every account is deleted in `finally`.
"""
import json, pathlib, time, urllib.request, urllib.error, uuid
config=json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens={}; label='fs'+uuid.uuid4().hex[:9]; community='Graduates'
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
def ids(items):return [item['id'] for item in items]
def clock(token):
    """A fresh delta clock: everything before it is older than the five-second overlap."""
    return ok('feed.delta',token,community=community,since=0,known_ids=[])['now']
try:
    for name in 'abcd':tokens[name]=ok('register',username=label+name,adult=True)['token']
    a,b,c,d=tokens['a'],tokens['b'],tokens['c'],tokens['d']
    posts=[ok('post.create',a,text=f'Synthetic feed sync {n}',anonymous=True,community=community,acceptsDM=True)['resource_id'] for n in range(7)]
    named_a=ok('post.create',a,text='Named post before a rename',anonymous=False,community=community)['resource_id']
    c_named=ok('post.create',c,text='Named post from a soon-blocked member',anonymous=False,community=community)['resource_id']
    c_anon=ok('post.create',c,text='Anonymous post from a soon-blocked member',anonymous=True,community=community)['resource_id']
    ok('comment.create',a,post_id=c_named,text='Anonymous reply that must stay unlinked',anonymous=True)

    seen=[]; cursor={}; inserted=None
    for page_number in range(40):
        page=ok('feed.page',b,community=community,limit=3,**cursor)
        assert len(page['posts'])<=3
        for post in page['posts']:
            assert post['id'] not in seen,'keyset page repeated a post'
            assert {'commentCount','syncedAt','repostCount','comments','score'}<=post.keys(),'post JSON shape changed'
            assert 'changedAt' not in post,'raw change time exposed'
            seen.append(post['id'])
        if page_number==0:inserted=ok('post.create',c,text='Inserted between pages',anonymous=True,community=community)['resource_id']
        if set(posts)<=set(seen) or not page.get('next'):break
        cursor=page['next']
    assert set(posts)<=set(seen),'keyset pages skipped a post'
    assert len(ok('feed.page',b,community=community,limit=500)['posts'])<=50
    assert len(ok('feed.page',b,community=community,limit=1e10)['posts'])<=50,'huge page size not clamped'
    assert call('feed.page',b,community=community,limit='all')[0]==400
    snapshot=ok('snapshot',b,feed_community=community)['snapshot']
    assert len(snapshot['posts'])<=30 and 'serverNow' in snapshot and 'feedNext' in snapshot
    print('PASS keyset feed pages without skips or repeats under inserts, clamped limits and a slim snapshot',flush=True)

    # The delta clock overlaps by five seconds; let the fixture posts age past it first.
    time.sleep(7)
    since=ok('feed.delta',b,community=community,since=snapshot['serverNow'],known_ids=posts)['now']
    time.sleep(1)
    ok('post.vote',b,post_id=posts[0],value=1)
    ok('comment.create',b,post_id=posts[1],text='Delta reply')
    ok('post.delete',a,post_id=posts[2])
    delta=ok('feed.delta',b,community=community,since=since,known_ids=posts)
    changed={post['id']:post for post in delta['changed']}
    assert changed[posts[0]]['vote']==1 and changed[posts[1]]['commentCount']==1 and changed[posts[2]]['deleted'] is True
    assert posts[3] not in changed,'an untouched post came back'
    assert label+'a' not in json.dumps(delta),'anonymous author leaked'
    assert delta.get('resync') is False
    print('PASS delta returns voted, commented and deleted posts only',flush=True)

    # A rename, a block and a bookmark must not move anything else a third party can see.
    time.sleep(6)
    since={name:clock(token) for name,token in tokens.items()}
    time.sleep(1)
    ok('profile.update',a,username=label+'r')
    ok('post.save',b,post_id=posts[3],saved=True)
    ok('block',b,target_type='post',target_id=c_named)
    known=posts+[named_a,c_named,c_anon]
    observer=ok('feed.delta',d,community=community,since=since['d'],known_ids=known)
    moved=set(ids(observer['changed']))
    assert named_a in moved and next(p for p in observer['changed'] if p['id']==named_a)['author']==label+'r','named post did not show the new name'
    assert not moved&(set(posts)|{c_named,c_anon}),('a rename, block or bookmark moved posts a third party could link',moved)
    assert observer['resync'] is False,'a third party was asked to resync'
    for name in 'abc':assert ok('feed.delta',tokens[name],community=community,since=since[name],known_ids=known)['resync'] is True,name+' was not asked to resync'
    print('PASS renames move named content only, blocks and bookmarks move nothing for others, and the parties resync',flush=True)

    stranger=str(uuid.uuid4())
    held=ok('feed.posts',b,community=community,ids=[posts[0],c_named,c_anon,stranger])
    assert ids(held['posts'])==[posts[0]] and set(held['removed'])=={c_named,c_anon,stranger},held['removed']
    assert call('feed.posts',b,community=community,ids='all')[0]==400
    assert len(ok('feed.posts',b,community=community,ids=[str(uuid.uuid4()) for _ in range(80)])['removed'])<=50
    print('PASS feed.posts returns readable held posts and reports the rest removed',flush=True)

    since=ok('feed.delta',b,community=community,since=since['b'],known_ids=known)['now']
    ok('report',b,target_type='post',target_id=posts[4],reason='Synthetic hide check')
    known=posts+[c_named,str(uuid.uuid4())]
    delta=ok('feed.delta',b,community=community,since=since,known_ids=known)
    assert {posts[4],c_named}<=set(delta['removed']),'hidden or blocked post not removed'
    assert set(delta['removed'])<=set(known),'delta reported an id the caller did not hold'
    assert not {posts[4],c_named}&set(ids(delta['changed']))
    assert delta['resync'] is True,'hiding a post does not resync its quote cards'
    assert len(ok('feed.delta',b,community=community,since=since,known_ids=[str(uuid.uuid4()) for _ in range(400)])['removed'])<=300
    print('PASS removed covers hidden and blocked posts, only for known ids, known ids clamped',flush=True)

    for n in range(3):ok('comment.create',a,post_id=posts[5],text=f'Reply {n}')
    replies=ok('comments.page',b,post_id=posts[5],limit=2)
    assert len(replies['comments'])==2 and replies['next'] and replies['commentCount']==3
    older=ok('comments.page',b,post_id=posts[5],limit=2,**replies['next'])
    assert len(older['comments'])==1 and not set(ids(older['comments']))&set(ids(replies['comments']))
    assert call('comments.page',b,post_id=posts[4])[0]==403,'hidden post replies served'
    print('PASS reply pages without overlap; hidden posts refuse replies',flush=True)

    room=ok('dm.request',b,post_id=posts[6],text='Feed sync hello')['resource_id']
    ok('dm.accept',a,room_id=room)
    first=ok('room.messages',b,room_id=room)['messages'][-1]['sequence']
    ok('room.send',a,room_id=room,text='Newer one',nonce=str(uuid.uuid4()))
    ok('room.send',b,room_id=room,text='Newer two',nonce=str(uuid.uuid4()))
    newer=ok('room.messages',b,room_id=room,after_seq=first)
    assert [m['text'] for m in newer['messages']]==['Newer one','Newer two'] and all(m['sequence']>first for m in newer['messages'])
    assert {m['author'] for m in newer['messages']}=={'You','Them'} and label+'a' not in json.dumps(newer)
    assert newer['meta']['id']==room and newer['more'] is False
    assert call('room.messages',c,room_id=room)[0]==403,'non-member read the room'
    assert call('room.messages',b,room_id=room,after_seq=1,before_seq=9)[0]==400
    assert len(ok('room.messages',b,room_id=room,limit=500)['messages'])<=50
    print('PASS room.messages after_seq returns only newer anonymous messages to members',flush=True)

    last=newer['messages'][-1]['sequence']
    watch=ok('room.messages',a,room_id=room,after_seq=last,changed_since=newer['now'])
    ok('room.delete',b,message_id=newer['messages'][1]['id'])
    ok('room.react',b,message_id=newer['messages'][0]['id'],emoji='👍')
    update=ok('room.messages',a,room_id=room,after_seq=last,changed_since=watch['now'])
    changes={m['id']:m for m in update['changed']}
    assert changes[newer['messages'][1]['id']]['deleted'] is True and changes[newer['messages'][1]['id']]['text']=='[Message deleted]'
    assert changes[newer['messages'][0]['id']]['reactions'].get('👍')==1
    assert all(m['sequence']<=last for m in update['changed']) and update['messages']==[]
    assert call('room.messages',a,room_id=room,changed_since=watch['now'])[0]==400,'changes without after_seq accepted'
    print('PASS an open chat sees deletions and reactions on held messages',flush=True)

    for payload in [dict(after_seq=1e30),dict(before_seq=-1),dict(after_seq=1,changed_since=1e300)]:
        status,result=call('room.messages',a,room_id=room,**payload)
        assert status==400 and result['code']=='invalid',(payload,status)
    for action,payload in [('feed.page',dict(before_created=1e300)),('feed.page',dict(before_created='not-a-date')),('feed.page',dict(before_created='infinity')),('feed.delta',dict(since=1e300)),('feed.delta',dict(since=-5))]:
        status,result=call(action,b,community=community,**payload)
        assert status==400 and result['code']=='invalid',(action,payload,status)
    print('PASS out-of-range sizes clamp and out-of-range cursors, clocks and sequences answer invalid',flush=True)

    since=clock(b)
    time.sleep(1)
    status,result=call('account.delete',a); assert status==200,('account.delete',status)
    tokens.pop('a')
    delta=ok('feed.delta',b,community=community,since=since,known_ids=[posts[6],posts[2]])
    gone=[post for post in delta['changed'] if post['id']==posts[6]]
    assert posts[6] in delta['removed'] or (gone and gone[0]['deleted'] is True and gone[0]['author']=='[deleted]')
    assert posts[2] not in ids(delta['changed']),'a long-deleted post moved with the account deletion'
    print('PASS a deleted account\'s post syncs as deleted; its long-deleted posts stay put',flush=True)
finally:
    for name,token in tokens.items():
        status,result=call('account.delete',token)
        if status!=200:raise RuntimeError(('Synthetic account cleanup failed',name,status))
    print('Synthetic accounts deleted.',flush=True)
