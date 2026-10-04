# Retired automatic random matching endpoint

The public `random-chat` endpoint now returns HTTP410. The owner replaced automatic anonymous text/voice matching with named, request-based interest discovery. Do not run the historical `test-random-chat.py` or guest `test-webrtc.py` against the current public deployment.

The current implementation is documented in [Discovery, calls and push](../../DISCOVERY-CALLS-PUSH.md), with native `DiscoveryService.swift` / `DiscoveryView.swift`, the `discovery` Edge endpoint and the paired-browser web client. The internal private signaling tables/functions remain implementation detail; they are not callable by anon/authenticated database clients.

Current real-media verification uses `tools/test-discovery-webrtc.py`: explicit request, recipient acceptance, both foreground acknowledgments, actual synthetic video/data through deployed signaling, then deletion of both synthetic accounts. See [WebRTC testing](../../../tools/WEBRTC-TESTING.md).

Ordinary accepted voice/video calls and fixed-anonymous post/reply DMs are preserved. Direct video requires explicit network-address consent; no paid relay has been enabled. Do not present same-host media tests as arbitrary-network or physical-camera proof.
