#!/usr/bin/env python3
"""Three synthetic HTTP clients exercise rich posts and private poll voting.

Credentials stay in memory. Account cleanup always runs; generated post IDs are
recorded separately so tombstones can be removed without touching real content.
"""
import concurrent.futures
import json
import os
import pathlib
import urllib.error
import urllib.request
import uuid

CONFIG = json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens = []
posts = []
label = 'pq' + uuid.uuid4().hex[:9]


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


def remember(post_id):
    posts.append(post_id)
    fd = os.open('/tmp/maroon-poll-test-resources.json', os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump({'posts': posts}, file)
    return post_id


def post(token, post_id):
    return next(item for item in ok('snapshot', token)['snapshot']['posts'] if item['id'] == post_id)


try:
    names = [label + suffix for suffix in 'abc']
    for name in names:
        tokens.append(ok('register', username=name, adult=True)['token'])
    a, b, c = tokens
    payload = dict(text='', anonymous=True, nonce=str(uuid.uuid4()),
                   link_url=' HTTPS://WWW.TAMU.EDU/?campaign=a%2Bb#visit ',
                   tags=[' #Howdy ', 'STUDY', 'study'],
                   poll=dict(question='Synthetic poll protocol check', options=['Library', 'Cafe'], duration_hours=24))
    created = ok('post.create', a, **payload)
    pid = remember(created['resource_id'])
    assert ok('post.create', a, **payload)['resource_id'] == pid
    changed = dict(payload, poll=dict(question='Changed retry', options=['Library', 'Cafe'], duration_hours=24))
    assert call('post.create', a, **changed)[1]['code'] == 'conflict'
    visible = post(b, pid)
    assert visible['text'] == '' and visible['tags'] == ['howdy', 'study']
    assert visible['linkURL'] == 'https://www.tamu.edu/?campaign=a%2Bb#visit'
    assert visible['anonymous'] and visible['author'] == 'Anonymous'
    assert names[0] not in json.dumps(visible)
    poll = visible['poll']
    assert isinstance(poll['endsAt'], (int, float)) and poll['totalVotes'] == 0
    one, two = [item['id'] for item in poll['options']]
    print('PASS three-client rich-post persistence, canonical link/tags, exact retry and anonymous author', flush=True)

    ok('poll.vote', a, post_id=pid, option_id=one)
    ok('poll.vote', b, post_id=pid, option_id=one)
    ok('poll.vote', c, post_id=pid, option_id=two)
    ok('poll.vote', b, post_id=pid, option_id=one)
    assert post(c, pid)['poll']['totalVotes'] == 3
    assert [item['votes'] for item in post(c, pid)['poll']['options']] == [2, 1]
    ok('poll.vote', b, post_id=pid, option_id=two)
    poll = post(b, pid)['poll']
    assert poll['myOptionID'] == two and poll['totalVotes'] == 3
    assert [item['votes'] for item in poll['options']] == [1, 2]
    assert set(poll) == {'id', 'question', 'options', 'endsAt', 'totalVotes', 'myOptionID'}
    assert all(set(item) == {'id', 'text', 'votes'} for item in poll['options'])
    assert all(name not in json.dumps(poll) for name in names)
    assert ok('snapshot', a)['snapshot']['karma'] == 0
    # The per-account lock + (poll, member) PK must also survive concurrent taps.
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(lambda choice: call('poll.vote', b, post_id=pid, option_id=choice), [one, two, one, two]))
    assert all(status == 200 for status, _ in results)
    assert post(a, pid)['poll']['totalVotes'] == 3
    print('PASS author participation, one current choice, concurrent vote changes and aggregate-only responses', flush=True)

    second = remember(ok('post.create', c, poll=dict(question='Another synthetic poll', options=['A', 'B'], duration_hours=72))['resource_id'])
    unrelated = post(c, second)['poll']['options'][0]['id']
    assert call('poll.vote', b, post_id=pid, option_id=unrelated)[1]['code'] == 'invalid'
    assert call('post.create', b, link_url='https://person:secret@example.com/')[1]['code'] == 'invalid'
    assert call('post.create', b, tags=['study'])[1]['code'] == 'invalid'
    assert call('post.create', b, text='Valid', tags=['bad tag'])[1]['code'] == 'invalid'
    assert call('post.create', b, poll=dict(question='Duplicate', options=['Same', ' same '], duration_hours=24))[1]['code'] == 'invalid'
    linked = remember(ok('post.create', b, link_url='https://www.tamu.edu/')['resource_id'])
    assert post(a, linked)['poll'] is None and post(a, linked)['text'] == ''
    exported = ok('export', b, endpoint='account-controls', section='preferences')['data']['poll_votes']
    assert len(exported) == 1 and exported[0]['post_id'] == pid
    print('PASS cross-poll rejection, credentialed-link/tag/option validation, link-only post and own-choice export', flush=True)

    ok('block', b, target_type='post', target_id=pid)
    assert call('poll.vote', b, post_id=pid, option_id=one)[0] == 403
    assert all(item['id'] != pid for item in ok('snapshot', b)['snapshot']['posts'])
    assert post(a, pid)['poll']['totalVotes'] == 2
    ok('post.delete', c, post_id=second)
    assert post(a, second)['poll'] is None
    assert call('poll.vote', a, post_id=second, option_id=unrelated)[0] == 403
    ok('post.delete', a, post_id=pid)
    deleted = post(c, pid)
    assert deleted['poll'] is None and deleted['linkURL'] is None and deleted['tags'] == []
    assert call('post.create', a, **payload)[1]['code'] == 'conflict'
    print('PASS blocked poll access/votes, aggregate removal, deleted extras and deleted nonce denial', flush=True)
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
    print('Synthetic accounts deleted; post IDs retained only for bounded tombstone cleanup.', flush=True)
