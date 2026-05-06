# Status: all-eligible

## Last updated: 2026-05-06

## Status
IN_PROGRESS (PR-2 ready for review; PR-1 merged via #899)

## Goal

Diagnostic tool that — for every Stage-2 entry signal that fires across a
backtest period — allocates a fixed dollar amount per signal, bypasses every
portfolio-level rejection, and tracks each position independently to its
natural exit. Produces per-trade alpha + aggregate stats so we can separate
**signal quality** from **portfolio mechanism**:

| Tool | Measures |
|---|---|
| `optimal-strategy` | Counterfactual perfect picking within universe scope |
| `all-eligible` (this track) | Raw signal alpha — what would each Stage-2 signal return |
| `actual` (live backtest) | Strategy + portfolio mechanism interaction |

## Plan

- **PR-1** (#899, merged) — `Backtest_all_eligible.All_eligible.grade` pure
  function: takes scored candidates from the `optimal-strategy` scanner +
  scorer, projects each into a fixed-dollar `trade_record`, computes
  aggregate (win rate, mean/median return, total P&L, return-bucket
  histogram). Lib + 10 tests. No CLI, no I/O.
- **PR-2** (this PR — `feat/all-eligible-runner-cli`) — CLI exe + on-disk
  emission. `all_eligible_runner.exe --scenario <path> --out-dir <path>` →
  `trades.csv` + `summary.md` + `config.sexp`. 9 integration / unit tests.
  Bin lives at `trading/trading/backtest/all_eligible/bin/`.
- **PR-3** (deferred) — wire `all_eligible_runner` into the release-report
  pipeline so every nightly run emits the diagnostic alongside
  `optimal_strategy.md`.

## Open work

- [ ] **PR-3 wiring** — invoke `all_eligible_runner.exe` from the
  release-report pipeline (or scenario_runner post-step) so every backtest
  produces the diagnostic without manual invocation.
- [ ] Hand-crafted Stage-1→2 breakout fixture for content tests of the
  smoke suite (current smoke uses flat-price bars ⇒ zero breakouts ⇒
  pins runner shape but not alpha math). Currently a deferred follow-up
  noted in `bin/test/test_all_eligible_runner.ml`.
- [ ] Extract shared snapshot-orchestration helpers (Friday calendar,
  forward-table, `_build_world` / `_scan_and_score`) from
  `Optimal_strategy_runner` and `All_eligible_runner` into a shared lib
  under `backtest_optimal/` so PR-2 stops carrying ~150 LOC of duplicated
  scaffolding.
- [ ] Thread `--config-overrides` into the scanner config so callers can
  sweep cascade thresholds without editing scenario files. Currently the
  flag is a passthrough — accepted for forward-compat but not yet
  threaded.

## Completed

- 2026-05-06 — **PR-1 lib** merged via #899. `All_eligible.grade` /
  `build_trade_record` / `compute_aggregate` shipped with 10 unit tests
  covering 3-trade synthetic scenarios + bucket boundaries + empty input.
- 2026-05-06 — **PR-2 CLI exe** ready for review on
  `feat/all-eligible-runner-cli`. `All_eligible_runner` lib + binary +
  9 tests. End-to-end smoke run validated against
  `goldens-sp500/sp500-2019-2023.sexp` — produced 27,092 Stage-2
  signals over 5y, 25.11% win rate, -$7.4M total raw P&L on
  $10K-per-signal sizing (negative all-eligible alpha across the
  universe — informs the "screener cascade is keeping the average
  signal out" hypothesis).

## Verify

```bash
# Build + tests
dune build trading/trading/backtest/all_eligible
dune runtest trading/trading/backtest/all_eligible

# Smoke run against the 5y SP500 baseline
dune exec trading/trading/backtest/all_eligible/bin/all_eligible_runner.exe -- \
  --scenario trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp \
  --out-dir /tmp/all_elig_sp500_5y/
ls /tmp/all_elig_sp500_5y/   # → trades.csv summary.md config.sexp
```

## Reference

- Issue: https://github.com/dayfine/trading/issues/870
- PR-1: https://github.com/dayfine/trading/pull/899
- Plans: `dev/plans/all-eligible-trade-grading-2026-05-06.md` (PR-1) and
  `dev/plans/all-eligible-runner-cli-2026-05-06.md` (PR-2).
- Sister track: `dev/status/optimal-strategy.md`.
