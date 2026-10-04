# Private media, durable compositions, and activity publishing

Implemented October 4, 2026. All endpoints use the shared authenticated social adapter; database RPCs are service-role-only invoker functions with fixed empty search paths. The four new private activity tables and community photo table have RLS and explicit service-role policies. The security advisor returned no notices after these migrations.

## Video and photographs

Native video preparation accepts at most 100 MB / 60 seconds and emits an MP4 under 5 MB, using 720p then 480p export. A fresh AVMutableComposition copies media tracks, which removes source QuickTime location metadata; simply setting exporter metadata to empty did not remove it in testing. The native test checks the actual output metadata, dimensions, duration and thumbnail. The picker never captures device media without the user's selection.

`social attachment.upload` supports `kind:video` and bounded, self-contained H.264/AAC MP4. The Edge parser checks MP4 boxes, duration, dimensions, codec, chunk locations and external references and zeros metadata boxes without changing sample offsets. Media remains in the private `social-media` bucket. Native downloads require current attachment authorization; playback uses a protected temporary file which is removed on disappearance, and pauses on background. The feed/chat shows an explicit play control and thumbnail.

`group-photos` accepts read/upload/remove with room_id and scope group/member. Member targets use room-scoped member_key (or self); usernames/private universal IDs are not accepted as the photo target. Only accepted members may read member photos, only self can change a member photo, and only the current group owner changes the cover. A legitimate invite preview can show the cover without exposing member photos/history. Photo attachments have a separate purpose so ordinary chat media cannot be repurposed. Server-side JPEG decoding/re-encoding strips metadata and bounds dimensions. Replaced/removed objects enter the existing private Storage deletion queue. A bounded memory-only cache coalesces repeated avatars; its scope includes the local account, room/member, revision and returned attachment ID. Snapshot membership/roster changes immediately hide and evict affected pixels, including formerly joined public covers, before a fresh authorization read. Visible foreground avatars refresh after 30 seconds.

`room-preferences` get/set supports hours 0,1,8,24,168,-1 (unmute, durations, indefinite). It requires an accepted membership and current room access. `room_members.muted_until` affects push delivery only; it does not suppress inbox messages/unread counts.

## Drafts and sending

A protected atomic document persists post and chat composition fields, poll/link/tags, compressed media, reply targets, and idempotency identifiers. Plan and organization-promotion drafts use the same store. Recipient-scoped requests, nested replies, group creation (including partial invitation/photo acknowledgements) and meme captions/photos are also restored. Group join/identity-edit consent forms do not auto-restore or auto-submit membership actions. It is excluded from backup and bound to a random local account cache owner; account reset replaces that owner and clears the document. Fixture launches use the isolated fixture cache. Every composer retains its original account owner; imperative saves/deletes reject an old owner, and delayed social responses cannot apply to a replacement account. Stable media identities keep a recomputed draft binding from producing spurious edits. Explicit discard removes the persisted copy.

The outbox persists each message before trying the network, stores an upload acknowledgement before sending, and removes it only after server acknowledgement. It rechecks membership after a successful foreground refresh. Transport failures retry with bounded backoff; authorization/validation failures require explicit retry or cancellation. Messages do not send while the app is closed. Inbox > New conversation > Unsent messages can review all queued messages, including a room that is no longer accessible. Queue/draft/media limits reject new content without silently dropping old messages. Post publication keeps its nonce/resource/upload acknowledgement across relaunch, so retrying an interrupted attachment resumes the same post.

## Recurring study and organization promotions

`activity-plans` forwards these actions to `public.activity_plans`:

- `series.create`: nonce, title, place, starts (epoch), weeks (2–8), capacity (2–100), details, optional course and approval_required. One transaction creates all activity rooms and host memberships. Meetings preserve America/Chicago wall-clock time through DST; nonexistent clock times are rejected. Twenty meetings per host per day. Identical nonce replay returns the same IDs; changing the payload under that nonce is a conflict.
- `series.info`: activity_id. Returns is_series, can_manage and ordered occurrences with epoch starts/cancelled. Attendees join meetings separately through existing canonical activity actions.
- `series.cancel_future`: activity_id. Host only; closes future, uncancelled meeting rooms through the existing activity cancellation flow. Past meetings remain.
- `promotion.create`: organization_id, nonce, title, place, starts, capacity, details. Requires current admin membership in a verified organization. It uses the existing organization publication flow and returns a stable activity_id. Public bylines remain the organization name, not the administrator account.
- `poster.upload/read/remove`: activity_id plus JPEG data for upload. Only verified current admins write; eligible members may read a noncancelled promotion with existing host block/ban gates. The private upload has purpose organization_poster, bounds 2 MB, decodes/re-encodes to at most 1600 pixels, and never exposes a public Storage URL.

The organization composer offers a poster, complete preview, explicit publish, local draft saving, and a retry state that preserves an already-published event when only the poster failed. Existing organization verification gates remain in place.

## Evidence

- Parent native run: VideoCompressionTests 2, GroupPhotoServiceTests 3, DurableCompositionsTests 5 passed, along with the full native checkpoint. ActivityPlansServiceTests 4 source-ready at this document's update; parent owns the next run.
- `tools/test-group-photos-security.sql` and `tools/test-activity-plans-security.sql`: rollback suites passed. Checks include pending/outsider/private access, scoped identities, ownership, purpose isolation, nonce conflict, DST, cancellation, verified admin authority, block gates and direct client grants.
- `tools/test-private-media.py`: real host-generated AVFoundation MP4 and JPEG upload/read passed, including pending/outsider denial, duplicate send, metadata removal, leave revocation, mute/unmute and photo removal. Log: `build/private-media-e2e.log`.
- `tools/test-activity-plans.py`: shared three-meeting creation/visibility, host-only cancel, idempotent verified-org promotion and real poster upload/read/removal passed. Log: `build/activity-plans-e2e.log`.
- These two HTTP suites used only synthetic members provisioned without consuming signup limits; all five accounts were deleted, and the five recorded closed synthetic rooms plus the single synthetic organization were removed by exact ID/name checks. No real account/community was modified.
- `tools/make-synthetic-video.swift` creates only synthetic pixels on the host; this is API/codec evidence, not physical-camera or on-device playback UX evidence. Parent owns simulator and visual testing. Physical-device background behavior and APNs delivery require separate verification.
- Storage cleanup accepts generated UUID `.mp4` paths as well as images; all 10 retention helper tests passed, including real MP4-path validation, HTTP failure retention, bounded batches and no ACK before deletion. `refresh-campus` was redeployed with this helper.
- GroupPhotoCacheTests 5 source-ready cover request coalescing, photo revision refresh, accepted-roster/account isolation, invited cover/member separation, cancelled late responses, and public cover reauthorization after removal. Parent owns the native run.

The newest draft pass adds AppStoreAccountBoundaryTests (three delayed success/error/account-deletion response cases), four additional DurableCompositionsTests (owner enforcement, partial group recovery, recipient fingerprint isolation, scoped reply/request/meme relaunch and discard), and DurableDraftsUITests (two explicit-save/relaunch journeys). These sources parse; they await the parent-run integrated native/UI checks and are not reported as passed here.
