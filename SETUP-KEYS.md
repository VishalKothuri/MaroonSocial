# Keys and pending setup

Everything below is already integrated in code. Each key switches a feature on; until it is set, the app keeps working on the fallback listed. Secrets go into the Supabase project with the CLI (never into the repository):

```bash
supabase secrets set NAME=value --project-ref myxbghfbapbfffkpndwo
```

## Keys to provide

| Secret | Where to get it | Turns on | Fallback while unset |
|---|---|---|---|
| `APNS_TEAM_ID` | Apple Developer → Membership (10 characters) | Push notifications | Pushes are skipped; in-app badges still update |
| `APNS_KEY_ID` | Apple Developer → Keys → the APNs key (10 characters) | Push notifications | Same as above |
| `APNS_PRIVATE_KEY` | The downloaded `.p8` file, full PEM text including the BEGIN/END lines | Push notifications | Same as above |
| `APNS_TOPIC` | The app bundle id, `app.maroonsocial.MaroonSocial` | Push notifications | Same as above |
| `APNS_ALLOWED_ENVIRONMENTS` | `sandbox,production` (or only `sandbox` while testing) | Push environments | Same as above |
| `PUSH_WORKER_SECRET` | Any long random string you generate | The push worker that drains the queue | Queue is not drained |
| `CALL_RELAY_ENABLED` | Set to `true` once the two TURN values below exist | Cloudflare TURN relay for calls | Calls use STUN-only peer-to-peer; some networks cannot connect |
| `TURN_KEY_ID` | Cloudflare dashboard → Realtime → TURN → create a TURN key | TURN credentials | Same as above |
| `TURN_API_TOKEN` | Shown once when the TURN key is created | TURN credentials | Same as above |
| `MEDIA_BACKEND` | Set to `r2` once the four R2 values below exist | New uploads go to Cloudflare R2 | Media stays in Supabase Storage (today's behaviour) |
| `R2_ACCOUNT_ID` | Cloudflare dashboard → R2 → account id | R2 storage | Same as above |
| `R2_ACCESS_KEY_ID` | R2 → Manage API tokens → create token with Object Read & Write on the bucket | R2 storage | Same as above |
| `R2_SECRET_ACCESS_KEY` | Shown once with the token above | R2 storage | Same as above |
| `R2_BUCKET` | The bucket name you create in R2 | R2 storage | Same as above |
| `R2_PRIVATE_BUCKET` (optional) | A second R2 bucket for chat and DM media; never attach a custom domain to it | Chat and DM media on R2 | Chat and DM media stays on Supabase Storage |
| `R2_PUBLIC_BASE_URL` (optional) | The custom domain you attach to `R2_BUCKET` only, e.g. `https://media.<your domain>` | CDN delivery for post media | Post media is served through 24-hour signed URLs without the CDN |
| `R2_CDN_ZONE_ID` (with the CDN) | Cloudflare dashboard → the domain's zone id | Purging deleted post media from the CDN | CDN URLs are not issued |
| `R2_CDN_PURGE_TOKEN` (with the CDN) | Cloudflare API token with only Zone → Cache Purge on that zone | Purging deleted post media from the CDN | CDN URLs are not issued |
| `REALTIME_JWT_SECRET` | Supabase dashboard → Project Settings → API → JWT secret (or an imported signing key). Set it only after `20261005200000_realtime_pokes.sql` and `20261005210000_realtime_pokes_review_fixes.sql` are applied | Realtime pokes for chats, inbox and game-day chat | Chats and inbox keep polling every few seconds |
| `CF_REALTIME_APP_ID`, `CF_REALTIME_APP_SECRET` (later) | Cloudflare Realtime → SFU app | SFU for group calls | Group calls keep the current path |
| `EMAIL_PROVIDER` | `brevo` (default) or `resend` | Sends TAMU mailbox verification and recovery codes | Verification and email recovery show "unavailable" |
| `BREVO_API_KEY` or `RESEND_API_KEY` | Brevo → SMTP & API → API keys, or Resend → API Keys (match `EMAIL_PROVIDER`) | Email delivery | Same as above |
| `EMAIL_SENDER` | A sender address verified with that provider, e.g. `verify@<your domain>` | Email delivery | Same as above |
| `VERIFICATION_HMAC_SECRET` | Any long random string you generate (e.g. `openssl rand -hex 32`) | Hashes verification codes | Same as above |

Order for R2: apply the revocation migration, set the four `R2_*` credentials (and `R2_PRIVATE_BUCKET` if chats should use R2), then `MEDIA_BACKEND=r2`, and redeploy the functions. The CDN comes last: zone id and purge token first, then `R2_PUBLIC_BASE_URL`. Switching `MEDIA_BACKEND` back off is safe because every object records its backend in its path.

App-side file (not a Supabase secret): image search in the post composer uses Google Programmable Search. Copy `MaroonSocial/Resources/ImageSearch.example.json` to `MaroonSocial/Resources/ImageSearch.json` (gitignored) and fill `apiKey` (Google Cloud → Custom Search JSON API key) and `searchEngineID` (programmablesearchengine.google.com, image search on). Until then the image search sheet shows that search is unavailable. `Klipy.json` is already in place.

Dashboard-only setup (no secret): create the R2 bucket, attach the custom domain, add a Cache Rule "Eligible for cache / respect origin" on that hostname, and enable Smart Tiered Cache. After Realtime is confirmed working, turn off Realtime "Allow public access" in Supabase.

## Database changes waiting for approval

Schema changes are applied by the owner. These migration files are in `supabase/migrations/` but are not yet on the database (the live history ends at `20261005135428`). Apply them in this order; `supabase db push` uses filename order:

| Order | File | What it enables | Verify after applying |
|---|---|---|---|
| 1 | `20261005160000_feed_sync_incremental.sql` | Incremental feed (only new or changed posts every few seconds), 30-post pages with infinite scroll, "Load earlier replies", per-chat message catch-up | Apply together with the next file, in this order |
| 2 | `20261005170000_feed_sync_review_fixes.sql` | Review fixes for the file above: no change clock that could link anonymous posts to accounts, per-member resync instead, message edits/reactions/unsends in the catch-up, input range checks. **Corrected in place twice on October 6** (it had never been applied): `messages.changed_at` is now added before `touch_messages`, which needs it, and votes or poll votes on an already-deleted post no longer move that post's change marker (deleting an account used to move its long-deleted posts) | `python3 tools/test-feed-sync.py`, then `psql … -f tools/test-feed-sync-security.sql` |
| 3 | `20261005190000_r2_media_revocation.sql` | Deleted posts and attachments queue their R2 objects for deletion and CDN purge. Apply it before setting `MEDIA_BACKEND=r2` | `psql … -f tools/test-r2-media-revocation.sql` |
| 4 | `20261005200000_realtime_pokes.sql` | Realtime pokes for chats, the inbox and game-day chat (id-only signals; the app then fetches the new messages) | Apply together with the next file, in this order |
| 5 | `20261005210000_realtime_pokes_review_fixes.sql` | Review fixes for the file above: pending group invitees get no message pokes, receiving needs the same TAMU verification as the app, and calls, DM answers, membership and room changes poke open chats | `psql … -f tools/test-realtime-security.sql`, then `EXPECT_REALTIME=1 python3 tools/test-realtime-token.py` after setting `REALTIME_JWT_SECRET` |
| 6 | `20261006100000_gateway_activity_lock_alias.sql` | **Fixes a live bug:** editing, approving or cancelling a plan currently fails with "column reference r.id is ambiguous" | `psql … -f tools/test-activity-plans-security.sql` and `tools/test-social-security.sql` |
| 7 | `20261006101000_external_media_optional_feed_community.sql` | **Fixes a live bug:** attaching KLIPY media without `feed_community` (older callers) fails with "Choose an available community." | `psql … -f tools/test-klipy-security.sql` |
| 8 | `20261006200000_post_topics.sql` | Topic catalog (8 launch topics active, 6 reserve topics off), one optional topic per post, `topic` in every post read, topic in the data export and in post reports, and a backfill that gives existing posts a topic from their tags | Apply together with the next two files, in this order |
| 9 | `20261006210000_topic_feed_sync.sql` | Topic pages, deltas and resyncs (`topic` on `feed.page`, `feed.delta`, `feed.posts`), `topics.list` with 7-day counts, `post.topic` for authors, and the operator commands `topic.set`, `topic.disable` and `topic.enable` | — |
| 10 | `20261006220000_post_text_filter.sql` | A whole-word denylist (stored as hashes; extend it with the operator's `filter.add` / `filter.remove`) for posts and replies, and at most 5 new posts per 15 minutes on top of the 10-per-minute burst | `psql … -f tools/test-topics-security.sql`, then deploy the `social` function and run `python3 tools/test-topics.py` |

Dependencies:

- Files 6 and 7 apply cleanly straight onto the live database, with or without files 1–5. They fix bugs users can hit today.
- Apply the two feed-sync files (1 and 2) back to back and never the first one alone: on its own it would publish a raw change clock that the second file removes.
- The realtime files (4 and 5) depend on the two feed-sync files.
- The topic files (8–10) depend on the two feed-sync files (they patch `post_json` and `feed_sync`) and on file 6 (they patch the current gateway text).
- After the topic files are applied, deploy the `social` edge function (it adds `topics.list` and `post.topic` to its action list): `supabase functions deploy social`. Until then the app keeps its feed without topics.
- After file 10, a member who creates a sixth post within 15 minutes gets "Take a moment before posting again." The runners `tools/test-feed-sync.py`, `tools/test-post-extras.py` and `tools/test-reposts.py` spread their fixture posts so that each synthetic account stays within 5 posts per 15 minutes (`test-feed-sync.py` uses a fifth account), so they pass with file 10 applied (checked on the local stack).
- The `psql … -f tools/test-*-security.sql` checks in the last column run inside one transaction that rolls back, and change nothing outside it, so they are safe to run once as the database owner after applying. `tools/test-topics-plan.sql` is the exception: its query-plan check needs `ANALYZE`, whose table estimates survive the rollback, so it runs only on a local stack (see TESTING.md).

Apply with the Supabase CLI from the repository root. Link once, mark the course catalog file as applied (its data is on the database, but the history does not list `20261004012836`, so `db push` would try to run it again), preview, then push. `db push` applies every local migration the database does not have yet and asks for the database password:

```bash
supabase link --project-ref myxbghfbapbfffkpndwo
```

```bash
supabase migration repair --status applied 20261004012836 --linked
```

```bash
supabase db push --linked --dry-run
```

```bash
supabase db push --linked
```

The dry run should list only the pending files above. You can also paste a file's contents into the Supabase SQL editor, in the same order.

Until they are applied, the app detects the older server and keeps its previous full-refresh behaviour, so nothing breaks.
