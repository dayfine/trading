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

---

# Part 2 — 2000-2011 regime matrix (bear-decade read, 2026-06-11 PM)

25 starts, `snap_top3000_2000`, 2000-01-03 → 2011-06-30, same Cell-E config +
GSPC.INDX overlay. Raw: `matrix-t3k-2000-regime-raw.md`. Wall ~6.5h.

## Trimmed read (n=21: drop 3 sub-15-month tail starts + 1 corrupt fold)

| measure | 2000-2011 (this) | 2011-2026 (Part 1) |
|---|---|---|
| Median edge vs GSPC | +2.96 pp/yr | +3.2 pp/yr |
| Starts beating | 67% (14/21) | 57% |
| p10 edge | **−3.9 pp** | −16 pp |
| Worst-start edge | **−4.9 pp** | −28 pp |
| Edge IQR | **4.9** | 17.9 |
| Median MaxDD | 26.2% (GSPC: −49% then −57%) | 44.2% |

**Median edge is the SAME ~+3pp (≈ +1pp dividend-adjusted) in both regimes —
the strategy never wins the CAGR race (Sharpe's arithmetic). What changes is
the distribution shape: in the bear decade the left tail is chopped** (worst
start −4.9pp vs −28; IQR compresses 3.6×; drawdowns ~half the index's through
two −50%+ crashes). The strategy is a **distribution compressor**: Stage-4
exits cut the left tail (pays in bear regimes), winner-touching cuts the right
tail (costs in bulls). This is the per-start-date confirmation of the
structural frame in `memory/project_index_beating_structural_bar` and the
regime-conditional version of the barbell finding.

## Structure

1. **Alpha concentrates at the dawn of post-bear bull legs:** 2003-04 starts
   (+8.9 to +12.2pp/yr, realized +51-114%) mirror the 2011-12 cluster in
   Part 1. Early-Stage-2 entries off deep bases are the sweet spot.
2. **2006-08 starts = protection without profit:** dodged the GFC (MaxDD
   24-45% vs index −57%) but realized returns −18 to −29% — survival value,
   CAGR ≈ index.
3. **2000-02 starts (entering THROUGH the dot-com bust): all positive edge**
   (+1.6 to +7.7pp) with MaxDD 20-31% — the macro gate + Stage-4 avoidance
   doing exactly the designed job.

## New artifact

- **A2 second specimen:** 2009-06-26 row is corrupt — CAGR −40.5% with
  MaxDD 0.00 and TimeUnderwater 0.00 (internally impossible). With Part 1's
  190%-DD row, the per-start summary projection bug is now ~reproducible;
  investigation moves up to the top of the A-list. Edge/CAGR columns of OTHER
  rows are unaffected (computed from initial/final), but treat per-start DD
  columns as suspect until fixed.
