# Experiment Framework Plan

## Problem

We can run backtests but have no structured way to:
- Define and test hypotheses (e.g. "wider stops improve win rate")
- Compare results across parameter variations
- Track what was tried and what worked
- Run fast smoke tests for iteration speed

The baseline results (analysis.md) identified several areas to investigate,
but each investigation currently requires ad-hoc scripting.

## What we need

### 1. Experiment Runner (extend backtest_runner)

The current `backtest_runner.exe` runs one backtest with default config.
Extend it to support config overrides and experiment tracking.

```
experiment_runner <experiment-name> <start_date> [end_date]
  --override stage.ma_period=40
  --override stops.initial_stop_buffer=1.08
  --baseline    # also run with default config for comparison
```

Output structure:
```
dev/experiments/<experiment-name>/
  experiment.sexp        # hypothesis, parameter overrides, date range
  baseline/
    summary.sexp
    trades.csv
  variant/
    summary.sexp
    trades.csv
  comparison.sexp        # side-by-side metric diffs
```

**Implementation**: This is an extension of `backtest_runner.ml`, not a new
binary. Add `--override key=value` flags and a `--baseline` mode that runs
twice (default config + overridden config) and outputs a comparison.

### 2. More Metrics (extend Metric_computers)

Add to `metric_computers.ml` and `metric_types.ml`:
- **Profit factor**: gross profit / gross loss
- **CAGR**: annualized return
- **Calmar ratio**: CAGR / max drawdown
- **Open positions at end**: count and unrealized P&L
- **Trade frequency**: trades per month
- **% positions profitable**: at period end

Most of these are simple to compute from existing `step_result` data.

### 3. Smoke Test Scenarios

Short representative windows for fast iteration (~5 min each):
- **Bull**: 2019-06-01 to 2019-12-31 (6 months, strong uptrend)
- **Crash**: 2020-01-02 to 2020-06-30 (6 months, COVID)
- **Recovery**: 2023-01-02 to 2023-12-31 (1 year, post-bear)

These could be:
- A `--smoke` flag on the runner that runs all three
- Or a separate `smoke_test.exe` that runs them and reports pass/fail
  based on basic sanity checks (positive final value, trades generated)

### 4. Intermediate Trade Logging

For diagnosing entry/exit quality, add per-trade context to `trades.csv`:
- Initial stop level and distance (% from entry)
- Whether stop triggered on gap-down vs intraday move
- Stage at entry (Stage2, Stage2-late)
- Volume ratio at entry (breakout volume / average volume)
- Days from entry to first stop trigger

This requires changes to the strategy and order generator to pass context
through to the trade record. The `trade_metrics` type needs extending.

## Prioritized Workstreams

### Phase 1: Infrastructure (enables everything else)

1. **More metrics** — extend `Metric_computers` and `metric_types`
   - ~200 lines, straightforward
   - No new agents needed, part of normal feature work

2. **Config override flags** — add `--override key=value` to runner
   - Parse sexp-style key paths (e.g. `stops.initial_stop_buffer`)
   - Apply overrides to `Weinstein_strategy.config`
   - ~300 lines

3. **Smoke test scenarios** — add `--smoke` flag or separate binary
   - Runs 3 short windows, prints summary table
   - ~100 lines

### Phase 2: First Experiments

4. **Experiment: initial stop buffer**
   - Hypothesis: widening from 2% to 8% improves win rate and reduces whipsaw
   - Run: default (2%) vs 5% vs 8% vs 12% on smoke scenarios
   - Compare: win rate, avg holding days, total P&L, max drawdown

5. **Experiment: support-floor-based stops**
   - Hypothesis: using `base_low` from screener as stop (per book Ch. 6)
     gives more appropriate stop distances than fixed %
   - Requires: wiring `base_low` from screener output to order generator

6. **Experiment: segmentation library for stages**
   - Hypothesis: trend segmentation gives better Stage classification
     than MA slope thresholds
   - Requires: adapting `Stage.classify` to use segmentation output

### Phase 3: Systematic Tuning

7. **Tuner module** (from eng-design-4)
   - Grid search over parameter ranges
   - Walk-forward validation
   - This is the design doc's M6/M7 milestone work

## Agent Recommendations

### New agent: `experiment-runner`

**Purpose**: Run experiments (hypothesis → backtest variants → compare).
Not a persistent agent — invoked on demand when testing a hypothesis.

**Why a new agent?** The experiment workflow crosses multiple modules
(config overrides, running backtests, comparing results) and benefits from
a defined protocol. An agent can be prompted with a hypothesis and
autonomously run the comparison backtests.

**Scope**: Takes a hypothesis description and parameter overrides, runs
the smoke scenarios with default and modified configs, writes comparison
results.

### Existing agents — no changes needed

- **feat-weinstein**: continues for strategy logic changes (stop mechanism,
  screener tuning)
- **health-scanner**: continues for build/test health
- **ops-data**: continues for data fetching
- **lead-orchestrator**: could coordinate experiment runs in the future

## Dependencies and Ordering

```
More metrics ──────────┐
                       ├──→ Config override flags ──→ Experiment runner agent
Smoke test scenarios ──┘

                         ┌──→ Experiment: stop buffer
Config override flags ───┤
                         └──→ Experiment: support-floor stops

Segmentation experiment ──→ (independent, needs Stage.classify changes)

Tuner module ──→ (Phase 3, after experiments validate the approach)
```

## Estimated Effort

| Item | Lines | Time | Priority |
|------|-------|------|----------|
| More metrics | ~200 | 1 session | P0 |
| Config override flags | ~300 | 1 session | P0 |
| Smoke test scenarios | ~100 | 1 session | P0 |
| Experiment runner agent def | ~50 | 0.5 session | P1 |
| Stop buffer experiment | ~50 + runtime | 1 session | P1 |
| Support-floor stops | ~200 | 1-2 sessions | P1 |
| Intermediate trade logging | ~300 | 1 session | P2 |
| Segmentation experiment | ~400 | 2 sessions | P2 |
| Tuner module | ~800 | 3-4 sessions | P3 |
