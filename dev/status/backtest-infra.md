# Status: Backtest Infrastructure

## Last updated: 2026-04-14

## Status
IN_PROGRESS

## Ownership
Human-driven. **Not** assigned to a `feat-*` agent — the existing `feat-weinstein`
agent covers order_gen + Simulation Slice 2 only. Any future agent delegation
for this track would need a new agent definition.

## Landed (merged to main)

- `#195` — `strategy_cadence` on simulator config
- `#196` — Weinstein strategy `STRATEGY` implementation
- `#298` — Universe sort for partial determinism
- `#304` — Metric suite: ProfitFactor, CAGR, CalmarRatio, OpenPositionCount,
  UnrealizedPnl, TradeFrequency, plus base stats; derived metric computer
  pattern (`depends_on`)
- `#308` — Inline TODO slugs: `TODO(area/descriptive-slug)` anchored in status files
- `#311` — Metric computer split (each computer in its own file)
- `#312` — Sexp deriving on strategy config types (prereq for generic overrides)
- `#306` — `--override '<sexp>'` flags with generic deep-merge
- `#315` — Extract `backtest_runner_lib` from CLI; restructured into
  `trading/trading/backtest/{lib,bin}/` with `Backtest.{Summary,Runner,Result_writer}`;
  Summary uses `[@@deriving sexp_of]` with custom converters for `Money` and
  `Metric_set` to preserve human-readable formatting
- `#316` — Unified scenario runner with fork-based parallel execution
  - `trading/trading/backtest/scenarios/{scenario.ml,scenario_runner.ml}`
  - `Scenario` derives sexp (with custom range of_sexp and `[@@sexp.allow_extra_fields]`)
  - Fork pool; each child runs `Backtest.Runner` and writes `actual.sexp`; parent
    reads back and prints checks table in declaration order
  - Fixture files at `trading/test_data/backtest_scenarios/{goldens,smoke}/`

## Open PRs
None.

## Baseline results (2026-04-13, pre-experiments)

| Scenario | Period | Return | Win Rate | Max DD | Sharpe |
|----------|--------|--------|----------|--------|--------|
| six-year | 2018-2023 | +57% | 28.6% | 34.0% | 1.28 |
| bull-crash | 2015-2020 | +305% | 33.3% | 38.7% | 0.79 |
| covid-recovery | 2020-2024 | +27% | 47.7% | 38.0% | 1.00 |

**Critical finding:** 74% of trades exit within 1 day (whipsaw). Stop buffer too tight.

## Performance

- 6-year / 1654 stocks: ~40 min, 7 GB RAM (single run)
- 6-month smoke: ~5 min
- Parallel scenarios (post-#316): N scenarios run concurrently as forked children;
  memory scales ~linearly with N because each child reloads universe data.
- Non-deterministic due to Hashtbl ordering (tracked, not fully fixed)

## Next Actions

### Immediate: first experiment — stop buffer tuning

The infrastructure above was built specifically to unblock this. Setup:

1. `trading/test_data/backtest_scenarios/experiments/stop-buffer/` with
   ~5 scenario files differing only by `initial_stop_buffer` (e.g. 1.05,
   1.08, 1.10, 1.12, 1.15; current default 1.08).
2. Run via smoke period first for speed, then goldens for the winner.
3. Compare `win_rate`, `avg_holding_days`, `max_drawdown`, `total_return`
   across variants.
4. Record findings in `dev/experiments/stop-buffer/` (directory does not
   yet exist — see §Experiment framework below).

### Immediate: experiment framework

No framework exists yet. For the first experiment we can hand-roll output
files; formalization is a follow-up once we know what structure we actually
want. Candidate conventions:

- `dev/experiments/<name>/` — one directory per experiment
- `hypothesis.md`, `variants/*.sexp` (reuse `Scenario.t` format),
  `report.md` with comparative metrics table
- Optional: an `experiment_runner` wrapper around `scenario_runner` that
  emits the comparative report automatically

Defer formalization until after the first 1-2 experiments so the structure
is informed by actual needs.

### Medium-term

- **Drawdown circuit breaker** (Weinstein Ch. 7 — 20% threshold) — new
  feature, order_gen side. See
  `TODO(backtest-infra/drawdown-circuit-breaker)` when added.
- **Per-trade stop logging** — augment `trades.csv` with the stop level
  and which rule triggered. Enables post-mortem on whipsaws.
- **Experiment framework formalization** — once 1-2 experiments show the
  shape.
- **Token/cost tracking** (T3-E from harness.md) — unrelated to this track
  but listed here historically.

## Potential experiments (cross-functional — need feature work before runnable)

These have trading-behaviour impact but require upstream feature work before
they can be framed as a scenario variant. Owner-wise they straddle feature
tracks; tracked here so the planner sees the experiment end-state.

1. **Wider sector coverage** — filling in sector/industry for more of the
   universe (see `dev/status/data-layer.md` §Sector coverage expansion).
   Changes which symbols pass the `Sector` screener filter. **Hypothesis**:
   broader coverage → more qualifying Stage-2 candidates → different
   portfolio composition and possibly different win rate. Feature work
   needed: scrape + cache sector/industry (e.g. from Finviz).

2. **Universe composition cleanup** — drop mutual funds + low-volume ETFs
   (see `dev/status/data-layer.md` §Universe composition cleanup).
   **Hypothesis**: removing instruments that never pass the volume filter
   anyway should be a no-op on trade outcomes but speed up the simulation.
   Good sanity check that the filter is doing its job. Feature work
   needed: `universe_filter.ml`.

3. **Segmentation-based stage classifier** — piecewise linear regression
   on the MA series (already tracked in `dev/status/screener.md`
   §Followup). **Hypothesis**: fewer false stage-direction flips from
   short-term noise → steadier Stage 2 identification → fewer whipsaw
   exits. Feature work needed: swap `_compute_ma_slope` for
   `Segmentation.classify`. High likelihood of trading-behaviour
   improvement — ranks alongside stop-buffer tuning.

4. **Simulation performance** — not a trading-behaviour experiment but
   unblocks cheaper sweeps. See `dev/status/simulation.md` §Follow-up.

## Backtest Analysis TODOs (from dev/backtest/analysis.md)

1. **Stop placement** [HIGHEST IMPACT] — test wider stops and
   support-floor-based stops. **← this is the first experiment above.**
2. **Stop analysis logging** — per-trade stop level and trigger info in
   trades.csv
3. **Drawdown circuit breaker** — 20% threshold
4. **Portfolio health metrics** — partially done (#304 merged:
   OpenPositionCount, UnrealizedPnl)
5. **Segmentation for stages** — test trend segmentation library

## Harness items

- T2-B: Reference backtest config — landed via `test_data/backtest_scenarios/`
- T3-E: Token/cost tracking — not started (out of scope for this track)
