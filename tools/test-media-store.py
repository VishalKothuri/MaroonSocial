#!/usr/bin/env python3
"""Media store contract (caching phase 2) against the deployed edge functions.

With MEDIA_BACKEND unset the deployed behaviour must equal the pre-phase-2 behaviour:
attachment.read answers {attachment_id, mime, media_data} (no url/expires), post and
room uploads round-trip, outsiders are refused, and group-photos honours the new
known_attachment_id short-circuit only after authorization. Two synthetic accounts are
registered through the social function; their credentials stay in memory and both
accounts are deleted in `finally`. Prints a digest of every decoded media payload so
two runs (before/after a deploy) can be compared byte for byte.

    python3 tools/test-media-store.py            # run
    python3 tools/test-media-store.py --digest   # also print sha256 of each payload
    python3 tools/test-media-store.py --baseline # pre-phase-2 deployment: stop before known_attachment_id
"""
import base64, hashlib, json, pathlib, struct, subprocess, sys, tempfile, urllib.error, urllib.request, uuid, zlib
import runner_backend

config = runner_backend.load()
label = 'ms' + uuid.uuid4().hex[:9]
tokens = []
digests = {}

def call(endpoint, action, token=None, **payload):
    headers = {'Content-Type': 'application/json', 'apikey': config['publishableKey']}
    if token: headers['X-Social-Token'] = token
    request = urllib.request.Request(config['url'] + '/functions/v1/' + endpoint, data=json.dumps({'action': action, **payload}).encode(), headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=45) as response: return response.status, json.load(response)
    except urllib.error.HTTPError as error: return error.code, json.load(error)

def ok(endpoint, action, token=None, **payload):
    status, result = call(endpoint, action, token, **payload)
    assert status == 200, (endpoint, action, status, result.get('error') if isinstance(result, dict) else result)
    return result

def png(width, height, rgb):
    raw = b''.join(b'\x00' + bytes(rgb) * width for _ in range(height))
    chunk = lambda kind, data: struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')

def jpeg_from(png_bytes):
    with tempfile.TemporaryDirectory() as folder:
        source = pathlib.Path(folder, 'in.png'); target = pathlib.Path(folder, 'out.jpg')
        source.write_bytes(png_bytes)
        subprocess.run(['sips', '-s', 'format', 'jpeg', str(source), '--out', str(target)], check=True, capture_output=True)
        return target.read_bytes()

def media_read(token, attachment_id, name):
    result = ok('social', 'attachment.read', token, attachment_id=attachment_id)
    # Supabase backend: inline bytes only, exactly today's keys.
    assert set(result) == {'attachment_id', 'mime', 'media_data'}, sorted(result)
    data = base64.b64decode(result['media_data'])
    digests[name] = hashlib.sha256(data).hexdigest()
    return result, data

try:
    for suffix in 'ab':
        tokens.append(runner_backend.accept_guidelines(config,ok('social', 'register', username=label + suffix, adult=True))['token'])
    a, b = tokens
    picture = png(24, 16, (128, 0, 0))

    post_id = ok('social', 'post.create', a, text='Synthetic media store verification', anonymous=True)['resource_id']
    attachment = ok('social', 'attachment.upload', a, post_id=post_id, kind='image', data=base64.b64encode(picture).decode())['attachment_id']
    result, data = media_read(a, attachment, 'post_png_author')
    assert result['attachment_id'] == attachment and result['mime'] == 'image/png'
    assert data.startswith(b'\x89PNG') and struct.unpack('>II', data[16:24]) == (24, 16), 'sanitised PNG keeps its size'
    _, other = media_read(b, attachment, 'post_png_reader')
    assert other == data, 'every reader gets the same immutable bytes'
    print('PASS post PNG upload -> attachment.read returns inline media_data with today\'s keys (no url/expires)')

    status, denied = call('social', 'attachment.read', b, attachment_id=str(uuid.uuid4()))
    assert status in (403, 404) and 'media_data' not in denied and 'url' not in denied
    status, _ = call('social', 'attachment.read', None, attachment_id=attachment)
    assert status == 401
    print('PASS unknown attachment and anonymous reads are refused without media')

    # Deleting the post revokes its media for every reader (Supabase reads are authorized per request;
    # R2 objects are queued for deletion and CDN purge by migration 20261005190000_r2_media_revocation).
    ok('social', 'post.delete', a, post_id=post_id)
    for reader in (a, b):
        status, gone = call('social', 'attachment.read', reader, attachment_id=attachment)
        assert status in (403, 404) and 'media_data' not in gone and 'url' not in gone, (status, sorted(gone))
    print('PASS deleting the post revokes its media for the author and other readers')

    room = ok('communities', 'create', a, title='Synthetic media store QA', description='Temporary media store contract test.', category='Friends', avatar='gold', is_public=False, alias='Captain', member_avatar='sage', nonce=str(uuid.uuid4()))['room_id']
    room_attachment = ok('social', 'attachment.upload', a, room_id=room, kind='image', data=base64.b64encode(png(10, 10, (0, 80, 160))).decode())['attachment_id']
    ok('social', 'room.send', a, room_id=room, text='Synthetic room media', attachment_id=room_attachment, nonce=str(uuid.uuid4()))
    _, room_bytes = media_read(a, room_attachment, 'room_png_member')
    assert room_bytes.startswith(b'\x89PNG')
    assert call('social', 'attachment.read', b, attachment_id=room_attachment)[0] == 403
    print('PASS room media stays private: member reads inline bytes, outsider is refused')

    photo = jpeg_from(png(64, 64, (90, 20, 20)))
    ok('group-photos', 'upload', a, room_id=room, scope='group', data=base64.b64encode(photo).decode())
    first = ok('group-photos', 'read', a, room_id=room, scope='group')
    assert first['has_photo'] and 'media_data' in first and 'unchanged' not in first
    digests['group_photo'] = hashlib.sha256(base64.b64decode(first['media_data'])).hexdigest()
    if '--baseline' in sys.argv:
        ok('communities', 'close', a, room_id=room)
        print(json.dumps(digests, sort_keys=True)); sys.exit(0)
    known = ok('group-photos', 'read', a, room_id=room, scope='group', known_attachment_id=first['attachment_id'])
    assert known == {'has_photo': True, 'attachment_id': first['attachment_id'], 'unchanged': True}, known
    stale = ok('group-photos', 'read', a, room_id=room, scope='group', known_attachment_id=str(uuid.uuid4()))
    assert 'media_data' in stale and 'unchanged' not in stale
    # Authorization runs before the short-circuit: an outsider learns nothing, even with the right id.
    assert call('group-photos', 'read', b, room_id=room, scope='group', known_attachment_id=first['attachment_id'])[0] in (400, 403)
    print('PASS group photo: known id skips bytes only for an authorized reader; stale id gets bytes')
    ok('communities', 'close', a, room_id=room)
    if '--digest' in sys.argv: print(json.dumps(digests, sort_keys=True))
finally:
    # Attempt every deletion before reporting any failure, so one bad response never strands the other account.
    failed = []
    for index, token in enumerate(tokens):
        try: status = call('social', 'account.delete', token)[0]
        except Exception as error: status = type(error).__name__
        if status != 200: failed.append((index, status))
    assert not failed, ('account.delete', failed)
    print('PASS synthetic accounts deleted; no credentials retained')
