# MaroonSocial — HideZone, key-based accounts, and random-chat distribution

> **October 1, 2026 implementation update:** Coding is now authorized. The user selected SwiftUI, iPhone first, and connected Supabase **Maroon Social** plus GitHub **VishalKothuri/MaroonSocial**. Mascot work is paused. This document preserves the earlier research/proposals; its older no-code statements are historical. See [README](README.md) for tested implementation status and remaining work.

September 29, 2026. This update incorporates your answers. Research and visual design only. Your latest message explicitly confirms NO CODE.

## Confirmed direction

- TAMU email eligibility. Exact @tamu.edu versus explicitly approved subdomains still needs confirmation; no arbitrary .edu access.
- Anonymity should extend to the operator, with bans resistant to creating another account. This is the requested goal, not a guarantee already achieved.
- One unified username across named sections, including ordinary class chat, study groups, recreation, and tag. This replaces the separate section usernames.
- One unified course chat per semester, such as CHEM 107 for the chosen term, without professor/section subdivision for now.
- 18+ access.
- Random matching remains essential. Distribution must accommodate the actual behavior; interest-based introductions are not a replacement.
- HideZone is the specific IRL game reference. Tag is the immediate focus; broader account/eligibility binding can be deferred in the tag design, but must be resolved before claiming a public release is TAMU-only or ban-resistant.

The original optional anonymous community posting remains the prior requirement. Your phrase “one unified username for everything” could change that; a narrow clarification is pending. Named posts should use the unified username, while any retained anonymous mode must not reveal it automatically.

## HideZone: verified reference

I opened the supplied App Store page and inspected its four published screenshots. They show dark radar/map gameplay, a prominent timer/range, an item shop, mode/settings selection, and team chat. The description advertises private lobby IDs, GPS play, a shrinking-zone hide-and-seek mode, multiple other modes, and items including scanning, decoys, and temporary concealment. It says no signup is required and advertises deletion of location data at match end. These are storefront observations and developer claims, not independent gameplay tests. [HideZone App Store page](https://apps.apple.com/us/app/hidezone-gps-hide-seek/id6759913726).

The privacy policy is more precise: a properly ended game deletes location/chat/game state, while abandoned lobbies are cleaned later. Anonymous identifiers and some diagnostic/analytics records can outlast a match. It identifies Firebase services, AdMob, and RevenueCat. Consequently “no account signup” should not be read as “no persistent identifiers.” We should define our own retention and SDK choices. [HideZone privacy policy, updated August 28, 2026](https://dramiley.dev/privacy).

I also searched the Mobbin MCP for HideZone. The returned flows were Yubo and Bump, not HideZone; I did not treat them as HideZone evidence. Earlier Yik Yak research did use the Mobbin MCP directly. A Mobbin search miss does not prove the app is absent from its entire library.

## Proposed tag scope to review

Design one good campus hide-and-seek mode first. HideZone's multi-mode catalog is a reference, not an instruction to copy every mechanic, asset, or rule.

| Element | Proposed first version | Still to choose |
|---|---|---|
| Entry | Create private lobby or join with lobby code | Whether strangers may discover open lobbies |
| Identity | Unified MaroonSocial username in lobby and match | Any exception for anonymous community content |
| Arena | A selected, permitted public outdoor campus area | Which areas and who approves/maintains boundaries |
| Teams | Hiders and seekers, ready check, hiding countdown | Team balance and role selection |
| Main view | Radar/directional hint plus boundary map and timer | Compass-only, radar, or both |
| Hints | Periodic permitted hints with accuracy/freshness | Interval, precision, and whether reveals are team-wide |
| Catch | Server-validated encounter confirmation | Rotating code, QR, or mutual confirmation |
| Items | Model an optional slot for scanner/decoy later | Which item, if any, belongs in first release |
| Zone | Fixed approved boundary first | Whether to add shrinking zones after field tests |
| Communication | Lobby/team text chat | Voice remains optional and separately budgeted |
| Ending | Results, rematch, stop location, cleanup | Duration, scoring, and tie/disconnect rules |

These are proposals. No numeric game presets, shrinking-zone rule, catch method, or platform has been silently selected.

The shrinking-circle mechanic needs special treatment on campus: a circle can move through roads, restricted buildings, construction, or inaccessible ground. A later shrinking mode should shrink through approved walkable areas rather than blindly moving a radius. Hints should not direct a player into an excluded area. A GPS location is not sufficient evidence that a person was caught.

### Screen and button flow

| Screen | Main content | Buttons and transitions |
|---|---|---|
| Tag home | Create / Join code, upcoming joined games | Create → setup; Join → code sheet → lobby |
| Setup | Arena, teams, duration, reveal rules, capacity | Preview → map/rules; Create → lobby; Cancel → home |
| Lobby | Username roster, invite code, rules, connection state | Share invitation, Ready, Leave; host Start after readiness checks |
| Location consent | Who sees what during play, background behavior, stop control | Enable → OS prompt → lobby; Decline → leave or spectator only if later approved |
| Hide countdown | Role, time before seeking, boundary, sharing state | Map, Team chat, Leave |
| Seeker play | Direction/radar, distance band, freshness, timer | Map, Team chat, Confirm catch, Leave, Report |
| Hider play | Timer, next reveal, sharing indicator | Map, Team chat, encounter confirmation, Leave |
| Catch flow | Encounter proof and server decision | Confirm or Cancel; disputed/stale attempts do not auto-eliminate |
| Interrupted play | Connection/permission/location accuracy issue | Retry, relevant settings, Leave; no pretend live coordinates |
| Results | Outcome, participants, rematch | Rematch → fresh lobby/consent; Done → home; Report |

Proposed gameplay layout:

    ‹ Match                  08:42 remaining       Leave
    @unifiedname · Seeker       Location sharing: active
    --------------------------------------------------
                   [RADAR / DIRECTION]
                     NE · 100–200 m
                 Hint age: 18 seconds
    --------------------------------------------------
    [Boundary map]                    [Team chat]
    Next reveal: 00:12
    [Confirm catch]                   [Report / Help]

Numbers are illustrative labels only. Use maroon branding and a high-contrast, daylight-readable view rather than copying HideZone's visual assets. Leave must remain reachable with one hand.

### Architecture that lets binding wait

The tag engine accepts an opaque player ID, display username, and a server-authorized match membership. It does not accept or need an email, wallet seed, personal-email address, or full account profile. Later, the membership service determines which players are eligible. This is a responsibility boundary, not permission to ship an unrestricted public product.

Keep authoritative match state, hint generation, catch validation, and clock transitions on the server. Deliver only the permitted information for that player's role. Separate temporary precise locations from durable scores. A client hiding coordinates visually is insufficient if those coordinates still arrive over the network.

Proposed state progression: lobby → ready → hiding → seeking → completed, with cancelled/interrupted branches. Store a match version and server deadlines. Reject stale commands, repeated catches, expired memberships, and state-changing actions from a removed player. Host disconnect must not stop a server timer; host-transfer behavior is a separate rule.

Location consent, approximate/precise permission, locked screen, app termination, GPS drift, compass calibration, power restrictions, and bad cellular coverage require real-device field testing. Expo development builds can access native location capabilities, but they do not remove OS restrictions. [Expo location documentation](https://docs.expo.dev/versions/latest/sdk/location/).

Cleanup must cover normal finish, leave, force-quit, abandoned lobbies, and server recovery after outages. A retention timer must exist independently of a client sending an “end game” request. Match deletion must not falsely promise deletion of separately retained report evidence; report evidence should avoid precise trails unless necessary under the adopted policy.

## Your crypto analogy: the part that works

A user can possess a private key and prove ownership by signing a fresh challenge. The server verifies with a public key and does not need the private key. Standard public-key authentication already does this; no cryptocurrency, blockchain, gas fees, or real crypto wallet is required. Passkeys are a practical authentication option, but are not themselves an anonymous eligibility credential. [W3C WebAuthn](https://www.w3.org/TR/webauthn-2/).

Do not use a user's financial-wallet seed. A dedicated app key avoids linking campus activity to a financial address. Private keys must be securely generated and protected; properly implemented public-key cryptography is designed to make deriving the private key from the public key computationally infeasible, not mathematically “impossible.”

**The limitation:** anyone can generate another key pair. Banning an account/public key does not prevent the same person registering a new one. That is an eligibility/duplicate-enrollment problem, separate from authentication.

### Candidate privacy-preserving ban design

This is an architecture for expert evaluation, not an invented protocol to implement directly:

1. **Enrollment authority:** verify control of the permitted TAMU mailbox; if true student-only membership is required, verify affiliation too. Keep a protected uniqueness record so the same eligible identity cannot receive unrelated new membership credentials. Delete raw school email after its configured verification lifetime, including assessed processor handling.
2. **Membership credential:** issue one audited credential for a client-held membership secret, using a scheme that hides the relationship between enrollment and its later app presentation.
3. **App-specific stable marker:** the user proves membership and correctly derives a persistent application-specific pseudonym, sometimes called a nullifier. It is derived inside a verified proof from the certified membership secret and fixed application scope; it cannot be a random client-chosen string.
4. **Login key:** bind an app login public key to that marker through a proof or authorized credential flow. Use normal challenge signing for routine login. Rotating login keys preserves the same membership marker and ban state.
5. **Ban:** deny the marker at the app, terminate sessions and active games, and reject newly registered login keys presenting that same marker.
6. **Recovery/renewal:** preserve the membership secret/marker or carry forward revocation through a reviewed protocol. Reissuing a brand-new unrelated secret after “I lost my key” must not reset the ban. Enrollment records cannot be wiped and re-created merely because the social account is deleted.

Semaphore demonstrates anonymous group-membership proofs and double-signaling prevention; its documentation supports off-chain operation. Privacy Pass describes unlinkable issuance/redemption and metadata/collusion limits. Neither is a complete turnkey TAMU account, renewal, recovery, or lifetime-ban system. The exact credential construction and ban-preserving recovery require specialist design and review. [Semaphore overview](https://docs.semaphore.pse.dev/), [Semaphore identities and proofs](https://semaphore.pse.dev/learn), [IETF Privacy Pass architecture](https://www.rfc-editor.org/rfc/rfc9576.html).

The stable marker intentionally makes one account's activity recognizable to the app. The privacy objective is hiding its real-world identity and verification relationship, not hiding the existence of the account. If issuance is limited only once per semester but produces a new marker every semester, bans can disappear at semester rollover; the lifetime/renewal design must prevent that.

### Honest guarantees and limitations

| Goal | What is needed / limitation |
|---|---|
| Public key does not expose secret key | Standard reviewed key generation and signing; secure storage |
| Same approved mailbox cannot simply enroll twice | Persistent uniqueness state and correct handling of mailbox aliases |
| Banned member cannot reset through a new key/device | Ban tied to stable membership, not installation or public login key alone |
| Operator cannot look up school email from account | Unlinkable enrollment/presentation, separated metadata and access, appropriate threat model |
| Person can never return using another identity | Cannot honestly guarantee with email-only evidence; borrowed/additional accounts remain possible |
| Lost key is recoverable without revealing identity | User-held recovery material or a reviewed recovery arrangement; ordinary email-reset linkage conflicts with the strongest claim |
| Absolute real-world anonymity | Not promised: precise locations, voice, timing, content, IP addresses, and meetings can identify people |

A server HMAC of email is useful for duplicate detection against a database-only attacker, but a key-holding operator can test guessed emails. It does not provide operator unlinkability on its own. An independent verifier can reduce trust concentrated in the operator, but who runs it and what happens under collusion are open decisions.

The original “link personal email first” requirement needs revisiting for this stronger model. Keeping personal email and account in the same recoverable relationship identifies the user even if the school email is absent. We can defer the binding implementation as requested; we cannot claim the stronger guarantee until this is settled.

## Random matching stays essential: distribution findings

The relevant comparison is distribution for TAMU users located in the United States. Random matching is retained as the product requirement. This analysis does not replace it with an interest-based matching flow.

| Route | Finding | Practical conclusion |
|---|---|---|
| iOS App Store | Guideline 1.2 explicitly flags random/anonymous chat and Chatroulette-style experiences | Treat the proposed feature as a major rejection risk; TAMU email or 18+ is not a documented exemption |
| Unlisted iOS app | Direct-link discoverability still uses App Review and its guidelines | Useful for audience targeting, not a policy bypass |
| TestFlight | Beta review applies; builds expire after 90 days, up to 10,000 external testers | A test channel, not a sustainable alternate public distribution strategy |
| Apple Enterprise | For qualifying organizations' internal employee apps | Not a route for distributing a consumer app to TAMU students |
| Regional alternative iOS distribution | Apple's documented alternatives depend on supported regions and user eligibility | Do not assume an EU/Japan/Brazil route reaches students physically in Texas |
| Standalone mobile website/PWA | Accessed through the browser rather than an App Store binary | Strong candidate to retain random matching for iPhone users; hosting, moderation, privacy, and media permissions still apply |
| Google Play | Current policy requires blocking minors for core random/anonymous communication; UGC moderation requirements also apply | Potential native distribution route, subject to full review and compliance; no approval guarantee |
| Android direct distribution | Android documents website APK distribution with user opt-in | Technically possible, with installation, update, trust, and current verification requirements to assess before release |

Sources: [Apple guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple unlisted distribution](https://developer.apple.com/support/unlisted-app-distribution), [Apple unlisted review explanation](https://developer.apple.com/videos/play/tech-talks/10892/), [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [Enterprise eligibility](https://developer.apple.com/programs/enterprise/), [regional alternative distribution](https://support.apple.com/en-ie/118110), [Google age restrictions](https://support.google.com/googleplay/android-developer/answer/16302250), [Google UGC requirements](https://support.google.com/googleplay/android-developer/answer/9876937), [Android distribution](https://developer.android.com/distribute/marketing-tools/alternative-distribution).

**Recommended option to evaluate:** native tag/campus features plus an independently accessible browser random-chat product with a shared, properly designed eligibility boundary. Do not silently embed, remotely enable, or disguise the random-chat experience in an iOS app after review. Any in-app promotion/link/integration remains part of the app's review context. A standalone web option is a product/distribution choice, not a promise that Apple will approve an associated native app.

A web-first whole product is another option, but tag needs careful evaluation of foreground/background location behavior. A browser random-chat product and native tag can share server contracts without pretending their OS capabilities are identical. The framework decision still depends on your launch platforms.

## Remaining immediate decisions

1. Resolved: visual design only; no application coding.
2. Exactly @tamu.edu, or approved subdomains too?
3. Does main-feed anonymous posting remain alongside the single username?
4. iOS, Android, or both; operating budget; and tag's first rule set?

Broader email/credential binding is deferred in the tag scope. No public eligibility or permanent-ban guarantee should be advertised by a prototype that has not implemented it.
