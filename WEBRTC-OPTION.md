# Random chat — WebRTC + Node.js/Socket.IO

> **October 1, 2026 implementation update:** Coding is now authorized. The user selected SwiftUI, iPhone first, and connected Supabase **Maroon Social** plus GitHub **VishalKothuri/MaroonSocial**. Mascot work is paused. This document preserves the earlier research/proposals; its older no-code statements are historical. See [README](README.md) for tested implementation status and remaining work.

September 29, 2026. Research only; no code or deployment.

Yes, this is a viable low-cost prototype stack. Node/Socket.IO handles random pairing and signaling; WebRTC carries audio/video. The matching server does not need to process each video frame. [WebRTC peer connections](https://webrtc.org/getting-started/peer-connections).

| Component | Proposed responsibility |
|---|---|
| Node.js + Socket.IO | Eligibility checks, random queue, pairing, signaling, Next/End, disconnect cleanup |
| WebRTC | One-to-one encrypted media, microphone/camera permissions |
| Managed TURN | Reliable relaying; prevent disclosing network addresses to the random peer |
| Durable storage | Membership enforcement, bans, blocks, reports that survive restarts |
| Browser interface | Candidate distribution route; native release remains separate |

For anonymous strangers, recommend relay-only WebRTC on both clients, without silent direct fallback. The standard explicitly describes this as a way to prevent remote peers learning IP addresses. Infrastructure providers still see network metadata; voice/video can identify people. [W3C WebRTC](https://www.w3.org/TR/webrtc/).

Some networks prevent direct connections; TURN provides a relay. A signaling service is not a TURN server. [WebRTC TURN guide](https://webrtc.org/getting-started/turn-server).

## Hosting and cost

Render supports WebSockets. Free services sleep after 15 minutes without inbound HTTP/WebSocket traffic and take roughly one minute to wake. The workspace receives 750 free instance hours monthly. Restarts and ephemeral storage require handling. Suitable for testing, not the recommended production matching host. [Render limits](https://render.com/docs/free), [WebSocket hosting](https://render.com/docs/websocket).

Glitch ended project hosting July 8, 2025; remove it from consideration. [Glitch announcement](https://blog.glitch.com/post/changes-are-coming-to-glitch).

Cloudflare TURN includes 1,000 GB before charges, then $0.05/GB. Billable traffic is outbound from the edge to TURN clients including overhead; the allowance is shared with Realtime SFU. [Cloudflare pricing](https://developers.cloudflare.com/realtime/turn/faq/).

Illustration: a combined billable rate of 2 Mbps across both participants gives about 0.15 GB per ten-minute call before overhead. 1,000 calls consume about 150 GB; 10,000 about 1,500 GB, approximately $25 above an otherwise unused 1,000 GB allowance. This assumed bitrate is not a video-quality guarantee or total operating budget. Measure actual traffic.

Issue short-lived TURN credentials only for eligible matched sessions. Add quotas, duration limits and server-enforced usage controls. Do not publish provider secrets or log SDP/ICE unnecessarily. Avoid banning all campus Wi-Fi users through a shared-IP rule.

Next must close the old peer connection and stop old media before matching again. Reject former partners' delayed signaling, prevent duplicate queue entries, re-check bans on reconnect, and exclude blocked accounts. On restart, recover or cleanly end queue/session state. Store bans durably, not just in process memory. No assumption of recorded or reviewable live video.

Choosing WebRTC does not alter platform policy. See [random-chat distribution research](TAG-AND-PRIVACY-UPDATE.md). Browser delivery is a candidate; a native WebView wrapper does not remove App Review.
