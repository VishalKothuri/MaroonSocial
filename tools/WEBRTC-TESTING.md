# Synthetic WebRTC integration test

`test-discovery-webrtc.py` creates two authenticated synthetic member accounts against the backend in `MaroonSocial/Resources/Backend.json`. It checks direct-media consent enforcement, creates an explicit request, recipient acceptance and both foreground acknowledgments, obtains the deployed ICE configuration, and sends actual SDP offers, answers, and separate ICE candidates through the chat API. Two `aiortc` peer connections then exchange changing synthetic video in both directions and echo a data-channel payload. It never opens a camera or microphone.

This is a live integration test. Run it against a project you operate, while other automated discovery tests are stopped. It creates two temporary account identities. It refuses to transmit if its two sessions do not share the same room. Network addresses in ICE are sent to the configured signaling backend, as with the app's explicitly consented direct preview.

## Optional dependencies and execution

The app has no Python dependency. For this test, install Python 3.10 or newer and create an isolated environment:

```sh
python3 -m venv /tmp/maroon-webrtc-venv
/tmp/maroon-webrtc-venv/bin/pip install aiortc==1.15.0
/tmp/maroon-webrtc-venv/bin/python tools/test-discovery-webrtc.py
```

Override the backend file with `--config /absolute/path/Backend.json`. Only a publishable key is needed; never put a service-role key into that file.

The test always closes peer connections, leaves discovery and attempts account deletion through the authenticated social API. It writes `/tmp/maroon-discovery-webrtc-test-receipt.json` containing only SHA-256 hashes for any account whose deletion failed. An empty `token_hashes` array confirms successful cleanup. The receipt contains no bearer credentials; any retained hashes require exact operator cleanup. The historical `test-webrtc.py` used the retired anonymous endpoint and should not be used against the current deployment.

## What a pass proves

A pass requires two connected peers, an exact bidirectional data-channel echo, at least 65 decoded 160×120 video frames in each direction spanning more than two seconds, changing image values, and inbound RTP packets. SDP and candidates travel through the real deployed gateway rather than a mock or an in-memory signaling shortcut.

Both peers run on the same host. This validates the WebRTC/signaling/media pipeline but does not prove connectivity between arbitrary networks. The direct preview may fail behind restrictive or symmetric NATs; dependable cross-network support still needs a working TURN relay. This script does not verify iOS camera permissions, device capture, or rendering; those require an iPhone test.

Verified on October 4, 2026 (America/Chicago): both peers connected, 8 trickled ICE candidates delivered, 65 video frames over 2.13 seconds and 66 inbound RTP packets per peer, plus successful data-channel echo. Synthetic server identities were deleted afterward.
