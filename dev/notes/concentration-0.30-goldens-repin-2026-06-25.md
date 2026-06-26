# Concentration = 0.30 — long-only goldens re-pin (2026-06-25)

Re-pins the long-only regression goldens from `max_position_pct_long 0.14 → 0.30`
(the production default) so the research basis **matches production**. Authorized by
the user on the back of the broad top-3000 WF-CV ACCEPT
(`2026-06-25-capacity-concentration-broad`). **Not a live-behavior change** — the
canonical default is already 0.30; production already runs it. The goldens were
artificially overriding *down* to 0.14, so they were **mis-stating** production.

## Store resolution (the earlier "data-store landmine", resolved)
Each golden is re-measured against **the store its own validator uses**, both
reproducible locally:
- **sp500 goldens** → committed `test_data` CSV (set `TRADING_DATA_DIR`), the
  `golden-runs-sp500-15y` cron store. Verified: each reproduces its prior 0.14 band
  against test_data before the change.
- **broad goldens** → the delisting-complete warehouse (`--snapshot-dir
  /tmp/snap_top3000_1998_2026`), the #1733/#1738 standard.

The earlier blocker (same golden → 23.5% / 49.1% / ≤30-band across three stores) was
running against the *wrong* store (gitignored `data/`). None of these 8 goldens is in
PR CI (all postsubmit / local-verify), so the re-pin cannot break the PR build.

## The honest per-window picture — 0.30 is regime-dependent

| golden | window | 0.14 → 0.30 return | verdict |
|--------|-------:|-------------------:|---------|
| sp500-2010-2026 | 16y | 340 → **672%** (DD 19→**18%**, Sharpe 0.84→0.92, Calmar 0.49→0.74) | 0.30 dominates |
| sp500-1998-2026 | 28y | 227% (sentinel band) | ✓ |
| decade-2014-2023 | 10y | 95 → **134%** (DD 37→39) | 0.30 better |
| covid-recovery-2020-2024 | 4y | 41 → **53%** (Sharpe 0.46→0.57) | 0.30 better |
| sp500-30y-capacity-1996 | 30y | 952% (sentinel band) | ✓ |
| sp500-2019-2023-long-only | 5y | 26 → 41% (DD 31→**39%**, Calmar ~flat) | wash (return-for-DD) |
| **bull-crash-2015-2020** | 5y | 38 → **10%** (Sharpe 0.47→0.18) | **0.30 hurts** |
| **six-year-2018-2023** | 6y | 19 → **4%** (Sharpe 0.28→0.11) | **0.30 hurts** |

**0.30 helps the long / multi-regime windows (where the broad WF-CV ACCEPT came from)
and the aggregate, but HURTS some short windows** (bull-crash, six-year). This is the
same high-dispersion signature the broad surface showed (σ roughly doubles with
concentration). The ACCEPT is a **broad-aggregate verdict, not a per-window guarantee**
— concentrating capital amplifies the fat tail, which pays off across a full cycle but
can sting in a single short window where the concentrated names underperform.

This is exactly why re-pinning matters: at 0.14 the goldens **overstated** production
on the short windows (showing 38% / 19% when production does 10% / 4%) and
**understated** it on the long windows (340% vs the true 672%). 0.30 is the honest
production picture, warts and all.

## Scope — what was and wasn't touched
**Re-pinned (8, long-only):** `goldens-sp500/sp500-2019-2023-long-only`,
`goldens-sp500-historical/{sp500-1998-2026, sp500-2010-2026}`,
`goldens-broad/{decade-2014-2023, six-year-2018-2023, bull-crash-2015-2020,
covid-recovery-2020-2024, sp500-30y-capacity-1996}`.

**Deliberately NOT touched:**
- `experiments/*` — frozen historical experiment records (config is part of the record).
- Any `*-longshort* / enable_short_side true` golden — 0.14 has a real
  force-liquidation-cascade rationale on the short side; re-pin separately if at all.
- `goldens-small/*` smoke variants — left at 0.14 for now (fast-CI smoke; a follow-up
  could align them for consistency, lower priority).
- The canonical default config — already 0.30; no code change.

## Verification
Every re-pinned golden re-run against its store **PASSES** the new bands (3/3 sp500 via
test_data, 5/5 broad via warehouse). Bands: ±15% (sp500) / ±20% (broad) around the 0.30
actuals; wide absolute bands on the two near-zero-return windows (six-year, bull-crash)
to absorb their volatility.
