# TAMU mailbox verification

The `verification` Edge Function and `VerificationService` are implemented. Email sending is currently **disabled**: no provider account, sender, or API key has been supplied. No real verification email has been sent and no real account has been marked verified. The development community remains accessible through device credentials. This module verifies control of an exact `@tamu.edu` mailbox; it does not attest current enrollment, a particular campus, a person's age, or university endorsement. Supabase Auth personal-email login/recovery is not implemented by this module.

## Provider choice, checked October 3–4, 2026

| Provider | Free transactional allowance | Sender requirements |
| --- | --- | --- |
| Brevo | 300/day | Verify an address you control. For a free-email sender, Brevo temporarily substitutes its own transactional sending domain; an owned authenticated domain is the durable recommendation. |
| Resend | 3,000/month and 100/day | To email arbitrary users, verify an owned domain. Its resend.dev test domain only sends to the account owner's email. |
| Mailjet | 6,000/month and 200/day | Verify an owned sender address or domain; Mailjet warns that free-mail sender domains can be rejected or land in spam. |

Sources: [Brevo free plan](https://help.brevo.com/hc/en-us/articles/208589409-About-Brevo-s-pricing-plans), [Brevo temporary sender replacement](https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders), [Brevo sender verification](https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email), [Resend pricing](https://resend.com/pricing), [Resend testing-domain restriction](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain), [Mailjet free quota](https://documentation.mailjet.com/hc/en-us/articles/8625025643803-Mailjet-Subscription-Management), [Mailjet sender validation](https://documentation.mailjet.com/hc/en-us/articles/360042759253-How-to-add-a-sender-address).

Brevo best matches the requested no-purchased-domain preview and higher free daily allowance. Its provider-domain replacement is temporary, not a permanent free custom domain or deliverability guarantee. Resend is also implemented as an alternative when the owner provides an owned domain. Neither provider is an enrollment authority. Account activation, sender verification and provider anti-abuse review still apply; no paid plan or domain was created.

## Owner setup

Keep secrets in Supabase Edge secrets, never Backend.json, Swift source, a checked-in env file, or a chat message containing the value.

| Secret | Value |
| --- | --- |
| EMAIL_PROVIDER | `brevo` (default) or `resend` |
| EMAIL_SENDER | Exact address verified/authorized by the chosen provider. BREVO_SENDER_EMAIL is a legacy fallback. |
| BREVO_API_KEY or RESEND_API_KEY | API credential from the owner's chosen provider account. |
| VERIFICATION_HMAC_SECRET | Independently generated, cryptographically random secret of at least 32 characters. Keep it stable and securely backed up. |

The owner must provide an account they can sign into and a sender they control. For Resend this also needs domain DNS verification; a resend.dev sender cannot verify arbitrary TAMU recipients. Do not guess a sender or university-owned From address. The send adapters use the official [Brevo transactional API](https://developers.brevo.com/reference/send-transac-email) and [Resend email API](https://resend.com/docs/api-reference/emails/send-email).

After configuring secrets, use the app to request and confirm a code at an explicitly authorized real `@tamu.edu` mailbox. Check delivery and spam handling, then test resend, wrong-code lockout and expiry. `enabled=true` only means configuration is present; a successful provider HTTP response only means the provider accepted the email. Actual inbox delivery requires this real test.

Only after the real test and owner decision, enable the private membership gate through the database operator:

```sql
update verification_private.settings set require_verified=true where id=true;
```

It defaults to false and was never enabled outside rollback-only tests. When enabled, unverified/expired accounts receive redacted community snapshots and cannot post, message, use Tag, interact with games, or place accepted-DM calls. Verification, profile editing and account deletion remain accessible. Random guest matching is a separately labeled guest preview and is not an enrollment-gated service. Decide whether to disable that guest mode for a verified-only launch.

## Security and data boundaries

The isolated `verification_private` schema stores challenge IDs, member references, purpose-scoped HMACs, attempt counters and expiry; it has no raw mailbox or raw OTP column. Raw addresses/codes are used transiently by the Edge Function and passed to the email provider. No provider response body, OTP, address or API key is logged by the function. Provider delivery logs, infrastructure logs and backups have their own retention; this does not claim operator unlinkability or deletion from those systems. Schema separation inside one project is not a separately operated verifier.

Codes use Web Crypto random generation and HMAC-SHA256 via the standard Web Crypto API. Each code is bound to the challenge and requesting account, expires in 10 minutes, is usable once, and allows at most 5 incorrect attempts. Incorrect attempts persist even when returning an error. A resend invalidates prior pending codes. Verification binds a mailbox to one current account; a correct code for a mailbox already bound to another account requires owner-assisted recovery. It does not silently transfer an account or bypass a suspension.

The exact lowercase domain is `tamu.edu`; subdomains, lookalike suffixes, other TAMU-system domains and plus aliases are not accepted. Domain policy can be expanded only deliberately. A successful mailbox grant lasts 180 days; expiration requires re-verification, not merely login recovery. A protected mailbox identifier remains while the account exists; account deletion cascades its grant/challenges. Sending abuse records retain protected identifiers for up to 24 hours plus the 5-minute cleanup interval. Expired challenges are purged every 5 minutes; used/cancelled challenge verifiers are erased immediately. A rotation of VERIFICATION_HMAC_SECRET requires a planned migration/re-verification policy because protected mailbox identifiers depend on it.

Send limits: one request/minute, four/hour/account, eight/day/mailbox, 15/hour/network, and a project cap of 250/day for Brevo or 90/day for Resend. Daily capacity reserves room below published free caps; other email usage on the same provider account can still exhaust its allowance. Provider failure cancels the challenge and surfaces an error rather than pretending delivery. Client cancellation prevents delayed network responses from reopening an old code screen.

## Validation and remaining work

`tools/test-verification-security.sql` uses synthetic hashes in a rollback-only transaction and passes private grants/exact domain, sent-only/account binding, persistent five-guess limit, resend cooldown, expiry/replay, content redaction and write enforcement, valid grant/expiry, and account deletion. These tests do not send mail or create real verified users. The social and room-call SQL security suites were rerun after the authentication helper split and passed. Supabase security advisor has no findings.

Four native `VerificationServiceTests` cover unconfigured status, wrong-code state, cancellation of delayed requests, and local expiry. Actual provider delivery remains untested pending owner setup. The stronger blind/unlinkable credential design and personal-email login/recovery from the architecture remain separate work requiring explicit provider choices and specialist review.
