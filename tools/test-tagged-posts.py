#!/usr/bin/env python3
"""Live synthetic clients verify server tag discovery and community isolation."""
import json
import os
import pathlib
import urllib.error
import urllib.request
import uuid

config = json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
label = 'tq' + uuid.uuid4().hex[:9]
tag = label + '_topic'
tokens = []
post_ids = []


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
    status, value = call(action, token, **payload)
    assert status == 200, (action, status, value)
    return value


def create(token, **payload):
    post_id = ok('post.create', token, **payload)['resource_id']
    post_ids.append(post_id)
    fd = os.open('/tmp/maroon-tagged-post-test-resources.json', os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump({'posts': post_ids}, file)
    return post_id


try:
    for suffix in 'abc':
        tokens.append(ok('register', username=label + suffix, adult=True)['token'])
    a, b, c = tokens
    campus = create(a, text='Synthetic tag discovery', tags=[tag], anonymous=True,
        poll=dict(question='Tag poll?', options=['Yes', 'No'], duration_hours=24))
    other = create(c, link_url='https://www.tamu.edu/', tags=[tag], anonymous=True)
    result = ok('posts.tag', b, tag='#' + tag.upper(), community='Texas A&M')
    assert result['tag'] == tag and {p['id'] for p in result['posts']} == {campus, other}
    assert [p['id'] for p in result['posts']] == [other, campus]
    full = ok('snapshot', b)['snapshot']['posts']
    assert next(p for p in result['posts'] if p['id'] == campus) == next(p for p in full if p['id'] == campus)
    assert all(p['author'] == 'Anonymous' for p in result['posts'])
    print('PASS three-client server tag query, normalized tag, newest order and exact shared serializer', flush=True)

    option = next(p for p in result['posts'] if p['id'] == campus)['poll']['options'][0]['id']
    ok('poll.vote', b, post_id=campus, option_id=option)
    ok('post.vote', b, post_id=campus, value=1)
    ok('post.save', b, post_id=campus, saved=True)
    canonical = next(p for p in ok('posts.tag', b, tag=tag, community='Texas A&M')['posts'] if p['id'] == campus)
    assert canonical['vote'] == 1 and canonical['score'] == 1 and canonical['saved']
    assert canonical['poll']['myOptionID'] == option and canonical['poll']['totalVotes'] == 1
    print('PASS tag results reflect canonical post/poll votes and bookmarks', flush=True)

    ok('community.join', a, community='NSFW')
    adult = create(a, text='Synthetic adult tag fixture', community='NSFW', tags=[tag])
    assert call('posts.tag', b, tag=tag, community='NSFW')[0] == 403
    ok('community.join', b, community='NSFW')
    assert [p['id'] for p in ok('posts.tag', b, tag=tag, community='NSFW')['posts']] == [adult]
    assert {p['id'] for p in ok('posts.tag', b, tag=tag, community='Texas A&M')['posts']} == {campus, other}
    ok('community.leave', b, community='NSFW')
    assert call('posts.tag', b, tag=tag, community='NSFW')[0] == 403
    assert call('posts.tag', b, tag='bad tag', community='Texas A&M')[0] == 400
    print('PASS separate adult/campus scopes, explicit adult opt-in and malformed tag denial', flush=True)

    ok('block', b, target_type='post', target_id=campus)
    assert [p['id'] for p in ok('posts.tag', b, tag=tag, community='Texas A&M')['posts']] == [other]
    ok('post.delete', c, post_id=other)
    assert ok('posts.tag', b, tag=tag, community='Texas A&M')['posts'] == []
    assert len(ok('posts.tag', a, tag=tag, community='Texas A&M')['posts']) == 1
    print('PASS block/hidden filtering and deleted-post removal without affecting unrelated viewers', flush=True)
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
    print('Synthetic accounts deleted; generated post IDs retained for bounded tombstone cleanup.', flush=True)
