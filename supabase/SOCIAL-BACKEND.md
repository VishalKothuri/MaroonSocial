# Shared social backend and operations

The deployed project is `myxbghfbapbfffkpndwo`. `SocialService` uses the `social` Edge Function and a separate 256-bit device credential stored in Keychain. Random chat uses its own guest credential. The database stores only credential hashes. A device account proves possession of that credential; it is not verified university enrollment, strong age proof, personal-email recovery, or the unlinkable membership scheme described in the architecture proposal.

## Client contract

`connect(username:adult:)`, `refresh()` and `perform(action,payload:)` return `SocialResponse` with `snapshot` and optional `resource_id`. Snapshot timestamps are Unix seconds. Courses use `CODE-term` room IDs; all other resource IDs are opaque. Private universal member IDs never appear in social snapshots. Named conversations use the unified username; anonymous-origin DMs retain anonymous bylines. Organization events, conversation titles, messages and typing indicators use the organization byline for the administrator.

Common actions and payloads:

| Actions | Inputs |
| --- | --- |
| `post.create` | text, anonymous, community, acceptsDM, nonce; optional poll, link_url, tags |
| `post.vote`, `post.save`, `post.delete` | post_id, value(-1/0/1) or saved |
| `poll.vote` | post_id, option_id (one current choice per member) |
| `posts.tag` | tag, community; returns at most 100 matching visible posts |
| `comment.create`, `comment.delete`, `comment.vote` | post_id/text/anonymous/nonce and optional parent_id; or comment_id/value |
| `course.join`, `course.leave` | code/title/term/icon, or room_id |
| `room.send` | room_id, text, nonce, optional reply_to and one attachment_id |
| `room.read`, `room.typing`, `room.react`, `room.delete` | room_id, typing; or message_id/emoji |
| `dm.request`, `dm.accept`, `dm.decline` | exactly one of post_id/comment_id/username, text; or room_id |
| `group.create` | title, description, category, is_public, avatar, alias, member_avatar, nonce; same contract as communities create |
| `group.invite/accept/decline/remove/transfer/leave` | room_id; invite: account username; accept: alias/member_avatar; remove/transfer: scoped member_key |
| `activity.create/edit` | title, kind, place, starts, capacity, details, course, approval_required; activity_id for edits |
| `activity.join/leave/cancel/approve` | activity_id, username for approval |
| `organization.apply` | name, about, contact, evidence |
| `organization.follow/update/publish/message` | organization_id, followed/about/activity fields/text |
| `join_sports`, `save_event` | event_id, saved for save_event |
| `report`, `block` | target_type/target_id/reason; block may use post_id or DM room_id |
| `profile.update`, `account.delete` | username, or no payload |

Retries must reuse a nonce only for the exact same message or post payload. Editing a failed draft creates a new nonce. For posts this includes poll question/options/duration, link, tags, community and identity preferences. An exact retry keeps the original post/poll/option IDs and closing time; a changed or deleted post with that nonce is rejected. Snapshot returns at most 150 recent posts, 200 replies per post and 100 recent messages per room; older data remains in server storage. Tag discovery is a separate bounded server query. General feed history pagination is not implemented.

`conversationMeta` provides canSend, unread, lastRead, typing, pendingOutgoing, group members visible only to accepted members, and optional call summary. Activity membershipStatus distinguishes accepted/pending/waitlisted; joinRequests is host-only. Capacity changes cannot exclude accepted people. Verified organization authorization is rechecked for publication, editing, messaging and calls. Verification is an operator decision, not university endorsement.

## Polls, links and tags

`post.create` accepts these additional fields in the same transaction as the post:

```json
{
  "text": "",
  "poll": {
    "question": "Where should we study?",
    "options": ["Library", "Coffee shop"],
    "duration_hours": 24
  },
  "link_url": "https://www.tamu.edu/",
  "tags": ["study", "campus"]
}
```

Text is limited to 1,000 characters and may be empty when a poll or link is present. A tag alone is not a post. Polls require a 1–180 character question, two to four distinct trimmed options of 1–80 characters, and a duration of 24, 72 or 168 hours. Option uniqueness ignores case. Links are HTTP/HTTPS, at most 2,048 characters, with no embedded credentials, control characters or whitespace. The backend validates the address without fetching it or generating third-party link previews. Tags normalize a leading `#`, whitespace and case; a request accepts up to five tags of 1–24 ASCII letters, digits or underscores and stores distinct lowercase values.

The post projection includes `linkURL`, `tags` and optional `poll`. A poll contains `id`, `question`, `options` (`id`, `text`, `votes`), `endsAt` in Unix seconds, `totalVotes`, and nullable `myOptionID`. Poll votes never return a voter list, username or private member identifier. Authors may vote in their own polls. Voting does not change karma; post/reply upvotes and downvotes retain their separate rules. Each member has one current choice and may change it until the database deadline. The deadline is checked after the post lock is acquired. Cross-poll option IDs, deleted/blocked/unavailable posts, suspended participants and expired polls are rejected. Aggregate counts exclude suspended voters and votes between blocked author/voter pairs.

Deleting a post or its author removes the poll, choices and votes and clears its link/tags. Deleting a voter removes that member's votes. Self-export includes authored post extras and only the requesting account's own poll choices. Post-report evidence includes the link/tags/poll content while omitting the reporter's selected option.

`posts.tag {tag,community}` returns `{tag,community,posts}` with the newest 100 matches. It queries server storage rather than filtering the newest feed page, and uses the same private post serializer as snapshots. Deleted, hidden, blocked and suspended-author results are excluded. Campus and NSFW are separate scopes; NSFW requires active adult-community opt-in. The client cannot raise the result cap. The native tag page retains an owner-scoped query while navigating into replies or another tag. Refreshes and mutations retrieve canonical tag results before updating the local store; these additional posts do not expand the main feed or its disk cache. Empty/error results do not restore removed content from an older query.

Deployed migrations: `20261004043414_post_polls_links_tags.sql` and `20261004044952_server_tag_discovery.sql`. The `social` Edge Function adds only the `poll.vote` and `posts.tag` client actions for these features; credentials, media and other social routes retain the shared adapter.

## Private media

`SocialService.upload(media,roomID:postID:)` sends `attachment.upload` with base 64 media. A post must exist first. Upload commits the single ready attachment to that post; `post.attach` validates it and refreshes state. Room uploads remain private to the uploader until bound to a message. `attachment.read` rechecks access on every fetch and returns authenticated bytes, never a public or long-lived signed URL.

The server checks actual JPEG/PNG/GIF format, decodes and reencodes to strip metadata, caps input/output at 5 MB, image size at 12 megapixels, GIF frames at 80 and duration at 15 seconds, and limits uploads to 30/hour/account. This is format validation; an automated sexual-content classifier, malware scanner and staffed moderation SLA are not configured. One image OR one GIF per message is enforced including retries and forged requests.

Account deletion revokes the credential, tombstones content, cancels hosted activities, closes DMs/calls and deletes owned media. The native app saves deletion intent in Keychain before sending; a lost response is retried after reconnect/relaunch. Only successful deletion or an already-revoked credential clears the local account; a suspended account is not silently replaced. Failed physical storage removal stays in `social_private.storage_deletions` for operator retry. Backups and narrowly retained report evidence have separate retention behavior; no claim of immediate removal from backups is made. Full launch retention policy remains an operator decision.

## Accepted DM voice/video

`RoomCallView(social:roomID:)` uses `RoomCallService` and the `room-calls` Edge Function. The calls API accepts invite, accept, decline, end, poll, signal and media. Payloads contain room_id; actions on an existing call add call_id. Invite adds mode voice/video, nonce and allow_direct. Both parties must accept before media configuration is returned. Signals are offer/answer/ice/media objects with monotonically increasing IDs; poll supplies after.

No account is eligible for simultaneous calls. Invitations expire after 60 seconds, disconnected participants after 30 seconds, active calls after 2 hours; ended signaling is deleted after 1 day. Leaving/backgrounding clears local media immediately and ends the exact call ID, even if a network response is delayed. Forbidden membership stops capture.

Without server TURN_KEY_ID/TURN_API_TOKEN, direct transport requires explicit consent from both participants. Direct ICE can expose network addresses and cannot connect every network. With Cloudflare TURN configured, the server issues short-lived relay credentials and the bundled WebRTC client uses relay-only policy. No camera/microphone recording is stored. Real-device permission/camera testing and TURN coverage remain separate from the synthetic integration test.

## Private operator workflow

No app user, anon/authenticated API role, or Edge service_role can execute `social_private.operator`. Only the database operator can review this private queue. `operator_audit` records reviewer label, database role, action, target and reason. The label is operator-supplied; it is not a claimed independently verified staff identity.

`tools/social-admin.py` defaults to printing exact reviewable SQL for the existing Supabase database connector:

```sh
python3 tools/social-admin.py reports
python3 tools/social-admin.py organizations
python3 tools/social-admin.py --reviewer operator-name review-report REPORT_UUID remove --note 'Specific policy finding and evidence reviewed'
python3 tools/social-admin.py --reviewer operator-name review-organization ORG_UUID verified --evidence-checked --note 'Documented authority and evidence reviewed'
python3 tools/social-admin.py --reviewer operator-name suspend --report-id REPORT_UUID --note 'Specific suspension reason'
python3 tools/social-admin.py --reviewer operator-name suspend --username username --note 'Specific suspension reason'
python3 tools/social-admin.py audit
python3 tools/social-admin.py pending-media-deletions
```

To execute directly, provide `SUPABASE_ACCESS_TOKEN` privately in the operator environment and add `--execute` before the command. The tool uses the official [Supabase Management API query endpoint](https://supabase.com/docs/reference/api/v1-run-a-query), which is currently documented as beta. It never reads a token from the app, prints an access token, or bundles operator credentials. The existing database connector is an alternative execution path and was used to validate all review operations with transactional synthetic fixtures.

Organization decisions are verified/declined/suspended. Verification requires an explicit evidence-checked flag and note. Adopt a documented evidence standard, reviewer access controls and renewal/appeal process before real verification. Reports can be resolved/dismissed/remove; removal tombstones the target or suspends/closes the relevant organization/activity/room. Suspension can resolve a private author from a report without exposing that identity in client data; it rejects future shared API requests and ends calls/DMs. Tag cleanup removes suspended participants; games reject interactions involving suspended members. Operators must actually inspect queues; no staffed review promise is made by the app.

For queued media deletion, use an authorized Storage API/CLI session to delete the listed `social-media` paths, then call `public.social_media_cleanup_complete(paths)` using a service/operator credential. This function removes queue entries only after physical deletion; never clear pending jobs before deletion succeeds. Do not delete rows from storage.objects directly because that can orphan physical files.

## Validation

The 2026-10-04 UTC verification passed:

- `tools/test-post-extras-security.sql`: transactional malformed-input, nonce/atomicity, same-poll choice, single-vote counts, server deadline, author vote, anonymity, block/ban/adult gating, own export, report evidence and deletion checks.
- `python3 tools/test-post-extras.py`: three independent HTTP clients, including concurrent choice changes, shared post persistence, canonical metadata, block/deletion behavior and cleanup.
- `tools/test-tagged-posts-security.sql`: a matching post older than 160 newer fixtures remains discoverable outside the feed; newest-100 bounds and all visibility restrictions are enforced. All fixtures roll back.
- `python3 tools/test-tagged-posts.py`: three-client tag queries, exact shared post serialization, canonical post/poll/bookmark changes, community isolation, block/hidden filtering and deletion.

Captured live stdout and cleanup evidence are in `build/backend-post-extras-and-tags.log`. Each live script deleted its three synthetic accounts; the three generated post tombstones from each run were subsequently removed by exact recorded IDs, with zero remaining. The nested-reply, course-retention and KLIPY SQL security regressions passed after the poll migration; reply and course-retention regressions passed again after extracting the tag serializer. Supabase's security advisor returned zero findings. These are protocol/security checks, separate from native UI and device testing.

`python3 tools/test-social.py` exercises independent accounts, feed, replies, votes, bookmarks, access boundaries, shared course rooms, anonymous DM requests, sanitized private attachments, nonce integrity, waitlists/approvals, groups, reports/blocks and deletion. It deletes its account credentials and media; exact remaining synthetic resource IDs are written privately to `/tmp/maroon-social-test-fixtures.json` for operator cleanup. `tools/test-social-security.sql` rolls back every test including synthetic organization verification, byline privacy, suspension and private-schema permissions.

`tools/test-room-calls.py` requires aiortc 1.15.0 and runs actual two-way synthetic video/data through the accepted-DM API with separate offer/answer/ICE delivery. The measured run decoded 62 and 63 frames over 2.1 seconds, exchanged 8 ICE candidates and verified End revocation. Both peers run on the same host; it does not establish cross-network TURN reliability. Account cleanup occurs in finally; `/tmp/maroon-room-call-fixtures.json` identifies the exact empty test room for removal.

Native `RoomCallServiceTests` cover consent and delayed-response teardown. Root project tests also exercise the bundled WebKit bridge. Simulator builds must be signed (normal ad-hoc Xcode signing is sufficient); disabling code signing breaks secure Keychain storage.

Mailbox verification is implemented separately in [VERIFICATION.md](VERIFICATION.md). Delivery and the required-membership switch remain disabled until an owner-controlled sender/provider is configured and a real authorized mailbox test succeeds.


## Campus community chats

`communities` uses the same server-validated social credential/Auth adapter as messaging. The service-only `communities_gateway` RPC manages `community_private` records backed by canonical `group` rooms. Existing invite-only groups remain private and acquire independent generated group aliases until members edit their profile. Account usernames are never the default group byline. The existing TAMU-mailbox enforcement switch remains server-side; its deployment status is described above and is not inferred from a group joining successfully.

The creation contract is `create {title,description,category,is_public,avatar,alias,member_avatar,nonce}`. Titles are 3–60 characters and descriptions 10–500. Categories are Class, Major, Dorm or House, Study Group, Friends, People on app, Other. Preset avatars are maroon, gold, sage, sky, violet, coral, slate, rose. Every member chooses a 3–24 character `[A-Za-z0-9_]` alias, unique case-insensitively inside that room. Each room has independently generated member keys. Removal retains the chosen alias reservation; account deletion removes its private identity record.

Public directory entries show title, description, category, avatar and member count without a roster. Private entries remain absent for outsiders. Public `join {room_id,alias,member_avatar}`, private `join_code {invite_code,alias,member_avatar}`, and invited `accept {room_id,alias,member_avatar}` establish membership explicitly. A repeated acceptance preserves the original chosen profile; changes use `profile {room_id,alias,member_avatar}`. Accepted members can read past group messages. A pending request exposes no messages, attachments, roster, typing, or unread activity.

The owner sends `invite {room_id,username}` using a privately resolved account username; unknown, blocked or banned targets return an explicit error. A successful invite appears in the recipient’s Requests. Owner-only `pending` contains the account handles the owner addressed plus scoped `invitation_key` values; these do not appear in ordinary rosters or messages. `revoke {room_id,invitation_key}` is repeat-safe. `decline {room_id}` is repeat-safe and begins a 24-hour reinvitation cooldown even for an old invitation. Invitee identity is not chosen by the owner.

Accepted roster entries contain `alias`, preset `avatar`, scoped `member_key`, `is_me`, role/status (the compatibility `username` field also contains only the alias). Snapshot fields use camelCase `memberKey/isMe`; group metadata adds `avatar/category/myAlias/myAvatar`. Group message authors, typing and game players use group aliases. Removed authors display Former member; generated historical game invitation text is sanitized to remove old account handles. Ordinary user-authored text is preserved.

Limits remain 200 accepted members per community, 30 memberships per account, three new groups per day, and twelve invitation-code attempts per minute. Owner `update` accepts title/description/category/avatar/is_public. `remove/ban/unban/transfer` use `{room_id,member_key}` and reject keys from another room. Other controls include rotate_code, close, and leave. Owners with accepted peers must transfer or close before leaving; a final owner leaving closes the room and revokes pending invitations. Owner blocks remove incompatible nonowners, including preexisting blocks when ownership changes. Owner suspension/deletion closes owned rooms. Database triggers enforce the rules beneath legacy group endpoints. Scoped identity records alone never grant chat, attachment or game access.

Group games require `opponent_member_key` on invitation. Only that accepted member can accept; other accepted members receive a scoped-alias/status card without private game state or match entry. Both chosen players must retain room access. Existing anonymous DM games retain contextual player aliases. The `games` Edge Function computes accepted turns under the recorded rules version.

Regression evidence: `tools/test-group-identities-security.sql` and `tools/test-group-identities.py` cover the complete scoped identity/invitation flow, with the latter also testing actual image and game endpoints. `tools/test-communities-security.sql` retains legacy-route ban/capacity, code-rate and owner lifecycle checks; `tools/test-group-games-security.sql` and `tools/test-group-games.py` retain spectator/turn/revocation checks with scoped opponents. SQL fixtures roll back. Live scripts delete their synthetic accounts and record exact synthetic room IDs in `/tmp` for targeted cleanup; never remove unrelated rooms. Self-export includes only the caller’s group alias/avatar/key with current authorized group metadata, without invitation codes, peer rosters or universal member IDs.


## Personal library and activity inbox

The `social` Edge Function forwards the authenticated actions `library`, `notifications`, `notification.read`, and `notifications.read_all` to the service-only `social_activity` RPC. It validates the same device credential or verified email Auth session as posting and messaging. No client role can read the activity tables or execute this RPC directly.

`library {kind,offset}` supports `posts`, `comments`, and `saved`. Pages contain 50 entries and `hasMore`; `comments` includes the caller's own comments with their post context. `library {kind:"post",post_id}` loads an authorized notification destination independently of the homepage's 150-post window. Post documents reuse the current anonymous-byline, poll, vote and link projection. Active collection pages refresh after mutations and remain retained while a post is open. They never expand the homepage feed. Deleted, blocked, hidden and unavailable adult-community content is filtered server-side.

`notifications` returns up to 100 current items and an unread count. New comments on a member's posts and replies to their comments create private events; authors do not notify themselves. Positive post-score milestones are 1, 10, 25, 50, 100, 250, 500 and 1,000, delivered once per post/milestone even if votes are toggled. Existing historical activity is not backfilled. Deleted or blocked comment/post content disappears from the inbox. Notification text never includes the private account identity of an anonymous commenter.

`notification.read {id}` acknowledges one visible item. `notifications.read_all {ids}` acknowledges only the displayed IDs, leaving concurrently arriving items unread. Receipts belong to the caller and account deletion removes them. The app uses a compact bell popover with a badge and opens post destinations in a sheet. This is an in-app inbox; no push permission is requested.

Announcements use the existing private database-operator workflow, not a client-provided admin flag. `python3 tools/social-admin.py announcements` lists them; `--reviewer <label> publish-announcement --title <title> --body <body> --note <review-note>` produces reviewable SQL (add `--execute` before the command to use an authorized management token). `withdraw-announcement <id> --note <note>` withdraws a notice. Announcements expire after 90 days; publication and withdrawal record the reviewer in the operator audit. No sample announcement is published by the tests.

`tools/test-activity-notifications-security.sql` runs all fixtures and operator announcements in one rolled-back transaction. `tools/test-activity-notifications.py` uses disposable real clients to verify deployed routing, privacy, receipts, collections and revocation, then deletes those accounts. Its exact generated post IDs are saved privately in `/tmp/maroon-activity-test-resources.json` for bounded cleanup. Native regressions live in `ActivityLibraryTests`, `NotificationsServiceTests`, and `ProfileActivityUITests`.

## Shared meme library (`meme.*`)

KLIPY has no upload API, so memes members choose to share live in the private `social-media` bucket as root-level `<uuid>.png|jpg` objects with rows in `social_private.shared_memes`. The `social` function forwards only documented keys to `public.social_memes` (service-role only): `meme.publish` (`data` base64 still image, optional `title` ≤ 80; sanitized like uploads, GIFs rejected, 30 per member per rolling 24 hours), `meme.list` (`page`, optional `query` ≤ 60, 24 newest per page, never the owner or path, excludes removed, banned-owner and blocked-relationship memes), `meme.read` (`meme_id` → authenticated bytes as `media_data`), `meme.report` (`meme_id`, `reason`; one report per member, three distinct reporters hide the meme, a `shared_meme` row lands in `social_private.reports`), and `meme.remove` (owner only). Removal and account deletion queue the object in `storage_deletions` for the hourly worker. Tests: `tools/test-shared-memes.py` (live) and `tools/test-shared-memes-security.sql` (rollback).
