# Verification

Evidence updated October 4, 2026 (America/Chicago). This is a connected iPhone development build: community, classes, conversations, activities, online games and multiplayer Tag use deployed Supabase services. Local UI fixtures, synthetic protocol peers and physical-device behavior are different forms of evidence; they are distinguished below. See [feature status](FEATURE-STATUS.md) for the remaining requirements.

## Current implementation checkpoint — October 4, afternoon

This section supersedes earlier visual/feature descriptions below; older sections retain their original evidence dates. The current wordmark fills every letter maroon and then returns to white, with both words present from the first frame and no underline. Manual refresh uses the actual data request and a shared ten-second admission gate. Texas A&M is the main feed; the five requested class-year communities are deployed.

- **291 distinct native tests have passing evidence**: the full 289-test suite passed with zero failures in `build/oct4-complete-integration-tests.log`; `build/oct4-final-focused-tests.log` then passed 13 focused cases, including two new hosted-pool WebView cases. The other 11 are reruns, not additions. Media coverage includes real transcode/metadata checks, activity-plan adapters, nine durable-composition cases, three delayed-response/account-boundary cases and group-photo service/cache revocation. The original opt-in media UI failures and their successful repairs are distinguished below.
- **Two durable-draft UI journeys passed** in `build/oct4-native-live-and-drafts.log`: explicit save/relaunch/restore/discard for a message request and group creation. These use isolated local fixtures.
- **Real video-picker UI journey passed** in `build/oct4-media-picker-repair-tests.log` (32.885 seconds): select the imported synthetic MP4 through the system Photos picker, wait for native compression/thumbnail, publish in an isolated local fixture, open the post and AVKit playback, then background/foreground and require an explicit play action again. The first attempt exposed a real presentation defect: PhotosPicker embedded inside the attachment Menu dismissed without opening. Its presentation now belongs to the persistent composer container. This is native wiring/playback evidence; fixture publication is not network delivery.
- **Real group-photo picker/restoration UI passed** in `build/oct4-final-focused-tests.log` (38.448 seconds): select the imported synthetic JPEG in the real picker, compress it, save and close the draft, terminate/relaunch, restore the cover, then remove it. Earlier attempts encountered default Apple sample photos and an accessibility-label mismatch; the final test selected the exact synthetic asset. Fixture draft restoration is separate from the already-passing live authorized upload/read tests.
- **One real native discovery journey passed** in `build/oct4-discovery-native-ui.log`: live account, six selected interests with a seventh disabled, waiting-person grid, visible profile, explicit pending request, cancellation and leave. The peer is a separately authenticated synthetic participant. Three screenshots are in `build/discovery-native-evidence/`. This is not a physical camera test.
- **Eight browser tests passed** (`npm --prefix web test`), including the actual page with delayed media permission, leaving/backgrounding during requests, stale-token errors, lost verification and profile restoration. Computer control additionally exercised live two-account pairing, requests in both directions, acceptance, text in both directions, continuation into Inbox and leaving. Synthetic WebRTC peers decoded 65 frames each; same-host direct success does not establish connectivity on restrictive networks.
- The main web app is published at `https://maroon-social-web.vercel.app`; the pool host is `https://maroon-social-games.vercel.app`. Custom domains are attached in Vercel, and Namecheap records point there. Local Cisco Umbrella interception prevents trusted HTTPS testing of the new `.chat` domain on this network; no certificate warning was bypassed.

Email/TAMU delivery and paid ads remain paused by request. APNs code, sandbox scoping and queue tests are implemented, but Apple’s browser download did not produce the restricted `.p8` key, so no real push delivery is claimed. Direct video has explicit consent and network-failure handling without a paid relay. GPS, physical camera/audio, haptic feel and real-device push remain separate hardware checks.

## Current private media, drafts and publishing evidence

`VideoCompressionTests`, `GroupPhotoServiceTests`, `GroupPhotoCacheTests`, `DurableCompositionsTests`, `AppStoreAccountBoundaryTests` and `ActivityPlansServiceTests` all passed in the 289-test native run. They exercise actual output metadata/thumbnail generation, bounded image preparation, photo authorization invalidation after room/member/account changes, restored media and reply/recipient contexts, partial group creation acknowledgements, stale-account response rejection and weekly-plan/promotion request contracts. The two passing draft UI journeys verify typed recipient/group fields survive explicit save and process relaunch; they do not simulate a successful server invitation.

Live HTTP checks in `build/private-media-e2e.log` used synthetic AVFoundation MP4/JPEG files and verified authorized video/photo upload/read, pending/outsider denial, duplicate-send handling, metadata removal, leave revocation, mute/unmute and photo removal. `build/activity-plans-e2e.log` verifies shared weekly meetings, host-only future cancellation, idempotent verified-organization publication and real poster upload/read/removal. The corresponding rollback SQL suites check private purpose/role/access boundaries. All five synthetic accounts, five recorded closed test rooms and the single synthetic organization were removed with exact resource checks; no real account was modified.

Drafts remain account-scoped, local and excluded from backup. The outbox retains failed messages and retries only after a successful foreground refresh and current room authorization; it does not send while the app is closed. Physical camera import, device playback quality, long-session memory/battery behavior and real push delivery remain outside this evidence.

## Earlier haptic coverage — October 4

The audit's four missing areas now use the existing local haptic preference: matchmaking Find/Cancel and match/practice entry; random-chat Start/End/Next/Again/Retry/Send and deliberate privacy/moderation actions; campus dates/filters/events, save/unsave, Calendar, transit/dining/map actions; and GIF/meme categories, preview/back, attach, retry and clearing recents. Native segmented controls and toggles retain their system feedback. Unchanged selections, typing, pagination, polling, incoming messages and remote matchmaking updates do not emit new custom feedback.

Random-chat send outcomes require the same visible, connected room; campus-event outcomes require the detail content to remain visible. A dismissed event sheet cannot emit a delayed completion pulse. Attachment feedback runs once after the selected media is assigned to the draft, not when merely previewed. Success/error cues follow actual send, save and Calendar results.

The signed build passes in `build/oct4-haptics-coverage-final-build.log`. All **23 focused native tests pass** in `build/oct4-haptics-coverage-native.xcresult`: haptic policy/preferences plus random-chat, campus and matchmaking service regressions. All **six UI journeys pass** in `build/oct4-haptics-coverage-ui.xcresult`: preference persistence, three media-picker journeys, campus filters/transit, and practice-game entry/chess move/undo. The latest build is installed on the three test simulators with their real accounts preserved. Physical vibration strength and feel still require an iPhone; simulator evidence verifies code paths and interaction behavior.

## Haptics, bounded homepage swipes and group redesign — October 4

Major navigation, feed actions, post/group composition, messaging and local game interactions now use one optional semantic haptic service. It defaults on, persists the setting, suppresses inactive-app feedback and coalesces only rapid identical selection/impact events. Typing, data polling, computer chess moves and remote game replay do not trigger feedback. Native controls retain their own system feedback. Guidance: [Apple, Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).

Homepage horizontal gestures switch only New ↔ Hot, without wrapping or leaving Community. The recorded transition moves neighboring feed pages horizontally without a fade. Tab taps remain available; the other root screens retain their existing slides. Group creation now has three custom steps—details, group identity and invitations—with previews, purpose/visibility choices, preserved drafts and retries, and a separate footer. At accessibility sizes, progress and Continue labels remain readable and the full focused editor is repositioned after the keyboard settles.

- **229 native tests passed**, zero failures, in `build/oct4-haptics-native-final.xcresult`, including six haptic policy/preference tests and three new Community gesture tests. An earlier broad run hit a simulator WebKit ScreenTime KVO exception; the complete rerun passed.
- **13 distinct affected UI journeys passed** across `build/oct4-haptics-navigation.xcresult` (three inline-feed checks), `build/oct4-haptics-group.xcresult` (four standard group journeys plus haptic preference persistence), `build/oct4-haptics-final-ui.xcresult` (four navigation journeys), and `build/oct4-group-accessible-final.xcresult` (repaired Accessibility XXXL group journey and standard keyboard recheck). Earlier failures exposed a partially positioned switch tap, oversized accessibility footer, and clipped editor; the corrected checks passed. An earlier interrupted navigation run waited for simulator animation quiescence; its isolated rerun passed with normal timings.
- Manual Simulator review covered all three group steps, live preview text, identity shuffle, software keyboard layout, draft discard, and the haptic preference. `build/oct4-group-redesign-final.png` and `build/oct4-group-invitations-redesign.png` show the redesign. `build/oct4-home-sort-verified.mov` and `build/oct4-home-sort-transition.png` record and sample actual XCTest swipe gestures. Native computer-control dragging sometimes synthesized a tap, so that attempt is not counted as successful swipe evidence.
- Haptic test preferences use a separate local key, preserving the real account's setting. The latest build is installed on iPhone 17 Pro, Phone 2 and iPhone 17 Pro Max. The real Pro Max account retained haptics enabled. Simulator verifies routing and settings, but physical vibration strength and feel require an iPhone.

## Keyboard, motion and profile polish — October 4 (earlier pass)

The screenshot's group footer no longer overlays the invitation editor. Group setup uses a scrolling form with a separate footer, including at accessibility text sizes. Keyboard accessory Done bars are removed; compact keyboard-dismiss controls and interactive dismissal remain. Sending a chat keeps the editor focused and preserves text/media entered while the previous message is sending.

Both words stay white throughout startup loading, with progress drawn underneath. Root tabs use interactive adjacent-page translation. The bottom bar translates vertically, restores when a cached Community view leaves the window, and yields to keyboard/navigation ownership. Search no longer filters a long, scrolled lazy stack into a flexible empty row: the empty state is separate, the expanded header sizes naturally, and search/filter changes reset the result position. The exact collapse → swipe → return → search freeze is covered, including a second search after scrolling restored results.

Pull feedback stays enabled during the request cooldown. The refresh artwork anchors directly below the header, excludes UIKit's native refresh inset, and ignores inherited hosting safe areas. A bounded pull/retraction lifecycle clears the artwork even when UIKit leaves a small negative resting offset. Frame inspection caught both the original 62-point positioning error and a residual logo sliver that endpoint assertions missed.

| Check | Latest evidence |
|---|---|
| Native app | **220 passed**, no failures/skips; `build/oct4-native-complete.xcresult`. Includes real rendered wordmark/refresh pixels, actual tab-bar presentation positions, interrupted motion, keyboard ownership, draft snapshots, personal libraries and notification races. |
| UI journeys | **36 distinct fixture journeys passed across the full run and targeted repairs**. `build/oct4-ui-full.xcresult` initially passed 32 with four failures; `build/oct4-ui-layout-final.xcresult` passes nine affected journeys; `build/oct4-search-recovery.xcresult` passes the repaired scroll/search journey. The final three affected composer, repeated-refresh and focused-search checks also pass in `build/oct4-ui-settled.xcresult`. One opt-in live two-phone group test was skipped in the fixture suite; its separate earlier live evidence is below. Reruns are not added to the distinct total. |
| Core models/rules | **33 passed**; `build/oct4-ui-core-tests.log`. |
| Game rules/physics | **16 passed**; `build/oct4-ui-game-tests.log`. Native game WebView checks and actual pool/pong gesture journeys also passed. |
| Build | Signed simulator test build succeeded in `build/oct4-ui-settling-build.log`. |

Computer control separately walked group setup with the software keyboard, edited the profile username, inspected the notification popover, created and attached a meme draft, and played/undid a local chess move. `build/oct4-group-keyboard-fixed.png` records the corrected invitation layout. XCTest supplied the native short/repeated pull gestures, connected tab swipes, collapse/restore sequence, and pool/pong gestures. Videos and extracted frames under `build/oct4-*motion*`, `build/oct4-search-recovery.mov`, and `build/oct4-refresh-settled.mov` provide visual checks alongside endpoint assertions. Final frame review confirms the refresh logo remains next to the header during both large pulls and retracts completely after each release; `build/oct4-refresh-settled-contact.png` records the sequence.

These checks used iPhone simulators and isolated fixtures. They do not establish physical-device frame rates or hardware keyboard/camera/GPS behavior. Notification backend tests and their cleanup are documented separately below.

## Earlier navigation and loading iteration

### Group setup, invitations and room identities

At that earlier checkpoint, the five-step group flow was shared by Inbox and Explore: purpose, name/description/avatar, discoverability, a separate group alias/avatar, and optional invitations by account username. Public groups remain campus groups; private groups are hidden from Explore. No contacts or phone-number permission is requested. That checkpoint used eight preset icons; uploaded group covers and room photo avatars were added later, with current evidence listed above.

The native group checks passed **20 cases** (community service, form rules, scoped game recipients and Inbox counts) in `build/oct4-groups-tests.log`. All **three fixture UI journeys** passed across that log and `build/oct4-group-completion-tests.log`; the public-flow test needed an input-selection correction before passing. They exercise public/private setup, back-navigation draft retention, nickname and invite-code validation, invitation skipping, and truthful unavailable-service errors. The completion log also passes five refresh-work cases, including a post-mutation snapshot starting after any older request and cancellation of a waiting caller. MaroonCore passed **33 tests**, including two backward-compatible group-message decoding cases (`build/oct4-core-tests.log`).

Three opt-in native stages passed against the actual backend on the two named test simulators (`build/group-live-create.log`, `build/group-live-accept.log`, `build/group-live-verify.log`). The first account created a private group and invited the second by account username. The recipient found it in Requests, could not see history or the composer before acceptance, received a duplicate-alias error, chose a different alias/avatar, and exchanged messages with the owner. The owner then saw both room aliases in settings without either account username. The exact temporary room and its two messages were removed afterward; both accounts and all other rooms were retained (`build/native-group-cleanup-receipt.json`). Computer control separately walked all five setup steps, typed a draft, changed visibility and shuffled the identity, then discarded that draft.

Backend checks passed three transactional security scripts plus live group-identity, communities, group-games and broad social regression suites. They cover pending-invite privacy, unique aliases, private media, typing, games, moderation, ownership transfer, revocation, cooldowns and scoped exports. See `tools/test-group-identities.py`, `tools/test-group-identities-security.sql`, `tools/test-communities-security.sql` and `tools/test-group-games-security.sql`. Synthetic receipts were cleaned and the security advisor returned zero findings. This is functional/security evidence, not a campus-scale load test.

Final review repaired two recovery paths: a saved group waits for a fresh accepted-membership snapshot before navigating, and a failed refresh leaves an Open group retry plus a Close escape without recreating the group or resending successful invitations. Detail polling pauses during moderation confirmation/actions so an in-flight read cannot silently swallow a confirmed action. The final signed build passed in `build/oct4-groups-final-build.log`.

### Earlier behavior: complete wordmark, silent refresh blocking and inbox rows

This subsection records the earlier implementation and its checks. This was superseded by the current full-letter maroon fill described at the top of this document; request throttling remains separate from visual feedback.

The follow-up covers **26 distinct native cases** across `build/oct4-loading-tests.log` and `build/oct4-refresh-inbox-tests.log`: two real rendered-wordmark tests, six native refresh-control cases, five gate cases, three request/pull-presentation cases, five startup timing cases and five native tab-bar ownership cases. The first run caught SwiftUI cancelling the native refresh action during a state update and clipping fast fills. The refresh now owns its work until completion or actual disappearance; all six native refresh cases passed after repair. Pixel checks independently compare the bundled artwork's left and right glyph regions, proving both words are present on the first white frame, fully maroon after filling, and white after completion.

Three UI journeys passed in `build/oct4-refresh-inbox-tests.log`: the real pull gesture preserves the feed/composer, the full scroll-collapse/restore/tab-swipe sequence keeps navigation usable, and incoming anonymous requests use the latest message as their row text while retaining separate request counts. Native cases also prove that partial pulls reveal the artwork from the first pixels, long pulls keep it near the header, cooldown disables the control without another request, and restoring a hidden tab bar requests one animated upward transition. Fast results wait only for the requested complete fill and settling fade; network work starts immediately. Reduce Motion bypasses the animation wait.

Phone 2's cached launch image already contained both words. The final computer-control check reproduced a stale, clipped launch snapshot on the primary simulator despite the corrected bundled artwork. The launch storyboard is now `CommunityLaunch`; the primary's derived SplashBoard snapshot was backed up and regenerated with a targeted simulator restart. Both final cached launch images were decoded and visually verified with the complete wordmark (`build/primary-launch-regenerated-0.png`, `build/phone2-launch-cache-final-4.png`). No account or document data was cleared. Both final installed apps were launched and checked using computer control; native simulator tests provide the gesture evidence.

### Media, post features and matchmaking follow-up

The focused follow-up covers **26 distinct native cases** across `build/final-social-tests.log` and `build/social-repair-tests.log`: six matchmaking, three actual native refresh, nine compression/playback, five server-tag integration, two post/poll persistence, and one actual two-WebView video test. Initial media fixture assumptions and a fractional-time fixture comparison were corrected; all native cases passed on their final relevant run. Independent review also found and repaired zero-delay GIF sampling and stale overlapping-tag presentation; regressions exercise both defects. The nine UI journeys in the first log all passed, covering KLIPY, inline composition, polling, tags and scrolling. Affected tag/GIF journeys passed again in the repair run; both preview journeys passed after the final layout correction (`build/klipy-preview-layout-tests.log`). Earlier focused KLIPY service/thumbnail/ad checks, refresh gate/waiter checks, 31 Core tests, 16 game rules tests and two local gesture journeys have separate logs and are not added to this count. The final signed build was installed and launched on both named test simulators; their existing user accounts were retained.

The Community wordmark is centered independently of the side buttons. Its clipped vertical translation follows pull distance continuously, including quarter and half pulls; it does not toggle opacity at a threshold. The native refresh artwork animates while awaiting the actual social request, including joining an already-running request. A shared single-flight gate rejects duplicate refreshes and imposes a ten-second cooldown. Native lifecycle checks exercise real SwiftUI refresh controls and confirm the original scroll delegate remains attached. The idle-control geometry regression that could leave the header hidden after release was reproduced and repaired.

KLIPY now uses a black two-column masonry picker with natural media proportions, compact search, Memes/GIFs/Recents, provider ad boundaries, a separate preview and explicit attachment. The grid loads bounded first-frame thumbnails; animation runs in the selected preview. Recents contain at most 30 validated references, not image bytes or community identity. Real provider results, a test advertisement and a downloaded meme preview were inspected using computer control. That final live inspection caught a large blank area above the preview title: the preview now uses a native navigation header, a bottom attachment inset and an explicitly sized image viewport. A UI regression checks that the back control stays near the sheet top. Fixture UI checks cover search/category transitions, preview/back/attach, recents, and preservation of the inline draft.

Polls, links and tags are connected through the native composer, canonical post projection and deployed gateway. Poll votes are one per member and can change before the server deadline. Tag browsing queries up to 100 matching visible posts, including posts older than the newest 150-post feed, without expanding the main feed. Active navigation scopes retain canonical state when opening a post or nested tag. SQL rollback checks and live three-client tests cover validation, expiry, idempotency, concurrent vote changes, adult-community separation and blocked/hidden/deleted content. See `tools/test-post-extras.py`, `tools/test-post-extras-security.sql` and `tools/test-tagged-posts-security.sql`.

The main game buttons now open a live player-search lobby; pass-and-play is under an explicit practice action. Two existing simulator accounts matched through the app's live queue. Phone 2 initially showed Waiting for opponent with shooting disabled; after Phone 1's shot, the same canonical table appeared on Phone 2 with Your turn and shooting enabled. Independent API tests exercise pool, cup pong and chess with wrong-seat rejection, shared replay/state, resume, cancellation races, blocked-player exclusion and concurrent unique pairing. SQL checks validate private queue access and cleanup. See `tools/test-game-matchmaking.py` and `tools/test-game-matchmaking-security.sql`.

The linked open-source projects were reviewed; no code or assets were copied from them. The rationale and existing physics engines are documented in `games/README.md`. This iteration repairs game entry and multiplayer ownership; it does not claim a native Swift physics rewrite.

User photo/GIF preparation now runs off the main thread, removes source metadata, accepts originals up to 30 MB and retains a 5 MB output ceiling. Photos aim for 350 KB with bounded dimensions and a readability floor. GIF sampling retains the full timeline and both endpoints within 80 frames and a 12-million-decoded-pixel budget. Live WebRTC capture and sender encoding use lower bounded settings; two actual bundled WebViews exchanged synthetic decoded video and retained the configured sender limits. At that checkpoint there was no recorded-video attachment flow. The later MP4 importer/transcoder and real Photos-picker/playback journey are covered above; neither pass is a physical camera test.

Focused checks passed **12 native tests and 9 UI journeys** across `build/oct3-chrome-tests.log` and `build/oct3-chrome-final-tests.log`. These cover the native animated tab-bar ownership, scroll-direction state, branded native async refresh, all five tab swipes, removal of duplicate root headings, pushed-screen back navigation, short-feed bounce, the full collapse/restore cycle, the persistent composer, Inbox drafts, and post/reply input. The first pass exposed a too-small composer touch target and an unattached-refresh-control test assumption; the composer now has a full 48-point hit area, and both affected UI checks plus the native refresh tests passed on rerun.

The top feed header remains mounted and slides through a clipped, animated height. The bottom bar uses UIKit's public animated visibility API. A list that would fit after hiding the bars does not collapse, avoiding an offset-to-zero/reopen loop. Reduce Motion disables the slide. Automated tests verify endpoints and ownership, not frame-rate smoothness.

Launch and runtime startup now use the same vector artwork, dark background, safe-area center, 24-point gap, and “Loading your community…” text. The vector was rasterized and visually inspected; this caught and repaired a CoreText pen-position error that had clipped the second word. Every existing pull-to-refresh uses the branded native control. The final asset build passed (`build/oct3-chrome-final-build.log`) and was installed on both simulators. Computer control visually checked the clean Classes, Explore, Campus and Inbox roots with their functional controls retained.

## Earlier integrated test-run status

The integrated simulator run and focused repairs now cover **123 distinct native tests and all 25 UI journeys passing**. The initial UI run passed 21/25; repairs were rerun against the changed code. A subsequent live KLIPY check exposed a blocked initial ad-document load. The repair passed an actual WKWebView regression and a final computer-control check rendered the provider’s yellow “Test Advertisement” banner inside the results.
| Check | Recorded result | Evidence / qualification |
|---|---|---|
| MaroonCore | **25 passed** | `build/oct3-core-final.log`; models, backward-compatible comment decoding and local game rules. |
| Native app tests | **123 distinct tests passed across integrated and focused runs** | `build/oct3-integrated-tests.log` passed 120; focused runs add fast-scroll and actual toolbar-layout correction regressions. All five feed-state tests pass. `build/klipy-wk-tests.log` adds actual ad-document rendering/reuse/redirect validation and reruns six Klipy service tests. |
| UI journeys | **25 distinct journeys passed across integrated and focused runs** | Integrated run, `build/oct3-focused-repairs.log`, `build/feed-collapse-final.log` and `build/klipy-wk-tests.log`; isolated fixture accounts. |
| Physics rules 2.1 | **16 passed** | `npm test --prefix games`; revised rolling deceleration, break energy, tapered cup geometry and authoritative replay. |
| Calendar import / retention worker | **11 + 9 passed** | Deno tests for official calendar parsing and bounded deletion/acknowledgment, including failures. |

Distinct totals do not double-count reruns. The initial failures were an outer-row consent tap, a missing Keep editing action, inherited reply identifiers, and a real collapse/restore loop caused by toolbar layout corrections. The recorded offset trace now has a model regression, and the native UI collapse/restore/tab-swipe journey passed after repair. Earlier test counts describe older builds and are not added to these totals. Native game tests execute the bundled WebViews; this is distinct from physical playtesting or real camera/GPS testing.

## Manual checks on two iPhone simulators

Two independently running app instances exercised the deployed service with separate accounts. This was actual app-to-backend-to-app interaction, not fixture insertion:

- A post appeared on the second device; its vote and reply reached the first.
- A post-origin anonymous DM request was accepted, then text traveled in both directions while the conversation retained anonymous identity.
- A private image was uploaded and rendered on both devices.
- An online 8-ball invitation was sent and accepted; both clients displayed the match and successive server-authoritative turns.
- An activity was created through the native form, joined from the second account, and its roster updated to two people. A group message reached Phone 2, whose reply then appeared in the first phone’s inbox with an unread badge.
- A named friend request was received and accepted; the connected account appeared in the recipient’s list.
- The native private-data export completed through the iOS Files save sheet.
- The real Transit Gameday Bus Service event (`377073-1791003600`) reproduced a server save failure. After fixing the SQL alias collision, native Save event changed to Saved successfully.
- A private Tag lobby was created and joined; both players chose roles and consented, the host started, timers advanced, coarse hints and lobby messages appeared, and mutual catch confirmation produced the result and location cleanup.

Computer control opened a live campus event, followed its official-calendar link, added it through EventKit, acknowledged the success alert, and visually confirmed that the disabled “Added to iPhone Calendar” button retained its outline on both simulators. Save and official-source actions also kept their borders. The final Phone 2 screenshot is `build/verified-calendar-outline.png`. Both simulators have the updated build.

The current Phone 2 computer-control check also searched live KLIPY for “aggies,” downloaded a real meme preview, attached it to the inline draft, typed into the actual editor, verified maroon privacy switches, and discarded that temporary draft without posting.

These checks used simulators and synthetic Tag coordinates. They do not prove physical GPS, compass, camera or microphone quality. The stationary-coordinate check exposed a refresh defect: movement filtering and automatic location pausing allowed a hider’s fix to expire. The updated implementation disables that filtering during active play and requests a genuine one-shot fix through a separate manager when needed; it never changes an old `CLLocation` timestamp. Three passing fake-manager tests cover refresh throttling, stale/late callbacks, and stopping both location sources on revocation. The rebuilt native app then passed a 115+ second stationary regression with a separate synthetic API participant: coarse hints remained fresh after 90 seconds, with no simulated movement (`build/oct3-stationary-tag.log`). Ending the round returned the native app to the lobby screen, and the simulated location was cleared. This is native-to-backend evidence, not a physical GPS claim.

Earlier hands-on random-chat checks confirmed keyboard typing, a message and reply with an independent live test guest, Next ending the prior room on both sides, and Cancel leaving the queue. Those checks are distinct from the current fixture UI suite.

## Native and UI coverage

The current 120-test native run includes:

- AppStore persistence and isolated test files; course-room repair; leaving/rejoining and host cancellation; full/expired activity guards; accepted requests; image decode and payload limits; write-failure rollback; saved posts, votes, reports and username validation.
- Random-chat credential expiry versus suspension, delayed responses after leaving, idempotent retry, consent, secure-storage failure, and immediate media teardown during delayed safety operations.
- Accepted-DM call consent, delayed invite/media responses, background teardown and membership revocation.
- Tag creation nonce reuse after an unknown outcome, nonce rotation after an acknowledged lobby, background cleanup of a delayed creation, and consent/revocation without starting location in a lobby.
- Actual bundled game WebViews: real WebGL initialization, a pool break, a scored pong throw, non-scoring replay, online input messages/canonical state, opponent-turn disabling and phone-size layout checks.
- Two actual bundled WebRTC WebViews exchanging and decoding generated canvas video, then stopping all tracks. This test does not mock `RTCPeerConnection` and does not open a camera.

The 120-test run additionally covers seven comment-thread cases (including orphan/cycle/deep chains), reply vote/karma persistence, anonymous request scope, official course catalog validation, seven semester-calendar cases plus cache expiry, community request/response validation, Klipy URL/media rules, unread bucket counts, scroll-chrome decisions and swipe exclusions.

The expanded native run also passed checks for export page assembly/partial failure/private-list revocation; stationary GPS refresh; real JPEG meme rendering, bounded dimensions, orientation and metadata removal; disabled mail provider, wrong-code state, delayed cancellation and local expiry; and lost account-deletion acknowledgements, safe retry/relaunch, suspension, persisted intent and concurrent requests.

The revised UI tests use an **isolated fixture account**. They check onboarding validation/relaunch, post-editor and reply input, community search/saved-empty state, class search/add-course draft, activity-form validation, incoming-request privacy/new-message draft, Campus date/saved/transit search, local chess moves/undo, pool/pong controls/replay, and the meme composer journey. A local fixture publication is not evidence of network delivery. These tests do not join live random or Tag sessions or activate location capture.

## Profile, collections and notification backend

Verified October 4, 2026 against the configured development project `myxbghfbapbfffkpndwo`. Migration [`20261004062228_activity_notifications_library.sql`](supabase/migrations/20261004062228_activity_notifications_library.sql) was applied, and the `social` Edge Function was redeployed with authenticated routing for `library`, `notifications`, `notification.read` and `notifications.read_all`. The public app key cannot directly access the private tables/RPC; account credentials still determine the caller.

[`tools/test-activity-notifications-security.sql`](tools/test-activity-notifications-security.sql) passed its final transactional run. It verifies private comment and parent-reply delivery, self-notification suppression, anonymous identity projection, foreign-read rejection, caller-bound read-all, deduplicated first/ten-upvote milestones, block/deletion filtering, collections beyond the latest 150-post feed, 50-entry pagination, direct-post access, and account cleanup. A directly inserted 200-plus-reply fixture verifies that the own-comment query is independent of the regular thread projection; it does not change the public endpoint's existing 200-reply cap. Earlier test fixture errors (an overlength synthetic username and attempting to create that oversized thread through the capped public action) were corrected before the final pass.

Owner announcement publication, separate recipient read receipts and withdrawal were checked inside that same rolled-back transaction. No test announcement was committed or published to app members. Privilege assertions deny ordinary client roles the activity tables/RPC and deny the Edge service role announcement publication and the operator function. The post-migration Supabase security advisor returned an empty findings list. These are scoped authorization checks, not an independent penetration or load test.

[`tools/test-activity-notifications.py`](tools/test-activity-notifications.py) then passed through the deployed HTTP gateway using two disposable accounts. Its recorded checkpoints were:

```text
PASS live anonymous comment notification, authenticated access and private read receipt
PASS live upvote milestone without duplicate notifications after a vote toggle
PASS live My posts, My comments, Saved posts and direct notification post destination
PASS live deletion and block revocation across notifications and collections
Synthetic accounts deleted; exact generated post IDs retained for bounded tombstone cleanup.
```

Cleanup evidence: the script deleted both synthetic accounts in `finally`. Its private receipt, `/tmp/maroon-activity-test-resources.json`, recorded the sole created post `b18d03b8-e1ea-4b32-a8ec-1fc75fb68f35`. A subsequent scoped SQL cleanup required that exact ID, a null author and the deleted flag; it returned exactly that one tombstone. No other account/post or user-created content was removed. SQL security fixtures, including announcements and their operator audit rows, were rolled back. The CLI announcement-publish command was also exercised in SQL-printing mode only, without `--execute`.

The implementation shows up to 100 current inbox items and a separate unread count. Acknowledgement affects the displayed IDs, so a concurrently arriving item remains unread. New comment/reply events and milestones are recorded from this deployment onward; historical activity is not backfilled. Supported milestones are 1, 10, 25, 50, 100, 250, 500 and 1,000 positive post score; announcements expire after 90 days. This is a foreground inbox, with no APNs/background-delivery evidence. Native rendering/navigation tests and simulator checks are recorded separately; protocol passes alone do not establish that every UI animation or physical-device interaction passed.

## Live backend and security evidence

The latest live additions also passed independently of the local UI fixtures:

- `tools/test-comment-votes.py` and its rollback security SQL: nested reply parent integrity, reply votes, private karma, anonymous contextual requests, outsider rejection and cleanup.
- `tools/test-course-catalog.py` plus catalog/lifecycle rollback SQL: 10,182 official codes, lazy room creation, aggregate activity only, server clock, future-term denial, immediate closing/read/export guards, calendar-month retention and queued media deletion.
- `tools/test-communities.py` and security SQL: discoverable/private communities, invite consent, membership/capacity/owner rules, ban enforcement and scoped export. Group-game scripts passed selected-opponent and observer restrictions.
- `tools/test-klipy.py`: real trending/search GIFs and meme search with the locally configured key, bounded actual PNG/GIF loads, server reference authorization and cleanup. The initial API exercise returned **zero ads**. The later live Phone 2 picker returned provider ad placements; their initially blocked document load was fixed. A yellow provider “Test Advertisement” then rendered correctly in the scrolling results. No ad was clicked; paid ad fill and earnings remain unverified. The Settings placement preview is explicitly sample content, with no AdMob SDK or revenue.
- Supabase Auth: 12 adapter mock checks and a two-account signed-JWT exercise passed, including refresh, revocation and account deletion. Real email delivery remains disabled and untested.

| Suite | Verified behavior | Limits |
|---|---|---|
| [Social API](tools/test-social.py) | Independent accounts, shared posts/replies/votes, private bookmarks, one course room, nonce integrity, outsider denial, anonymous DM acceptance, real sanitized image/GIF upload/read, one attachment, capacity/waitlists/approval, group invitation/transfer/removal, organization publishing gates, reports/blocks and account deletion. | Synthetic accounts; no load or staffed-moderation guarantee. |
| [Campus actions SQL](tools/test-campus-social.sql) | Real Edge save/duplicate-save/unsave/duplicate-unsave passed for the reported event. Rollback SQL covers private bookmarks, aged-out unsave, canonical sports rooms, and future/cancelled/ended/non-sports rejection. | Native Save event was separately confirmed after deployment; Calendar export remains a separate OS operation. |
| [Social SQL security](tools/test-social-security.sql) | Rollback-only checks of organization authority/byline privacy, suspension, room access and private-schema permissions. Rerun after authentication-helper changes. | Transactional authorization tests, not a broad external penetration test. |
| [Authoritative games](tools/test-games.py) and [anonymous games](tools/test-games-anonymous.py) | Invitation/acceptance gates, outsider/wrong-turn rejection, invalid inputs, concurrent turn compare-and-swap, matching canonical state/replay, nonce retries, persistence, resignation, block revocation and anonymous player aliases. | Deterministic pinned rules and synthetic participants; no real-time tournament or cross-platform physics certification. |
| [Physics engine tests](games/README.md) | Actual Matter.js/cannon-es/chess.js rules, collision/replay behavior, foul/ball-in-hand cases, cup reachability and wins, hostile input, source/bundled-engine consistency. | Native gesture and visual testing remains separate. |
| [Multiplayer Tag](tools/test-tag.py) | Two clients create/join, roles/readiness/consent, server hiding timer, coarse hints, team-chat privacy, idempotent messages, invalid catch rejection, decline/confirm, completion, report/block and blocked rejoin. | Only synthetic coordinates; no user’s precise location uploaded by this script. |
| [Tag privacy SQL](tools/test-tag-privacy.sql) | Rollback-only checks for suspended/caught cached-hint removal, immediate suspended-position purge, stale-coordinate expiry while remaining teams play, and abandoned-match cleanup. | Server retention logic, not proof of physical sensor behavior or backup deletion. |
| [Account controls](tools/test-account-controls.py) | Three accounts; explicit named consent, recipient-only acceptance, idempotency, private lists, context-safe anonymous block labels, owner-only unblock, connection revocation/cooldown and self-only export. | JSON export deliberately excludes peer messages, binary media, credentials, verifier hashes and precise positions. |
| [Export security SQL](tools/test-account-controls-security.sql) | A 205-record paginated export and no current private-room title leakage after removal; all fixture writes rolled back. | Not a large-account performance benchmark. |
| [Mailbox security SQL](tools/test-verification-security.sql) | Synthetic challenge hashes, exact domain, sent-only/account binding, five-guess limit, resend cooldown, expiry/replay, valid grants/expiry, optional content gate and deletion. | No real email was sent or real account verified. Sending and required-membership enforcement remain disabled pending owner setup. |
| [Random chat](tools/test-random-chat.py) and [security SQL](tools/test-random-chat-security.sql) | Real matching/messages, duplicate protection, outsider denial, quotas, Next/End/block/report, media consent, participant-only signals, stale screen/session cleanup. | Separate guest identities are not TAMU enrollment verification or ban persistence across new identities. |
| [Accepted calls](tools/test-room-calls.py) and [security SQL](tools/test-room-calls-security.sql) | Recipient acceptance, participant-only signaling and End revocation; synthetic peers decoded 62/63 frames over about 2.1 seconds and exchanged eight ICE candidates. | Same host/network, no physical capture or all-network relay proof. |
| [Random WebRTC](tools/test-webrtc.py) | SDP/ICE through the deployed gateway; two peers each decoded 65 changing synthetic frames over 2.13 seconds, with a data-channel echo. | Same host/network. See [setup and limits](tools/WEBRTC-TESTING.md). |

The JavaScript bridge lifecycle suite additionally checks explicit direct-mode consent, relay configuration, denied media, late permission cleanup, stale offer suppression, ICE ordering and reset presentation with mocks. This supplements the real WebRTC tests.

The owner-only moderation workflow was checked with transactional fixtures: report/organization review, audit records and suspension are not callable by ordinary app accounts or the Edge service role. Most recent Supabase **security** advisor checks returned zero findings. Direct `anon`/`authenticated` execution of account-controls RPC and reads of private block-label data are denied. These point-in-time checks are not a substitute for launch security/load testing.

Campus verification separately confirmed the shared event cache and actual official route/stop responses. Native transit search has an always-visible field and a cached fallback. Structured dining requests return HTTP 403; dining and live bus/departure views therefore link to official pages instead of fabricating data. Live scores remain dependent on an approved source.

## Reproduce

```sh
swift test --package-path MaroonCore
npm test --prefix games
xcodegen generate
xcodebuild -project MaroonSocial.xcodeproj -scheme MaroonSocial \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- test
node tools/test-video-bridge.mjs
python3 tools/test-social.py
python3 tools/test-games.py
python3 tools/test-games-anonymous.py
python3 tools/test-tag.py
python3 tools/test-account-controls.py
python3 tools/test-activity-notifications.py
python3 tools/test-random-chat.py
python3 tools/test-course-catalog.py
python3 tools/test-comment-votes.py
python3 tools/test-communities.py
python3 tools/test-group-identities.py
python3 tools/test-group-games.py
python3 tools/test-klipy.py
deno test --allow-read supabase/functions/_shared/course-calendar_test.ts
deno test supabase/functions/_shared/course-retention_test.ts
```

Run the SQL security scripts through an authorized database connector; their synthetic checks use transactions and rollback. WebRTC Python tests require the optional `aiortc` environment documented in [WEBRTC-TESTING](tools/WEBRTC-TESTING.md). Run live matching tests serially so two test runs cannot match each other’s guests. Only use the configured project you operate.

Keep simulator code signing enabled. Normal ad-hoc signing supports Keychain; an unsigned simulator binary can fail secure credential storage. Do not add service-role keys, SMTP credentials or TURN secrets to the public `Backend.json`.

UI tests use `preview-state-ui-tests.json`, separate from the user’s local state. `--uitesting` resets only fixtures; `--uitesting-preserve` verifies a fixture relaunch. Native AppStore tests use temporary directories. Live scripts close sessions/delete synthetic accounts in cleanup where supported; some tombstoned content or reports can remain under normal retention. Use their exact fixture receipts for scoped operator cleanup, not broad deletes. SQL rollback suites leave no committed fixtures.

## Defects reproduced and repaired

Simulator showed a post cursor but accepted no Mac keyboard input. Reconnecting the hardware keyboard and toggling the software keyboard restored input, including after restart. Cream form/list/launch backgrounds and visible transit search removed several blank/white-looking states. Leaving an unavailable conversation now has a useful state. Native tests caught a Swift exclusive-access crash while leaving an activity; the mutation now snapshots the username first. Game QA caught a clipped pool table, leading to a complete adaptive viewport and actual physics controls.

The current iteration also repaired stale Tag hint exposure after catches/suspension, delayed lobby cleanup, nonce reuse after a successful lobby was left, and the stationary-location refresh issue described above. Account export review found and masked current titles of private rooms the exporter had left. The meme UI regression uncovered three separate defects: Form row actions competed with the meme button, attachment previews retained a 1,200-pixel intrinsic size, and iOS 26 confirmation popovers omitted the Keep editing control. Explicit button styles, constrained media sizing, and a native alert repaired the journey; all three affected focused UI tests passed. The latest inline composer, inherited reply identifiers, toolbar-collapse correction and KLIPY WebView repairs have their focused passing evidence listed above.

## Remaining validation and external dependencies

- Physical camera/microphone permissions and quality, audio routing, GPS/compass drift, battery behavior, lock screen/force quit, Calendar accounts and accessibility at large text sizes need physical-device checks. The paired iPhone was unavailable earlier; this iteration uses simulators.
- No working TURN provider is configured. Direct calls require explicit consent because a peer may learn a network address and restrictive networks can fail. The public Open Relay static endpoint timed out and was not enabled as a pretend fallback.
- Supabase Auth email-code screens, Keychain storage, refresh/recovery and logout are implemented, but owner-controlled sender/provider configuration and a delivered-email test remain required; the delivery gate is off. Mailbox ownership does not establish current enrollment or strong age verification. The proposed blind/unlinkable membership design remains separate unfinished work.
- APNs signing-key installation and physical background-delivery validation remain blocked; the sandbox-only worker, private queue and native routing are implemented. Incoming-call OS integration and permitted structured dining data remain absent. Official sports scores, tracker links and matched Kalshi market prices are implemented, but licensed in-app ball coordinates and a calibrated winning-probability model are not. Owner review tooling still requires an actual review process and retention/appeal decisions.
- Concurrent campus-scale traffic, adverse-network recovery, cost ceilings, distribution signing and independent security review remain release work. Current simulator screenshots and controls have been inspected; physical-device and adverse-network validation remain separate.
