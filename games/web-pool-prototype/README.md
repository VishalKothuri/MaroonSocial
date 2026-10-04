# Maroon Social browser pool

Separate **GPL-3.0** website using the actual [tailuge/billiards](https://github.com/tailuge/billiards) physics and renderer, pinned at `9cd48c5cc0986f86e5514d21f7668aa408d538ea` (2026-10-04). Browser visitors get practice. The native app can connect a short-lived pool-only session for authoritative two-player matches.

## Build / Vercel

```sh
npm ci --ignore-scripts
npm run build
npm run serve
```

Published practice: https://maroon-social-games.vercel.app. The app uses this exact origin while the custom games.maroonsocial.chat domain is affected by a local network filter. Open http://localhost:4173 for local development. Deploy project root `games/web-pool-prototype`, output `dist`, Node 22+. `vercel.json` includes a restrictive CSP. The only network game origin is the configured Supabase endpoint. No credentials or environment variables are needed in the website build. The complete corresponding source and licenses are linked beside every distributed build.

At the first practice rack, move the cue ball then tap **Place Ball**. Drag to aim, set power/spin, and shoot. Own aiming and shots remain overhead. New rack resets practice. `?game=nineball` enables practice nine-ball; connected online matches are always eight-ball.

## Authoritative online adapter

`server/engine.ts` runs the same pinned sliding/rolling/angular-spin/Mathavan-cushion physics in the Edge runtime, at fixed 1/512s steps. Its immutable version is `maroon-web-pool-3.0.0`. Input is aim angle, bounded power/spin/elevation and legal cue placement after a foul. The server determines first contact, pots, scratch/foul, groups, turn and winner. No client outcome is accepted. A bounded 16fps canonical replay accompanies the settled state.

The isolated `web-pool` Edge endpoint authenticates each request. Native `WebPoolView` mints a random one-hour pool-only credential, passes it through WKWebView arguments (never URLs/storage), and revokes on exit or account change. A generation/owner guard rejects late creation responses; the old pool-only credential can revoke itself without a new account’s credential. Full account credentials stay in native code. Verified Auth scopes are bound to the issuing live Auth session; legacy scopes are bound to the original credential hash. Blocks, bans and configured verification apply on every action.

The new private matchmaking queue never mixes 3.0 with 2.x matches. Both members must explicitly search. Match identity is **Player 1 / Player 2**; no account usernames or IDs are shared. Turns use optimistic version checks and nonce receipts; identical retries return the committed result, altered retries are rejected. Searches expire after 45 seconds without a heartbeat; hidden/closed pages cancel searching. Matches persist through navigation. A week without a turn closes an abandoned match; data is purged after 30 days. New matches are limited to 30/member/day. Public website practice does not sign in or match automatically.

Browser `OnlinePool` reuses the upstream cue input controls, but disables local physics/rule advancement while online. It plays server frames and only enables the current member’s cue. Existing native 2.x matches, invitations, replays and server resolvers stay untouched. New Pool invitations use 3.0 and the existing chat message card. The recipient must explicitly accept; a group invitation selects a room-scoped member key. Group aliases, discovery names and anonymous labels are preserved, including read-only observer cards. Both players must retain room access to play. Native match lists merge both engines, while only a not-found response allows a historical endpoint fallback.

Finished games offer a same-opponent rematch. A new pending game is created once per finished parent; only the receiver accepts. Concurrent requests recover the same pending game and never auto-accept. Declined/expired rematches can be followed by a fresh chat invitation or another random opponent. Multiple asynchronous accepted games are supported; accepting an invitation cancels still-waiting searches under the same queue lock, without deleting any match already paired. Pending invitations expire after 24 hours.

## Verification

```sh
npm run test:physics   # 61 upstream physics regressions
npm run test:adapter   # headless solver properties + browser lifecycle boundary
# repository root, live synthetic accounts only:
python3 tools/test-web-pool.py
python3 tools/test-web-pool-invitations.py
```

`tools/test-web-pool-security.sql` runs rollback-only ACL/isolation/cancel/turn/revocation checks. Live regression exercises concurrent pairing and turns, then checks canonical Edge state/replay equals the pinned local solver. It deletes its exact three synthetic accounts. The invitation regression verifies actual DM cards, concurrent accept/search, a real scoped physical shot, simultaneous rematch creation, explicit consent, group aliases, observer boundaries and self-revocation; it deletes all synthetic accounts. `tools/test-web-pool-invitations.sql` additionally verifies anonymous/discovery identity, expiry and stale-room denial in a rollback. Native routing, exact origins and late-account lifecycle have focused test classes for the app build. These checks do not prove subjective play feel or physical-device touch performance; browser/native manual validation is separate.

## Attribution / limits

`upstream/` preserves original source/assets/tests/license. Upstream public networking, score submission, analytics and URL shortening are not used. `web/` provides presentation, a neutral room/green felt, overhead camera, and the scoped adapter. `server/` contains our GPL authoritative engine adapter; matching source is included in the downloadable archive. Dependency versions/licenses are collected during build.

Review GPL obligations for the actual app/web distribution architecture. A separate website or directory alone is not a legal guarantee for the wider app. The GPL engine is not bundled into the Swift app or its MIT engine. Cup Pong and Chess continue on the existing separately licensed production engine.
