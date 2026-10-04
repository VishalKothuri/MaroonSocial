# Sports data integration

The app now has Campus → Scores and a sports-event score header. The shared `sports` Edge endpoint authenticates through the same social identity adapter and `social_private.require_member`, including bans and request limits. The service-role-only `sports_cache` RPC leases one refresh for the whole project every two minutes, with a 30-second failed-attempt backoff. It returns the last factual snapshot when a provider fails, preserving its original timestamp. No credentials or private identities enter the cached sports payload.

## Connected sources

- [Texas A&M Athletics public live-events widget](https://static.12thman.com/widgets/live-home/index.html) uses the CORS visitor endpoint `https://12thman.com/website-api/schedule-events`. We request bounded upcoming and past results with `schedule.sport`, `scheduleEventLinks` and `scheduleEventResult`. Published win/loss scores are mapped to A&M from the outcome, not home/away order. The source status `as_scheduled` never becomes `live` based on our clock. Official result, schedule and StatBroadcast links are allowlisted HTTPS URLs. The app attributes 12thman.com and displays the fetch time.
- [Kalshi public market-data documentation](https://docs.kalshi.com/getting_started/quick_start_market_data) describes unauthenticated public quote access. We request the college-football game series `KXNCAAFGAME`, then require exact `Texas A&M` winner identity, opponent and Chicago calendar day before showing a contract. This excludes East Texas A&M and ambiguous matches. Only actual bid/ask quantities or an actual previous trade are displayed. These are **market prices per $1 contract**, not a statistical model's win probability. There is no trading, account connection or order placement.

Provider responses have 10-second deadlines and a 3 MB cap; the normalized cache is capped at 200 games/512 KB. No sports media/assets are copied. The official visitor API is publicly readable, but that is not a blanket commercial redistribution license; review provider terms for the production distribution model and higher request volume.

## Still requires a provider

The official widget currently has its live-score API unset (`LIVE_API = ""`). The visitor schedule feed is not evidence of live ball position, drive state, possession, game clock or a probability model. Accordingly `livePlayAvailable` is false, the app does not invent an animated field/clock, and play-by-play opens the official provider page.

[SportsDataIO's College Football API](https://sportsdata.io/developers/api-documentation/ncaa-football) offers licensed score and play-by-play feeds with a subscription/API key. A licensed provider, key and permitted display terms are needed before adding an in-app ball/drive tracker; no paid service was purchased. A win-probability model would also need its own provider or a documented, calibrated model. Kalshi quotes must keep their market-price label.

## Verification

`deno test tools/test-sports-provider.ts` covers result ownership, unknown/live status, bad URLs/dates, exact market pairing, order quantity, ambiguous games, oversized responses, provider outage and deduplication. `tools/test-sports-live.py` creates one synthetic account and deletes it after checking unauthorized denial, official real results, quotes and shared-cache reuse. The 2026-10-04 run fetched 108 games, 16 numeric final results and 2 exact football quotes. These counts are a recorded test outcome, not constants.

`SportsServiceTests` covers native decoding, market-vs-live separation, safe event matching, refresh coalescing/throttling and retained results after an outage; native execution belongs to the root's integrated build. No physical-device sports UI test has been claimed by this work.
