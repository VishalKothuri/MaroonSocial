#!/usr/bin/env python3
"""Server search (posts.search) and the Top sort (feed.top) through the edge function, with five
synthetic accounts. Proves search matches (prefix, stem, topic, community) and never matches the
author's username, keyset paging with the opaque cursor sent back verbatim, input validation, the
30-searches-per-minute limit, Top order by the score the app shows (the author's own upvote included)
for each window, concurrent votes leaving the right score, and Top paging without duplicates.

Local only by default: the target comes from MAROON_API_URL / MAROON_API_KEY (tools/runner_backend.py),
and the runner stops before any request unless that target is a loopback address (127.0.0.1, ::1 or
localhost). Set MAROON_ALLOW_REMOTE=1 to run it against another backend on purpose.
Skips with a message (exit 0) when the server has no posts.search / feed.top ("Unknown social action.").
Credentials stay in memory and every account is deleted in `finally`.
"""
import json, os, sys, threading, urllib.error, urllib.parse, urllib.request, uuid
import runner_backend

config = runner_backend.load()
host = urllib.parse.urlsplit(config['url']).hostname or ''
if host not in ('127.0.0.1', '::1', 'localhost') and os.environ.get('MAROON_ALLOW_REMOTE') != '1':
    sys.exit('Refusing to run against %s: this runner is local-only by default (set MAROON_API_URL/MAROON_API_KEY '
             'to the local stack, or MAROON_ALLOW_REMOTE=1 on purpose). Nothing was created.' % host)
base = config['url']; key = config['publishableKey']
tokens = {}; label = 'st' + uuid.uuid4().hex[:9]; community = 'Graduates'
word = 'qr' + uuid.uuid4().hex[:10]


def call(action, token=None, **payload):
    headers = {'Content-Type': 'application/json', 'apikey': key}
    if token: headers['X-Social-Token'] = token
    request = urllib.request.Request(base + '/functions/v1/social', data=json.dumps({'action': action, **payload}).encode(), headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=40) as response: return response.status, json.load(response)
    except urllib.error.HTTPError as error: return error.code, json.load(error)


def ok(action, token=None, **payload):
    status, result = call(action, token, **payload)
    assert status == 200, (action, status, result.get('code'), result.get('error'))
    return result


def refused(code, message, action, token, **payload):
    status, result = call(action, token, **payload)
    assert status != 200 and result.get('code') == code and (message is None or result.get('error') == message), (action, status, result.get('code'), result.get('error'))


def ids(result): return [post['id'] for post in result['posts']]
def unknown(status, result): return status != 200 and result.get('error') == 'Unknown social action.'


def pages(action, token, limit, **payload):
    """Every page of a search or Top read, sending the cursor back verbatim. Returns (ids, page count)."""
    seen, count, cursor = [], 0, None
    while True:
        extra = {'cursor': cursor} if cursor is not None else {}
        result = ok(action, token, limit=limit, **payload, **extra)
        count += 1
        assert set(result) >= {'posts', 'more', 'cursor'}, result.keys()
        assert result['more'] == isinstance(result['cursor'], dict), result
        seen += ids(result)
        if not result['more']: return seen, count
        cursor = result['cursor']
        assert count < 20, 'paging does not end'


# The edge function before any account: a server without the actions says so.
for action in ('posts.search', 'feed.top'):
    status, result = call(action, community=community)
    if unknown(status, result):
        print('SKIP this server has no %s (edge function not deployed); nothing was created.' % action, flush=True); sys.exit(0)
try:
    for name in 'abcde':
        tokens[name] = runner_backend.accept_guidelines(config, ok('register', username=label + name, adult=True))['token']
    a, b, c, d, e = (tokens[name] for name in 'abcde')
    for action, extra in (('posts.search', {'query': word}), ('feed.top', {'window': 'day'})):
        status, result = call(action, b, community=community, **extra)
        if unknown(status, result):
            print('SKIP the database gateway has no %s (migrations not applied).' % action, flush=True); sys.exit(0)
        assert status == 200, (action, status, result)

    # Search -------------------------------------------------------------------------------------
    anon = ok('post.create', a, text='Anonymous %s calculus notes, studying tonight' % word, community=community, anonymous=True, topic='academics')['resource_id']
    named = ok('post.create', a, text='Named %s post about dorms' % word, community=community, anonymous=False, topic='housing')['resource_id']
    sports = ok('post.create', a, text='%s tailgate' % word, community=community, topic='sports')['resource_id']
    found = ok('posts.search', b, community=community, query=word)
    assert set(ids(found)) == {anon, named, sports} and found['more'] is False and found['cursor'] is None, found
    assert all({'id', 'author', 'text', 'score', 'topic', 'created'} <= set(post) for post in found['posts'])
    assert next(post for post in found['posts'] if post['id'] == anon)['author'] == 'Anonymous'
    assert ok('posts.search', b, community=community, query=label + 'a')['posts'] == [], 'the author username matched'
    assert ids(ok('posts.search', b, community=community, query=word + ' calc')) == [anon]
    assert ids(ok('posts.search', b, community=community, query='  %s STUDIES  ' % word.upper())) == [anon]
    assert ids(ok('posts.search', b, community=community, query=word, topic='housing')) == [named]
    assert ok('posts.search', b, community='Freshmen', query=word)['posts'] == []
    seen, count = pages('posts.search', b, 1, community=community, query=word)
    assert sorted(seen) == sorted([anon, named, sports]) and len(set(seen)) == 3 and count == 3, (seen, count)
    print('PASS posts.search finds body words by prefix and stem within community and topic, never the username, and pages without duplicates', flush=True)

    for bad in (None, 5, 'a', '   a  ', 'x' * 81):
        refused('invalid', 'Search for 2 to 80 characters.', 'posts.search', b, community=community, query=bad)
    refused('invalid', 'Choose an available topic.', 'posts.search', b, community=community, query=word, topic='nope')
    refused('invalid', 'Choose an available community.', 'posts.search', b, community='Elsewhere', query=word)
    refused('invalid', 'Use a valid page cursor.', 'posts.search', b, community=community, query=word, cursor={'rank': 'x'})
    for n in range(30):
        ok('posts.search', e, community=community, query=word)
    refused('rate_limit', 'Too many searches. Try again in a minute.', 'posts.search', e, community=community, query=word)
    print('PASS search validation and the 30-per-minute limit', flush=True)

    # Top ----------------------------------------------------------------------------------------
    # Every new post starts with its author's upvote (score 1). Four readers vote the sports post at
    # the same moment; then one more vote each on the named post.
    barrier = threading.Barrier(4); errors = []
    def vote(token):
        try:
            barrier.wait(10); ok('post.vote', token, post_id=sports, value=1)
        except Exception as error: errors.append(error)
    threads = [threading.Thread(target=vote, args=(token,)) for token in (b, c, d, e)]
    for thread in threads: thread.start()
    for thread in threads: thread.join()
    assert not errors, errors
    ok('post.vote', b, post_id=named, value=1)
    ok('post.vote', c, post_id=anon, value=-1); ok('post.vote', d, post_id=anon, value=-1)
    for window in ('day', 'week', 'all'):
        top = ok('feed.top', b, community=community, window=window, limit=30)
        mine = [post for post in top['posts'] if post['id'] in (anon, named, sports)]
        assert [(post['id'], post['score']) for post in mine] == [(sports, 5), (named, 2), (anon, -1)], (window, [(p['id'], p['score']) for p in mine])
        scores = [post['score'] for post in top['posts']]
        assert scores == sorted(scores, reverse=True), scores
    assert [post['id'] for post in ok('feed.top', b, community=community, window='week', topic='sports')['posts']][:1] == [sports]
    seen, count = pages('feed.top', b, 1, community=community, window='day')
    assert len(seen) == len(set(seen)) and {anon, named, sports} <= set(seen), seen
    refused('invalid', 'Choose Today, This week or All time.', 'feed.top', b, community=community, window='month')
    refused('invalid', 'Use a valid page cursor.', 'feed.top', b, community=community, window='day', cursor='x')
    ok('post.delete', a, post_id=sports)
    assert sports not in ids(ok('feed.top', b, community=community, window='day', limit=30)), 'deleted post still on Top'
    print('PASS feed.top orders by the shown score (self-vote and concurrent votes counted) in every window, filters by topic, pages without duplicates and drops deleted posts', flush=True)
finally:
    failures = []
    for token in tokens.values():
        status, result = call('account.delete', token)
        if status != 200: failures.append((status, result.get('code')))
    if tokens: print('Synthetic account credentials deleted.' if not failures else 'Cleanup failed: %s' % failures, flush=True)
    if failures: raise RuntimeError(('Synthetic account cleanup failed', failures))
