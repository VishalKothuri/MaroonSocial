# Hangouts, organizations, NSFW discussions, and message media

> **October 1, 2026 implementation update:** Coding is now authorized. The user selected SwiftUI, iPhone first, and connected Supabase **Maroon Social** plus GitHub **VishalKothuri/MaroonSocial**. Mascot work is paused. This document preserves the earlier research/proposals; its older no-code statements are historical. See [README](README.md) for tested implementation status and remaining work.

Design update — September 29, 2026. User-confirmed requirements; no application code.

## Confirmed

- Hangouts means casual coffee, food, movies, or meeting on campus, using the unified username.
- Organization and party promotions come from verified organization accounts. Public authorship is the organization name; administrators' personal identities stay private from other members.
- NSFW appears directly below Texas A&M in the community selector. It is an optional 18+ discussion space: no nudity or explicit sexual content.
- Chat messages can contain one image OR one GIF, not multiple attachments. Optional text may accompany that attachment.
- The cute squirrel remains the mascot.

## Navigation and screen behavior

| Screen | Actions and destinations |
|---|---|
| Activities home | Hangouts → casual plans; Organizations → directory. Rec, Tag, Sports, Gaming and Random chat remain reachable. |
| Hangout discovery | Filter by category; View → detail; Create hangout → title/category/time/place/capacity/description form. |
| Hangout detail | Join using unified username → participant room; Message host → DM request; Leave cancels membership. Full/expired/canceled states disable joining. |
| Organization directory | Search/filter; Follow; open profile; Register organization starts a private verification application. |
| Organization profile | About/Events; Follow; Message organization; event card → event detail. No public administrator list or personal-account links. |
| Organization event | Interested, message organizer, share authorized deep link, report. RSVP visibility and whether interest opens an event chat remain undecided. |
| Private org dashboard | Verified authorized administrator can create/edit promotions, edit profile, or manage private access. |
| New promotion | Choose organization introduction/event/party; enter copy and appropriate date/place/poster; Preview. |
| Promotion preview | Displays exact organization byline; Publish after authorization re-check; Save draft; Back to edit. |
| Community selector | Texas A&M first, NSFW directly beneath with 18+ label. NSFW selection checks access and opt-in before opening its feed. |
| NSFW join/rules | State 18+ discussion-only boundary, no explicit content; Join community or Not now. No checkbox-only age-proof claim. |
| NSFW feed | New/Hot, post/reply, report/block, rules, leave. Anonymous/named authorship follows the community controls. |
| Message media composer | Photo or GIF → one preview; Replace or Remove; send optional text plus selected media. |
| GIF picker | Single selection; choose another replaces the choice; Use GIF returns to composer. |

The mockups use fictional organizations and events. A verified organization badge means verification by this app under an adopted process; it must not imply university endorsement. Method, evidence, retention, reviewer access and renewal need definition before implementation. The organization directory remains inside TAMU membership access unless explicitly changed.

## Architecture additions

Reuse the existing activity scheduling, capacity, membership and chat components for Hangouts, with a hangout category and its own discovery entry. Joining the last spot is atomic. A member removed from a hangout loses associated room access.

Organizations are separate public entities, not new personal aliases. Store organization profiles, verification status, private administrative roles, promotions, follows and optional event interest. Server authorization requires valid membership, an active authorized org role, and verified/non-suspended organization status on every publish/edit. Revocation immediately prevents new promotions. Keep audit authorship private from public responses, exports intended for other members, notifications and profile links. Do not promise anonymity from authorized verification reviewers.

Community content carries an explicit community identifier. Enforce NSFW access, opt-in and membership in feed/search/reply/media/deep-link endpoints and realtime subscriptions. Proposal: keep NSFW posts out of general-feed recommendations and notification previews; do not publish a user's NSFW membership or link anonymous activity to the named profile. Leaving stops subscriptions and future notifications. Server controls must match the UI.

Messages have optional text and at most one media attachment, either image or GIF. Enforce cardinality on the server, including retries/edits and crafted requests. Validate actual file type and decode limits, not just filename. Reject a second attachment rather than silently dropping it; the client offers Replace. Failed upload preserves text and allows retry/removal. GIF playback needs a pause/reduced-motion behavior. Apply content rules to GIFs as well as still images. GIF provider, upload size/duration and quotas remain open. This cap applies to chat messages, including DMs, class/study/hangout/group and organization conversations; it does not silently decide the separate limit for feed posts or promotion posters. Game invitations remain separately defined message types.

## Distribution context

The chosen NSFW scope excludes explicit sexual content. Keep that rule visible and enforce it on text and media; an 18+ label is not a blanket app-store exemption. Apple restricts overtly sexual material and has a narrow incidental mature-UGC provision. Google requires moderation and restricts promotion of sexual UGC. These policies do not establish approval for this app, especially given the separately researched random-chat feature. [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/), [Google UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937).
