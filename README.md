# Maroon Social

An iPhone-first SwiftUI app for a TAMU-only social community. This repository contains the first runnable development build and the earlier research/design specifications.

**Current build:** local social preview + real public campus data from Supabase. Student enrollment is closed. It is not a production anonymous network yet.

## Run

Open `MaroonSocial.xcodeproj`, choose the **MaroonSocial** scheme and an iPhone simulator, then Run. The project targets iOS 18 or later. Tested with Xcode 26.6 and the iPhone 17 Pro simulator on iOS 26.5. No signing team is needed for the simulator.

Enter a preview username and confirm 18+ to explore. Sample posts and activities are labeled. Social changes are saved only on the device. Campus events come from official A&M feeds through the connected Supabase project.

```sh
swift test --package-path MaroonCore
xcodebuild -project MaroonSocial.xcodeproj -scheme MaroonSocial \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

`project.yml` is the XcodeGen source. Run `xcodegen generate` after adding source files if regenerating the checked-in project.

## Working in this build

- Community: anonymous/named posts, replies, vote switching, saves, local hide/report actions, separate post-origin conversations, and an opt-in non-explicit 18+ community.
- Classes: course + semester membership, one room per course, username-based chats.
- Inbox: request acceptance/decline, text, one image **or** animated GIF per message, 5 MB attachment limit, local game invitations.
- Explore: create/join/leave hangouts, study groups, recreation and gaming plans; capacity checks; local activity chats.
- Games: native SceneKit models, a physics pool practice table, cup-pong aiming practice, and local chess with legal moves/check/checkmate, castling, en passant and automatic queen promotion. Online game state is not connected. Chess does not yet implement repetition or insufficient-material draws.
- Campus Tag: foreground-only compass practice and an explicit stop control. It does not track other people or upload location.
- Campus: official A&M/Rec calendar, saved events, iPhone Calendar export, source links, route catalog and bus-stop links to Maps.

## Connected Supabase project

Project: **Maroon Social** (`myxbghfbapbfffkpndwo`, us-east-1).

`MaroonSocial/Resources/Backend.json` contains only the public project URL and publishable client key. **Never put a service-role key, database password, SMTP credential or TURN secret in the app or repository.**

- `public.campus_cache`: a single public, read-only snapshot. RLS is enabled. Anonymous and authenticated clients have SELECT only.
- `public.campus_refresh_lock`: server-only atomic refresh lease.
- `refresh-campus`: JWT-verified Edge Function; upstream requests are bounded to once per 55 minutes. All database writes use its server-side credential.
- `maroon-campus-hourly`: hourly Supabase Cron job at minute 17. Vault stores its project URL and public invocation token. No billing plan was changed.
- Feeds are normalized to the next 31 days. Unneeded fields such as event contact emails are discarded. A last-known snapshot is preserved on upstream failure.
- Bus feeds work from the development machine but currently fail from the hosted Edge Function. The initial 33-route / 221-stop snapshot is preserved with a separate timestamp and an in-app notice.

To recreate the backend, apply `supabase/migrations`, deploy `supabase/functions/refresh-campus`, configure the two documented Vault values, and update the public client configuration. The deployed migration history may use platform-generated timestamps; local SQL records the same operations.

`python3 tools/pull-campus.py` refreshes the bundled fallback from the official public feeds. It does not upload anything. Hosted refresh is handled by the Edge Function.

## Still required before real enrollment

- An email sender domain and delivery service. No email is collected by this preview.
- Final approved TAMU domain allowlist and what qualifies as a current student. Owning a TAMU mailbox alone also includes some non-students.
- Identity/credential design that meets the desired operator-unlinkability and persistent-ban goals. No promise of cryptographic anonymity has been implemented. A plain email hash would not meet that goal.
- Authenticated social API, private media storage, moderation delivery, ban enforcement, account recovery and deletion, push notifications and multiplayer synchronization.
- Verified organization publishing and private administrator authorization.
- Random matching, WebRTC signaling, TURN, abuse controls, and an approved distribution path. The screen is a locked entry point, not a working call service.
- Multiplayer Tag lobbies, agreed catch rules, boundaries and temporary location handling.
- Dining menus/hours: the provider blocks automated requests; the app links to the official site instead of inventing menu data.
- Licensed live sports scores. Game-chat timing logic exists, but the current official athletics calendar feed is empty.

## Cost approach

Supabase was selected for relational memberships, moderation and shared caching. Its current free plan includes 50,000 MAUs, 500 MB database, 1 GB storage, 2 million Realtime messages and 200 peak connections. Those are separate limits; a large class chat can consume message allowance quickly. Firebase Firestore's free allowance is based on daily reads/writes and has a different workload profile. Neither means unlimited free chat.

Start without always-on presence, subscribe only to an open room, paginate history, resize media, retain only necessary data, and use shared feed snapshots. Voice/video relay traffic requires a separate budget. Review [Supabase pricing](https://supabase.com/pricing) and [Firebase pricing](https://firebase.google.com/pricing) before launch; pricing was checked October 1, 2026.

See [architecture](ARCHITECTURE.md), [research](RESEARCH.md), [open decisions](OPEN-DECISIONS.md), [screen specification](SCREENS-AND-FLOWS.md), and [photo attribution](THIRD_PARTY_NOTICES.md). Earlier design boards are in `design/` as historical concepts; mascot development is paused.
