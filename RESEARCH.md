# MaroonSocial — research and product direction

> **October 1, 2026 implementation update:** Coding is now authorized. The user selected SwiftUI, iPhone first, and connected Supabase **Maroon Social** plus GitHub **VishalKothuri/MaroonSocial**. Mascot work is paused. This document preserves the earlier research/proposals; its older no-code statements are historical. See [README](README.md) for tested implementation status and remaining work.

Research date: September 29, 2026. Planning only; no application code, prototype, accounts, or infrastructure have been created.

This document distinguishes observed competitor behavior, published claims, recommendations, and unresolved choices. The accompanying architecture and screen specification are proposals for discussion, not decisions made on your behalf. The project folder was empty when research began.

## What your request establishes

Access must be limited to the intended TAMU community. Onboarding starts with a personal email, followed by university-email verification. You do not want to retain the TAMU email. The campus feed supports anonymity and optional usernames. Classes have general chats and study groups. Your follow-up selects one unified username across named features, including ordinary class chats, study groups, recreation, and IRL tag. One course-wide chat per semester is confirmed. Random matching remains essential, and tag is the immediate design focus. Visual design only; no application coding.

The requested product also includes DMs, memes, games such as cup pong and 8-ball, possible friends and private groups, an Omegle-like discovery experience, potentially voice/video, gaming hangouts, and TAMU sports countdowns/scores with event chat opening 30 minutes before each game.

## Yik Yak: what I actually verified

I searched Mobbin directly and inspected returned screenshots. The captured interface includes Nearby/Nationwide feeds and older visual styling. Mobbin did not return a capture date or app version. These are useful historical interaction references, not proof that every screen matches today's app.

| Research surface | Evidence | Useful lesson |
|---|---|---|
| Onboarding | An 18-screen flow; inspected previews show phone verification, a tutorial, and New/Hot feed entry | Explain privacy and behavior before participation, but avoid a long compulsory tutorial |
| Feed and post detail | Text-led cards, voting controls, comments, message/share/menu actions; a persistent composer on detail | Make campus conversation the immediate focus |
| Commenting | A five-screen flow; reply field remains at the bottom, keyboard opens inline, sent comment appears in the thread | Preserve context while writing |
| Direct messaging | A five-screen flow from a post to chat; OP badge, message composer, sent bubble | Start DMs from a specific interaction |
| Chat list | Empty state tells users to reply to a post/comment; populated list leads to a conversation with a link back to the source post | Explain how to begin and why a conversation exists |
| Reporting/blocking | Screens show confirmation feedback after those actions | Put safety controls on the content itself |
| Own activity | My Yaks, My Comments, and reset-conversation-icon entries are visible | Give users private access to their own activity |

References: [Mobbin onboarding](https://mobbin.com/flows/a6877e6d-48f0-48bc-afb0-9ba0b9aeabf7), [post detail](https://mobbin.com/flows/764d0ca5-044c-42dc-b151-a55c77a14dd0), [comment flow](https://mobbin.com/flows/d2e89f8a-8320-4738-b35e-1a3fdc264f11), [DM flow](https://mobbin.com/flows/9ffdd376-4c66-47b2-8f00-984de70d736b), [chat list](https://mobbin.com/flows/0327abb5-190a-4cc9-98d6-4ca20ced06c5), [My Yaks](https://mobbin.com/flows/cd3dce95-9c2b-4984-993f-d6c559e79439), [block feedback](https://mobbin.com/screens/7693cff5-45db-47b2-9678-0d5e0b95e064).

Yik Yak's current FAQ says usernames are optional, college communities require .edu verification, and receiving DMs is enabled on individual posts. It says DMs do not automatically disappear. Its anonymity description concerns what other users see; it is not a claim that the operator has no identifying records. The FAQ describes phone signup and a single college community per matching email. These current statements take priority over old screenshots when they conflict. [Official FAQ](https://yikyak.com/faq).

Its guardrails say posts at −5 vote points are removed and prohibit identifying students through names, photos, or descriptions. That is evidence for a moderation pattern, not a reason to copy the threshold: a small campus app is vulnerable to coordinated downvoting. [Community Guardrails](https://yikyak.com/community-guardrails).

The official privacy link redirects to a Notion document labeled January 24, 2023. I loaded it in the browser. It describes collecting phone numbers, post content and timestamps, location, device information, and IP addresses, and retaining some removed content. Its age language and location-oriented description also show why it should not be treated as a reliable description of every current feature. I found no verified basis for claiming Yik Yak deletes school emails, uses blind credentials, or offers end-to-end encrypted DMs. [Linked policy and terms](https://yikyak.notion.site/Yik-Yak-Terms-of-Service-Privacy-Policy-7bf2e5c2184a4ba6a9d34ae3fa086d8f).

**What remains unverified:** current username change limits, whether aliases rotate per thread, exact identity behavior when an anonymous user enters a DM, current DM request filtering, nested reply depth, database design, school-email retention, and cross-post conversation merging. An OP badge or icon-reset button does not establish those underlying rules. No verified TAMU test account was used.

### Proposed adaptation for MaroonSocial

Keep the campus feed anonymous by default. Let the composer explicitly choose Anonymous or a community handle for that post. Anonymous participants receive stable identifiers within a discussion so replies remain understandable; a new discussion gets a different identifier. Do not show a public list of an anonymous author's other posts.

A DM begins with “Message this author,” provided that author has enabled requests. It enters a request inbox before normal messaging. Keep the source-post card in the conversation. Do not automatically reveal a class, recreation, study, or gaming identity. Separate anonymous contexts should not automatically merge into one visible conversation, because that would link the author's posts. Users may explicitly choose to connect identities later.

These are original design recommendations, not assertions about Yik Yak's internal implementation.

## Other interface references

Discord's inspected Mobbin screens separate text, voice, and forum channel types and show per-server profile settings. Borrow explicit room purpose and identity scope, while avoiding a complex server/sidebar hierarchy for a one-campus app. [Discord channel creation](https://mobbin.com/flows/eaff9aa7-3808-42e0-a26a-f882a5b6f398).

Partiful's inspected event screens prioritize event details, RSVP state, attendance, and activity. Borrow clear time/place/capacity and Join/Leave actions; use scoped pseudonyms instead of real-name guest profiles. [Event details](https://mobbin.com/screens/d4e3b2a7-69c9-4776-be64-7f952d5bcaf3), [RSVP/activity](https://mobbin.com/screens/301b1252-7ce0-4a4a-b2ab-8263ed634515).

GamePigeon's developer listing confirms cup pong, 8-ball, and other games inside messaging. The useful pattern is a game invitation and playable turn in the conversation. It does not establish an embeddable SDK or licensing permission; plan original game implementations and artwork. [Developer App Store listing](https://apps.apple.com/us/app/gamepigeon/id1124197642).

## TAMU eligibility: email is evidence of mailbox access

TAMU states students, faculty, and staff have @tamu.edu addresses. Its account-lifecycle documentation also describes access outside the period of active enrollment. Therefore an email OTP cannot honestly guarantee “current student at College Station.” Periodic email verification refreshes mailbox control, not enrollment status. [TAMU FAQ](https://stuactonline.tamu.edu/app/help/faq), [email lifecycle](https://service.tamu.edu/TDClient/36/Portal/KB/PrintArticle?ID=452).

There are two distinct product choices:

| Eligibility rule | What can be claimed | Dependency |
|---|---|---|
| Approved TAMU mailbox + OTP | “TAMU email verified” | Exact approved-domain list and university alias handling |
| Current-student affiliation | “Student status verified as of [date]” | Authorized university integration or an appropriate verification provider |

TAMU documents NetID integration through several authentication technologies, including Shibboleth. Application registration is required. This establishes a possible integration route, not that a student-founded commercial app will receive approval or the exact campus/enrollment attributes needed. No university contact has been made. [NetID integration](https://www.it.tamu.edu/services/services-by-category/information-security/netid-authentication.html), [Shibboleth registration](https://docs.security.tamu.edu/docs/identity-security/authentication/options/shibboleth/).

The course catalog can seed names such as CHEM 107, General Chemistry for Engineering Students. It cannot prove a user is enrolled in that class. Class selections should be labeled self-selected unless a separate enrollment integration is authorized. [TAMU chemistry catalog](https://catalog.tamu.edu/undergraduate/course-descriptions/chem/).

## Privacy choices

**Removing the TAMU email is worthwhile, but retaining a personal email still leaves a private identity link.** Anonymity from classmates, deletion of a school address, unlinkability from the operator, and end-to-end encryption are separate properties.

| Option | Mechanics | Benefit | Limit |
|---|---|---|---|
| A: Minimized records | Isolated OTP verifier; discard raw school address; retain a keyed duplicate-detection value; store membership status against the app account | Practical, affordable, supports recovery and repeat-account controls | Operator can still correlate activity to personal login; a key holder can test suspected school emails |
| B: Unlinkable membership issuance | Separate verifier issues an audited blind credential; app redeems proof without school identity | Stronger separation between verification and app membership | More engineering, specialist review, recovery and revocation difficulties; network/timing metadata can still correlate |
| C: University-attested eligibility | University/provider attests current-student status; app receives minimal claims, optionally via a privacy-preserving credential layer | Better eligibility evidence | Requires approval, scoped attributes, integration, and privacy review |

An ordinary hash of a school email is guessable. A keyed HMAC reduces offline guessing by a database thief without the key, but is still pseudonymous data, not anonymity from the operator. A signed token that embeds the email or its ordinary hash does not fix that.

Privacy Pass provides a published architecture for unlinkable issuance/redemption, including explicit treatment of collusion, IP addresses, and timing. It is a research basis, not a ready-made university enrollment/ban system. Credential ownership, renewal, duplicate issuance, recovery, and abuse controls need a separate reviewed design. [IETF RFC 9576](https://www.rfc-editor.org/rfc/rfc9576.html).

Your follow-up targets the stronger option B, with key-based access and persistent bans. The precise credential and recovery design is deferred; see the privacy update. If the requirement means “the operator must not be able to identify authors,” the proposed mandatory personal-email linkage also needs redesign or meaningful separation. Neither separate database tables nor encryption with an operator-held key establishes that property.

## Expo or Swift?

| Criterion | Expo + React Native | Swift + SwiftUI |
|---|---|---|
| Launch reach | Shared mobile application foundation for iOS and Android | Apple UI stack; Android requires a separate UI effort |
| Campus feed, messages, events | Strong fit | Strong fit |
| Small team and iteration | My preferred direction if both platforms matter | Attractive if the team already knows Swift and launch is iPhone-only |
| Location game | Native permissions and device testing still required | Direct access to Apple's location APIs; same OS restrictions remain |
| Voice/video | Native SDK integrations available | Native SDK integrations available |
| 2D games | Dedicated renderer/physics module is feasible | SpriteKit/native rendering is an option |
| Main risk | Native dependency compatibility and multi-device QA | Separate Android cost and duplicated feature work |

Expo development builds allow custom native libraries; Expo Go alone is insufficient for this scope. Daily publishes an Expo example requiring native code. Background location is subject to OS permissions and lifecycle behavior whichever UI framework is used. [Expo development builds](https://docs.expo.dev/develop/development-builds/introduction/), [Daily Expo example](https://github.com/daily-demos/daily-expo-demo), [Expo location](https://docs.expo.dev/versions/latest/sdk/location/), [SwiftUI](https://developer.apple.com/swiftui/).

**Conditional recommendation:** Expo + React Native + TypeScript for iOS/Android and a small team. SwiftUI if an iPhone-only launch and native expertise are deliberate choices. Cup pong or location tracking alone is not a reason to build two entire native apps. Team experience, platform priorities, and launch scope remain open.

## IRL tag: relevant products and a campus-specific proposal

Hide & Seek describes phone-compass play, live location, timers, and configurable boundaries. HIDE describes hunters/runners, scheduled position reveals, and a six-digit catch code; its page says locations are limited to a game and its rules. These are developer descriptions, not field tests. Neither has been confirmed as the exact product you mean. [Hide & Seek](https://hideandseekapp.com/), [HIDE](https://hide-app.com/).

Suggested loop: join a scheduled lobby → use the unified username → review boundary/rules/location sharing → ready check → hiding countdown → seeking with periodic directional hints → proximity encounter confirmed by a rotating code → results/rematch.

Use an uncertain direction cone, freshness indicator, and broad distance band rather than promising an exact indoor compass. Sparse delayed hints create suspense and reduce precision exposed to strangers. The server should send the allowed hint, not hide raw target coordinates behind the interface. Repeated hints can still help infer location; do not claim this makes participants untrackable.

The game should have explicit opt-in participants, public outdoor play zones, no private-room destinations, a permanent Leave/Stop sharing control, and suspended tracking when permission or connectivity fails. Catch confirmation should not require touching or photographing someone. GPS is insufficient to prove a catch. Exact location history should have a short, explicit expiry, with no normal long-term route replay.

Walking-only versus running, trusted-friends versus open lobbies, tag versus hide-and-seek, match size, hint frequency, campus permission, and operating hours are open choices. IRL meetings necessarily reduce anonymity because people can recognize one another.

## Random matching, voice, and video

Apple guideline 1.2 explicitly includes Chatroulette-style experiences and random/anonymous chat among experiences that do not belong on the App Store. TAMU verification does not create a documented exception. Google Play's current age-restricted policy requires blocking minors for apps centered on random connections or deliberately hidden identities. The university audience includes people under 18, so email verification cannot serve as an age check. [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/), [Google Play age policy](https://support.google.com/googleplay/android-developer/answer/16302250).

Your follow-up confirms pure random matching as essential. Preserve a random queue with Next/End; do not substitute interest matching. Browser distribution is a candidate; native distribution remains subject to platform review. See [distribution and privacy update](TAG-AND-PRIVACY-UPDATE.md).

Cost/complexity order I recommend: text → consent-based voice in existing conversations → small group voice → optional video if justified. Cameras and voices can identify people; describe those modes as pseudonymous, not identity-proof.

Direct peer-to-peer WebRTC can reveal network addresses to the peer. For stranger interactions, evaluate relay-only TURN or an SFU and verify the SDK's actual routing behavior. Transport encryption is not automatically end-to-end encryption, and a relay does not hide the participant's address from the infrastructure provider. [WebRTC security architecture](https://www.rfc-editor.org/rfc/rfc8827.html).

## Sports: schedule and score are different integrations

The official athletics site provides an all-sports schedule and live-event destinations. I did not find a documented public Google sports-score API suitable for this product. Google search results should not be treated as a licensed backend feed. [Official schedule](https://12thman.com/all-sports-schedule), [live events](https://static.12thman.com/widgets/live-home/index.html).

Proposed low-cost starting point: approved schedule import or a small maintained schedule, accurate countdowns, a link to the official score page, and automatic chat opening 30 minutes before the confirmed event start. Automated in-app live scores require a provider with the right sports coverage and redistribution terms.

SportsDataIO's Discovery Lab is next-day delayed and not licensed for commercial redistribution; live commercial feeds are quoted separately. Do not use a trial or hobby-plan price as the production live-score budget. Women's sports and Olympic sports need explicit coverage checks. [Developer products](https://sportsdata.io/developers), [licensing FAQ](https://sportsdata.io/help/data-rights-and-licensing-questions).

## Cost model — examples, not your budget

Prices below were checked for this research date. Workload examples are illustrative and are not assumed launch targets. Costs exclude development labor, human moderation, taxes, store accounts, legal/privacy review, sports licensing, and unlisted overages.

| Component | Checked basis | Interpretation |
|---|---|---|
| App build service | Expo Free; Starter $19/month plus usage | Builds/updates, not the chat backend |
| API compute | Cloudflare Workers paid subscription starts at $5/month, with usage charges | WebSocket/stateful room services add their own metering |
| Example managed Postgres | Neon Launch $0.106/CU-hour and $0.35/GB-month | 0.25 CU × 730 hours ≈ $19.35 compute; 1 CU ≈ $77.38, before storage/other charges |
| Images/memes | R2 standard storage $0.015/GB-month; operations charged separately, Internet egress free | Compression and upload quotas matter; transforms/moderation cost extra |
| OTP delivery | Resend Free 3,000 emails/month, 100/day; Pro $20 for 50,000/month | Two initial email verifications use at least two messages per enrollment |

Sources: [Expo pricing](https://expo.dev/pricing), [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/), [Neon's published plan documentation](https://github.com/neondatabase/website/blob/main/content/docs/introduction/plans.md), [R2 pricing](https://developers.cloudflare.com/r2/pricing/), [Resend pricing](https://resend.com/pricing).

Resend's published free plan lists 30-day data retention. Deleting the address from your database therefore does not justify “nobody retains your TAMU email.” Provider retention, delivery logs, suppression lists, university mail systems, and backups must be assessed. Provider selection is still open.

For a modest text/media pilot, I would provisionally reserve **$50–150/month for core infrastructure**, subject to measured connections, messages, storage, and availability needs. That is an engineering allowance, not a vendor quote or an all-in operating budget. Human moderation needs its own staffing plan. A student population count alone cannot predict the bill.

Daily publishes 10,000 free participant-minutes monthly, then first paid-tier rates of $0.00099 per audio participant-minute or $0.004 per video participant-minute. Any video track in a session triggers video billing. Examples below model either an all-audio or all-video workload using that one allowance; do not double-count it for mixed usage. [Daily pricing](https://www.daily.co/pricing/video-sdk/).

| Illustrative monthly usage | Participant-minutes | Audio transport | Video transport |
|---|---:|---:|---:|
| 1,000 calls × 2 people × 10 minutes | 20,000 | $9.90 | $40.00 |
| 5,000 calls × 2 people × 10 minutes | 100,000 | $89.10 | $360.00 |
| 100 hangouts × 8 people × 60 minutes | 48,000 | $37.62 | $152.00 |

Cloudflare TURN/SFU instead publishes 1,000 GB free monthly and $0.05/GB thereafter. At a hypothetical combined two-way video egress of 2 Mbps, a ten-minute call is about 0.15 GB before overhead; 10,000 calls would be about 1,500 GB, or $25 beyond that allowance. This models media bandwidth only, not signaling, SDK work, moderation, or a full calling product. Audio is smaller, but integration labor can dominate the saving. [Cloudflare TURN pricing](https://developers.cloudflare.com/realtime/turn/faq/).

Budget enforcement belongs on the server: cap room sizes and duration, expire empty rooms, limit invitations/uploads, apply per-account quotas, record provider usage, and reject new expensive sessions when a chosen spend threshold is reached. Billing alerts alone are not spending caps.

## Current design priority

Your follow-up prioritizes IRL tag, with credential binding deferred, and explicitly requests visual screens without code. [HideZone](https://apps.apple.com/us/app/hidezone-gps-hide-seek/id6759913726) is now the primary tag reference; the earlier examples remain secondary research. See [updated tag research](TAG-AND-PRIVACY-UPDATE.md).

The visual concepts cover community, classes/study, tag, activities/sports, DMs/games/random chat, and selected onboarding screens. This is not a committed implementation or release order. Platforms, budget, media launch scope, and final eligibility/recovery design remain open.

Next documents: [architecture](ARCHITECTURE.md), [screens and flows](SCREENS-AND-FLOWS.md), [open decisions](OPEN-DECISIONS.md).
