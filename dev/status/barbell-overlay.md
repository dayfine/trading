# Status: barbell-overlay

## Last updated: 2026-06-21

## Status
MERGED

<!-- Gate-#2 deployable overlay (PR #1683) merged to main 2026-06-21 (commit 3411c952).
     Follow-up (a) scenario-entrypoint wiring MERGED 2026-06-21 (PR #1689, commit
     1edd7621, authored + self-merged by the maintainer; orchestrator post-hoc QC
     APPROVED/APPROVED quality 5, run 27919789702 [run 3]). One [non-blocking]
     follow-up remains (see ## Next Steps): exposing barbell_floor_weight as a
     Variant_matrix axis (R2). NB: that axis follow-up entangles with the
     Weinstein_strategy.config-centric Overlay_validator (floor_weight lives in a
     separate Barbell_config.t), so it is not self-contained config-plumbing. -->

## Notes
Gate #2 of the barbell program: make the validated SPY-FLOOR + Cell-E-ENGINE
barbell **deployable** (not just a post-hoc `blend.awk` of two separate
backtests). Built **Option A — sleeve orchestration** per
`dev/plans/barbell-deployable-overlay-2026-06-21.md`: two independent strategy
legs on split capital, a cash-only rebalance between sleeves on a configurable
cadence, and a combined NAV / metrics output. **No core-module edits** —
Portfolio / Orders / Position / Strategy / Engine / Simulator are untouched; the
overlay reuses the existing `Backtest.Runner` for each leg unchanged.

Default-off + searchable per `.claude/rules/experiment-flag-discipline.md`: the
config defaults are a no-op (`enable=false`, `floor_weight=0.0` = pure engine),
the record is `sexp`-derivable so each field can become a `Variant_matrix`-style
axis, and **no default is flipped on**. Documented promotion target is a light
floor `~0.30-0.40` (`dev/backtest/engine-edge-1998-2026/FINDINGS.md`), but the
weight is a config parameter and that flip is a separate, ledger-gated decision
(R3 / `.claude/rules/promotion-confirmation.md`).

## Interface stable
NO

## Surface
- `trading/trading/backtest/barbell/lib/barbell_config.{ml,mli}` — the 3-field
  config record (`enable`, `floor_weight`, `rebalance_weeks`), all no-op at
  default; `rebalance_stride_days` (weeks→days) + `validate`.
- `trading/trading/backtest/barbell/lib/barbell_blend.{ml,mli}` — the pure blend
  core. `blend_with_stride_days` / `blend` run the two-sleeve orchestration over
  the dates common to both legs and compute the blend.awk metric set
  (total_return, sharpe, maxdd, calmar, ulcer). Daily stride (=1) reproduces
  `blend.awk` exactly; coarser cadence drifts within tolerance.
- `trading/trading/backtest/barbell/lib/barbell_runner.{ml,mli}` — the
  orchestrator: forces two leg thunks (each a `Runner.run_backtest`), blends
  their equity curves, writes the combined `equity_curve.csv`. Leg runs are
  thunks so the orchestration is unit-testable without forking a backtest
  (mirrors `Rolling_start_runner`'s pure/executable split).

## Completed
- [x] **Gate #2 deployable barbell overlay (Option A, default-off)** —
  `feat/barbell-overlay`. Config + pure blend core + sleeve-orchestration
  runner under `trading/trading/backtest/barbell/`. Backward-compat (default =
  pure engine), degenerate weights (`1.0`≡floor, `0.0`≡engine), and an
  exact-match proof against `blend.awk` (5-point fixture: ret 27.4%, sharpe
  9.651, maxdd 6.4%, ulcer 3.37 — bit-identical) are all pinned by tests.
  Verify: `dune runtest trading/backtest/barbell/`.
- [x] **(a) Scenario-entrypoint wiring** — PR #1689 (commit 1edd7621, MERGED
  2026-06-21, authored + self-merged by the maintainer; orchestrator post-hoc QC
  APPROVED/APPROVED quality 5). Adds `trading/trading/backtest/barbell/scenario/`
  (thin lib + bin seam mirroring `Rolling_start_runner`'s pure/executable split):
  `barbell_scenario.run` resolves the scenario universe, builds one
  `Backtest.Runner.run_backtest` thunk per leg (FLOOR = `Spy_only_weinstein` 30wk;
  ENGINE = `Weinstein` Cell-E), projects each to an equity curve, hands both +
  `Barbell_config.t` to `Barbell_runner.run`. Default-off, no core edits; an
  integration test runs both legs end-to-end on a 22-symbol fixture universe and
  pins the blended NAV + `floor_weight=0.0`≡pure-engine no-op.

## Next Steps
- [ ] Expose `barbell_floor_weight` as a `Variant_matrix` axis so 70/30 vs
  neighbours stays searchable (R2 completion). NB: `floor_weight` lives in a
  separate `Barbell_config.t`, but `Variant_matrix.expand` validates axis
  overrides against `Weinstein_strategy.config` via `Overlay_validator` — so this
  requires integrating the barbell config into that machinery, not trivial
  config-plumbing. `[non-blocking]`

## Out of scope
- Flipping any default on (promotion). Requires a confirmation-grid ACCEPT per
  `.claude/rules/promotion-confirmation.md`.
- Option B (composite STRATEGY) — rejected in the design note (would need
  core-sizing changes).
