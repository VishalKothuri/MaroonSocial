// Deterministic lifecycle tests for the bundled WebRTC bridge, no device media captured.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html = readFileSync(new URL('../MaroonSocial/Resources/video-call.html', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
function deferred() { let resolve; const promise = new Promise(r => resolve = r); return { promise, resolve }; }
function harness({ mediaError, mediaWait, offerWait } = {}) {
  const messages = [], peers = [], tracks = [{ kind: 'audio', enabled: true, stopped: false, stop() { this.stopped = true; } }];
  const media = { getTracks: () => tracks };
  const elements = new Map();
  const element = id => { if (!elements.has(id)) elements.set(id, { style: {}, setAttribute() {}, play: () => Promise.resolve() }); return elements.get(id); };
  class Peer {
    constructor(config) { this.config = config; this.applied = []; peers.push(this); }
    addTrack() {}
    getSenders() { return []; }
    async createOffer() { if (offerWait) await offerWait.promise; return { type: 'offer', sdp: 'test' }; }
    async createAnswer() { return { type: 'answer', sdp: 'answer' }; }
    async setLocalDescription(v) { this.localDescription = { ...v, toJSON: () => v }; }
    async setRemoteDescription(v) { this.remoteDescription = v; this.applied.push(v); }
    async addIceCandidate(c) { this.applied.push(c); }
    close() { this.closed = true; }
  }
  const sandbox = {
    document: { getElementById: element, querySelector: () => element('main') },
    navigator: { mediaDevices: { getUserMedia: async () => { if (mediaWait) await mediaWait.promise; if (mediaError) throw mediaError; return media; } } },
    RTCPeerConnection: Peer,
    setTimeout: () => 1, clearTimeout: () => {},
    window: { webkit: { messageHandlers: { maroonCall: { postMessage: x => messages.push(x) } } }, addEventListener() {} }
  };
  vm.runInNewContext(script, sandbox);
  return { api: sandbox.window.MaroonCall, messages, peers, tracks, element };
}
const config = { initiator: true, video: true, iceServers: [{ urls: ['turn:relay.example.invalid'], username: 'temporary', credential: 'temporary' }] };
{
  const h = harness();
  await h.api.start({ ...config, iceServers: [{ urls: ['stun:example.invalid'] }] });
  assert.equal(h.peers.length, 0);
  assert.match(h.messages.at(-1).value, /relay is unavailable/);
}
{
  const h = harness({ mediaError: { name: 'NotAllowedError' } });
  await h.api.start(config);
  assert.match(h.messages.at(-1).value, /permission was denied/);
  assert.equal(h.peers.length, 0);
}
{
  const mediaWait = deferred();
  const h = harness({ mediaWait });
  const pending = h.api.start(config);
  h.api.stop(); mediaWait.resolve(); await pending;
  assert.equal(h.tracks[0].stopped, true, 'late permission must release tracks after leaving');
  assert.equal(h.peers.length, 0);
}
{
  const offerWait = deferred();
  const h = harness({ offerWait });
  const pending = h.api.start(config);
  await new Promise(resolve => setImmediate(resolve));
  h.api.stop(); offerWait.resolve(); await pending;
  assert.equal(h.messages.filter(x => x.type === 'signal').length, 0, 'no stale offer after leaving');
  assert.equal(h.peers[0].closed, true);
}
{
  const mediaWait = deferred();
  const h = harness({ mediaWait });
  const pending = h.api.start({ ...config, initiator: false });
  await h.api.receive({ type: 'ice', payload: { candidate: 'test-candidate' } });
  await h.api.receive({ type: 'offer', payload: { type: 'offer', sdp: 'remote' } });
  mediaWait.resolve(); await pending;
  assert.equal(h.peers[0].config.iceTransportPolicy, 'relay');
  assert.equal(h.peers[0].applied[0].type, 'offer');
  assert.equal(h.peers[0].applied[1].candidate, 'test-candidate');
  assert.equal(h.messages.filter(x => x.kind === 'answer').length, 1);
  h.element('placeholder').style.display = 'none'; h.api.stop();
  assert.equal(h.element('placeholder').style.display, 'flex');
}
{
  const h = harness();
  await h.api.start({ ...config, transport: 'direct', iceServers: [{ urls: ['stun:example.invalid'] }] });
  assert.equal(h.peers[0].config.iceTransportPolicy, 'all');
  h.api.stop();
}
console.log('6 video bridge lifecycle checks passed (mock media, no live relay claimed).');
