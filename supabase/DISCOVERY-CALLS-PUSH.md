# Interest discovery, accepted calls and notification delivery

Current development status, October 4, 2026. Email recovery, TAMU mailbox delivery and mandatory mailbox enforcement remain paused. This document does not claim enrollment verification, public-distribution approval, cross-network reliability, operator-unlinkable identity or working Apple delivery before a real-device test.

## Named discovery

The previous public `random-chat` endpoint returns HTTP 410. Its anonymous text/voice queue is no longer offered. Ordinary accepted voice/video calls and contextual anonymous post/reply DMs remain available.

`discovery` accepts the normal private member credential or verified Supabase session. The browser accepts a separate one-hour, discovery-only credential from `random-browser`: native `pair.create` issues a one-use 60-second code; `pair.claim` exchanges it for the scoped credential. No long-lived account token goes into a website, URL or browser storage. The browser holds its limited grant in sessionStorage and revokes it on logout. Account deletion and suspension revoke backend access; independent paired grants otherwise expire after one hour.

The participant chooses a unique discovery username and up to six interests. Account usernames are not automatically published. People appear only after explicitly entering the waiting area. A request needs recipient acceptance, followed by both foreground clients acknowledging within five seconds. No text or media room exists until both acknowledge. Waiting presence expires after 15 seconds without a heartbeat; requests expire after 20 seconds. Native/background and browser visibility changes leave immediately; leases cover crashes or network loss. Capacity is bounded to 100 foreground presences, six requests/minute, a 30-second same-target delay, five incoming requests and 30 accepted sessions/day for each participant. Sessions end after 20 minutes.

Responses expose rotating presence IDs, chosen names/interests, scoped request/session IDs and participant-only messages/signals. Blocks, suspensions, current membership and session instance are checked server-side. A deliberate **Continue chatting in Inbox** creates an idempotent named request using the agreed discovery names. The recipient still must accept. Inbox title, typing, messages and game player cards use those names rather than account handles. Discovery invitations do not send persistent push calls.

Native actions are serialized with foreground-generation checks before dispatch and after response. Leave/background immediately drops media configuration and pending text. A browser handoff first leaves native presence. Suggested hashtag chips and custom interests share the six-item cap; **Save & enter** publishes the displayed profile rather than a stale saved profile.

The exact native DTO/action contract is in `DiscoveryService.swift` and `functions/discovery/index.ts`. Production CORS permits only `https://maroonsocial.chat` and `https://www.maroonsocial.chat`; explicit development origins come from `RANDOM_WEB_ORIGINS`, currently localhost/127.0.0.1 port4174 plus the exact production host `https://maroon-social-web.vercel.app`. Arbitrary preview domains and wildcard origins are not allowed.

## Calls and cost limits

Accepted DM voice/video calls remain participant-bound. Group calls support up to four explicitly joined members of the accepted group, scoped aliases and recipient-specific signaling, with a 20-minute maximum. Camera/microphone start only after another participant joins. Leaving, backgrounding, lost authorization, room removal and expiry tear down local tracks. Group media is a small peer mesh; it is not a scalable broadcast service or CallKit/PushKit integration.

`CALL_RELAY_ENABLED` is false unless an owner explicitly opts in. Merely installing `TURN_KEY_ID` and `TURN_API_TOKEN` cannot activate Cloudflare billing. The configured implementation issues short-lived relay credentials and caps credential issuance per authorized call, but Cloudflare has not been enabled because the owner requires no paid overages. The active path is direct WebRTC with explicit disclosure that another participant may learn the network address. Another Wi-Fi/mobile network can help, but does not guarantee a connection.

Official LiveKit Build documentation describes hard usage caps that fail new requests rather than bill overages: https://docs.livekit.io/deploy/admin/quotas-and-limits/. It remains an optional, unconfigured SFU/provider integration; no account, paid plan or resource was created. Direct same-host tests do not establish campus/cellular NAT connectivity.

## APNs and foreground game activity

Private device registrations use an installation secret and monotonic sequence. Delayed registrations cannot restore a logged-out device. Account deletion cascades devices; Auth-session revocation removes session-bound registrations. Notification jobs contain references rather than message text, names or account IDs. Eligibility is rechecked for current membership, blocks, bans, mute settings, read state, current invitation identity and game participants. Workers use bounded leases, retries/backoff and token-version checks; obsolete requests cannot reappear after a decline/reinvite.

Mutation endpoints best-effort wake `push-delivery`, with a one-minute cron retry fallback. Provider authentication uses standard ES256 APNs JWTs and an HTTP/2-only client. There is no simulated success. Foreground Inbox → Game activity exposes authorized game invitations/turns for 24 hours with read state; lock-screen payloads use generic copy and destinations resolve authorization again before navigation.

The owner has an Apple Developer team, and project signing/entitlements are configured. The restricted Sandbox APNs key still needs its original owner-provided `.p8` installed and actual device delivery validated. Use:

```
python3 tools/setup-apns.py --key-file /absolute/AuthKey_ID.p8 --key-id TENCHARKEY --install
```

The helper defaults to team `259BRQX9UQ`, topic `app.maroonsocial.MaroonSocial` and **sandbox only**. It validates the PEM, uploads via a private temporary file, installs the fixed worker secret in Vault, removes the temporary file and never prints private keys. It does not send an alert itself; eligible queued alerts may begin delivering after configuration. `--environments production` or `sandbox,production` requires a credential authorized for those environments. The queue will not lease unsupported environments, and the provider refuses unsupported hosts. Production builds remain unconfigured under a Sandbox-only key.

Secrets: `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`, `APNS_ALLOWED_ENVIRONMENTS`, `PUSH_WORKER_SECRET`. The Vault worker value is installed only through the fixed-name, service-only setup function; no generic Vault API is exposed.

## Evidence and limits

- `tools/test-discovery-security.sql`: service-role rollback checks for six interests, case-insensitive names, direct consent, explicit recipient acceptance, both acknowledgments, stale presence, handshake timeout, participant text and Continue identity projections. Fixtures roll back.
- `tools/test-discovery-webrtc.py`, `build/discovery-webrtc.log`: two independently authenticated participants, actual offer/answer plus eight ICE signals through Supabase, bidirectional data echo, 65 decoded synthetic video frames per peer over2.13seconds. Same host, no real camera/microphone. Both synthetic accounts were deleted; cleanup receipt has no remaining hashes.
- October 4 hosted production browser checks passed: pairing, the six-interest limit, waiting profiles, explicit outgoing/incoming request acceptance, named text in both directions, Continue request, background leave/reentry and End. Native discovery UI checks also passed against the live service. Both synthetic actors and their sole synthetic-only Continue room were removed after testing; read-only receipt checks confirmed zero retained fixture accounts, profiles, presence, requests, sessions, transport links, pairing codes, browser grants or Inbox messages. Both existing native test accounts were preserved, and both CLI peers were stopped.
- `tools/test-calls-push-security.sql`: service-role rollback checks for account block/suspension, group capacity/consent/scoped signaling/expiry, APNs proof/versioning, mute/read/stale-invitation checks, sandbox-only leases and deletion.
- `tools/test-call-push-adapters.ts`: seven passing mocked/cryptographic tests, including real ES256 signature verification, provider privacy/host checks, sanitized failures, relay opt-in/TTL/CORS and production rejection under sandbox credentials. No real Apple request.
- `web/tests/lifecycle.test.mjs` executes the actual page code and markup with controlled delayed responses: End cannot restart capture, backgrounding during profile save cannot enter, an old token401 cannot clear a new pairing, and repeated verification failures stop capture. Together with signal-buffer and profile-restoration tests, eight Node tests pass; these use jsdom and do not establish browser media permissions.
- `tools/test-pool-push-security.sql`: new3.0 pool invitations/turns, room-less game routing/inbox, accepted-room revocation, mute/read/preferences, stale revisions, blocks/bans, rematch expiry and deletion all pass in a service-role rollback. Queued game routes resolve the authorized gameID directly. Expired jobs have a separate bounded ten-minute cleanup even without Apple credentials.
- Supabase security advisors returned zero lints after these migrations. Native/UI execution is tracked by the root integration log and TESTING.md; it must not be inferred from source parsing.

Practical account-level blocks and suspension are now shared. They are not cryptographic unlinkability, Sybil resistance or a guarantee against replacement accounts while verification is paused. Privacy Pass (RFC9576) requires explicit issuer/attester/origin roles and a reviewed threat model; it has not been invented or quietly substituted into this app. Operators can associate account activity, reports retain necessary evidence, and platform/backup retention remains separate.
