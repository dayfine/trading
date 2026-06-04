# Status: stage-accuracy

## Last updated: 2026-06-03

## Status
IN_PROGRESS

## Interface stable
YES

P1 of the 2026-06-03 stage-lifecycle pivot
(`dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md`): wire the
already-computed-but-discarded `Stage2 { late }` MA-deceleration signal
into held-position risk management, instead of consuming it only at
entry. The diagnosis shows `late` fired weeks-to-months before 6 of 7
major single-name / index tops, while the strategy's actual de-risk
trigger (Stage-4 flip) lagged every top by 5-29 weeks (price already
down 5-44%).

## Completed

- **Late-Stage-2 trailing-stop tightening dial** (default-off). New
  module `Late_stage2_stop_runner`
  (`trading/trading/weinstein/strategy/lib/late_stage2_stop_runner.{ml,mli}`):
  on Friday ticks, raises the trailing stop of every held `Stage2
  { late = true }` long to `close * (1 - buffer_pct)`, never lowering an
  existing stop. Emits `UpdateRiskParams` adjust transitions (not
  exits). Wired into `weinstein_strategy.ml` `_process_market_day` via
  `_run_late_stage2_tighten`, gated on
  `config.enable_late_stage2_stop_tighten`.
  - Config fields (both default to baseline no-op):
    `enable_late_stage2_stop_tighten : bool [@sexp.default false]`,
    `late_stage2_stop_buffer_pct : float [@sexp.default 0.0]`.
  - Flag-discipline: default-off (R1), real config field → `Variant_matrix`
    flag axis (R2), NOT promoted / not wired into any preset (R3).
  - Weinstein-faithful: exit-aggressiveness dial (trader preset), book
    §Stage 3 detail "protect remaining half with tight sell-stop below
    support". Spine untouched.
  - Tests: `test_late_stage2_stop_runner.ml` (13 cases) — tighten on
    late Stage 2, no-op on every other stage / early Stage 2, never-lowered
    invariant (both directions), non-Friday / short-side / empty / missing
    stage / missing price no-ops.

## In Progress

- PR open: `feat/late-stage2-stop-tighten`. Awaiting CI + QC + merge.

## Next Steps

1. **Confirmation grid** (`.claude/rules/promotion-confirmation.md`):
   evaluate the dial across ≥3 independent period × universe contexts
   (incl. one deep pre-2009 macro-regime cell) before any promotion.
   Sweep `late_stage2_stop_buffer_pct` on bull + deep backtests: does it
   cut the 37% / 17.5% MaxDD without killing the 918% / 237% return?
   Promote a grid-robust value only via the grid, never a single-window
   winner. The dispatcher runs the grid separately.
2. **Partial-trim variant** (separate larger PR): on `late`, trim the
   position toward a configurable fraction instead of (or in addition to)
   tightening the stop. Needs Position-core partial-exit support — out of
   scope for this PR.
3. Pair with the daily gap stop for fast vertical blow-offs (2020-style),
   which reset `late` before the top — the gap stop, not `late`, catches
   those; do not weaken it.

## Follow-ups

None.
