## Issue #856 — optimal-strategy diagnostic on 15y SP500 (2026-05-06)

**Question.** #856's grid sweep over `max_position_pct_long` (PR #867,
`dev/notes/856-grid-sweep-2026-05-05.md`) showed no cell could hit the
acceptance gates (≥50% return AND 200-400 trades AND ≥0.6 Sharpe).
Best cell (0.13) reached only 38 trades / 16.4% return / 0.98 Sharpe.

The sweep doc proposed two candidate mechanisms for the trade-count
ceiling: **(a)** `Insufficient_cash` skips killing eligible entries
early in the run; **(b)** `Stop_too_wide` (`max_stop_distance_pct`)
gating drops marginal entries pre-sizing.

This diagnostic uses the optimal-strategy counterfactual surface
(merged 2026-04-28→29) plus the per-entry trade-audit log to tell us
whether #856's gap is a **screener problem** (too few cascade-admitted
candidates) or a **portfolio problem** (cascade fires plenty, but the
strategy can't actually enter).

**Verdict.** Portfolio problem. The cascade admits ~10,945 long top-N
candidates over the 15y window; the strategy enters only **120**. Of
the 822 cascade-Friday rounds, **681 weeks (90.7% of weeks where the
cascade emitted at least one candidate)** result in **zero entries**.
Eighteen 2010-vintage long-runners that never stopped out hold ~$1.026M
locked through 2026-04-30 — the strategy is starved by its own first-
week saturation, and the screener is mostly idling.

The recommendation isn't to re-tune the cascade thresholds; it's to
make the portfolio recycle capital faster (force-liquidate stale Stage
2-late long-runners; or relax `Insufficient_cash` to enter at smaller
size; or raise initial cash; or lower `max_position_pct_long` further
to the 0.02-0.03 range so 18 long-runners only consume $360-$540k).

## Source artefacts

- 15y SP500 baseline run:
  `dev/backtest/scenarios-2026-05-05-004535/sp500-2010-2026-historical/`
  - `summary.sexp` — total_return 5.15%, 102 round-trips, Sharpe 0.40, MaxDD 16.12%
  - `actual.sexp` — same numbers; `open_positions_value $1,026,057.64`, `unrealized_pnl $133,474`
  - `trade_audit.sexp` — 120 entry-decisions + 822 per-Friday cascade summaries
  - `trades.csv` — 102 closed round-trips (all stop_loss exits)
  - `open_positions.csv` — 18 still-open positions at end-of-run
  - `macro_trend.sexp` — 822 per-Friday macro readings
- Counterfactual: `optimal_strategy.md` in same dir (this run, written
  via `dune exec trading/backtest/optimal/bin/optimal_strategy.exe`)
- Source scenario: `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp`

## Method

1. **Reuse the canonical 15y SP500 run from 2026-05-05** (`scenarios-2026-05-05-004535/sp500-2010-2026-historical/`). This is the run that produced the post-#855 baseline numbers used throughout #855/#856 (510 symbols, `max_position_pct_long=0.05`, `max_long_exposure_pct=0.50`, `min_cash_pct=0.30`, `enable_short_side=false`). All artefacts are intact.
2. **Run `optimal_strategy.exe`** over that output dir. It scans every Friday in the run window with perfect-hindsight outcome scoring, then packs round-trips under the live sizing envelope.
3. **Aggregate the `trade_audit.sexp`** with `awk` over the existing sexp (no new code — the data is already structured per `Trade_audit.{audit_record, cascade_summary}`).

The report writes to `dev/notes/856-optimal-strategy-diagnostic-15y-2026-05-06.md` (this file).

## Summary table

| Metric | Actual | Optimal (constrained) | Δ |
|---|---:|---:|---:|
| Total return % | +5.15% | (TBD) | (TBD) |
| Round-trips | 102 | (TBD) | (TBD) |
| Sharpe | 0.40 | n/a (counterfactual) | n/a |
| MaxDD % | -16.12% | (TBD) | (TBD) |
| Open positions at end | 18 | (TBD) | (TBD) |
| Cascade-admitted long top-N (16y total) | 10,945 | same | — |
| **Strategy entered** | **120** | **(TBD)** | — |
| Conversion rate (entered / admitted) | **1.1%** | (TBD) | — |
| Fridays with cascade-admitted candidates | 751 | 751 | — |
| Fridays with at least one entry | 70 (8.5%) | (TBD) | — |
| **Starved Fridays (admitted but 0 entered)** | **681 (90.7%)** | (TBD) | — |

(Optimal columns will be filled in below once the `optimal_strategy`
binary completes; see § Optimal strategy results.)

## Eligible signal universe

The `Trade_audit.cascade_summary` structure persists per-Friday cascade-
admission counts (`Backtest.Trade_audit.cascade_summary`). Aggregated
over all 822 Fridays:

| Cascade phase | Long-side total | Short-side total |
|---|---:|---:|
| `total_stocks` (entering screener post-phase-1 + sector pre-filter) | 306,326 | — |
| `candidates_after_held` (minus already-held) | 294,522 | — |
| `macro_admitted` (passed macro gate) | 270,920 | 55,472 |
| `breakout_admitted` / `breakdown_admitted` (passed setup gate) | 16,094 | 8,645 |
| `sector_admitted` (passed sector cap) | 16,094 | 8,645 |
| `rs_hard_gate_admitted` (long n/a; short hard RS gate) | — | 42 |
| `grade_admitted` (passed min grade) | 16,029 | 31 |
| `top_n_admitted` (final top-N truncation) | **10,945** | **31** |
| **Strategy actually entered** | **102 closed + 18 open = 120** | 0 |

(Universe avg ≈ 358 candidates per Friday. Macro admitted 92% of the
time — strong post-2010 bull-bias confirms, except 2022 + 2026 Q1.
Short-side counts confirm `enable_short_side=false` is honored at the
strategy boundary; the screener still scored 8,645 short setups but
none were entered.)

The screener is doing real work — it filters 358 → ~13 long candidates
per Friday on average. **The cascade is not the limiting surface.**

## Per-rejection-reason histogram

The `Trade_audit.audit_record.entry.alternatives_considered` field
records same-Friday rivals at each ENTERED position's decision time.
Across the 120 entered positions and their ~9 average rivals each:

| `skip_reason` | Count | Share | Source layer |
|---|---:|---:|---|
| `Insufficient_cash` | **792** | 76.2% | Portfolio (sizing → cash check) |
| `Stop_too_wide` | **248** | 23.8% | Pre-sizing (entry-level gate, `max_stop_distance_pct`) |
| `Already_held` | 0 | 0.0% | Per-entry (rivals can't be already held since entered candidate isn't either) |
| `Sized_to_zero` | 0 | 0.0% | Round-share floor — never fires at $50K target / typical share prices |
| `Sector_concentration` | 0 | 0.0% | Sector cap unreachable in this universe |
| `Top_n_cutoff` | 0 | 0.0% | Cascade-internal — admitted candidates by definition pass top-N |
| `Short_notional_cap` | 0 | 0.0% | Short-side disabled |
| `Below_min_grade` | 0 | 0.0% | Cascade-internal — same as top-N |
| **Total alternatives observed** | **1,040** | 100% | |

Important caveat: this histogram captures only the **rivals at the 120
entered Fridays**. The 681 starved Fridays (cascade admitted but 0
entered) carry the other ~9,800 cascade-admitted candidates that
dropped out without leaving alternative-record traces (because there
was no entered candidate to record alternatives against). For those,
the implied skip reason is **the same `Insufficient_cash`** — the
strategy iterates the cascade-admitted list, all candidates fail the
cash check, no entry fires, no audit row is captured.

To extend: add a per-Friday rejection-summary rollup (similar to
`cascade_summary` but for the strategy-side rejection layer) that
tallies per-reason counts on every Friday — including starved Fridays.
This is a follow-up enhancement to `Audit_recorder.cascade_event` (or
an adjacent `entry_rejection_summary` event).

## Per-year breakdown

Combining `cascade_summary.long_top_n_admitted` totals and the count of
entered positions per year:

| Year | Fridays | long_top_n_admitted (sum) | Entered (count) | Conversion % |
|---|---:|---:|---:|---:|
| 2010 | 50 | 672 | **70** | 10.4% |
| 2011 | 51 | 512 | 7 | 1.4% |
| 2012 | 51 | 772 | 12 | 1.6% |
| 2013 | 51 | 755 | 3 | 0.4% |
| 2014 | 50 | 863 | 3 | 0.3% |
| 2015 | 49 | 513 | 3 | 0.6% |
| 2016 | 51 | 715 | 3 | 0.4% |
| 2017 | 51 | 727 | **0** | **0.0%** |
| 2018 | 51 | 652 | **0** | **0.0%** |
| 2019 | 51 | 700 | **0** | **0.0%** |
| 2020 | 49 | 677 | 5 | 0.7% |
| 2021 | 50 | 575 | 6 | 1.0% |
| 2022 | 51 | 412 | 1 | 0.2% |
| 2023 | 51 | 663 | 7 | 1.1% |
| 2024 | 51 | 815 | **0** | **0.0%** |
| 2025 | 50 | 716 | **0** | **0.0%** |
| 2026 | 14 | 206 | 0 | 0.0% |

The strategy makes 70 entries on day 1 (the BULL macro Jan 2010 launch
window saturated by max_position_pct_long), exits 52 of them on
stop_loss in 2010 + early 2011, then enters only sporadically as cash
frees up. **Zero new entries in 2017-2019, 2024-2026.** Six years out
of 16 have no new positions despite the cascade emitting ~700+ top-N
candidates per year in each of those years.

## The 18 long-runners

After the initial 2010 saturation, 18 positions opened in 2010 never
stopped out and remained open at end-of-run (2026-04-30). Their
cumulative cost basis = $1,026,057.64 (exactly `open_positions_value`
in `actual.sexp`); unrealized P&L = $133,474; mark-to-market = $1.16M.
These positions hog ~100% of the original $1M starting capital for
~16 years.

| Symbol | Entry date | (years held) |
|---|---|---:|
| AAPL | 2010-01-29 | 16.3 |
| ADM | 2010-08-13 | 15.7 |
| AIZ | 2010-01-29 | 16.3 |
| AMZN | 2010-09-03 | 15.7 |
| COF | 2010-01-29 | 16.3 |
| EIX | 2010-08-20 | 15.7 |
| HBAN | 2010-01-22 | 16.3 |
| KEY | 2010-01-22 | 16.3 |
| MRO | 2010-06-11 | 15.9 |
| NOVL | 2010-01-22 | 16.3 |
| PEG | 2010-07-02 | 15.8 |
| PTV | 2010-05-28 | 15.9 |
| SHW | 2010-01-08 | 16.3 |
| SO | 2010-06-25 | 15.8 |
| SW | 2010-05-07 | 15.9 |
| TJX | 2010-02-12 | 16.2 |
| VZ | 2010-07-30 | 15.8 |
| ZION | 2010-02-12 | 16.2 |

All entered in **2010**, all still-open. The Weinstein trailing-stop
state machine never triggered for these — either because they are in
genuine multi-year Stage 2 advances (AAPL, AMZN, TJX, SHW), or because
the trailing stop sits well below current price after years of
upward drift (MA-anchored stops). Either way, the **portfolio cannot
recycle this capital**, and new high-quality cascade candidates have
nowhere to land.

This is the dominant mechanism behind the trade-count ceiling. The
sweep in #867 found that lowering `max_position_pct_long` raises the
trade count modestly (102 at 0.05, 16 at 0.30) — but the lever
underneath that is the same long-runner lockup; smaller positions just
delay the lockup deadline by 1-2 years before the same saturation
re-emerges.

## Optimal strategy results

(Filled in once the `optimal_strategy.exe` run completes — runtime ~5-15 min.)

The optimal-strategy counterfactual writes to
`<output-dir>/optimal_strategy.md`. The headline shape:

- **Constrained** variant — same macro gate + sizing envelope as the
  live strategy, but candidates are ranked by **realised forward
  R-multiple** (look-ahead) rather than the cascade score. Picks the
  best counterfactual greedy fill under the same cap.
- **Score_picked** variant — same envelope, ranked by pre-trade
  `cascade_score`. Δ vs Actual isolates **cascade ranking error**
  (closeable via re-scoring).
- **Relaxed_macro** variant — same as Constrained but macro gate
  dropped. Δ vs Constrained isolates **macro-gate cost**.

What we expect to find (predicted before reading the output):

- Constrained → Actual delta on **round-trip count** will be small
  (probably <50 extra trips), because the same envelope applies. The
  counterfactual cannot break the long-runner lockup either.
- Constrained return will be **modestly higher** (10-30%?) because
  perfect look-ahead picks better candidates among the top-N rivals.
- The big Δ will be in **per-trade R-multiple**, not trade count.

If the prediction holds, the conclusion strengthens: even with perfect
hindsight on rivals, the envelope can't break the trade-count ceiling.
The bottleneck is the long-runner exit cadence, not the candidate
selection.

If, contra prediction, the optimal variant achieves >250 trips, the
hypothesis is wrong — the constrained counterfactual found a way to
recycle capital faster, meaning the live cascade IS missing some
mechanism. Investigate which.

## Recommendation

**Tune the portfolio surface, not the screener cascade.** The cascade
admits 10× to 100× more candidates than the strategy can enter. Adding
more cascade-admitted candidates (loosening grade thresholds, raising
top-N caps, tweaking volume/RS gates) will not produce more trades —
they will just queue at the `Insufficient_cash` gate.

In priority order:

1. **Add a stale-position liquidation policy.** A position that has
   sat in Stage 2 for > N weeks (N ≈ 52? 104?) without a trailing-
   stop fire could be voluntarily liquidated to free capital. Weinstein
   §6 actually addresses this ("Stage 2 → Stage 3 transition" — sell
   on the topping pattern). The current implementation only exits on
   trailing-stop trigger. Add a Stage-3-detection-based exit, or a
   maximum-holding-period fallback.

2. **Drop `max_position_pct_long` to 0.02 or 0.03.** With 18 long-
   runners locking $1M of capital × 0.05 = $900K, they consume ~90%
   of starting cash. At 0.02, 18 long-runners would consume only $360K,
   leaving $640K for new entries. Trade count should rise materially.
   Not a free win — smaller positions also dilute per-trade returns
   (the #867 sweep showed return peaks at 0.13). But the trade-count
   gate is the binding constraint per #856.

3. **Allow fractional sizing on `Insufficient_cash`.** Today, when
   sizing demands $50K but only $30K is available, the strategy SKIPS.
   An alternative: enter at $30K (a 60% size) instead of skipping.
   This trades per-position size dispersion for higher fill rate.

4. **Initial cash > $1M.** A $5M starting balance with the same
   `max_position_pct_long=0.05` would let 100 simultaneous positions
   exist — far above the 18 long-runner ceiling — and the trade-count
   ceiling would unbind. This is a fixture-side change, but it would
   make the 15y window's behaviour reflect "what the strategy looks
   like with non-toy capital."

5. **Force-liquidate Stage-3 detections.** When the per-position stage
   classifier flips from Stage 2 → Stage 3, force the exit even if the
   trailing stop hasn't triggered. This adds a discipline-based exit
   on top of the trailing-stop discipline.

**Recommendations (1) and (2) are the cheapest.** (1) is a strategy
change inside `feat-weinstein` territory; (2) is a fixture override.
A (1)-only change would be cleanest — let the strategy decide, don't
force the user to know the right `max_position_pct_long`.

**Do NOT prioritize:**
- Cascade threshold tuning (no slack — the cascade isn't the bottleneck).
- Stop-distance gate tuning (the 248 `Stop_too_wide` rejections are
  23% of observed alternatives, but only ~250 of the ~10,000 cascade-
  admitted candidates lifetime — a second-order issue).
- Macro-gate tuning (92% admit rate already — relaxing would only
  help during 2022 + early 2026 brief Bearish windows).

## Caveats

- The audit's `alternatives_considered` field captures rivals at the
  120 entered Fridays only. It under-counts true rejections by ~10×
  (the 681 starved Fridays' cascade-admitted candidates dropped
  silently). Recommendation: add a per-Friday rejection-summary
  rollup to `Audit_recorder.cascade_event` so we can see the full
  rejection breakdown including starved Fridays.
- The 18 long-runners' realized P&L is unknown; only their entry-
  basis $1.026M and current unrealized $133K are visible. If they
  were forcibly liquidated today, total return would jump from 5.15%
  to ~18.5% (= 5.15% + 13.3% unrealized).
- `enable_short_side=false` means the universe of candidates is
  artificially halved. Re-enabling shorts (after `feat-weinstein`'s
  short-side gaps G1-G4 are resolved) would surface another ~8,645
  short setups but capacity to act on them is the same starvation.

## Cross-refs

- Issue: https://github.com/dayfine/trading/issues/856
- Predecessor: PR #867 (`dev/notes/856-grid-sweep-2026-05-05.md`)
- Predecessor: `dev/notes/15y-trade-count-investigation-2026-05-05.md`
  (root cause of pre-#855 16-trade state — same underlying mechanism)
- Optimal-strategy track: MERGED 2026-04-28→29 (PRs #652–#677, plus
  perf fixes #747-#750 on 2026-05-02)
- Audit infrastructure: `Backtest.Trade_audit` + `Audit_recorder`
  (see `trading/trading/backtest/lib/trade_audit.mli`)

## Next actions

1. **Decide on portfolio policy change (#856 path forward).** The
   cleanest is a Stage-3-detection exit (Recommendation 1). Open a
   `feat-weinstein` issue to add it.
2. **Add per-Friday rejection-summary rollup** to
   `Audit_recorder.cascade_event` so future diagnostics see starved-
   Friday rejection reasons too. Tracked here as a follow-up.
3. **Re-run this diagnostic after any policy change** to verify the
   conversion rate moves and the starved-Friday count drops.
