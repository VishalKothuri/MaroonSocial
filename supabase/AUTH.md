# Personal-email login and recovery

Implemented with Supabase Auth's official Swift `Auth` product, pinned to **2.55.3** with the resolved dependency lockfile. The app uses custom Maroon Social SwiftUI screens, with no provider logo or hosted login page. Supabase manages OTP creation/verification, refresh rotation and authentication. Refresh tokens live in device-only Keychain storage; the community cache never contains them.

**Production email delivery is not configured. The server availability gate is false.** The current phones retain their private device credentials. Linking, new personal-email accounts and the native send-code button are unavailable until setup is complete. The real-signed-JWT integration test uses isolated synthetic confirmed Auth fixtures and password sign-in only to test session transport; it is not evidence of email delivery. No user has been marked university-verified by this work.

## Privacy and authorization

Personal email belongs to Supabase Auth, separate from the exact-`@tamu.edu` verifier documented in [VERIFICATION.md](VERIFICATION.md). A confirmed personal-email login never creates a TAMU grant and never proves current enrollment. Operators with privileged Auth/database access can associate these records; this is not operator-unlinkable identity or end-to-end encryption.

Each private Edge feature uses `_shared/social-auth.ts`. With a bearer token, it calls Supabase Auth `/auth/v1/user` to verify that exact token before inspecting its session identifier. The private service-only bridge then checks the live `auth.sessions` row, user confirmation, expiry, private revocation, mapping tombstone and suspension. Neither client-supplied email, user ID, nor editable `user_metadata` authorizes requests. `Authorization` never falls back to a supplied device token if invalid. Public payloads omit personal emails, Auth UUIDs, internal member UUIDs and internal credential hashes.

The social, games, Tag, accepted-DM calls, account controls and mailbox-verification endpoints share this adapter. Random chat retains its separate anonymous guest credential. Private schemas and bridge RPCs are inaccessible to `anon` and `authenticated`; only server credentials may invoke the bridge. No server key is in the app.

Linking requires both a verified live Auth session and the original device credential in the same request. It preserves the member/content/settings/ban and rotates the old device credential. The old hash is retained only inside the private mapping for idempotent acknowledgement recovery. A persisted link intent retries after relaunch; a different Auth user cannot claim the same account. Normal startup never silently registers a replacement account when a session expires. Existing email accounts can recover by entering another OTP and leaving the new-username field blank.

Logout immediately adds the session to the private denylist and calls Supabase Auth logout for refresh-token revocation, then clears Keychain and the private local cache. Database-managed Auth permissions do not allow direct session deletion; there is no definer escalation. Cached access JWTs are rejected by every feature immediately. An offline logout retains a retryable session; confirmed revoked sessions can be cleared locally.

Account deletion saves a random 256-bit receipt in Keychain before the request. The server stores only its SHA-256 hash. Member deletion tombstones the Auth mapping, marks the receipt, revokes access and queues Auth-user removal. The receipt lets a relaunched client confirm deletion even after Auth tokens are revoked or the response is lost. It cannot read user data. The endpoint rate-limits receipt checks by a salted network hash. Immediate cleanup and the existing hourly campus refresh worker retry leased Auth-user deletions. Credentials, addresses, OTPs and receipt secrets are never logged.

## Owner setup before enabling

1. Create/configure the chosen free transactional sender account and verify the owned `maroonsocial.chat` domain using the provider's exact DNS records. Domain ownership alone is insufficient; do not invent SMTP credentials or DNS values.
2. Configure Supabase Auth custom SMTP with that provider's verified sender. Its default SMTP is limited to project-team recipients and is unsuitable for public login. No provider account was created, paid plan selected or SMTP secret fabricated here.
3. In Supabase Auth, enable email confirmations, refresh rotation, a 15-minute JWT lifetime, a 10-minute six-digit OTP, and at least a 60-second resend interval. Set appropriate provider/project quotas. Review abuse controls before public launch. Local `config.toml` contains the intended settings but does not change hosted settings by itself.
4. Set both Confirm signup and Magic Link templates to the branded `templates/login-code.html`, using `{{ .Token }}`. A confirmation URL alone cannot drive the app's typed-code flow. Set the project site URL to the owned HTTPS domain when its site is configured; this flow does not require an OAuth callback or universal-link entitlement.
5. Confirm real delivery, wrong/expired/replayed code rejection, refresh, second-device recovery, logout and deletion with an owner's test mailbox. Confirm the sender DNS and quotas first. Do not describe synthetic-token tests as a delivered-email test.
6. Only then, using privileged operator SQL, update `social_auth_private.settings` to `enabled=true, stage='ready'` for `singleton=true`. The app checks this gate before sending a code. Roll it back to false to stop new linking/registration while preserving existing mapped users' access.

The gate is an app/backend rollout control, not a substitute for Supabase Auth's own rate limits and signup settings. The public Auth API must also be configured appropriately before launch. Legacy device registration remains available for the current development phones; disable it as a separately reviewed launch migration only after recovery is proven.

## Verification

- `tools/test-social-auth-security.sql`: service-role rollback tests for mappings, sessions, gates, two-credential linking, bans, tombstones, receipts, cleanup leases and immediate logout revocation.
- `tools/test-social-auth-adapter.ts`: isolated HTTP adapter tests, including invalid bearer plus valid legacy credential (no fallback), verified-subject/session binding, revoked sessions and sanitized errors.
- `tools/test-email-auth.py`: real Supabase-signed JWTs from isolated synthetic Auth fixtures; two-client shared data, refresh/logout, cross-feature revocation and provider account deletion. Prepare and clean only its exact fixture IDs via the privileged connector. It never enables the global gate or sends email.
- `EmailAuthServiceTests` and `SocialServiceTests`: disabled-delivery behavior, resend/wrong-code state, late OTP/logout and refresh races, secure deletion acknowledgement recovery, idempotent link recovery and no replacement registration.

Use an ad-hoc signed simulator build (`CODE_SIGN_IDENTITY=-`); disabling code signing removes the Keychain entitlement needed by real accounts. UI fixtures inject an unavailable no-op Auth implementation and never touch production Auth Keychain sessions or send email.
