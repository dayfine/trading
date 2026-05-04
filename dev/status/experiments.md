# Status: experiments

## Last updated: 2026-05-04

## Status
IN_PROGRESS

## Notes
**M5.2 experiment infrastructure is COMPLETE.** All five sub-PRs merged: 2a (PR #756), 2b (PR #758), 2c (PR #762), 2d (PR #765), 2e (PR #769). Plus follow-ups: comparison label table refactor (PR #768), smoke catalog sp500-default + `--shared-override` (PR #774), `--fuzz` parameter-jitter mode (PR #780). M5.4 sweep harnesses landed: E3 (PR #815), E4 (PR #816). **Next priority dispatches: M5.4 E1 (short on/off A/B) and E2 (segmentation-driven Stage classifier)** — both mechanical hypothesis runs that use the now-complete `--baseline` infra.

Track created 2026-05-02 to absorb M5.2 (experiment infra) + M5.4 (mechanical experiments). Plan: `dev/plans/m5-experiments-roadmap-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.2 + M5.4 (added 2026-05-02).

## Interface stable
NO

## Blocked on
- None. Prior M5.1 blocker (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`) was RESOLVED by PR #752 weeks ago; G14 split-adjust + G15 short-side risk surfaces also landed (see `dev/status/short-side-strategy.md`). Sweep runs are now interpretable — M5.4 E3/E4 sweep runs themselves remain local-only follow-ups (~5×2h tier-3 budget each).

## Scope

### M5.2 — Experiment infrastructure (5 sub-PRs) — COMPLETE

- [x] **2a — Config override + baseline + smoke flags** (PR #756, ~700 LOC). New: `backtest/lib/config_override.{ml,mli}`, `backtest/lib/comparison.{ml,mli}`, `backtest/scenarios/smoke_catalog.{ml,mli}`. Modifies: `backtest/bin/backtest_runner.ml`. Output: `dev/experiments/<name>/{baseline,variant,comparison.{sexp,md}}`. Follow-ups: PR #768 (label-table refactor), PR #774 (sp500-default + `--shared-override`), PR #780 (`--fuzz` parameter-jitter mode).
- [x] **2b — Trade aggregates + return basics** (PR #758, ~300 LOC). Extends `metric_computers.ml` + `metric_types.ml` with win_rate, avg_win/loss, profit_factor, expectancy, max_consecutive_*, etc.
- [x] **2c — Risk-adjusted + drawdown analytics** (PR #762, ~300 LOC). Sharpe, Sortino, Calmar, MAR, Omega, ulcer/pain index, underwater area.
- [x] **2d — Distributional / antifragility** (PR #765, ~250 LOC). Skewness, kurtosis, **concavity_coef** (γ from quadratic regression), bucket_asymmetry, CVaR, tail_ratio, gain_to_pain.
- [x] **2e — Per-trade context logging** (PR #769, ~600 LOC incl. tests). Extends trade-audit (#638/#642/#643/#651) with entry_stage, entry_volume_ratio, stop_initial_distance_pct, stop_trigger_kind, days_to_first_stop_trigger, screener_score_at_entry. New `Trade_context` module (`trading/trading/backtest/lib/trade_context.{ml,mli}`) does the pure projection; `Stop_log.classify_stop_trigger_kind` distinguishes gap-down from intraday stops; `Trade_audit.entry_decision` gains `volume_ratio : float option`; `Result_writer` extends trades.csv with the 6 new columns (header pinned by test_result_writer; full join pinned by test_trade_context). Verify: `dune runtest trading/backtest/test --force`.

### M5.4 — Mechanical experiments

- **E1 — Short on/off A/B** (uses 2a `--baseline`)
- **E2 — Segmentation-driven Stage classifier** (`stage_method = MaSlope | Segmentation` enum; lib already exists at `analysis/technical/trend/segmentation.{ml,mli}`)
- [x] **E3 — Stop-buffer sweep harness** (8 cells: 1.00 / 1.02 / 1.05 / 1.08 / 1.10 / 1.12 / 1.15 / 1.20 on `goldens-sp500/sp500-2019-2023`). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/`; hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`. Run via `dune exec backtest/scenarios/scenario_runner.exe -- --dir trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep --parallel 5` (local-only; ~5×2h tier-3 budget). Sweep run + report.md is the follow-up.
- [x] **E4 — Scoring-weight sweep harness** (8 cells on `goldens-sp500/sp500-2019-2023` — `baseline`, `equal-weights`, `stage-heavy`, `volume-heavy`, `rs-heavy`, `resistance-heavy`, `sector-heavy`, `late-stage-strict`). One-axis-at-a-time perturbations of `Screener.scoring_weights` (manual prequel to M5.5 T-A grid). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/`; hypothesis + README at `dev/experiments/m5-4-e4-scoring-weight-sweep/`. Run via `dune exec backtest/scenarios/scenario_runner.exe -- --dir trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep --parallel 5` (local-only; ~5×2h tier-3 budget). Sweep run + report.md is the follow-up.

## In Progress
- (none — M5.2 infra complete; awaiting M5.4 E1/E2 dispatch)

## Completed
- M5.2a experiment-runner overrides + comparison + smoke catalog (PR #756, 2026-05-02) — `Backtest.Config_override` (key-path → partial-config sexp), `Backtest.Comparison` (per-metric delta sexp + Markdown), `Scenario_lib.Smoke_catalog` (Bull/Crash/Recovery windows). CLI flags on `backtest_runner`: `--override`, `--baseline`, `--smoke`, `--experiment-name`. Output layout: `dev/experiments/<name>/{baseline,variant}/{summary.sexp,trades.csv,...}` + `comparison.{sexp,md}`. Follow-ups: PR #768 (data-driven label table), PR #774 (sp500 default + `--shared-override`), PR #780 (`--fuzz` parameter-jitter). Verify via `dune runtest trading/backtest/test/` (passes test_config_override, test_comparison, test_smoke_catalog, test_backtest_runner_args).
- M5.2b trade aggregates + return basics (PR #758, 2026-05-02) — total_return_pct, volatility, downside_dev, best/worst day/week/month/quarter/year, num_trades, win/loss rates, profit_factor, expectancy, win_loss_ratio, max_consecutive_wins/losses on `metric_computers.ml` + `metric_types.ml`.
- M5.2c risk-adjusted + drawdown analytics (PR #762, 2026-05-02) — Sortino, MAR, Omega, avg/median DD, DD durations, time_in_DD, ulcer/pain index, underwater area.
- M5.2d distributional + antifragility (PR #765, 2026-05-02) — skewness, kurtosis, CVaR_95, CVaR_99, tail_ratio, gain_to_pain, **concavity_coef** (γ from quadratic regression vs benchmark), bucket_asymmetry.
- M5.2e per-trade context logging (PR #769, 2026-05-02) — 6 new columns on trades.csv; `Trade_context` module + `Stop_log.classify_stop_trigger_kind` + `Trade_audit.entry_decision.volume_ratio`. Trade audit + stop_log pure-projection join. Verify via `dune runtest trading/backtest/test --force` (passes 14/14 in test_trade_context.ml + 18/18 in test_stop_log.ml + 26/26 in test_result_writer.ml).
- M5.4 E3 stop-buffer sweep harness (PR #815, 2026-05-03) — 8-cell grid on `goldens-sp500/sp500-2019-2023` window (`{1.00, 1.02, 1.05, 1.08, 1.10, 1.12, 1.15, 1.20}`). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/buffer-1.XX.sexp`; hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`. Verify parse via `dune build && dune runtest trading/backtest/scenarios/test/`. Sweep itself is local-only follow-up (~5×2h budget).
- M5.4 E4 scoring-weight sweep harness (PR #816, 2026-05-03) — 8-cell single-axis perturbation grid on `goldens-sp500/sp500-2019-2023` window (`baseline`, `equal-weights`, `stage-heavy`, `volume-heavy`, `rs-heavy`, `resistance-heavy`, `sector-heavy`, `late-stage-strict`). Each cell doubles a single weight from `Screener.default_scoring_weights`. Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/<axis>.sexp`; hypothesis + README at `dev/experiments/m5-4-e4-scoring-weight-sweep/`. Verify parse via `dune build && dune runtest trading/backtest/scenarios/test/`. Sweep itself is local-only follow-up (~5×2h budget).

## Next Steps

1. M5.4 E1 (short on/off A/B) — mechanically simplest hypothesis, exercises the now-complete `--baseline` infra. Override: `weinstein_strategy.short_side_enabled = false`. Local-only run on smoke + sp500-2019-2023; report at `dev/experiments/short-on-off/`.
2. M5.4 E2 (segmentation-driven Stage classifier) — wire `stage_method = MaSlope | Segmentation` enum on `Stage.classify`; segmentation lib already exists at `analysis/technical/trend/segmentation.{ml,mli}`. Default `MaSlope` to preserve existing goldens; A/B via `--override` on the new flag.
3. M5.4 E3/E4 sweep runs — local-only, results in `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md` and `…e4-scoring-weight-sweep/report.md`.
4. M5.5 T-A grid search (`backtest/tuner/`) — depends on M5.2 metrics catalog (now complete) + per-trade context (M5.2e, complete).

## Out of scope

- Live trading wiring (M6.6).
- Tuning (M5.5) — separate `tuning` track.
- Scale infra (streaming + Norgate) — separate `data-foundations` track.
