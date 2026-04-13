# Status: Backtest Infrastructure

## Last updated: 2026-04-13

## Status
IN_PROGRESS

## Open PRs (need rework)

- **#304** (feat/more-metrics) — 6 new metric types added but:
  - [ ] Remove leaked `dev/status/harness.md` from diff
  - [ ] Add `sexp_of_metric_set` to metric_types so runner doesn't need custom sexp
  - [ ] Add map matchers (`contains_key`, `elements_are` for maps) to matchers library
  - [ ] Update test assertions to use map matchers instead of `Map.find` + `is_some_and`
  - [ ] Consider splitting metric_computers.ml (310 lines, @large-module)

- **#305** (feat/smoke-tests) — smoke mode works but:
  - [ ] Make scenarios data-driven: read from `dev/backtest/smoke-scenarios.sexp`
  - [ ] Remove hardcoded scenario definitions from backtest_runner.ml
  - [ ] Support `--scenarios <path>` for custom scenario files

- **#306** (feat/config-overrides) — basic override works but:
  - [ ] Long-term: generic sexp-based merge (requires `[@@deriving sexp]` on all config types)
  - [ ] Current match-based approach is acceptable for now, nesting fixed

- **#307** (harness/reference-backtest) — reference config created but:
  - [ ] Expected metrics should be per-scenario ranges, not aggregated
  - [ ] Clarify purpose: regression detection, not assuming scenarios are similar

- **#308** (harness/todo-cleanup) — TODOs converted but:
  - [ ] Use `TODO(simulation/followup-N)` format instead of `Tracked:` for grep-ability
  - [ ] Keep `TODO` keyword so standard tools find them

## Backtest Analysis TODOs (from dev/backtest/analysis.md)

1. **Stop placement** [HIGHEST IMPACT] — initial_stop_buffer 2% too tight vs book's 5-15%
   - Test wider stops (5%, 8%, 12%)
   - Investigate support-floor-based stops using screener's `base_low`
   - Blocked by: config overrides (#306)

2. **Stop analysis logging** — add per-trade stop level and trigger info to trades.csv
   - Blocked by: nothing, standalone change

3. **Drawdown circuit breaker** — implement 20% threshold per Weinstein Ch. 7
   - Blocked by: nothing, standalone change

4. **Portfolio health metrics** — % positions profitable, unrealized P&L tracking
   - Partially done in #304 (OpenPositionCount, UnrealizedPnl added)

5. **Segmentation for stages** — test trend segmentation library for Stage classification
   - Blocked by: nothing, experiment

6. **Experiment framework** — structured hypothesis testing
   - Depends on: config overrides, smoke tests, more metrics

7. **More metrics** — profit factor, CAGR, Calmar, trade frequency
   - In progress: #304

8. **Smoke test scenarios** — fast iteration windows
   - In progress: #305

## Inline TODOs in code (from #308)

- `order_generator.ml` — TODO(simulation/T1): StopLimit orders instead of Market
- `time_series.ml` — TODO(simulation/T2): monthly cadence conversion
- `test_time_series.ml` — TODO(simulation/T3): monthly conversion test
- `test_weinstein_strategy_smoke.ml` — TODO(simulation/T4): remove tmpdir round-trip
- `types.mli` — TODO(simulation/T5): configurable bar granularity
- `segmentation.ml` — TODO(screener/T1): move score weights into params

## Performance baseline

- 6-year / 1654 stocks: ~40 min, 7 GB RAM
- 6-month smoke: ~5 min
- Non-deterministic due to Hashtbl ordering (#298, merged but not fully fixed)

## Harness items

- T2-B: Reference backtest config — in progress (#307, needs rework)
- T3-E: Token/cost tracking — not started
