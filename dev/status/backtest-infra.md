# Status: Backtest Infrastructure

## Last updated: 2026-04-13

## Status
IN_PROGRESS

## Landed

- **Backtest runner CLI** (`trading/trading/scripts/backtest_runner/`) — produces sexp/csv output for one run
- **Metric suite** — ProfitFactor, CAGR, CalmarRatio, OpenPositionCount, UnrealizedPnl, TradeFrequency, plus base stats
- **Derived metric computer pattern** — `CalmarRatio` uses `depends_on` (CAGR, MaxDrawdown)
- **Non-trading day filter** in `Metric_computer_utils`
- **Map matchers** in matchers library (`contains_entry`, `map_includes`)
- **Metric computer split** — each computer in its own file, `metric_computers.ml` is thin assembly
- **Sexp deriving on all strategy config types** (#312) — prereq for generic config override
- **Inline TODO slugs** — `TODO(area/descriptive-slug)` with anchors in status files

## Open PRs

- **#306** — `--override key=value` flags (match-based). To be **reworked** using generic sexp merge now that #312 landed. Or close and open fresh.
- **#309** — This tracking doc itself
- **#313** — Unified scenario structure:
  - `trading/test_data/backtest_scenarios/{goldens,smoke}/*.sexp` — self-contained scenario files
  - `Backtest_runner_lib` — library extracted from the CLI
  - `scenario_runner.exe` — reads scenarios, runs each, compares actual vs expected ranges

## Replaced / Closed

- **#305** (superseded by #313) — had `--smoke` mode in runner, hardcoded then data-driven. Structure merged into scenario_runner.
- **#307** (superseded by #313) — had `dev/benchmarks/expected_metrics.sexp`. Moved to `trading/test_data/backtest_scenarios/goldens/`.

## Pending Cleanup (after #313 merges)

- Delete `dev/backtest/smoke-scenarios.sexp` (now in test_data)
- Delete `dev/benchmarks/expected_metrics.sexp` (now in test_data)
- Keep `dev/benchmarks/reference_backtest.sexp` (default config reference)

## Next Actions

### Immediate (post-#313)

1. **Rework #306**: replace match-based overrides with generic sexp merge
   - Now unblocked by #312 (all config types have `[@@deriving sexp]`)
   - `_apply_override` becomes: config → sexp → navigate to dotted key path → replace value → sexp_of_config
   - Works for any config field without code changes

2. **Run first experiment**: stop buffer tuning
   - Depends on: #306 rework merged, #313 scenario runner merged
   - Create a new scenarios directory (e.g. `experiments/stop-buffer/`) with variants
   - Invoke `scenario_runner --dir trading/test_data/backtest_scenarios/experiments/stop-buffer`

### Medium-term

- Drawdown circuit breaker (Weinstein Ch. 7 — 20% threshold)
- Experiment framework formalization (hypothesis → variants → compare)
- Token/cost tracking (T3-E from harness.md)

## Backtest Analysis TODOs (from dev/backtest/analysis.md)

1. **Stop placement** [HIGHEST IMPACT] — test wider stops (5%, 8%, 12%) and support-floor-based stops
2. **Stop analysis logging** — per-trade stop level and trigger info in trades.csv
3. **Drawdown circuit breaker** — 20% threshold
4. **Portfolio health metrics** — partially done (#304 merged: OpenPositionCount, UnrealizedPnl)
5. **Segmentation for stages** — test trend segmentation library

## Baseline results (2026-04-13, pre-experiments)

| Scenario | Period | Return | Win Rate | Max DD | Sharpe |
|----------|--------|--------|----------|--------|--------|
| six-year | 2018-2023 | +57% | 28.6% | 34.0% | 1.28 |
| bull-crash | 2015-2020 | +305% | 33.3% | 38.7% | 0.79 |
| covid-recovery | 2020-2024 | +27% | 47.7% | 38.0% | 1.00 |

Critical finding: 74% of trades exit within 1 day (whipsaw). Stop buffer too tight.

## Performance

- 6-year / 1654 stocks: ~40 min, 7 GB RAM
- 6-month smoke: ~5 min
- Non-deterministic due to Hashtbl ordering (tracked, not fully fixed)

## Harness items

- T2-B: Reference backtest config — landed via #313 (in test_data, not dev/benchmarks)
- T3-E: Token/cost tracking — not started
