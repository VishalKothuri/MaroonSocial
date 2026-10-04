# MaroonSocial — current decisions

> **October 1, 2026 implementation update:** Coding is now authorized. The user selected SwiftUI, iPhone first, and connected Supabase **Maroon Social** plus GitHub **VishalKothuri/MaroonSocial**. Mascot work is paused. This document preserves the earlier research/proposals; its older no-code statements are historical. See [README](README.md) for tested implementation status and remaining work.

September 29, 2026. Your latest request confirms visual design only, NOT CODE.

## Confirmed direction

- TAMU email access only, not arbitrary .edu enrollment.
- Stronger identity privacy, key-style access, and bans that survive new login keys are targets; no cryptographic guarantee has been implemented.
- One unified username across named features, including ordinary class chats, study, recreation and tag.
- One shared course chat per semester, without instructor/section splits.
- Pure random matching remains essential.
- Tag is the immediate design focus; credential binding is deferred. HideZone is the primary supplied game reference.
- 18+ direction is recorded from your final “yes”; the actual age-check mechanism is undecided.
- Visual screens are requested instead of relying on flowcharts and text.
- WebRTC + Node.js/Socket.IO is a proposed media stack under evaluation.

## Still open

| Decision | Why it matters |
|---|---|
| Exactly @tamu.edu, or selected subdomains? | A literal .tamu.edu suffix differs from the root tamu.edu domain; final allowlist needs clarification. |
| Does the main feed retain Anonymous / username choice? | Mockups preserve your original option as a proposal. |
| Random-chat distribution path | Native SwiftUI for iPhone is confirmed; browser distribution for random matching remains under review. |
| Expected users/concurrency, monthly ceiling, moderation owner? | Needed for a production budget. |
| Keep personal-email-first enrollment? | Linked personal email conflicts with the strongest operator-unlinkability goal; recovery is deferred. |
| Initial tag rules? | Private lobbies, example boundaries, hint timing and catch codes are illustrative proposals. |
| Which random-chat media modes launch first? | Text, voice and video remain in scope, with no committed release order. |

Deferred: friends/search; private groups; semester history; tag items/spectators; supported sports and licensed scores; anonymous-to-named DM disclosure; data retention; credential recovery and renewal.

Mobbin Yik Yak captures have no verified capture date. Current internal identity and DM merging behavior were not established through a logged-in TAMU account. HideZone research uses its listing/screenshots/privacy policy, not a live gameplay test. Mobbin search did not return an exact HideZone match.

See [tag/privacy update](TAG-AND-PRIVACY-UPDATE.md) and [WebRTC proposal](WEBRTC-OPTION.md).

## Additional confirmed decisions

Hangouts are casual plans using the unified username. Verified organizations can promote their organizations/events/parties under the organization name, keeping personal administrator identities private. NSFW sits directly below Texas A&M and allows 18+ non-explicit discussion only. Each chat message can include one image or one GIF. See [new feature specification](SOCIAL-ADDITIONS.md).

## October 1 build decisions

SwiftUI and iPhone first are confirmed. Supabase is connected. Dining means today’s public menus and hours, not a personal meal balance. Coding and uploading the project to the connected GitHub repository are authorized. Email delivery, identity enforcement and live multiplayer are not yet configured.

## Shared memes live in our backend, not KLIPY (October 4)

KLIPY’s documented API is retrieval-only (search, trending, share, report); there is no upload endpoint. “Publish this meme to other users” therefore stores the image in the app’s own private media bucket through new `meme.*` actions and shows it in the picker’s Community tab. Owners are never exposed, three distinct reports hide a meme, and owners can remove their own. Revisit if KLIPY adds a partner upload API.
