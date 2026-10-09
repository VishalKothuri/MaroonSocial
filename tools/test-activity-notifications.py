#!/usr/bin/env python3
"""Real synthetic clients verify notification and personal-library endpoints.
No announcements are published. Credentials stay in memory and test accounts are deleted.
"""
import json
import runner_backend
import os
import pathlib
import urllib.error
import urllib.request
import uuid

config = runner_backend.load()
label = 'aq' + uuid.uuid4().hex[:9]
tokens = []
posts = []


def call(action, token=None, **payload):
    headers = {'Content-Type': 'application/json', 'apikey': config['publishableKey']}
    if token:
        headers['X-Social-Token'] = token
    request = urllib.request.Request(config['url'] + '/functions/v1/social',
        data=json.dumps(dict(action=action, **payload)).encode(), headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=40) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def ok(action, token=None, **payload):
    status, result = call(action, token, **payload)
    assert status == 200, (action, status, result)
    return result


try:
    assert call('notifications')[0] == 401
    for suffix in 'ab':
        tokens.append(runner_backend.accept_guidelines(config,ok('register', username=label + suffix, adult=True))['token'])
    a, b = tokens
    post_id = ok('post.create', a, text='Synthetic activity inbox verification', anonymous=True)['resource_id']
    posts.append(post_id)
    fd = os.open('/tmp/maroon-activity-test-resources.json', os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump({'posts': posts}, file)
    comment_id = ok('comment.create', b, post_id=post_id, text='Synthetic anonymous reply')['resource_id']
    inbox = ok('notifications', a)
    notice = next(x for x in inbox['items'] if x.get('postID') == post_id and x['kind'] == 'comment')
    assert notice['body'] == 'Synthetic anonymous reply' and not notice['read']
    assert label + 'b' not in json.dumps(inbox)
    assert call('notification.read', b, id=notice['id'])[0] == 403
    ok('notification.read', a, id=notice['id'])
    assert next(x for x in ok('notifications', a)['items'] if x['id'] == notice['id'])['read']
    print('PASS live anonymous comment notification, authenticated access and private read receipt', flush=True)
    ok('post.vote', b, post_id=post_id, value=1)
    ok('post.vote', b, post_id=post_id, value=0)
    ok('post.vote', b, post_id=post_id, value=1)
    milestones = [x for x in ok('notifications', a)['items'] if x.get('postID') == post_id and x['kind'] == 'upvotes']
    assert len(milestones) == 1
    ok('notifications.read_all', a, ids=[x['id'] for x in milestones])
    assert next(x for x in ok('notifications', a)['items'] if x['id'] == milestones[0]['id'])['read']
    print('PASS live upvote milestone without duplicate notifications after a vote toggle', flush=True)
    ok('post.save', b, post_id=post_id, saved=True)
    assert [x['id'] for x in ok('library', a, kind='posts')['posts']] == [post_id]
    assert [x['id'] for x in ok('library', b, kind='saved')['posts']] == [post_id]
    comments = ok('library', b, kind='comments')['comments']
    assert [x['id'] for x in comments] == [comment_id] and comments[0]['postID'] == post_id
    assert ok('library', a, kind='comments')['comments'] == []
    assert [x['id'] for x in ok('library', b, kind='post', post_id=post_id)['posts']] == [post_id]
    print('PASS live My posts, My comments, Saved posts and direct notification post destination', flush=True)
    ok('comment.delete', b, comment_id=comment_id)
    assert all(x['id'] != notice['id'] for x in ok('notifications', a)['items'])
    assert ok('library', b, kind='comments')['comments'] == []
    ok('block', b, target_type='post', target_id=post_id)
    assert ok('library', b, kind='saved')['posts'] == []
    assert ok('library', b, kind='post', post_id=post_id)['posts'] == []
    ok('post.delete', a, post_id=post_id)
    assert all(x.get('postID') != post_id for x in ok('notifications', a)['items'])
    print('PASS live deletion and block revocation across notifications and collections', flush=True)
finally:
    failures = 0
    for token in tokens:
        try:
            status, value = call('account.delete', token)
            if status != 200 or not value.get('deleted'):
                failures += 1
        except Exception:
            failures += 1
    if failures:
        raise RuntimeError(f'{failures} synthetic account cleanups need attention')
    print('Synthetic accounts deleted; exact generated post IDs retained for bounded tombstone cleanup.', flush=True)
