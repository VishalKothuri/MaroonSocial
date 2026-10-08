#!/usr/bin/env python3
"""Two synthetic HTTP clients: a message request sent from a post carries a
persistent "From this post" tag that survives the post's deletion.

Credentials stay in memory. Both accounts are deleted in `finally`; the post is
soft-deleted by the author during the run and tombstoned again by account deletion.
"""
import json
import runner_backend
import pathlib
import urllib.error
import urllib.request
import uuid

CONFIG = runner_backend.load()
tokens = []
label = 'sp' + uuid.uuid4().hex[:9]


def call(action, token=None, endpoint='social', **payload):
    headers = {'Content-Type': 'application/json', 'apikey': CONFIG['publishableKey']}
    if token:
        headers['X-Social-Token'] = token
    request = urllib.request.Request(
        CONFIG['url'] + '/functions/v1/' + endpoint,
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


def snapshot(token):
    return ok('snapshot', token)['snapshot']


def tag(token, room):
    return next(item for item in snapshot(token)['conversationMeta'] if item['id'] == room)['sourcePost']


def conversation(token, room):
    return next((item for item in snapshot(token)['conversations'] if item['id'] == room), None)


try:
    names = [label + suffix for suffix in 'ab']
    for name in names:
        tokens.append(runner_backend.accept_guidelines(CONFIG,ok('register', username=name, adult=True))['token'])
    a, b = tokens
    body = 'Synthetic source post for the direct-message tag. ' * 4
    pid = ok('post.create', a, text=body, anonymous=True, acceptsDM=True, nonce=str(uuid.uuid4()))['resource_id']
    room = ok('dm.request', b, post_id=pid, text='Hello from your post', nonce=str(uuid.uuid4()))['resource_id']
    expected = body.strip()[:140]
    for token in (a, b):
        origin = tag(token, room)
        assert origin == {'postID': pid, 'excerpt': expected, 'deleted': False, 'fromReply': False}, origin
        assert conversation(token, room)['title'] == 'Anonymous conversation'
        assert all(name not in json.dumps(origin) for name in names)
    named = ok('dm.request', b, username=names[0], text='Named hello', nonce=str(uuid.uuid4()))['resource_id']
    assert named != room and tag(b, named) is None
    print('PASS post-originated request tagged with a 140-character excerpt for both participants; username request untagged', flush=True)

    ok('dm.accept', a, room_id=room)
    assert tag(a, room)['excerpt'] == expected and tag(b, room)['excerpt'] == expected
    ok('post.delete', a, post_id=pid)
    for token in (a, b):
        origin = tag(token, room)
        assert origin == {'postID': pid, 'excerpt': None, 'deleted': True, 'fromReply': False}, origin
        listed = conversation(token, room)
        assert listed is not None and listed['title'] == 'Anonymous conversation' and listed['messages'], listed
    assert ok('room.send', a, room_id=room, text='Still here after the post went away', nonce=str(uuid.uuid4()))['resource_id']
    assert tag(b, room)['deleted'] is True and tag(b, room)['excerpt'] is None
    print('PASS deleted post keeps the conversation open and listed with a deleted placeholder for both sides', flush=True)
finally:
    failures = 0
    for token in tokens:
        try:
            status, result = call('account.delete', token)
            if status != 200 or not result.get('deleted'):
                failures += 1
        except Exception:
            failures += 1
    if failures:
        raise RuntimeError(f'{failures} synthetic account cleanups need attention')
    print('Synthetic accounts deleted.', flush=True)
