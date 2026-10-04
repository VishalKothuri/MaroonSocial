#!/usr/bin/env python3
"""Real synthetic WebRTC video + data through the deployed interest-discovery signaling API.

Optional dependency: aiortc==1.15.0 (Python >=3.10). No camera or microphone is used.
Run only against a project you operate. Two temporary account identities are created,
they leave in finally, and their one-way token hashes are saved for operator cleanup.
"""
import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request
import uuid

from aiortc import RTCConfiguration, RTCIceServer, RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.sdp import candidate_from_sdp
from av import VideoFrame


class APIError(Exception):
    def __init__(self, status, result):
        self.status = status
        self.code = result.get('code')
        super().__init__(f'Chat API {status}: {result.get("error", "unknown error")}')


class ChatPeer:
    def __init__(self, config):
        self.config = config
        self.token = None
        self.instance = str(uuid.uuid4())
        self.room = None
        self.after = 0
        self.session = None
        self.deleted = False

    async def request(self, action, **payload):
        endpoint = 'social' if action in ('register','account.delete') else 'discovery'
        action = 'heartbeat' if action == 'poll' else action
        body = {'action': action, 'instance': self.instance, 'after_signal': self.after, **({'session_id':self.session} if self.session else {}), **payload}
        headers = {'Content-Type': 'application/json', 'apikey': self.config['publishableKey']}
        if self.token:
            headers['X-Social-Token'] = self.token
        request = urllib.request.Request(self.config['url'] + '/functions/v1/'+endpoint,
                                         data=json.dumps(body).encode(), headers=headers, method='POST')
        def perform():
            try:
                with urllib.request.urlopen(request, timeout=20) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                raise APIError(error.code, json.load(error)) from None
        result = await asyncio.to_thread(perform)
        if result.get('token'):
            self.token = result['token']
        if result.get('session'):
            self.session = result['session']['id'];self.room=result['session'].get('room')
        return result

    async def signal(self, kind, payload):
        return await self.request('signal', room=self.room, nonce=str(uuid.uuid4()), kind=kind, payload=payload)

    async def close(self):
        if self.token:
            payload = {'room': self.room} if self.room else {}
            try:
                await self.request('leave', **payload)
                await self.request('account.delete');self.deleted=True
            except (APIError, OSError):
                pass


class SyntheticVideo(VideoStreamTrack):
    def __init__(self, offset):
        super().__init__()
        self.offset = offset
        self.frames = 0

    async def recv(self):
        pts, time_base = await self.next_timestamp()
        frame = VideoFrame(width=160, height=120, format='yuv420p')
        self.frames += 1
        for plane, value in zip(frame.planes, [40 + (self.frames + self.offset) % 170, 90, 160]):
            plane.update(bytes([value]) * plane.buffer_size)
        frame.pts, frame.time_base = pts, time_base
        return frame


def split_description(description):
    """Send SDP and trickled ICE separately, matching the app's offer/answer/ice API."""
    lines = description.sdp.splitlines()
    candidates = []
    output = []
    section = -1
    mid = None
    for line in lines:
        if line.startswith('m='):
            section += 1
            mid = None
        if line.startswith('a=mid:'):
            mid = line[6:]
        if line.startswith('a=candidate:'):
            candidates.append({'candidate': line[2:], 'sdpMid': mid, 'sdpMLineIndex': section})
        elif line != 'a=end-of-candidates':
            output.append(line)
    return {'sdp': '\r\n'.join(output) + '\r\n', 'type': description.type}, candidates


async def transmit_description(api, description):
    payload, candidates = split_description(description)
    await api.signal(description.type, payload)
    for candidate in candidates:
        await api.signal('ice', candidate)
    return len(candidates)


async def receive_description(api, peer, kind, expected_candidates):
    seen_description = False
    seen_candidates = 0
    pending = []
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        result = await api.request('poll')
        if result['state'] != 'connected':
            raise AssertionError('Signaling room ended during negotiation')
        for signal in result['signals']:
            api.after = max(api.after, signal['id'])
            if signal['kind'] == kind:
                await peer.setRemoteDescription(RTCSessionDescription(**signal['payload']))
                seen_description = True
            elif signal['kind'] == 'ice':
                pending.append(signal['payload'])
        if seen_description:
            for payload in pending:
                candidate = candidate_from_sdp(payload['candidate'].removeprefix('candidate:'))
                candidate.sdpMid = payload['sdpMid']
                candidate.sdpMLineIndex = payload['sdpMLineIndex']
                await peer.addIceCandidate(candidate)
                seen_candidates += 1
            pending = []
        if seen_description and seen_candidates >= expected_candidates:
            await peer.addIceCandidate(None)
            return seen_candidates
        await asyncio.sleep(0.25)
    raise TimeoutError(f'{kind} / ICE did not arrive through backend')


async def main(args):
    config = json.loads(Path(args.config).read_text())
    apis = [ChatPeer(config), ChatPeer(config)]
    peers = []
    consumers = []
    frame_counts = [0, 0]
    frame_spans = [0.0, 0.0]
    video_done = [asyncio.Event(), asyncio.Event()]
    changed_luma = [set(), set()]
    data_echo = asyncio.Event()
    started = time.monotonic()
    try:
        suffix=uuid.uuid4().hex[:8]
        for i,api in enumerate(apis):
            await api.request('register',username='dvr'+suffix+str(i),adult=True)
            await api.request('profile',username='Video'+suffix+str(i),tags=['music','engineering'])
        try:
            await apis[0].request('enter')
            raise AssertionError('Direct media accepted without consent')
        except APIError as error:
            assert error.code == 'consent', error
        await asyncio.gather(*(api.request('enter',allow_direct=True) for api in apis))
        directory=await apis[0].request('heartbeat')
        person=next(p for p in directory['people']if p['username']=='Video'+suffix+'1')
        request=await apis[0].request('request',target=person['id'],nonce=str(uuid.uuid4()))
        request_id=request['outgoing']['id']
        accepted=await apis[1].request('accept',request_id=request_id)
        apis[0].session=accepted['session']['id']
        assert accepted['state']=='connecting' and accepted['session']['room']is None
        await asyncio.gather(*(api.request('ack')for api in apis))
        room_a,room_b=await asyncio.gather(*(api.request('heartbeat')for api in apis))
        assert room_a['state']==room_b['state']=='connected'
        assert apis[0].room==apis[1].room
        async def keepalive():
            while True:
                await asyncio.sleep(3)
                await asyncio.gather(*(api.request('heartbeat')for api in apis))
        consumers.append(asyncio.create_task(keepalive()))
        calls=await asyncio.gather(*(api.request('media',allow_direct=True)for api in apis))
        for call in calls:
            assert call['media_transport']=='direct'
            peers.append(RTCPeerConnection(RTCConfiguration(iceServers=[RTCIceServer(**server)for server in call['ice_servers']])))
        print('PASS: explicit request, accept and both foreground acknowledgments precede media',flush=True)

        async def consume(track, index):
            first = None
            while True:
                frame = await track.recv()
                assert frame.width == 160 and frame.height == 120, 'Decoded frame dimensions differ'
                now = time.monotonic()
                if first is None:
                    first = now
                frame_counts[index] += 1
                frame_spans[index] = now - first
                changed_luma[index].add(bytes(frame.planes[0])[0])
                if frame_counts[index] >= 65 and frame_spans[index] >= 2:
                    video_done[index].set()

        def track_handler(index):
            def received(track):
                if track.kind == 'video':
                    consumers.append(asyncio.create_task(consume(track, index)))
            return received

        for index, peer in enumerate(peers):
            peer.on('track', track_handler(index))
            peer.addTrack(SyntheticVideo(index * 40))

        @peers[1].on('datachannel')
        def remote_channel(channel):
            @channel.on('message')
            def echo(message):
                channel.send('echo:' + message)

        channel = peers[0].createDataChannel('maroon-integration-test')
        payload = 'synthetic-message-' + uuid.uuid4().hex
        @channel.on('open')
        def send_data():
            channel.send(payload)
        @channel.on('message')
        def receive_data(message):
            if message == 'echo:' + payload:
                data_echo.set()

        await peers[0].setLocalDescription(await peers[0].createOffer())
        a_candidates = await transmit_description(apis[0], peers[0].localDescription)
        received_a = await receive_description(apis[1], peers[1], 'offer', a_candidates)
        await peers[1].setLocalDescription(await peers[1].createAnswer())
        b_candidates = await transmit_description(apis[1], peers[1].localDescription)
        received_b = await receive_description(apis[0], peers[0], 'answer', b_candidates)
        print(f'PASS: actual offer/answer and {received_a + received_b} ICE candidates passed through Supabase', flush=True)
        await asyncio.wait_for(asyncio.gather(data_echo.wait(), *(event.wait() for event in video_done)), timeout=20)
        for consumer in consumers:
            if consumer.done() and consumer.exception():
                raise consumer.exception()
        assert all(len(values) >= 10 for values in changed_luma), 'Received video did not change over time'
        stats = await asyncio.gather(*(peer.getStats() for peer in peers))
        rtp_received = [sum(item.packetsReceived for item in report.values() if item.type == 'inbound-rtp') for report in stats]
        assert all(count > 0 for count in rtp_received), 'No real RTP packets received'
        print(json.dumps({'result':'PASS', 'connection_states':[p.connectionState for p in peers],
                          'bidirectional_data_echo':True, 'decoded_video_frames':frame_counts,
                          'video_seconds':[round(span, 2) for span in frame_spans],
                          'inbound_rtp_packets':rtp_received,
                          'elapsed_seconds':round(time.monotonic() - started, 2),
                          'scope':'two real peers on this host, live backend signaling, synthetic video only'}), flush=True)
    finally:
        for task in consumers:
            task.cancel()
        await asyncio.gather(*consumers, return_exceptions=True)
        await asyncio.gather(*(peer.close() for peer in peers), return_exceptions=True)
        await asyncio.gather(*(api.close() for api in apis), return_exceptions=True)
        hashes = [hashlib.sha256(api.token.encode()).hexdigest() for api in apis if api.token and not api.deleted]
        receipt = {'token_hashes': hashes, 'created_by':'tools/test-discovery-webrtc.py', 'created_at':time.time()}
        fd = os.open(args.receipt, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w') as file:
            json.dump(receipt, file)
        print(f'Test calls ended. Synthetic identity cleanup receipt: {args.receipt}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', default=str(Path(__file__).resolve().parents[1] / 'MaroonSocial/Resources/Backend.json'))
    parser.add_argument('--receipt', default='/tmp/maroon-discovery-webrtc-test-receipt.json')
    arguments = parser.parse_args()
    asyncio.run(main(arguments))
