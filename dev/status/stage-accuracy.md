# Status: stage-accuracy

## Last updated: 2026-06-04

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

- **MERGED via #1446 (2026-06-04, squash `919e10a8`)** — `feat/late-stage2-stop-tighten`.
  QC structural APPROVED q=5 (review 4426367035) + behavioral APPROVED q=5
  (review 4426387423); all 3 merge gates green; auto-merged (Step 6.5).
  Audit `dev/audit/2026-06-04-late-stage2-stop-tighten.json`. The confirmation
  grid (Next Step 1) is the maintainer's separate local backtest experiment.

## Next Steps

1. **Confirmation grid — DONE 2026-06-06: REJECTED.**
   (`dev/experiments/_ledger/2026-06-06-late-stage2-stop-tighten-grid.sexp`.)
   Swept `late_stage2_stop_buffer_pct ∈ {0.03,0.05,0.08}` × dial on/off on
   the deep (PIT-2000 SP500, 2000-2026, dot-com+GFC) and bull (PIT-2010,
   2010-2026) Cell E surfaces. The dial fires but is a clean REJECT:
   - **MaxDD unchanged to the basis point in BOTH windows** (37.32 deep,
     17.50 bull) — it does not cut drawdown, its entire design purpose.
   - **Buffer-insensitive** (0.03/0.05/0.08 byte-identical) — no tunable surface.
   - **Bull = complete no-op**; deep = a +321pp return bump (918→1239%) from
     ~1 trade (DD-neutral, Sharpe 0.70→0.76) = a single-episode capital-
     recycling artifact, not a robust improvement.
   - **Root cause:** the worst drawdowns are fast crashes (2000-02/2008/2020)
     that reset `late` before the top, so the dial never engages on the
     DD-defining episodes — vindicates Next-Step-3 below.

   Dial stays **default-off** + available as a `Variant_matrix` axis per
   flag-discipline; earns no further investment. The 2020-stall lever
   remains **breadth** (`project_cell_e_2020_stall_regime`), not this dial.
2. **Partial-trim variant** (separate larger PR): on `late`, trim the
   position toward a configurable fraction instead of (or in addition to)
   tightening the stop. Needs Position-core partial-exit support — out of
   scope for this PR.
3. Pair with the daily gap stop for fast vertical blow-offs (2020-style),
   which reset `late` before the top — the gap stop, not `late`, catches
   those; do not weaken it.

## Follow-ups

None.
