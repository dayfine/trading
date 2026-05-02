# M5 — Experiments + Tuning Roadmap

Date: 2026-05-02 — supersedes the standalone scope of `dev/plans/experiment-framework.md` (kept for history) and absorbs the tuning thrust originally scoped under §7 M7.

Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.1–M5.5 (added 2026-05-02).

## Context

M5 ("Historical Backtesting") landed as code months ago and has since spawned seven sub-tracks (`backtest-infra`, `backtest-scale`, `backtest-perf`, `data-panels`, `hybrid-tier`, `trade-audit`, `optimal-strategy`). What's missing is the **experiment loop** — a structured way to flip features on/off, sweep parameters, and compare results — and the **tuning loop** — search over the parameter surface (weights, thresholds, lookbacks) using ML techniques.

Drift since 2026-04-01:
- Backtest fidelity is the work that actually happens (split-day OHLC, tier-loaders, force-liquidation cascades, short-side risk).
- Experiments are run by hand: edit config in source, rebuild, rerun, eyeball metrics.
- No tuner exists. `optimal-strategy` is a per-run counterfactual (upper bound on a fixed run's universe), not a parameter search.

This plan structures the next phase: experiment infra (M5.2) → mechanical experiments (M5.4) → parameter tuning (M5.5). Scale infra (M5.3) and foundation hardening (M5.1) are scoped here for completeness but tracked separately.

## M5.1 — Foundation hardening

### Why first

No backtest result is interpretable while the foundation is leaking.

### Items

| Item | Status | Surface | Owner |
|---|---|---|---|
| **G14 split-adjustment on `Position.t` Holding state — Option 1 (raw close-price space)** | NEEDS_DECISION (scope-extension) | `weinstein_strategy.ml`, `position.ml` | feat-weinstein (with escalation) |
| **G15 short-side risk control — phantom Portfolio_floor was unintended** | NEEDS_DECISION (scope-extension) | `weinstein_strategy.ml`, `Trading_portfolio` | feat-weinstein (with escalation) |
| **CI red — `split_day_stop_exit:1:post_split_exit_no_orphan_equity`** | OPEN (2026-05-02) | `trading/trading/simulation/test/test_split_day_stop_exit.ml` + simulator/engine fill path | feat-backtest |
| **G6 deterministic `_generate_order_id`** | merged via #735 (forward-guard via #703) | `trading/orders/lib/create_order.ml` | done |
| **G4 long-side extension + portfolio-peak threshold (cross-cutting)** | NEEDS_DECISION | `weinstein_strategy.ml` | (TBD) |

### CI failure — first action

PR #678 ("fix(simulation): adjust strategy-side Position.t map on split events") was merged on 2026-04-29 with the PR-body warning *"Do NOT merge until: (a) maintainer-local `dune build && dune runtest` passes — local Docker was unresponsive during this session"*. CI run [25238889053](https://github.com/dayfine/trading/actions/runs/25238889053) (2026-05-02) confirms that test #2 of the suite (`post_split_exit_no_orphan_equity`) has been failing on `main` since #678 landed. Tests #1 and #3 pass.

Failure: exit cash = $99,600 vs $100,000 expected (Δ = $400 = 100 × $4).

Hypothesis: entry market order fills at day-2 close ($504) instead of day-2 open ($500) for the post-split-exit-day scenario only. Engine code-read says `_would_fill_market` returns `path[0] = bar.open_price` invariantly — contradicts the hypothesis. Needs docker reproduction to confirm.

Acceptance: test #2 green, sister tests #1 and #3 still green, sp500-2019-2023 baseline rerun produces the canonical (134 trades, +70.8% return, 5% MaxDD) numbers per `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md`.

## M5.2 — Experiment infrastructure

### Goal

Make hypothesis-driven backtest comparison fast and durable. Currently each experiment requires source-edit → rebuild → manual diff. Target: `--override key=value --baseline --smoke` runs default + variant configs and writes a comparison artifact, with a 35-metric suite scoring both.

### Sub-PRs

#### M5.2a — Config override + baseline + smoke flags (~700 LOC)

`backtest_runner` extension. Sexp-style key-paths (`stops.initial_stop_buffer=1.08`) applied to `Weinstein_strategy.config` before run. `--baseline` runs twice (default + override) and writes a comparison file. `--smoke` runs a fixed 3-window catalog (Bull 2019-06–2019-12, Crash 2020-01–2020-06, Recovery 2023) with a target wall of ~5 minutes per scenario.

Output structure:
```
dev/experiments/<name>/
  experiment.sexp       # hypothesis, overrides, date range, scenarios
  baseline/
    summary.sexp
    trades.csv
    metrics.sexp
  variant/
    summary.sexp
    trades.csv
    metrics.sexp
  comparison.sexp       # per-metric diff (variant − baseline)
  comparison.md         # human-readable
```

Files to touch:
- `trading/trading/backtest/lib/config_override.{ml,mli}` (new) — sexp path parser + applier
- `trading/trading/backtest/bin/backtest_runner.ml` — flag wiring + dual-run mode
- `trading/trading/backtest/lib/comparison.{ml,mli}` (new) — emits comparison.sexp + .md
- `trading/trading/backtest/scenarios/smoke_catalog.{ml,mli}` (new) — bull/crash/recovery presets

Acceptance:
- `--override stops.initial_stop_buffer=1.05` on a known scenario produces a different trades.csv vs baseline
- `--baseline` writes both subdirs + comparison.sexp/md
- `--smoke` runs 3 windows in <20 minutes on M2 hardware
- Override applies *only* to the named field; all other config sourced from default

#### M5.2b — Trade aggregates + return basics (~300 LOC)

Add to `trading/trading/backtest/lib/metric_computers.ml` + `metric_types.ml`:

| Category | Metric | Annualized? |
|---|---|---|
| Returns | total_return, CAGR, vol, downside_dev | ✓ all |
| Returns | best/worst day, week, month, quarter, year | — |
| Trade aggregates | win_rate, loss_rate, num_trades | — |
| Trade aggregates | avg_win_$, avg_win_pct, avg_loss_$, avg_loss_pct | — |
| Trade aggregates | largest_win, largest_loss | — |
| Trade aggregates | avg_trade_size_$, avg_trade_size_pct | — |
| Trade aggregates | avg_holding_days_winners, avg_holding_days_losers | — |
| Trade aggregates | profit_factor (= gross_profit / gross_loss) | — |
| Trade aggregates | expectancy (= win_rate × avg_win − loss_rate × avg_loss) | — |
| Trade aggregates | win_loss_ratio (= avg_win / avg_loss) | — |
| Trade aggregates | max_consecutive_wins, max_consecutive_losses | — |

Acceptance: every metric computable from existing `step_result` + `trade_metrics`. Test fixture with hand-pinned values.

#### M5.2c — Risk-adjusted + drawdown analytics (~300 LOC)

| Category | Metric | Annualized? |
|---|---|---|
| Risk-adjusted | Sharpe, Sortino, Calmar, MAR, Omega(threshold=0), Information_ratio | ✓ all |
| Drawdown | max_DD, avg_DD, median_DD | — |
| Drawdown | max_DD_duration_days, avg_DD_duration_days | — |
| Drawdown | time_in_DD_pct | — |
| Drawdown | ulcer_index, pain_index | — |
| Drawdown | underwater_curve_area | — |

Acceptance: pinned values on synthetic equity curves with known Sharpe + max_DD. `Calmar = CAGR / max_DD` cross-check.

#### M5.2d — Distributional + antifragility (~250 LOC)

The novel block. The concavity coefficient is the antifragility measurement.

| Metric | Definition |
|---|---|
| skewness | third standardized moment of return distribution |
| kurtosis | fourth standardized moment (excess kurtosis: subtract 3) |
| concavity_coef (γ) | quadratic regression `r_strat = α + β·r_bench + γ·r_bench²`. γ > 0 = convex/antifragile. γ < 0 = concave/fragile |
| bucket_asymmetry | bin benchmark into quintiles; compute strategy avg per bucket; report `(Q1 + Q5) / (Q2 + Q3 + Q4)`. > 1 = barbell |
| CVaR_95, CVaR_99 | mean of worst 5% / 1% of returns (Expected Shortfall) |
| tail_ratio | `mean(top 5% returns) / |mean(bottom 5%)|` |
| gain_to_pain | `Σ gains / |Σ losses|` |

Acceptance:
- Synthetic curve with known skew/kurt — pinned within tolerance
- Convex synthetic strategy (long volatility) — γ > 0 verified
- Concave synthetic strategy (short volatility) — γ < 0 verified
- All distributional metrics included in `comparison.md` rendering

#### M5.2e — Per-trade context logging (~300 LOC)

Extend `trade-audit` (already wired via #638/#642/#643/#651) with per-trade context:

| Field | Source |
|---|---|
| entry_stage | `Weinstein_strategy._screen_universe` decision at entry tick |
| entry_volume_ratio | breakout volume / 4-week avg volume at entry tick |
| stop_initial_distance_pct | initial stop / entry price ratio |
| stop_trigger_kind | `GapDown` / `Intraday` / `EndOfPeriod` (existing tags + new GapDown) |
| days_to_first_stop_trigger | days from entry to first stop hit (or NA if held) |
| screener_score_at_entry | the score the screener assigned (links to `optimal-strategy` oracle later) |

Acceptance:
- All fields populate on `trades.csv`
- Round-trip through `Trade_rating` heuristics (#649) without breaking existing 4 behavioral metrics
- Pinned on a known scenario via golden test

### Stability + benchmark-relative metrics (M5.2 second wave)

Once 2a–2e land, add:

| Category | Metric | Annualized? |
|---|---|---|
| Benchmark-relative | alpha, beta, tracking_error, up_capture, down_capture | ✓ where applicable |
| Benchmark-relative | pct_months_beating_bench, pct_years_beating_bench | — |
| Stability | rolling_Sharpe_12mo, rolling_Sharpe_36mo | ✓ |
| Stability | rolling_beta_12mo | — |
| Stability | return_autocorr_lag1, lag5, lag20 | — |

## M5.3 — Scale infra

### Daily-snapshot streaming (Option 2 hybrid-tier)

Per `dev/plans/daily-snapshot-streaming-2026-04-27.md`. ~3000 LOC across 5–8 PRs. Required for tier-4 release-gate at N≥5,000.

Status: P1 future work. Phase 1 starts after M5.1 hardening lands and M5.2a ships.

### Norgate Data ingestion (NEW)

Goal: survivorship-bias-aware historical universe (point-in-time S&P 500, Russell 1000, Russell 2000 membership).

EODHD's current universe is *today's* universe — symbols that delisted before today are missing, biasing all backtests upward.

| Item | Notes |
|---|---|
| Vendor decision | Norgate Data — $32–66/mo, purpose-built for backtesting |
| Universe coverage | US 1990-present; point-in-time index membership; delisted symbols included |
| Integration | New `analysis/data/sources/norgate/` lib mirroring `eodhd/` shape |
| Storage | CSV under `dev/data/norgate/<sym>.csv` + index-membership snapshots `dev/data/norgate/index_membership/<index>/<date>.csv` |
| Backwards compat | EODHD continues for live + recent (last 30d); Norgate is historical |

Acceptance:
- One symbol's daily bars fetchable via Norgate path
- `index_membership("S&P 500", "2008-09-15") = [list of 500 symbols on Lehman day]`
- Survivorship bias test: backtest 2000-01–2003-12 on dotcom S&P universe yields more failures than current EODHD baseline (qualitative, not pinned)

CRSP defer: ~$5k/yr institutional. Only viable for 100-year NYSE data (1925+). Skip until M7.1 ML training shows that scale matters.

## M5.4 — Mechanical experiments

Each is a `--baseline` run plus a one-line override. Listed in priority order.

### E1 — Short on/off A/B

Hypothesis: short-side signals add or subtract from total return + Sharpe; quantify on sp500-2019-2023 + 2022 bear scenarios.

Override: `weinstein_strategy.short_side_enabled = false` (already a flag). Runs once with shorts on, once with shorts off, compares all 35 metrics.

Acceptance: `dev/experiments/short-on-off/comparison.md` exists with all metrics + verdict.

### E2 — Segmentation-driven Stage classifier

Hypothesis: trend segmentation (in `trading/analysis/technical/trend/segmentation.{ml,mli}`, exists since 2026-03 but unwired) gives more accurate Stage 2 entry signals than the current MA-slope-based classifier.

Wire: add `stage_method = MaSlope | Segmentation` enum to `Stage.classify`. Default `MaSlope` (current behavior). New variant calls into `Trend.Segmentation.detect_change_points`.

Acceptance:
- Both methods produce a Stage.t for the same input
- A/B run on 5 scenarios shows distinct trade counts
- No behavioral regression on existing MA-slope path (golden tests still pass)

### E3 — Stop-buffer sweep

Hypothesis: widening from 2% to 5–8% improves win rate and reduces whipsaw.

Override: `stops.initial_stop_buffer = 1.05 / 1.08 / 1.12`. 4-cell sweep on smoke scenarios.

Acceptance: `dev/experiments/stop-buffer-sweep/comparison.md` reports win rate + total return + max DD across 4 variants.

### E4 — Scoring-weight sweep

Hypothesis: current cascade weights (RS, volume, breakout, sector) were hand-set; a 3×3×3×3 grid (~81 cells) reveals which weight matters most.

Override: 4-dim grid on `screening.weights.*`. Skim parallelizable; run on smoke scenarios first to bound cost.

Feeds into M5.5 (tuning) — this is the manual prequel.

## M5.5 — Parameter tuning (ML)

### Approach ladder

| Tier | Method | Cost | Yields |
|---|---|---|---|
| T-A | Grid search over weights (4-dim, 81 cells × 3 scenarios = 243 backtests) | Wall-clock on smoke scenarios; cheap | Best static config |
| T-B | Bayesian optimization (Gaussian process, ~30 backtests/dim) | Medium | Better config + sensitivity surface |
| T-C | Supervised regression on per-trade features → predicted Score | Largest scope; needs feature engineering + model serialization | Replaces hand-set weights with learned model |

### Hard prerequisites

- M5.2 metrics catalog → ML target signals (CAGR, Sharpe, Calmar, concavity_coef)
- M5.2e per-trade context → ML features (entry_stage, entry_volume_ratio, etc.)
- M7.0 data foundations (Norgate) → train/test splits across long horizons + delisted symbols
- `optimal-strategy` track (already MERGED) → oracle labels for T-C (per-Friday counterfactual)

### T-A — Grid search

Implementation: `trading/trading/backtest/tuner/lib/grid_search.{ml,mli}` (new).

Inputs:
- Param spec: `[("screening.weights.rs", [0.2; 0.3; 0.4]); ...]`
- Objective: `Sharpe | Calmar | TotalReturn | Concavity_coef | Composite of [...]`
- Scenarios: list of backtest scenarios

Outputs:
- `dev/tuning/<name>/grid.csv` — one row per cell, all 35 metrics + objective
- `dev/tuning/<name>/best.sexp` — argmax(objective) cell
- `dev/tuning/<name>/sensitivity.md` — per-param marginal effect on objective

Acceptance:
- 81-cell grid runs in <2 hours on smoke scenarios
- Best cell + sensitivity report deterministic given fixed seed

### T-B — Bayesian optimization

Implementation: `trading/trading/backtest/tuner/lib/bayes_opt.{ml,mli}` (new). Pure OCaml Gaussian process — needs `gp` lib or roll-your-own (small, <500 LOC for the GP core). Acquisition function: Expected Improvement.

Acceptance:
- Converges to T-A's best cell within ~30 backtests on the same param space
- Uncertainty estimates reported per-param

### T-C — Supervised regression

Goal: replace hand-set scoring weights with a learned model that predicts which symbols are most likely to be in the `optimal-strategy` oracle's pick set.

Features (from M5.2e per-trade context, evaluated at every Friday):
- Stage (one-hot: Stage1/2/3/4)
- 30-week MA slope
- Volume_ratio (4-week)
- RS vs market
- Distance from breakout level
- Sector strength
- Macro regime (one-hot: Bullish/Bearish/Neutral)

Label: was this symbol in the `optimal-strategy` per-Friday oracle pick set?

Models (in order):
1. **Linear regression** (OCaml-native, ~200 LOC) — baseline + interpretable weights
2. **Decision tree** (OCaml-native or via `owl` lib if available) — captures non-linear interactions
3. **xgboost / lightgbm via FFI** (OCaml C bindings exist) — production-grade gradient boosting

Acceptance:
- Linear regression beats hand-set weights on test set Sharpe (walk-forward, 2019–2023 train, 2024–2025 test)
- Decision tree improves on linear by ≥5% on test Sharpe
- Model serializable to sexp; loaded at runtime by `Weinstein_strategy`

### Walk-forward validation protocol

For all three tiers:
- Train window: 2010–2018 (or as long as data allows post-Norgate ingest)
- Test window: 2019–2023
- Hold-out: 2024–2025 (final validation, run once)
- No peeking: walk forward in 1-year increments, retraining each year

### No Python

Per `.claude/rules/no-python.md`. ML done in OCaml-native or via FFI to C libs (xgboost, lightgbm). No `*.py` files anywhere in the repo — `no_python_check.sh` is wired into `dune runtest`.

## Files to touch (rollup)

| Phase | New files | Modified files |
|---|---|---|
| M5.2a | `backtest/lib/config_override.{ml,mli}`, `backtest/lib/comparison.{ml,mli}`, `backtest/scenarios/smoke_catalog.{ml,mli}` | `backtest/bin/backtest_runner.ml`, `backtest/lib/dune` |
| M5.2b–d | (extend) `backtest/lib/metric_computers.ml`, `metric_types.ml` | rendering helpers in `release_perf_report` |
| M5.2e | (extend) `trade_audit/lib/*` for per-trade context | `weinstein_strategy.ml` (capture sites) |
| M5.3 streaming | per `dev/plans/daily-snapshot-streaming-2026-04-27.md` | hybrid-tier surface |
| M5.3 Norgate | `analysis/data/sources/norgate/{lib,bin,test}` | `data-foundations` track |
| M5.4 segmentation | `analysis/weinstein/stage/lib/stage.ml` (`stage_method` enum) | `Trend.Segmentation` consumer |
| M5.5 tuner | `backtest/tuner/{lib,bin,test}` | `dev/tuning/<name>/` artifacts |

## Risks / unknowns

- **OCaml ML library landscape is thin.** `owl` exists (numerical) but coverage is partial. Decision tree + xgboost via FFI is the realistic path. Worst case: T-C requires bespoke OCaml decision tree (~600 LOC).
- **Concavity coefficient interpretation.** γ from quadratic regression is sensitive to benchmark choice. Spec the benchmark explicitly (default: SPY total return) and report γ alongside benchmark name.
- **Norgate licensing.** Licensing terms restrict redistribution. Make sure the data isn't checked into git; cache to `dev/data/norgate/` (gitignored) only.
- **Walk-forward leakage.** ML pipeline must train on data strictly before test window. Per-Friday `optimal-strategy` oracle is computed *after* the fact — careful to use only oracle labels from train-window Fridays as supervision.
- **CI red on main blocks all PR auto-merge.** M5.1 first action (CI repro + fix) must land before any other PR in this plan.

## Acceptance for the plan as a whole

- M5.1 hardening green; sp500-2019-2023 baseline matches canonical pin
- M5.2a–e + benchmark-relative + stability landed; comparison artifact + 35 metrics live
- M5.3 streaming + Norgate landed; tier-4 release-gate runs at N≥1000
- M5.4 four mechanical experiments completed with verdict files
- M5.5 T-A grid search produces a config that beats hand-set baseline by ≥10% on test-window Sharpe
- M7.0 + M7.1 ML pipeline (T-C) reports test-set performance; docs explain how to retrain

## Out of scope

- Live trading wiring (M6.6)
- 100-year NYSE data via CRSP (deferred until M7.1 proves scale matters)
- GAN/VAE synthetic generation (Synth-v4+ — defer)
- Daily-cadence intraday data (we trade weekly)
