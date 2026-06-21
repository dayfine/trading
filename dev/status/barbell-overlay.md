# Status: barbell-overlay

## Last updated: 2026-06-21

## Status
MERGED

<!-- Gate-#2 deployable overlay (PR #1683) merged to main 2026-06-21 (commit 3411c952).
     Two [non-blocking] follow-ups remain (see ## Next Steps): scenario-entrypoint
     wiring + exposing barbell_floor_weight as a Variant_matrix axis (R2). NB: the
     axis follow-up entangles with the Weinstein_strategy.config-centric
     Overlay_validator and likely depends on the scenario-entrypoint wiring landing
     first — not a self-contained config-plumbing task. Surfaced to the maintainer
     (orchestrator run 27906645873 [run 2] 2026-06-21). -->

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
- `trading/trading/backtest/barbell/scenario/lib/barbell_scenario.{ml,mli}` —
  end-to-end call-site wiring: builds the FLOOR + ENGINE leg thunks from a real
  `Scenario.t` (each a `Runner.run_backtest` over the scenario's period +
  resolved universe + bar source), projects each result's `steps` into an
  equity curve, and hands both to `Barbell_runner.run`. Mirrors
  `Rolling_start_runner`'s pure/executable split — `run` is unit-testable
  without a CLI.
- `trading/trading/backtest/barbell/scenario/bin/barbell_overlay_runner.ml` —
  thin CLI shim over `Barbell_scenario.run`: `--scenario` + `--floor-weight`
  (default `0.0` = pure-engine no-op) + `--rebalance-weeks` + floor dials +
  `--fixtures-root` / `--snapshot-dir`, writes the combined `equity_curve.csv`.
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
- [x] **End-to-end scenario wiring (P0.1)** — `feat/barbell-overlay`.
  `Barbell_scenario.run` builds the two leg thunks from a real `Scenario.t`
  (FLOOR = `Spy_only_weinstein`, ENGINE = the scenario's own strategy +
  overrides) and runs `Barbell_runner.run` end-to-end; a thin
  `barbell_overlay_runner.exe` CLI shim drives it (`--scenario`,
  `--floor-weight` default `0.0` = pure-engine no-op, `--rebalance-weeks`,
  floor dials, `--snapshot-dir`). **No core-module edits** — each sleeve reuses
  `Backtest.Runner.run_backtest` unchanged (Option A). Default-off preserved:
  `--floor-weight 0.0` short-circuits to the pure-engine curve (pinned by
  test). An integration test runs both legs on the committed 7-symbol parity
  fixture (BAH-AAPL floor vs Weinstein engine) and asserts the combined NAV is
  produced, starts normalised at 1.0, and the 50/50 blend's terminal NAV lies
  between the two legs'. Verify:
  `dune runtest trading/backtest/barbell/scenario/`.

## Next Steps
- [ ] Expose `barbell_floor_weight` as a `Variant_matrix` axis so 70/30 vs
  neighbours stays searchable (R2 completion). `[non-blocking]`

## Out of scope
- Flipping any default on (promotion). Requires a confirmation-grid ACCEPT per
  `.claude/rules/promotion-confirmation.md`.
- Option B (composite STRATEGY) — rejected in the design note (would need
  core-sizing changes).
