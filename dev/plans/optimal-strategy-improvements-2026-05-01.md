# Optimal-strategy improvements — analysis + plan

**Date:** 2026-05-01
**Owner:** TBD
**Status:** Plan — awaiting prioritisation
**Driver:** Empirical observation that `optimal_strategy.exe` runs ≥90 min on
`sp500-2019-2023` (491 symbols × 5 years), making it impractical to use the
counterfactual as a regular feedback signal.

## Background

`Optimal_strategy_runner.run` consumes a backtest's checkpointed artefacts
(`actual.sexp`, `macro_trend.sexp`, etc.) and emits a counterfactual
"perfect-foresight under same constraints" report. Two variants:

- **Constrained** — same macro gating + Stage1→2 + stop discipline as the
  strategy. Picks each Friday's filler entries by realised R-multiple
  (descending), greedy fill until cash / position-count / sector caps.
- **Relaxed_macro** — same but ignores macro gate.

The gap between strategy actual and these ceilings is meant to isolate
*cascade-ranking error* (closeable via better screener) from *structural
ceiling under Weinstein's rules*.

## What's slow — and why (perf analysis)

Algorithm summary:

```
Phase 1 — scan:    for each (symbol, friday) in 491 × ~260 = ~127k pairs:
                     Stock_analysis.analyze: 30w MA, 52w RS-SMA, resistance,
                                              volume, stage classify
                     → emit Stage1→2 candidates that pass scanner

Phase 2 — score:   for each candidate (~10k):
                     build forward_outlooks: ~130 fridays × Stage.classify
                                              (re-extract 90 weekly bars each)
                     walk: stop updates + Stage3-streak detection until exit
                     → scored_candidate

Phase 3 — fill:    per Friday, sort entries by R-multiple DESC, greedy fill
                                              under caps
```

Five concrete inefficiencies, biggest first:

### P1. Forward outlooks recomputed per candidate (3-5x speedup)

`_forward_outlooks` (`optimal_strategy_runner.ml:154-174`) is called once per
candidate. If AAPL produces 5 candidate entries across the 5-year window, each
candidate independently builds its 130-week forward outlook — re-extracting 90
weekly bars and re-running `Stage.classify` per Friday. Same symbol, same
future, recomputed.

**Fix:** build the per-symbol forward-stage-classification table ONCE during
Phase 1 (or as a separate Phase 1.5 sweep), keyed by `(symbol, friday)`. Phase
2 just slices into it from `entry_friday + 1`.

Estimated savings: 60-80% of Phase 2 wall time.

### P2. Stage classification redundancy across phases (1.5-2x)

Phase 1 already classifies the stage at every (symbol, friday) pair (inside
`Stock_analysis.analyze`). Phase 2 re-classifies at the same (symbol, friday)
pairs in `_forward_outlooks`. Memoize once, reuse twice.

**Fix:** during Phase 1, store the per-(symbol, friday) `Stage.result` in a
shared hashtable. Phase 2 reads from it; falls through to live classification
only on miss.

### P3. List operations in tight loops (small)

- `List.drop_while all_fridays ~f:(fun d -> Date.( <= ) d entry_friday)`
  (`optimal_strategy_runner.ml:157`): O(N_fridays) per candidate. With 10k
  candidates × 260 fridays ≈ 2.6M comparisons just to find the start of the
  forward window.
- `_entries_on` (`optimal_portfolio_filler.ml:62`): full filter+sort over all
  scored candidates per Friday — O(N_scored × N_fridays).

**Fix:** precompute a `Map.t Date → int_index` and a per-Friday bucket. O(N_scored + N_fridays).

### P4. No parallelism (5-7x with process pool)

Phase 1 is embarrassingly parallel across symbols. Currently single-threaded.
`scenario_runner.ml` already uses fork-based parallelism elsewhere — same
pattern can apply here.

**Fix:** chunk the universe into N_cores groups; fork-join over Phase 1.
Phase 2 doesn't need this if P1+P2 land first (forward outlooks become a
hashtable lookup).

### P5. Stock_analysis recomputes sliding-window aggregates per Friday

Each `Stock_analysis.analyze` call extracts ~90 bars and runs MA / RS /
resistance from scratch. These are *streaming* computations naturally — a
single sweep per symbol with running aggregates would be ~10-20x faster than
260 independent windows. But this requires API changes to `Stock_analysis`,
larger blast radius.

**Fix (deferred):** add a `Stock_analysis.analyze_panel` API that takes a
per-symbol bar series + a date stream and emits a per-Friday result list with
amortised O(N_bars) work per symbol.

## Definition-level concerns (separate from perf)

### D1. Perfect-foresight contamination in candidate ordering

The filler sorts candidates by `r_multiple` descending
(`optimal_portfolio_filler.ml:67-73`). The R-multiple is computed *forward*
from the candidate, so we're picking winners by their realised return — a
signal NOT available at decision time. Useful as a *ceiling*, misleading as a
*target*.

**Fix:** add a `Score_picked` filler variant that orders by `cascade_score`
(the screener's pre-trade score). The gap `Score_picked` → `Constrained`
reads cleanly as "cascade-ranking error closeable via better screener", while
`Constrained` → `Relaxed_macro` reads as "macro-gate cost".

### D2. Sector signal is half-honored

`_build_sector_context_map` (`optimal_strategy_runner.ml:132-144`) forces
every sector to `Strong / Stage2`. That short-circuits the per-sector
contribution to `cascade_score`, but downstream the filler still respects
sector concentration caps (`max_sector_concentration`). Half-honoring the
sector signal — either honor it fully (use the actual macro/sector data the
backtest had) or skip the sector concentration cap in the filler. Default
choice: honor fully.

### D3. Single optimization axis

The counterfactual measures "what if you picked the right Stage1→2 setup?"
Doesn't isolate other improvements:

- "what if stops were placed differently?" (e.g., wider initial stop)
- "what if you sized larger on high-R candidates?"
- "what if you held until Stage 4 vs Stage 3?"

**Fix (deferred):** add stop / sizing / hold variants as separate optimization
axes. Each becomes its own `Variant` with the rest of the pipeline holding.

## Plan

### PR-1 — perf P1 (memoize forward outlooks)

Per-symbol forward-stage table built once. Phase 2 lookups via Hashtbl.
Estimated 3-5x speedup, no algorithm redesign. Single-file change in
`optimal_strategy_runner.ml` plus a small types addition. Target: ~150 LOC.

### PR-2 — perf P2 (memoize Phase 1 stage results) + P3 (Friday index)

Combine memoization for cross-phase reuse with the Friday-index precompute.
Builds on PR-1's data structures. Target: ~100 LOC.

### PR-3 — perf P4 (parallelize Phase 1)

Fork-join across symbols with N_cores workers. Mirrors `scenario_runner.ml`
fork pattern. Target: ~150 LOC + a test that verifies determinism across
worker counts.

### PR-4 — definition D1 (Score_picked variant)

New variant in `Optimal_types.variant`; new sort path in
`Optimal_portfolio_filler._entries_on`. Updates `Optimal_summary` to emit a
third variant column. Updates `Optimal_strategy_report` rendering. Target:
~200 LOC.

### PR-5 — definition D2 (full sector honor)

Replace `_build_sector_context_map` with a real per-Friday sector-context
lookup. Source: the backtest's sector analysis output, or recompute against
the current Friday's panel. Target: ~150 LOC + integration test.

### Deferred — P5 + D3 (streaming Stock_analysis, additional axes)

Deferred until PR-1 through PR-5 measured impact is in. P5 needs
`Stock_analysis` API redesign across multiple modules. D3 is feature-creep
relative to the current "what's the right candidate?" question.

## Decision items

- [ ] Confirm priority order: P1 → P2/P3 → D1 → P4 → D2.
- [ ] Confirm we want a `Score_picked` variant rather than replacing
  `Constrained`'s sort.
- [ ] Confirm `Stock_analysis` API redesign (P5) is in-scope for a future
  follow-up.
- [ ] Set a perf target: e.g., `optimal_strategy.exe` on
  `sp500-2019-2023` should complete in <15 minutes after PR-1 + PR-2 land.

## References

- `trading/trading/backtest/optimal/lib/optimal_strategy_runner.ml`
- `trading/trading/backtest/optimal/lib/outcome_scorer.ml`
- `trading/trading/backtest/optimal/lib/optimal_portfolio_filler.ml`
- `dev/status/optimal-strategy.md` (subsystem status — currently MERGED for
  the v0 implementation; this plan extends it)
- `dev/plans/optimal-strategy-counterfactual-2026-04-28.md` (original design)
