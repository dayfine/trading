# Phase 1.1 — EODHD Fundamentals tier verification (2026-05-16)

Per the 4-item verification checklist in
`dev/status/data-foundations.md` §"Blocking Refactors" and the dispatch
brief in `dev/notes/next-session-priorities-2026-05-16.md` §Phase 1.1.
Zero-code research dispatch — no implementation changes.

## TL;DR — verdict FAIL

**Our current EODHD subscription does NOT include the Fundamentals
endpoint.** Phase 1.1 cannot proceed as scoped without either a tier
upgrade or a fallback source. The 5-event survivorship-correct
spot-check could not be executed (the endpoint returns 403 across the
board). Recommend: pivot Phase 1.1 to the Unicorn Bay
"S&P / Dow Jones Indices Historical Constituents Data API"
marketplace add-on ($29.99/mo) — same EODHD account, no new auth —
**or** drop Phase 1.1 and lean on Phase 1.4 (IWV scrape) as the
primary survivorship-correct source.

## What we have

- Account: paid `subscriptionType:"monthly"`, 100k req/day rate limit,
  500 extra-limit credits. (From `GET /api/user?api_token=...`.)
- EOD price endpoint (`/api/eod/...`) — works, HTTP 200.
- Fundamentals endpoint (`/api/fundamentals/...`) — **HTTP 403 across
  every variant tried**. Body: `Forbidden. Please contact
  support@eodhistoricaldata.com`.
- Historical Market Cap endpoint — HTTP 403 with explicit message:
  `Forbidden. You have no access to Historical Market Cap Data Feed.`
- Bulk Fundamentals endpoint — HTTP 403.

These three 403s together are conclusive: the entire Fundamentals
tier (which the
[EODHD pricing page](https://eodhd.com/financial-apis/stock-etfs-fundamental-data-feeds/)
gates as `Fundamentals Data Feed` $59.99/mo or `All-In-One` €99.99/mo)
is not on our plan.

## Probes run

All probes used the existing `EODHD_API_KEY` from the host environment.
Token never logged or committed. Response bodies written to `/tmp/` and
not retained.

| # | URL | HTTP | Result |
|---|---|---|---|
| 1 | `/api/fundamentals/GSPC.INDX?historical=1&fmt=json` | 403 | Forbidden |
| 2 | `/api/fundamentals/GSPC.INDX?fmt=json` (no historical) | 403 | Forbidden |
| 3 | `/api/fundamentals/AAPL.US?fmt=json&filter=General` | 403 | Forbidden |
| 4 | `/api/fundamentals/GSPC.INDX` (no params) | 403 | Forbidden |
| 5 | `/api/fundamentals/MCD.US` | 403 | Forbidden |
| 6 | `/api/eod/AAPL.US?from=2026-05-01&to=2026-05-10` | 200 | OK (sanity-check baseline) |
| 7 | `/api/user` | 200 | Returns `subscriptionType:"monthly"`, 100k/day |
| 8 | `/api/historical-market-cap/AAPL.US` | 403 | `Forbidden. You have no access to Historical Market Cap Data Feed.` |
| 9 | `/api/bulk-fundamentals/US?limit=1` | 403 | Forbidden |
| 10 | `eodhd.com/api/fundamentals/GSPC.INDX?historical=1` (alt host) | 403 | Forbidden |

## 5-event spot-check — NOT RUN (blocked on 403)

The intended events were:

| Ticker | Expected event | Expected field | Result |
|---|---|---|---|
| LEH | Delisted 2008-09-15 | `EndDate ~ 2008-09`, `IsDelisted: true` | NOT_RUN |
| KODK | Removed from SP500 2009-12-04 | `EndDate ~ 2009-12` | NOT_RUN |
| FB / META | Added to SP500 2013-12-23 | `StartDate ~ 2013-12` | NOT_RUN |
| TSLA | Added to SP500 2020-12-21 | `StartDate ~ 2020-12` | NOT_RUN |
| GE | Removed from SP500 2018-06-26 | `EndDate ~ 2018-06` | NOT_RUN |

## Earliest-StartDate test — NOT RUN (blocked on 403)

The 2026-05-16 vendor pivot doc (and the data-foundations track
description) claim `HistoricalTickerComponents` returns data from
Jan 2000. **This was not verified.** EODHD's own marketing page
states constituent tracking goes back to "the 1960s, though the most
complete data starts from 2016" — substantially worse than 2000 for
SP500 if we ever get access. This caveat must be re-tested before
any 2010-baseline re-pin decisions in Phase 1.3.

## Schema caveat — the assumed field name may be wrong

The vendor-pivot doc and `dev/status/data-foundations.md` Track 1
table both assume the JSON path is
`HistoricalTickerComponents` with per-row
`{ Code, Name, StartDate, EndDate, IsActiveNow, IsDelisted }`.

The EODHD public fundamentals docs (per WebFetch of
`/financial-apis/stock-etfs-fundamental-data-feeds/`) describe a
different shape: two sections, `Components` (current) and
`HistoricalComponents` (snapshots keyed by date), each row carrying
`{ Code, Exchange, Name, Sector, Industry, Weight }` (no
`StartDate`/`EndDate`/`IsDelisted` per row). If correct, this means
the basic endpoint **gives point-in-time snapshots, not per-symbol
tenure intervals** — usable but needs different downstream code
(diff snapshots to reconstruct entries / exits, same algorithm
Phase 1.4 plans to use for IWV).

If we eventually buy Fundamentals access we must re-verify the
schema before writing the parser; the priority-doc field list may
be from an older API version.

## Subscription-tier verdict — FAIL

Three independent signals confirm:
- HTTP 403 on every Fundamentals URL variant (including bulk and
  historical-market-cap with explicit denial message).
- Successful `/api/user` returns a `monthly` paid plan but does NOT
  include the Fundamentals add-on flag — the response only carries
  generic account info, not entitlements.
- Successful `/api/eod` for the same account confirms the token is
  valid and the 403s are scope, not auth.

EODHD's pricing page gates the Fundamentals API at:
- **Fundamentals Data Feed**: $59.99/mo (Fundamentals only).
- **All-In-One**: €99.99/mo (Fundamentals + EOD + Live + Options).

Our current plan is the EOD-only tier ($19.99/mo on the public page,
unverified for our specific account).

## Marketplace alternative — Unicorn Bay product

The most promising lower-cost alternative is the third-party
"S&P and Dow Jones: Indices Historical Constituents Data API"
listed on the EODHD marketplace under Unicorn Bay
(`eodhd.com/marketplace/unicornbay/spgloical`):

- **Price**: $29.99/mo regular; $50 for first 3 months promo.
- **Coverage**: "up to 12 years of historical and current data" for
  S&P 500 / 600 / 100 / 400 + 20 industries. **12 years is
  2014-present** — does not cover the 2010 baseline cleanly, and
  far short of the 2000-present claim in the vendor-pivot doc.
- **Access**: standalone marketplace purchase, separate from main
  EODHD subscription. Same account / billing surface.
- **Schema**: not published on the marketplace page (404 on the
  product detail link via WebFetch); would need a sales-team email
  or trial.

## Recommendation

Two viable paths; recommend **Option B** (skip Phase 1.1, lean on
Phase 1.4) for the next session.

### Option A — buy Fundamentals Data Feed tier ($59.99/mo)

- **Pros**: same EODHD client / Docker stack; covers index
  constituent history (subject to the schema caveat above) plus
  fundamentals for any future earnings/RS-vs-fundamentals work; the
  $720/yr is rounding-error vs the time saved.
- **Cons**: must re-verify the schema before writing the parser;
  the 2000-present claim is suspect (EODHD docs hedge to "complete
  from 2016"); doesn't fix the 1996-1999 tail; not strictly the
  cheapest path.
- **Next step**: user upgrades subscription; re-run the 5-event
  spot-check in 30 minutes once the tier flips.

### Option B — drop Phase 1.1; Phase 1.4 (IWV scrape) becomes the primary survivorship-correct source

- **Pros**: zero extra cost, no auth, OCaml-native cohttp client;
  IWV covers 2006-present which is wider than the Unicorn Bay 12y
  window; we were going to write Phase 1.4 anyway, so this just
  reorders the work; IWV is Russell 3000 (3000 names) which is
  strictly broader than SP500 (500 names) — every SP500 member is
  also in Russell 3000.
- **Cons**: 2006-2010 may have less reliable iShares snapshots
  (need to spot-curl an early date); SP500 baseline re-pin
  (Phase 1.3) becomes "Russell-3000 baseline" — a different
  experiment, would need fresh sign-off.
- **Next step**: dispatch feat-data on Phase 1.4 plan-first; verify
  the IWV URL pattern works for 2010-01-04 + 2006-Q3 with a single
  spot-curl before committing.

### Option C — Unicorn Bay add-on ($29.99/mo)

- **Pros**: cheapest paid path; explicitly built for survivorship-
  correct index history.
- **Cons**: 12y coverage only (~2014-present, no 2010 baseline);
  schema unverified; third-party reliability.
- **Recommendation**: do NOT buy without seeing the schema first.
  Email the EODHD marketplace contact to request a sample response
  before committing.

## What to update upstream

- `dev/status/data-foundations.md` §"Blocking Refactors" — flip the
  Phase 1.1 verification checklist's first item from "Pending" to
  "Verified FAIL — subscription tier does not include Fundamentals;
  see this doc". Other 3 items now NOT_RUN.
- `dev/notes/next-session-priorities-2026-05-16.md` — supersede the
  "1.1 verification → green → dispatch feat-data" arrow with one of
  the three recommended branches above (preferably Option B).
- `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` —
  doesn't exist yet in the repo (referenced but unauthored); if it
  gets authored, it should incorporate this verification result and
  the Unicorn Bay product as a separately-priced option.

## Reproducibility

Token sourced from host env `$EODHD_API_KEY` (never echoed). All probes
executed via `curl --max-time 30 -s -w "HTTP_STATUS:%{http_code}\n" -o
/tmp/<file>.json`. Response bodies written under `/tmp/` and not
committed (vendor ToS). Total API budget consumed: ~10 requests against
the 100k/day cap.

## Constraints respected

- No Python (per `.claude/rules/no-python.md`).
- No response JSON or HTTP logs committed.
- API token only read from env; never logged or printed.
- Workspace under `.claude/worktrees/agent-...` per
  `memory/project_jj_workspace_docker_path.md` (not `/tmp/` which is
  invisible to docker — though docker wasn't needed for any probe;
  all curl ran on the host).

## 2026-05-16 follow-up — Option B chosen; no tier upgrade pursued

Per `dev/decisions.md` 2026-05-16 §"Option B pivot — IWV scrape as
primary, EODHD Fundamentals retired", the recommendation from the
verification doc's §"Option B — drop Phase 1.1; Phase 1.4 (IWV
scrape) becomes the primary survivorship-correct source" was
selected. No Fundamentals tier upgrade was purchased; the Unicorn
Bay marketplace add-on was likewise rejected.

Phase 1.4 verification (PR #1108) returned green the same day —
iShares IWV URL pattern works HTTP 200 across the full 2006-09-29 →
2026-05-08 range with byte-identical headers. Full transcript in
`dev/notes/phase1.4-iwv-url-probe-2026-05-16.md`.

Phase 1.1 is now PARKED indefinitely. If the strategy ever needs
the 2000-2005 SP500 tail that IWV cannot cover, the cheapest revival
path is still the standalone Fundamentals Data Feed tier ($59.99/mo),
not the marketplace Unicorn Bay add-on (12y coverage doesn't reach
back further than IWV does). At that point this doc's
§"Schema caveat" must be re-verified before any parser work.
