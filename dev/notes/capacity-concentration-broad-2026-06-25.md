# Capacity / concentration — BROAD top-3000 WF-CV (2026-06-25)

**Verdict: ACCEPT on the broad basis. Candidate value 0.30 (= the production default).**
This is the correct-basis re-run of the concentration lever, prompted by the user's
2026-06-25 correction that **SP500-515 is too narrow** to exercise the capacity
bottleneck. It vindicates that correction: the signal that washed out on SP500 is
clean on top-3000. Ledger: `2026-06-25-capacity-concentration-broad`.

## Why the SP500 run was the wrong basis

The optimal-lens capacity diagnosis (misses are `Insufficient_cash`; ~280 churned
trades; winners identified but unfunded) came from the **broad top-3000** run, where
many breakout winners compete for the same cash. SP500-515 has far fewer winners, so
the capacity constraint barely binds — the concentration signal washed out
(`2026-06-25-capacity-concentration-surface`: knife-edge 0.25 spike, INCONCLUSIVE).

## The broad curve (top-3000-2000 PIT, 2000-2026, 13 × 2-year folds, snapshot warehouse)

| cap | Sharpe | Calmar | MaxDD % | Return μ% | CAGR % | Shp-wins/13 |
|-----|-------:|-------:|--------:|----------:|-------:|------------:|
| 0.14 (deep-golden base) | 0.442 | 0.578 | 17.23 | 16.31 | 7.19 | — |
| **0.30 (production default)** | **0.508** | **0.673** | 19.07 | 22.73 | 10.20 | **9/13** |
| 0.50 | 0.470 | 0.631 | 19.46 | 20.95 | 9.27 | 6/13 |

**Clean interior optimum at 0.30** — monotonic up to 0.30, then declines at 0.50
(over-concentration). Not the SP500 knife-edge. 0.14→0.30 lifts **CAGR +3pp/yr**
(7.2→10.2%, economically large), Sharpe +15%, Calmar +16%, for +1.8pp DD.

**Robust, not variance-amplification:** the 0.30>0.14 win holds 9/13 folds across
regimes, and 0.30 **loses less in the worst folds** (fold-012 −23.9% vs −17.1%;
fold-011 −7.4% vs −4.7%). Concentration here genuinely improves outcomes, not just
the right tail.

Caveat (rigor): 2-year folds (13) here vs 1-year (26) on SP500, so the cross-basis
comparison is **directional** (curve shape), not metric-exact. A 1y/26-fold broad
re-run + a period-disjoint broad cell would harden it further.

## Promotion: endorsed — but the re-pin is NOT a live-default flip

**0.30 is endorsed as the basis value.** Crucially this is **not** a live-behavior
change: the canonical default `default_max_position_pct_long` is **already 0.30**, and
production already runs 0.30. The deep + broad GOLDENS artificially **override down to
0.14**. So "promote 0.30" = **remove the 0.14 override from the long-only goldens** so
the research basis matches production (stops understating the strategy by ~3pp/yr
CAGR). Because it changes no live behaviour, the promotion-confirmation grid (which
guards live-default flips) does not gate it; the evidence here (2-universe agreement +
within-window period-split + clean broad optimum) is sufficient to endorse the re-pin.

## ⚠ Why the re-pin was NOT executed autonomously (data-store provenance landmine)

The mechanical re-pin (config 0.14→0.30 + re-measured `expected` bands) is **blocked on
a data-store reproducibility trap** that makes blind autonomous execution likely to
break main:

- The same long-only golden (`sp500-2019-2023-long-only`), **config unchanged at 0.14**,
  produces **23.5%** return via local `data/` CSV, **49.1%** via the warehouse
  (`/tmp/snap_top3000_1998_2026`), and is pinned to a band of **≤30%** (the CI
  `test_data` store, not present locally). Three stores, three numbers.
- **Different goldens are pinned against different stores** (CSV `data/` / warehouse /
  CI `test_data`), and some were re-pinned to the warehouse by #1733/#1738 while others
  were not.
- Setting `expected` bands from whichever store I have locally would make them wrong
  for whatever store CI/postsubmit (`golden-runs-sp500-15y`, perf-tier) actually uses —
  i.e. **break main's postsubmit goldens after merge**, with no one to fix a red main
  while the user is AFK.

The config change cannot be safely decoupled from a correct re-measure, and the
re-measure needs the matching store resolved per golden. So this is teed up, not done.

## Re-pin procedure (ready to execute once the store question is resolved)

1. **Decide the canonical re-measure store** for the long-only goldens — recommended:
   the **warehouse** (`/tmp/snap_top3000_1998_2026`, delisting-complete), the modern
   standard #1733/#1738 moved to. Confirm whether `golden-runs-sp500-15y` /
   perf-tier postsubmit can use it (GHA does not host the 2 GB warehouse per
   `broad-golden-complete-data-2026-06-24.md`, so these goldens may be local-verify-only
   — if so, re-pinning them won't touch PR CI at all).
2. **Scope = long-only regression goldens only.** Re-pin `max_position_pct_long
   0.14 → 0.30` in: `goldens-sp500-historical/{sp500-1998-2026, sp500-2010-2026}`,
   `goldens-sp500/sp500-2019-2023-long-only`, and the long-only `goldens-broad/*`
   (decade-2014-2023, six-year-2018-2023, bull-crash-2015-2020, covid-recovery-2020-2024,
   sp500-30y-capacity-1996). **DO NOT touch:** `experiments/*` (frozen historical
   records), any `*-longshort*` / `enable_short_side true` golden (0.14 has a real
   force-liquidation-cascade rationale on the short side — re-pin separately, if at all),
   or the catstop WF experiment bases.
3. For each: edit config → run `scenario_runner --dir <stage> --snapshot-dir <store>
   --fixtures-root test_data/backtest_scenarios --no-emit-all-eligible` → read actuals →
   set `expected` bands around the new 0.30 actuals (match the file's existing tolerance
   style, ±20% / ±5pp win-rate) → re-run to PASS.
4. Verify via the matching postsubmit script; PR with this note + the broad ledger
   ACCEPT as justification; dispatch qc-behavioral (goldens change).

## Cross-reference

Confirms `project_deep_goldens_conservative_vs_default`: the deep+broad goldens at 0.14
understate the strategy; 0.30 (the default) is broad-optimal. The SP500-515
INCONCLUSIVE verdict stands as "SP500 too narrow to show capacity signal" and is
superseded-by-basis for the headline. The turnover/laggard-cadence broad lever was
launched then stopped (~15% in) to free the container for this promotion work — re-run
next session.
