# Status: walk-forward-cv

## Last updated: 2026-05-16

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

### Second PR — Phase 2.2 PR-A: Explicit folds + structured aggregate (in flight)

Per `dev/plans/walk-forward-cv-rolling-30fold-2026-05-16.md`. This is the
first of the plan's two-PR split (PR-A = steps 1-2; PR-B = steps 3-5,
defer).

- [x] `Window_spec.t` promoted to variant `Rolling of rolling_spec | Explicit of explicit_fold list`. Backwards-compatible `t_of_sexp` accepts the legacy flat-record shape and silently promotes to `Rolling`. 6 new tests covering Explicit pass-through, empty/duplicate rejection, train_period preservation, sexp round-trip for both variants, and legacy-flat fallback.
- [x] `Walk_forward_report.compute` returns a structured `aggregate` record (fold_count, baseline_label, metric_label, per-variant stability, per-variant sensitivity, per-variant verdicts). Programmatic surface for Phase 3 Bayesian optimizer to score candidates without parsing markdown. Existing `render` now delegates to `compute` then to a new `Walk_forward_render.to_markdown` helper module — markdown output preserved byte-identically. 5 new tests covering per-variant stability (mean/stdev/min/max), sensitivity exclusion of baseline, Pass verdict shape, baseline-label validation, and aggregate sexp round-trip.
- [x] Type surface extracted to `Walk_forward_types` module so `Walk_forward_render` (the markdown emitter) can depend on the types without cycling back through `Walk_forward_report.compute`. `Walk_forward_report.mli` re-exports via `include module type of Walk_forward_types`.

### Verify (PR-A)

```
dune build && dune runtest trading/backtest/walk_forward/test && dune build @fmt
```

54 tests across the 4 modules (9 + 17 + 13 + 15), all pass. All linters
(nesting, fn-length, mli-coverage, file-length, magic-numbers, fmt) clean.

### Third PR — Phase 2.2 PR-B: multi-metric sensitivity + CAGR + fixture sexps

Per `dev/plans/walk-forward-cv-rolling-30fold-2026-05-16.md` (PR-B half).
PR-A landed as #1111; this PR is the §3-5 deferred half.

- [x] **Multi-metric sensitivity table** (plan §3) — `variant_sensitivity` extended from a single `wins_on_gate_metric : int` to four win counts (`sharpe_wins`, `calmar_wins`, `total_return_wins`, `max_drawdown_wins`). The markdown report's "Cross-fold sensitivity" section grows from 1 column to 4; the gate metric's column header is suffixed with `*` so the operator can see which column the verdict gates on at a glance. The `_wins_on_metric_for_variant` helper counts wins per (variant, metric) directly off the fold_actuals — independent of the gate. 3 new tests (multi-metric counts, gate-metric flagging for Sharpe, gate-metric flagging for MaxDD).
- [x] **Derived `cagr_pct`** (plan §4) — added as a public helper `Walk_forward.Walk_forward_runner.cagr_pct : test_days:int -> total_return_pct:float -> float`. Formula `((1+r)^(1/y)-1)*100` with `y = test_days /. 365.25`. Returns `Float.nan` when `test_days ≤ 0`. New field `cagr_pct : float` on `fold_actual` populated by the binary from each fold's calendar test window. New `cagr_pct : per_metric_stats` on `variant_stability`. Renderer prints `n/a` for NaN values so older fixtures don't break. 5 new tests covering 365-day identity, 182-day annualise-up, 730-day annualise-down, zero-days NaN, and negative-return handling.
- [x] **`Spec` module hoist** — the on-disk spec type (`base_scenario`, `window_spec`, `variants`, `baseline_label`, `gate`) was duplicated in the binary; hoisted to the library as `Walk_forward.Spec` so the test surface can validate fixture sexps without invoking the backtest. Binary updated to use it.
- [x] **`aggregate.sexp` writer** — binary now writes the structured aggregate per `Walk_forward.Walk_forward_report.compute` to `<out-dir>/aggregate.sexp` alongside the markdown report and `fold_actuals.sexp`. Phase 3 BO will read it directly.
- [x] **Two checked-in fixture spec sexps** under `trading/test_data/walk_forward/`:
  - `cell_e_8fold_2026_05_08.sexp` — Window_spec.Explicit re-expressing the 2026-05-08 hand-curated 8-fold experiment (4 underlying windows × 2 halves) as 8 folds named `bull-crash-2015-2017`, `bull-crash-2018-2020`, …, `sp500-2021h2-2023`. Variants `cell-A` (baseline; disables Cell E features) and `cell-E` (empty overrides; uses base's canonical config).
  - `cell_e_30fold_2026_05_16.sexp` — Window_spec.Rolling, OOS-only, base=`goldens-sp500-historical/sp500-2010-2026.sexp`, train_days=0 / test_days=365 / step_days=182. Generates ~30 folds spanning 2010-01 → 2026-04. Gate: 17/30 Sharpe wins, Δ≤0.30.
  - Both ship as **spec files only**; the actual sweeps are local-only follow-ups (multi-hour wall) and out of scope for this PR.
- [x] **`_mismatch_verdict` branch test coverage** — PR-A's CP4 review nit. New dedicated tests (`test_mismatch_verdict_when_fold_count_below_gate_n` and `test_mismatch_verdict_renders_skipped_line`) exercise the synthetic Fail produced when the (variant, baseline) fold-pair count doesn't match `gate.n`, and verify the renderer emits the `SKIPPED — fold-pair count mismatch:` line.

### Verify (PR-B)

```
dune build && dune runtest trading/backtest/walk_forward && dune build @fmt
```

73 tests across 5 modules (13 fold_gate + 14 runner + 17 window_spec + 7 spec + 22 report), all pass. All linters clean.

## Completed

- **PR #1100** (2026-05-15) — walk-forward CV harness first PR. Plan + 4 lib modules + binary + tests. ~1200 LOC including tests. All four checklist items satisfied (`dune build`, `dune runtest`, `dune fmt`, nesting + magic-number linters clean).
- **PR #1107** (2026-05-16) — Phase 2.2 plan: rolling 30-fold harness extension. Plan file only; implementation tracked across the PR-A + PR-B split.

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
