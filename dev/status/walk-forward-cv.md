# Status: walk-forward-cv

## Last updated: 2026-05-15

## Status
READY_FOR_REVIEW

## Notes

Track created 2026-05-15 by `feat-backtest` per the strategic pivot in
`dev/notes/next-session-priorities-2026-05-15.md` §"Phase 2 —
walk-forward CV harness". Plan at
`dev/plans/walk-forward-cv-harness-2026-05-15.md`.

Phase 2 of the broader P0 ML-discipline-tuning track. Scales the
existing hand-curated 8-fold walk-forward
(`dev/experiments/cell-e-walk-forward-2026-05-08/`) to a parameterised
rolling-window harness with a machine-checkable go/no-go gate. The gate
language is what would have rejected M5.5 axis-2 (PR #1086) and the
P3-followup combined-axis sweep (PR #1095) on their short-window data
alone — Phase 3 BO will consume this harness for variant scoring
instead of single-window mean-Sharpe.

## Interface stable
NO

M5.5 follow-on work — `WalkForwardRunner` spec sexp shape is explicitly
marked unstable in the binary's docstring; Phase 3 BO integration will
iterate it.

## Scope

### First PR (this PR, #1100) — harness modules + thin CLI

- [x] `Walk_forward.Window_spec` (`trading/trading/backtest/walk_forward/lib/window_spec.{ml,mli}`) — pure date-arithmetic spec for rolling train/test windows. Generates `fold` records (optional train period + required test period). Drops folds extending past `end_date`. 11 tests.
- [x] `Walk_forward.Fold_gate` (`trading/trading/backtest/walk_forward/lib/fold_gate.{ml,mli}`) — pure go/no-go evaluator. Rule: "variant wins ≥M of N folds AND no fold worse than baseline by >Δ". Direction inverted for `MaxDrawdownPct` (lower is better). 13 tests.
- [x] `Walk_forward.Walk_forward_runner` (`trading/trading/backtest/walk_forward/lib/walk_forward_runner.{ml,mli}`) — pure scenario builder: composes base scenario + Window_spec folds + variant overrides into the list of `Scenario.t` the harness runs. Variant overrides appended last (last-writer-wins per `Bayesian_runner_evaluator`). 9 tests.
- [x] `Walk_forward.Walk_forward_report` (`trading/trading/backtest/walk_forward/lib/walk_forward_report.{ml,mli}`) — pure markdown renderer. Emits 4 sections: per-fold metrics, stability (μ±σ per variant), cross-fold sensitivity (win-counts), go/no-go verdict per non-baseline variant. Deterministic. 10 tests.
- [x] `walk_forward_runner.exe` (`trading/trading/backtest/walk_forward/bin/walk_forward_runner.ml`) — thin CLI that reads a top-level sexp spec (`base_scenario` / `window_spec` / `variants` / `baseline_label` / `gate`), invokes `Backtest.Runner.run_backtest` sequentially per (variant, fold), writes `fold_actuals.sexp` + `walk_forward_report.md` under `--out-dir`. Same per-suggestion shape as `Bayesian_runner_evaluator` so Phase 3 can swap variant overrides for BO suggestions.

### Verify

```
dune build && dune runtest trading/backtest/walk_forward
```

43 tests across 4 modules (11 + 13 + 9 + 10), all pass.

Quick smoke (not run in CI; local-only because backtest invocation is
expensive):

```
dune exec trading/backtest/walk_forward/bin/walk_forward_runner.exe -- --help
# Usage: walk_forward_runner.exe --spec <spec.sexp> --out-dir <dir> [--fixtures-root <path>]
```

## In Progress

None for this PR. The harness is complete in its first-PR scope.

## Completed

- **PR #1100** (this PR, 2026-05-15) — walk-forward CV harness first PR. Plan + 4 lib modules + binary + tests. ~1200 LOC including tests. All four checklist items satisfied (`dune build`, `dune runtest`, `dune fmt`, nesting + magic-number linters clean).

## Next Steps

1. **First production sweep** — run the binary against a real spec
   (`base = goldens-sp500/sp500-2010-2026.sexp`, 30 rolling folds with
   train_days=730 / test_days=365 / step_days=182, variants = baseline +
   cell-E + cell-F-candidates). Local-only follow-up; multi-hour wall
   time. Output: `dev/experiments/walk-forward-cell-e-2026-05-XX/`.
2. **Re-baseline the M5.4-E3 and -E4 sweeps** — re-run those reports
   through the walk-forward gate to confirm which buffer / weight cells
   actually pass M-of-N on rolling folds.
3. **Phase 3 — Bayesian-optimizer integration** (~3-5 PRs, 1 week).
   `bayesian_runner.exe` consumes the walk-forward harness as its
   evaluator (replacing the single-window mean-Sharpe scoring); the BO
   loop chooses variant overrides. Convergence acceptance: a cell that
   beats Cell E on walk-forward Sharpe by ≥0.05 with MaxDD no worse.
4. **Parallel fold execution** — sequential is fine for first sweeps;
   wall-time will demand fork-pool akin to
   `Scenario_runner._run_scenarios_parallel` once sweeps go to ~30
   folds × ~10 variants.

## Out of scope (this track / deferred)

- Multi-universe sweeps within a single spec.
- Live trading wiring.
- Modifications to `Backtest.Runner`, `Scenario`, the tuner libs, or
  any existing surface (pure addition).
- Norgate / vendor data ingest (separate `feat-data` track).

## Commits

- `b193358` — plan: dev/plans/walk-forward-cv-harness-2026-05-15.md
- `3868131` — feat(walk-forward): Window_spec module + 11 tests
- `fbd20b9` — feat(walk-forward): Fold_gate go/no-go evaluator + 13 tests
- `6c69757` — feat(walk-forward): Walk_forward_runner scenario builder + 9 tests
- `a81f9aa` — feat(walk-forward): Walk_forward_report markdown renderer + 10 tests
- (next commit on this branch will add the binary + this status file)
