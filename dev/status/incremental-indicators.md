# Status: incremental-indicators

## Last updated: 2026-04-25

## Status
PENDING

## Interface stable
N/A

## Goal

Refactor Weinstein indicators from batch-shape (`bars list → values
list`) to incremental rolling state (`prev_state + today's OHLC →
new_state`). Eliminates the dominant memory term in Tier 3 (the
post-#519 promote-all-Friday pattern) and unblocks the tier-4
release-gate scenario (5000 stocks × 10 years, ≤8 GB Tiered).

The strategy interface ALREADY has `get_indicator_fn` (per
`strategy_interface.mli:23-24`); `Weinstein_strategy` just doesn't
use it. The refactor populates this existing API rather than adding
new surface.

## Plan

`dev/plans/incremental-summary-state-2026-04-25.md` (PR #551) —
12-step phasing, generic `INDICATOR` functor, indicator-by-indicator
porting matrix, risk register, decisions ratified.

## Open work

- **PR #551** (this plan, doc-only) — open for human review with
  decisions ratified inline.

## 12-step phasing (from the plan)

| Step | Owner | Scope | Branch |
|---|---|---|---|
| 1 | feat-backtest | `INDICATOR` functor + parity-test functor | `feat/incremental-step01-functor` |
| 2 | feat-backtest | EMA incremental | `feat/incremental-step02-ema` |
| 3 | feat-backtest | SMA + WMA incremental | `feat/incremental-step03-sma-wma` |
| 4 | feat-backtest | ATR(14) incremental | `feat/incremental-step04-atr` |
| 5 | feat-backtest | Daily→weekly aggregator (per-symbol "current week" accumulator) | `feat/incremental-step05-daily-weekly` |
| 6 | feat-backtest | Mansfield RS line incremental | `feat/incremental-step06-rs-mansfield` |
| 7 | feat-backtest | `Stage.classify` incremental (composes MA + slope + above-count) | `feat/incremental-step07-stage` |
| 8 | feat-backtest | `Summary_compute` rebuilt on top | `feat/incremental-step08-summary-compute` |
| 9 | feat-backtest | Wire `Indicator_state` into simulator (advance per tick); populated alongside Bar_history; no behavior change yet | `feat/incremental-step09-simulator-wiring` |
| 10 | feat-weinstein | Cut Weinstein_strategy over to `get_indicator` for the 5 easy bar-history sites; load-bearing parity-test step | `feat/incremental-step10-strategy-cutover` |
| 11 | feat-weinstein | Tiered support_floor + resistance via cheap pre-filter then on-demand bar load | `feat/incremental-step11-hard-cases` |
| 12 | feat-weinstein | Drop the post-#519 promote-all-Friday in `_run_friday_cycle` (now safe — Inner has full info from Indicator_state) | `feat/incremental-step12-revert-promote-all` |
| 13 | feat-weinstein | Cleanup: drop `summary_compute_mode` toggle, delete unused batch path. Scheduled after ≥2 release cycles of stability | `feat/incremental-step13-cleanup` |

## Next steps (post-#551 merge)

1. **Step 1 first** — `Incremental` functor + parity-test functor.
   Pure scaffolding, ~200 LOC, low risk. Dispatched to feat-backtest.
2. Steps 2-8 land in sequence over multiple PRs. Each independently
   merge-able with parity tests at every cut. ~1,200 LOC total.
3. Step 9 is the "activation switch" — Indicator_state is populated
   in parallel to Bar_history. No behavior change yet but parallel
   state exists for comparison.
4. Step 10 is the cut-over — feat-weinstein takes over here. Strategy
   reads via `get_indicator`. **`test_tiered_loader_parity` must be
   green at end of this step.** ~250 LOC.
5. Step 11 handles the hard cases (support_floor, resistance) via
   tier-cheap-then-hard. ~300 LOC.
6. Step 12 is the cleanup of the post-#519 promote-all. Net
   delete (~50 LOC).

## Ownership

Two-owner split per the plan:

- **Steps 1-9**: `feat-backtest` agent (infra under
  `trading/analysis/technical/indicators/` and
  `trading/trading/backtest/`).
- **Steps 10-12**: `feat-weinstein` agent (strategy code under
  `trading/trading/weinstein/`).
- **Step 13 (cleanup)**: scheduled separately after ≥2 release
  cycles of stability with the new path on by default.

Handoff happens at end of step 9 — `Indicator_state` is populated
alongside Bar_history, no behavior change yet, then feat-weinstein
picks up the strategy migration.

## Branch

One per step, merging into main between (per ratified decision).
Pattern: `feat/incremental-step<NN>-<slug>`.

## Blocked on

- **Step N requires step N-1 merged** (linear dependency chain). No
  concurrent step work possible.
- Step 13 (cleanup) blocked on ≥2 release cycles after step 12 lands.

## Success metric (two-pronged, ratified)

- **Release-gate**: Tiered ≤8 GB at N=5000, T=10y on production-
  realistic universe. The hard target.
- **Smaller-scale**: bull-crash 2015-2020 at N=292 on
  /tmp/data-small-302 should drop from today's Tiered 3.74 GB to
  **≤2 GB**. No regression at N≤1000 on any tier 2/3 scenario.

Each step's PR reports numbers against BOTH targets.

## Decisions (ratified 2026-04-25)

1. ✅ One branch per step (12 branches + 1 cleanup)
2. ✅ Owner split: feat-backtest steps 1-9, feat-weinstein steps 10-12,
   step 13 cleanup deferred
3. ✅ Two-pronged success metric (above)
4. ✅ Rollback toggle (`summary_compute_mode = Batch | Incremental`)
   for ≥2 releases, with explicit step 13 cleanup tracked

## References

- Plan: `dev/plans/incremental-summary-state-2026-04-25.md`
- Predecessor (Tier 3 architecture): `dev/status/backtest-scale.md`
- Existing strategy interface hook: `trading/trading/strategy/lib/strategy_interface.mli:23-24`
- Existing batch indicators (to be ported):
  `trading/analysis/technical/indicators/{ema,sma,atr,relative_strength,time_period}/`,
  `trading/analysis/weinstein/{stage,resistance,rs}/`,
  `trading/trading/backtest/bar_loader/summary_compute.{ml,mli}`
- Bar_history readers audit (the 6 sites being cut over):
  `dev/notes/bar-history-readers-2026-04-24.md`
- Sibling perf track: `dev/status/backtest-perf.md` (tier 4 release-
  gate is what this refactor unlocks)
