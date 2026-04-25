# Status: Backtest Infrastructure

## Last updated: 2026-04-25

## Status
MERGED

Step 1 (#399) + Step 2 (#419) landed long ago. Step 3 continued on
the backtest-scale track. The perf-sweep harness extension (#547)
landed 2026-04-25. Continuous perf monitoring + benchmark-suite work
moved to its own track at `dev/status/backtest-perf.md`. The 12-step
incremental-indicators refactor (the follow-on architecture for
Tier 3) tracked separately at `dev/status/incremental-indicators.md`.

## QC

Step 1 (PR #399, merged) — overall_qc APPROVED at e59f8d2 (both prior blockers U6/F1 and the BC4 advisory resolved; `_held_symbols` strategy fix domain-correct).

Step 2 (PR #419, ready for review):
- structural_qc: APPROVED (re-verification at 0381bde, 2026-04-18 run 4) — refactor-only delta from cc4edca6 (trace.ml sentinel→option, dropped `to_string`, simplified parsers; -23 net lines); fmt violation at 73f74c2 fixed by 0381bde.
- behavioral_qc: APPROVED (re-verification at 0381bde, 2026-04-18 run 4) — Trace is pure instrumentation plumbing; Weinstein domain axes remain NA; refactor preserves behavior.
- overall_qc: APPROVED (re-verification at 0381bde)

Step 2 of the scale-optimization plan complete on
`feat/backtest-phase-tracing` (PR #419). Adds a `Backtest.Trace` module
(`trading/trading/backtest/lib/trace.{ml,mli}`) with `Phase.t` (11
variants), a `phase_metrics` record, `record : ?trace -> Phase.t ->
(unit -> 'a) -> 'a`, and `write : out_path -> metrics -> unit`.
`Runner.run_backtest` gains an optional `?trace` argument (default off)
and instruments 5 coarse phases at the runner level: Load_universe,
Macro, Load_bars, Fill, Teardown. Finer-grained wraps for the per-bar
strategy phases (Sector_rank / Rs_rank / Stage_classify / Screener /
Stop_update / Order_gen) require strategy-level instrumentation and are
deferred (see §Follow-up). Step 2 unblocks the separately-tracked Step
3 tier-aware bar loader (`dev/status/backtest-scale.md`) by giving A/B
measurements a commit-stable sexp output format.

Step 1 (merged via PR #399) delivered the two-tier universe for
scenarios. Small-universe pinned at 300 symbols across all 11 GICS
sectors; broad-universe sentinel falls back to the full
`data/sectors.csv`. Goldens reorganised

**Environment note (2026-04-18):** the GHA `dev/lib/run-in-env.sh dune
build @runtest` target fails because the nesting linter reports 49
pre-existing violations (universe_filter, fetch_finviz_sectors, ad_bars)
— none introduced by this PR. `trading/backtest/lib/trace.ml` and
`trading/backtest/lib/runner.ml` are clean under the linter. The
pre-flight context said main exits 0; in this container it doesn't. The
PR's own targeted test command `dune runtest trading/backtest/test/`
passes with 0 warnings and all 19 cases green (10 new Trace tests + 6
Stop_log + 3 Runner_filter). Flagging for QC to confirm this is the
same pre-existing state seen elsewhere and not a regression.

Earlier on 2026-04-17 the per-scenario `unrealized_pnl` range pin landed
(feat/metrics-scenario-unrealized-pin, follow-up to merged #393). Before
that: UnrealizedPnl=0 bug fixed + CAGR docstring clarified via PR #393.
First experiment (stop-buffer) complete and REJECTED on golden — see
§Completed. Framework formalization still open; support-floor
experiment still blocked on `feat-weinstein` #382.

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
None. Merged in main:
- #399 Step 1 (two-tier universe) — 2026-04-17.
- #393 unrealized_pnl pin fix — 2026-04-17.
- #395 per-scenario `unrealized_pnl` range check — merged 2026-04-17.
- #419 Step 2 (per-phase tracing) — 2026-04-19.

## Next Steps

- **Step 3 (tier-aware bar loader)** now unblocked; separately tracked at
  `dev/status/backtest-scale.md`. A/B the Legacy vs Tiered loader
  against a traced Legacy baseline. Do not pick up Step 3 from this
  track — it has its own status file and branch
  (`feat/backtest-tiered-loader`).
- **Per-bar phase instrumentation** (Sector_rank through Order_gen)
  can land as a follow-up without changing the trace sexp schema — the
  Phase variants are already defined. See §Follow-up item 6. Practical
  prerequisite: the Tiered loader flip (`backtest-scale.md`) — per-bar
  tracing is most valuable once broad-universe runs are cheap enough
  to iterate on. Pick this up once the Tiered flip lands.

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

- [x] **Perf-sweep harness extension** (2026-04-23,
  `feat/backtest-perf-sweep-harness`). Wraps the existing C2 perf harness
  in a (N × T × strategy) sweep so future scaling investigations can read
  the slope of RSS / wall-time vs. universe size and run length, rather
  than rerunning a single-point hypothesis test for each variation. Four
  perf-sweep scenario sexps under
  `trading/test_data/backtest_scenarios/perf-sweep/{bull-3m,bull-6m,bull-1y,bull-3y}.sexp`
  use the broad universe sentinel so `--override '((universe_cap (N)))'`
  actually constrains the loaded set. Driver
  `dev/scripts/run_perf_sweep.sh` walks an 8-cell matrix (N=100/300/500/1000
  at T=1y plus T=3m/6m/3y at N=300 plus the 1000×3y worst corner), each
  cell × 2 strategies; skip-on-resume keys off non-empty
  `<strategy>.peak_rss_kb`; per-cell `timeout 1200` so a stuck cell
  doesn't hang the whole sweep. Aggregator
  `dev/scripts/perf_sweep_report.py` emits an RSS matrix, an N-sweep
  complexity table at fixed T=1y, a T-sweep complexity table at fixed
  N=300, a wall-time matrix, and a failure-section listing any cells
  that errored. Coarse linear-extreme-fit slope rows give the curve
  shape (sub-linear / linear / super-linear) without over-engineering
  the analysis. .gitignore extended with an explicit
  `dev/experiments/perf/sweep-*/` documentation pattern (already covered
  by the wildcard above). No production code touched. Verify:
  `bash -n dev/scripts/run_perf_sweep.sh`,
  `python3 -m py_compile dev/scripts/perf_sweep_report.py`,
  `dune build && dune runtest` (all green).

- [x] **Per-phase tracing (Step 2 of scale-optimization plan #396)**
  (2026-04-18, `feat/backtest-phase-tracing`, PR #419). New
  `Backtest.Trace` module (`trading/trading/backtest/lib/trace.{ml,mli}`)
  gives every backtest run a commit-stable phase-metrics sexp. Key shape:
  `Phase.t` has 11 variants (Load_universe / Load_bars / Macro /
  Sector_rank / Rs_rank / Stage_classify / Screener / Stop_update /
  Order_gen / Fill / Teardown); `record ?trace ?symbols_in ?symbols_out
  ?bar_loads phase f` runs `f ()` and appends one `phase_metrics` record
  with wall-clock elapsed_ms and best-effort peak_rss_mb (VmHWM from
  /proc/self/status). `?trace=None` is a no-op — callers wrap blocks
  unconditionally. `write ~out_path` emits a single sexp per run via
  `[@@deriving sexp]`, creating parent directories.
  `Runner.run_backtest` gains an optional `?trace` parameter and
  instruments 5 coarse phases at the runner level (Load_universe, Macro,
  Load_bars, Fill, Teardown — the first two inside `_load_deps`, the
  next two around `_make_simulator` and `_run_simulator`, Teardown
  around round-trip extraction + stop_infos gather). The 6 per-bar
  phases (Sector_rank through Order_gen) remain defined but not wired —
  they require strategy-level instrumentation inside `Simulator.run`
  and are a deliberate follow-up so Step 2 doesn't couple to a refactor
  of the simulator internals (see §Follow-up item 6). Output directory
  placeholder at `dev/backtest/traces/.gitkeep`. Ten OUnit2 cases under
  `trading/trading/backtest/test/test_trace.ml` cover `Phase.to_string`,
  sexp round-trip for all variants, `record` with ?trace=None
  passthrough, record with ?trace=Some recording (phase, counts,
  elapsed_ms >= 0), insertion order preservation, real elapsed
  measurement via busy-wait, and `write` + load_sexp round-trip with
  mkdir-p of a nested parent directory. Verify:
  `dev/lib/run-in-env.sh dune runtest trading/backtest/test/` (10 new
  tests).

- [x] **Related fix: strategy `_held_symbols` no longer includes Closed
  positions** (2026-04-17, `feat/weinstein-exclude-closed-from-held`).
  `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:130`
  previously returned every `portfolio.positions` entry regardless of
  lifecycle state — including `Closed` — which permanently blacklisted
  every symbol the strategy had ever traded from re-entry via both
  `held_tickers` passed to `Screener.screen` and the in-strategy
  candidate filter. Replaced with an exhaustive match that keeps
  `Entering | Holding | Exiting` and drops `Closed`. Two unit tests
  added (mixed-state + all-Closed). Unblocks meaningful backtests;
  `test_weinstein_backtest` scenario counts now shift and will be
  re-pinned on `feat/backtest-scenario-small-universe` (PR #399). See
  `dev/notes/strategy-dispatch-trace-2026-04-17.md` / PR #408.

- [x] **Two-tier universe for scenarios (Step 1 of scale-optimization
  plan #396)** (2026-04-17, `feat/backtest-scenario-small-universe`,
  PR #399). Adds a `universe_path : string` field to `Scenario.t`
  (defaults to `universes/small.sexp` via `[@sexp.default]`, backwards
  compatible). New `Scenario_lib.Universe_file` module parses the file
  as `Pinned of pinned_entry list | Full_sector_map`. Small-universe
  fixture (`trading/test_data/backtest_scenarios/universes/small.sexp`)
  pins ~300 symbols across all 11 GICS sectors (≥8 sectors, ≥100
  symbols enforced by test); broad-universe fixture is the
  `Full_sector_map` sentinel that falls back to `data/sectors.csv`.
  Goldens reorganised: `goldens/` → `goldens-small/`; new
  `goldens-broad/` with three scale-regression variants (`six-year`,
  `bull-crash`, `covid-recovery`) pinning the same expected ranges as
  the 2026-04-13 baseline. `Backtest.Runner.run_backtest` takes a new
  optional `?sector_map_override` parameter; `Scenario_runner` bridges
  via `Universe_file.to_sector_map_override`. New CLI flags
  `--goldens-small` (default, local-friendly), `--goldens-broad`
  (nightly/GHA), `--goldens` alias. Reproducible selection script at
  `trading/backtest/scenarios/pick_small_universe/pick.ml` (stratified
  sampling over `Inventory.load` + hand-curated known-historical
  cases) with docs pointer at `dev/scripts/pick_small_universe/README.md`.
  16 tests (9 scenario + 7 universe_file). This unblocks Step 2
  (per-phase tracing) under this track and the parallel
  `dev/status/backtest-scale.md` Step 3 work (tier-aware bar loader).
  Verify: `dune runtest trading/backtest/scenarios/test`.

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
- [x] **Pin `unrealized_pnl` per scenario** (2026-04-17,
  `feat/metrics-scenario-unrealized-pin`, follow-up to merged PR #393)
  — adds
  `expected.unrealized_pnl : range option` via `[@sexp.option]` to
  `Scenario.expected`, with the runner computing
  `UnrealizedPnl` into the `actual` record and pattern-matching a 7th
  range check. Scenarios that don't declare the field get `None` and
  skip the check (preserves prior behaviour). Five scenarios now pin a
  non-zero range (`min > 0`, intentionally wide to absorb the
  universe-size flux tracked under follow-up #3): all three goldens
  plus `bull-2019h2` and `recovery-2023` smokes. `crash-2020h1` is
  intentionally left unpinned because a crash regime can plausibly
  liquidate the whole portfolio. Also split the `scenarios/` dune into
  a tiny `scenario_lib` library + executable so parsing/validation is
  unit-testable without running a backtest. New test file
  `trading/trading/backtest/scenarios/test/test_scenario.ml` covers
  six cases (absent/present field parse, sexp round-trip, non-zero
  range rejects 0, near-zero range accepts 0, all real scenario files
  under `trading/test_data/backtest_scenarios/` parse and at least one
  pins `min > 0`). Verify:
  `dune runtest trading/backtest/scenarios/test` (6 tests).

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

0. ~~**BC4 — re-pin `goldens-small/*.sexp` expected ranges from real small-universe runs.**~~ **[x] RESOLVED 2026-04-17** — ranges re-measured against the 302-symbol small universe. Centers pinned (see each sexp's header block) with ±25% tolerance on counts/days, wide bands on ratios. Prior 1,654-symbol baseline preserved in git history. Broad-universe ranges separately flagged (see follow-up 5 below).

5. **Re-pin `goldens-broad/*.sexp` on GHA.** Broad goldens expect 1,654-symbol baseline but the active broad universe is 10,472 symbols (post Finviz sector-map refresh). Local re-pin is infeasible — Docker 7.75GB memory ceiling is exactly why the small universe exists. Current state (2026-04-17): each of the three broad sexps is marked `STATUS: SKIPPED` in-file; expected ranges widened to always-pass bounds so scenarios run-and-report without gating; `dev/status/_index.md` is not updated (per PR #401, orchestrator owns index). To unblock: add a GHA workflow (`goldens-broad.yml`, workflow_dispatch + weekly cron) that runs `--goldens-broad` on a bigger runner, uploads measured centers as artifacts; either a human or a follow-up PR commits tightened ranges and removes the SKIPPED banner from each sexp.



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

6. **Per-bar phase instrumentation (follow-up to PR #419).** The
   `Backtest.Trace` module (Step 2 of the scale-optimization plan)
   defines 11 `Phase.t` variants but the runner only wraps 5 coarse
   phases (Load_universe, Macro, Load_bars, Fill, Teardown). The
   remaining 6 (Sector_rank, Rs_rank, Stage_classify, Screener,
   Stop_update, Order_gen) are per-bar strategy phases that happen
   inside `Simulator.run` → `Weinstein_strategy.on_market_close`; wrapping
   them requires a small cross-cut inside the strategy or a tap point on
   the simulator's per-step callback. Deferred to keep PR #419 focused.
   Suggested approach: extend `Strategy_wrapper.wrap` with an optional
   `?trace` and have it wrap the strategy's `on_market_close` at the
   inner function boundaries where the screener cascade and stop update
   run. Trace sexp schema does not change — just more entries per run.
   Unblocks: detailed A/B of the Legacy vs Tiered bar loader (Step 3).

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
