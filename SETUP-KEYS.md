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
| `R2_PUBLIC_BASE_URL` (optional) | The custom domain you attach to the bucket, e.g. `https://media.<your domain>` | CDN delivery for post media | Media is served through short-lived signed URLs without the CDN |
| `REALTIME_JWT_SECRET` | Supabase dashboard → Project Settings → API → JWT secret (or an imported signing key) | Realtime pokes for chats, inbox and game-day chat | Chats and inbox keep polling every few seconds |
| `CF_REALTIME_APP_ID`, `CF_REALTIME_APP_SECRET` (later) | Cloudflare Realtime → SFU app | SFU for group calls | Group calls keep the current path |

Dashboard-only setup (no secret): create the R2 bucket, attach the custom domain, add a Cache Rule "Eligible for cache / respect origin" on that hostname, and enable Smart Tiered Cache. After Realtime is confirmed working, turn off Realtime "Allow public access" in Supabase.

## Database changes waiting for approval

Schema changes are applied by the owner. These migration files are in `supabase/migrations/` but are not yet on the database:

| File | What it enables | Verify after applying |
|---|---|---|
| `20261005160000_feed_sync_incremental.sql` | Incremental feed (only new or changed posts every few seconds), 30-post pages with infinite scroll, "Load earlier replies", per-chat message catch-up | Apply together with the next file, in this order |
| `20261005170000_feed_sync_review_fixes.sql` | Review fixes for the file above: no change clock that could link anonymous posts to accounts, per-member resync instead, message edits/reactions/unsends in the catch-up, input range checks | `python3 tools/test-feed-sync.py`, then `psql … -f tools/test-feed-sync-security.sql` |

Apply the two feed-sync files back to back and never the first one alone: on its own it would publish a raw change clock that the second file removes.

Apply with the Supabase CLI from the repository root. Link once, preview, then push; `db push` applies every local migration the database does not have yet and asks for the database password:

```bash
supabase link --project-ref myxbghfbapbfffkpndwo
```

```bash
supabase db push --linked --dry-run
```

```bash
supabase db push --linked
```

The dry run should list only the pending files above. You can also paste a file's contents into the Supabase SQL editor.

Until they are applied, the app detects the older server and keeps its previous full-refresh behaviour, so nothing breaks.
