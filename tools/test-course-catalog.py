#!/usr/bin/env python3
"""Live course activity smoke test using disposable members. Does not create course rooms."""
import json
import pathlib
import time
import urllib.error
import urllib.request

config = json.loads(pathlib.Path('MaroonSocial/Resources/Backend.json').read_text())
tokens = []

def call(endpoint, payload, token=None):
    headers = {'Content-Type': 'application/json', 'apikey': config['publishableKey']}
    if token:
        headers['X-Social-Token'] = token
    request = urllib.request.Request(config['url'] + '/functions/v1/' + endpoint,
                                    data=json.dumps(payload).encode(), headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)

try:
    for suffix in 'ab':
        status, result = call('social', {'action': 'register', 'username': 'qacat' + str(int(time.time()))[-8:] + suffix, 'adult': True})
        assert status == 200, (status, result)
        tokens.append(result['token'])
    snapshots = []
    for token in tokens:
        status, data = call('courses', {'action': 'activity', 'term': 'Fall 2026'}, token)
        assert status == 200 and isinstance(data['courses'], list), (status, data)
        assert all(set(row) == {'code', 'members'} and isinstance(row['members'], int) and row['members'] > 0 for row in data['courses'])
        snapshots.append(sorted(data['courses'], key=lambda row: row['code']))
    assert snapshots[0] == snapshots[1], 'Independent members saw different public aggregate counts'
    status, calendar = call('courses', {'action': 'terms'}, tokens[0])
    assert status == 200 and calendar['timeZone'] == 'America/Chicago' and calendar['serverNow']
    terms = {row['id']: row for row in calendar['terms']}
    assert terms['Fall 2026']['endsOn'] == '2026-12-10' and terms['Fall 2026']['verified']
    assert not terms['Fall 2027']['verified'] and terms['Fall 2027']['closesAt'] is None
    assert call('courses', {'action': 'terms'})[0] == 401
    status, future = call('social', {'action': 'course.join', 'code': 'CHEM 107', 'term': 'Spring 2027'}, tokens[0])
    assert status == 400 and future.get('code') == 'closed', (status, future)
    assert call('courses', {'action': 'activity', 'term': 'Fall 2026'})[0] == 401
    assert call('courses', {'action': 'activity', 'term': 'Fall 2026'}, '0' * 64)[0] == 401
    assert call('courses', {'action': 'activity', 'term': 'Fake 2026'}, tokens[0])[0] == 400
    print('PASS course activity: two live members, aggregate-only response, official calendar/server clock, unpublished term lock, future-join denial, credential rejection and semester validation')
finally:
    for token in tokens:
        status, result = call('social', {'action': 'account.delete'}, token)
        assert status == 200, (status, result)
    print('Synthetic course test members deleted')
