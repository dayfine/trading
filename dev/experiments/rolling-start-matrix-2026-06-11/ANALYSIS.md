# Rolling-start edge matrix — first full run (preliminary, top-3000-2011)

**Date:** 2026-06-11 · **Runner:** rolling-start v2 (#1536) · **Status:** PRELIMINARY
(pre-composition-policy universe; GSPC.INDX price-only benchmark; MTM + realized
columns). Raw output: `matrix-t3k-2011-raw.md` (33 starts).

## Setup

- Universe: PIT `top-3000-2011` (3015 symbols), snapshot warehouse `snap_top3000_2011`.
- Starts: 2011-01-03 + 170-day stride with seeded jitter (seed 42), 33 starts,
  all held to 2026-04-30. Cell-E config (0.14/0.70/0.30, force-exit h=1,
  laggard h=2). Serial fork-per-start; wall ~10h.
- Benchmark: GSPC.INDX buy-and-hold from the same start (price index — **no
  dividends**, flatters the strategy edge by ~2pp/yr vs total-return SPX).

## Headline (trimmed to n=30 — see Artifacts)

| measure | value |
|---|---|
| Median edge vs GSPC | **≈ +3.2 pp/yr** (raw n=33 report says +6.0; the +6.0 includes 3 meaningless short windows) |
| Starts beating GSPC | ≈ 57% (17/30) |
| p10 edge | ≈ −16 pp/yr |
| Worst start (2023-10-19) | −28.1 pp/yr |
| Dividend adjustment | vs total-return SPX, median edge ≈ **+1 pp/yr** |

**Read: on the 2011-2026 bull window, pre-policy universe, there is no robust
start-date edge over buy-and-hold SPX.** The single-start headline numbers the
program used to quote (e.g. realized +199% breadth wins) coexist with a
start-date distribution that is roughly a coin flip with fat negative tail.
This is the measurement the 06-11-PM doc said we were missing — it is a *lens*,
not a verdict: the window contains no real bear (the strategy's designed
payoff), and the universe pre-dates the composition policy.

## Structure in the matrix (the feature targets)

1. **The 2013-2018 start cluster is the gap.** Negative-edge starts concentrate
   there: 2013-10 (−2.5), 2013-12 (−8.9), 2015-07 (−11.6), 2016-06 (−8.3),
   2017-01 (−9.8), 2017-04 (−7.8), 2018-11 (−8.2). Matches the coarse
   `rolling_t3k` 2014/2016 rows. Diagnosing *why* mid-2010s entries lag (entry
   quality? chop regime? breadth?) is the highest-value feature question this
   matrix surfaces.
2. **Recent-start MTM edge is unrealized.** Every post-2020 start has positive
   MTM CAGR but **negative realized return** (2024-03-28: +48.8%/yr MTM vs
   −38% realized; 2021-10-16: realized −52.9%). The realized column (built for
   exactly this) shows the recent-start wins are open marks, not banked P&L —
   the AXTI-mark concern (`project_broad_universe_790_mtm_inflated`)
   generalizes across recent starts.
3. **Early starts are genuinely good on both bases:** 2011-2012 starts show
   +8-10pp edge AND realized +150-350%.
4. **TimeUnderwater ≈ 95-98% everywhere** — NAV spends nearly all its life
   below the running peak; consistent with terminal-mark-dominated equity
   curves.

## Artifacts / follow-ups (block the definitive run)

- **A1 — no min-window guard.** The last 3 starts (2025-01-20, 2025-11-09,
  2026-03-06) have ≤15-month windows; annualizing produces CAGR up to 2393%
  and poisons the raw summary (raw median edge +6.0 vs trimmed +3.2). The
  enumerator (or the report) needs a `--min-window-days` filter.
- **A2 — impossible drawdown on 2023-01-26 row:** MaxDD 190.4%,
  MaxUnderwaterVsInitial 156.3% — NAV below −56% of initial capital is
  impossible for a long-only 0.70-max-exposure portfolio. Runner/metric bug
  (forked-summary projection? NAV reconstruction?). Investigate before
  trusting per-start DD columns.
- **A3 — benchmark is price-only GSPC.** SPY bars are absent from both
  warehouses (`SPY.snap` not in manifests). Add SPY (and BRK-B) to the
  warehouse build so the overlay is total-return-ish.
- **A4 — rerun dependency:** definitive matrix waits on the composition-policy
  universe artifact ($-volume wiring → `apply_composition_policy.exe` → new
  golden) per `next-session-priorities-2026-06-12.md` §P1'.

## Companion smoke (dot-com window, new 2000 warehouse)

2-start smoke on `snap_top3000_2000` (2000-2005 windows): strategy beat GSPC
by +13.3 and +26.8 pp/yr with MaxDD 13-23%. n=2 — directional only, but the
first evidence from a bear-containing regime, and the regime where the
strategy is *supposed* to earn its keep. The full 2000-era matrix is the next
big read (P2' in the handoff).
