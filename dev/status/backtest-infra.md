# Status: Backtest Infrastructure

## Last updated: 2026-04-16

## Status
READY_FOR_REVIEW

UnrealizedPnl=0 bug fixed + CAGR annualized-return docstring clarified (follow-up items 1+2) on `feat/metrics-unrealized-fix`. First experiment (stop-buffer) complete and REJECTED on golden — see §Completed. Framework formalization still open; support-floor experiment still blocked on `feat-weinstein` #382.

## Ownership
`feat-backtest` agent — see `.claude/agents/feat-backtest.md`. Owns
experiments + strategy-tuning features (stop-buffer tuning, drawdown
circuit breaker, per-trade stop logging, segmentation-based stage
classifier). Distinct from `feat-weinstein`, which owns the base
strategy code (currently complete).

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

## Completed

- [x] **UnrealizedPnl=0 bug + annualized-return clarification**
  (2026-04-16, `feat/metrics-unrealized-fix`) — see Follow-up items 1
  and 2 for full root-cause writeup. Fix: `portfolio_state_computer.ml`
  now tracks last mark-to-market step separately from last step, so
  `UnrealizedPnl` no longer collapses to 0 when the sim ends on a
  weekend. CAGR docstring clarified as the canonical annualized-return
  metric. Verify: `dune runtest trading/simulation/test` (metrics
  suite grew from 33 → 35 tests).
- [x] **Stop-buffer tuning experiment** — full smoke + golden complete.
  Smoke (recovery-2023, 1yr) looked strongly positive for wider buffers
  (1.15 → +38.9%, Sharpe 1.78). **Golden (2018-2023, 6yr) reversed the
  result**: 1.15 returned -7.1% with Sharpe -0.01; 1.02 control won
  cleanly (+36.3%, Sharpe 0.36, lowest DD). Hypothesis REJECTED. Default
  `initial_stop_buffer = 1.02` stays. Scenario files at
  `trading/test_data/backtest_scenarios/experiments/stop-buffer/`. Report
  at `dev/experiments/stop-buffer/report.md`. Outputs:
  `dev/backtest/scenarios-2026-04-14-222425/` (smoke) and
  `dev/backtest/scenarios-2026-04-14-225929/` (golden).
- [x] **Per-trade stop logging** (#350, 2026-04-15) — `Stop_log`
  observer + `Strategy_wrapper` capture stop levels and exit-trigger
  type on each transition; `Result_writer` emits `entry_stop`,
  `exit_stop`, `exit_trigger` columns in `trades.csv`. Unblocks
  post-mortem of individual whipsaw exits.

## In progress
None.

## Blocked on
- **Support-floor-based stops experiment** (next in Next Actions) requires a new primitive in `weinstein/stops/` — stop placement by prior correction lows. Owned by `feat-weinstein`. Per 2026-04-16 direction change in `dev/decisions.md`, feat-weinstein is dispatched on `feat/support-floor-stops`; track at `dev/status/support-floor-stops.md`. Once it lands, feat-backtest picks up the experiment as a config-override variant next run.

## Next Actions

### Stop-buffer follow-ups (pick one)

The single-parameter fixed-buffer approach is brittle across regimes.
Alternatives ranked by expected value:

1. **Support-floor-based stops** (Weinstein's actual prescription):
   place stops at prior correction lows. Adapts to each stock's structure.
2. **Regime-aware stops**: use `Macro.analyze` trend to pick buffer width
   (tighter in bear, wider in bull). Testable via existing macro output.

Per-trade stop logging landed in #350 — now available as a diagnostic
input for any of the above experiments.

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
- **Experiment framework formalization** — once 1-2 experiments show the
  shape.
- **Token/cost tracking** (T3-E from harness.md) — unrelated to this track
  but listed here historically.

## Follow-up items (queued 2026-04-16)

1. ~~**Verify unrealized gain is meaningful in `summary.sexp`.**~~ **[x]
   RESOLVED 2026-04-16** — bug confirmed, fix landed on
   `feat/metrics-unrealized-fix`. Root cause: the simulator produces a
   `step_result` every calendar day, but `_compute_portfolio_value`
   (at `trading/trading/simulation/lib/simulator.ml:123-134`) falls
   back to `portfolio_value = current_cash` whenever any portfolio
   position's price bar is missing for that date — including all
   weekend/holiday steps. The portfolio-state computer was using the
   absolute last step, which in 6-year backtests ending 2023-12-31
   (Sunday) is 2023-12-30 (Saturday) — a non-trading day, hence
   `portfolio_value == current_cash` and `UnrealizedPnl = 0` even with
   `OpenPositionCount = 3`. Fix: track a `last_marked_step` alongside
   `last_step`; `UnrealizedPnl` derives from the last mark-to-market
   step (same heuristic as `Backtest.Runner._is_trading_day` at
   `trading/trading/backtest/lib/runner.ml:28-36`); `OpenPositionCount`
   still uses the absolute last step (positions are independent of
   price-bar availability). Two new unit tests at
   `trading/trading/simulation/test/test_metrics.ml` lock in the
   behaviour. Verify: `dune runtest trading/simulation/test` → 35
   metrics tests pass.

2. ~~**Add annualized-return metric for apples-to-apples comparison
   across scenarios.**~~ **[x] RESOLVED 2026-04-16** — picked option
   (a). CAGR already *is* the annualized-return metric — it's the
   constant yearly rate that compounds initial to final portfolio
   value over the backtest period. Clarified the docstring in
   `trading/trading/simulation/lib/types/metric_types.ml:144-154` to
   state this explicitly so future readers don't re-queue this. No
   second metric added; no code behaviour change.

3. **Rerun smoke + golden simulations once the Finviz sector mapping
   is promoted.** The 2026-04-14 stop-buffer results were produced
   against `data/sectors.csv` = 1,654 symbols. The live Finviz scrape
   has that file at ~9,000 and the Item 4 universe filter
   (#368) brings it back down to ~4,916 with different composition.
   Screener behavior depends on sector-map coverage, so the baseline
   and all published experiment deltas may shift. After #368 lands
   and the filtered CSV is promoted: re-run `smoke/recovery-2023.sexp`
   and all three `golden/six-year-2018-2023` buffer variants, compare
   against the 2026-04-14 numbers in
   `dev/experiments/stop-buffer/report.md`, update the report with a
   post-sector-expansion addendum.

4. **Consolidate "what data range do we have" into one document.**
   Today it's scattered:
   - Per-symbol price bar ranges live in `data/inventory.sexp` (fields
     `first_date` / `last_date` per symbol).
   - ADL Unicorn history documented in `dev/notes/adl-sources.md` as
     1965-03-01 → 2020-02-10.
   - Synthetic ADL coverage (post-2020-02-11) documented implicitly
     in the composition rule in `trading/weinstein/strategy/lib/ad_bars.mli`.
   - Sector ETFs cached in `data/<letter>/<XL...>/` but no aggregated
     range.
   - Global indices (FTSE/DAX/Nikkei) — per-symbol only.
   Add `dev/notes/data-coverage.md` with a single table: dataset →
   source → range → last refreshed. Written once, refreshed from
   `data/inventory.sexp` by a small script run from the ops-data agent.
   Makes it obvious at a glance when a backtest's requested window
   exceeds available data for some input.

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
