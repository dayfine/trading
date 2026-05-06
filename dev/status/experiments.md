# Status: experiments

## Last updated: 2026-05-06

## Status
IN_PROGRESS

## Notes
M5.2a–e all MERGED: config-override + comparison + smoke catalog (#756), trade aggregates (#758), risk-adjusted + drawdown (#762), distributional/antifragility (#765), per-trade context (#769). M5.4 E1 short on/off A/B (#777), E2 segmentation stage classifier (#754), E3 stop-buffer sweep harness (#815), E4 scoring-weight sweep harness (#816) all MERGED. Pending: E3/E4 actual sweep runs (local-only, ~5×2h each) + result `report.md` files.

Track created 2026-05-02 to absorb M5.2 (experiment infra) + M5.4 (mechanical experiments). Plan: `dev/plans/m5-experiments-roadmap-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.2 + M5.4 (added 2026-05-02).

## Interface stable
NO

## Blocked on
- None. Prior M5.1 blocker (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`) was RESOLVED by PR #752 weeks ago; G14 split-adjust + G15 short-side risk surfaces also landed (see `dev/status/short-side-strategy.md`). Sweep runs are now interpretable — M5.4 E3/E4 sweep runs themselves remain local-only follow-ups (~5×2h tier-3 budget each).

## Scope

### M5.2 — Experiment infrastructure (5 sub-PRs)

- **2a — Config override + baseline + smoke flags** (~700 LOC). New: `backtest/lib/config_override.{ml,mli}`, `backtest/lib/comparison.{ml,mli}`, `backtest/scenarios/smoke_catalog.{ml,mli}`. Modifies: `backtest/bin/backtest_runner.ml`. Output: `dev/experiments/<name>/{baseline,variant,comparison.{sexp,md}}`.
- **2b — Trade aggregates + return basics** (~300 LOC). Extend `metric_computers.ml` + `metric_types.ml` with win_rate, avg_win/loss, profit_factor, expectancy, max_consecutive_*, etc.
- **2c — Risk-adjusted + drawdown analytics** (~300 LOC). Sharpe, Sortino, Calmar, MAR, Omega, ulcer/pain index, underwater area.
- **2d — Distributional / antifragility** (~250 LOC). Skewness, kurtosis, **concavity_coef** (γ from quadratic regression), bucket_asymmetry, CVaR, tail_ratio, gain_to_pain.
- [x] **2e — Per-trade context logging** (PR #769, ~600 LOC incl. tests). Extends trade-audit (#638/#642/#643/#651) with entry_stage, entry_volume_ratio, stop_initial_distance_pct, stop_trigger_kind, days_to_first_stop_trigger, screener_score_at_entry. New `Trade_context` module (`trading/trading/backtest/lib/trade_context.{ml,mli}`) does the pure projection; `Stop_log.classify_stop_trigger_kind` distinguishes gap-down from intraday stops; `Trade_audit.entry_decision` gains `volume_ratio : float option`; `Result_writer` extends trades.csv with the 6 new columns (header pinned by test_result_writer; full join pinned by test_trade_context). Verify: `dune runtest trading/backtest/test --force`.

### M5.4 — Mechanical experiments

- [x] **E1 — Short on/off A/B** (PR #777, MERGED 2026-05-02)
- [x] **E2 — Segmentation-driven Stage classifier** (PR #754, MERGED 2026-05-02; `stage_method = MaSlope | Segmentation` enum)
- [x] **E3 — Stop-buffer sweep harness** (8 cells: 1.00 / 1.02 / 1.05 / 1.08 / 1.10 / 1.12 / 1.15 / 1.20 on `goldens-sp500/sp500-2019-2023`). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/`; hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`. Run via `dune exec backtest/scenarios/scenario_runner.exe -- --dir trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep --parallel 5` (local-only; ~5×2h tier-3 budget). Sweep run + report.md is the follow-up.
- [x] **E4 — Scoring-weight sweep harness** (8 cells on `goldens-sp500/sp500-2019-2023` — `baseline`, `equal-weights`, `stage-heavy`, `volume-heavy`, `rs-heavy`, `resistance-heavy`, `sector-heavy`, `late-stage-strict`). One-axis-at-a-time perturbations of `Screener.scoring_weights` (manual prequel to M5.5 T-A grid). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/`; hypothesis + README at `dev/experiments/m5-4-e4-scoring-weight-sweep/`. Run via `dune exec backtest/scenarios/scenario_runner.exe -- --dir trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep --parallel 5` (local-only; ~5×2h tier-3 budget). Sweep run + report.md is the follow-up.

## In Progress
- None. M5.2a–e and M5.4 E1–E4 harnesses all MERGED. Next: run E3/E4 sweeps locally and write result report.md files.

## Completed
- M5.4 E1 short on/off A/B (PR #777, MERGED 2026-05-02) — uses `--baseline` infra; `dev/experiments/short-on-off/` comparison artefacts.
- M5.4 E2 segmentation-driven Stage classifier (PR #754, MERGED 2026-05-02) — `stage_method = MaSlope | Segmentation` enum; both paths produce stage output; existing MA-slope goldens pass.
- M5.2d distributional/antifragility catalog (PR #765, MERGED 2026-05-02) — skewness, kurtosis, concavity_coef (γ), bucket_asymmetry, CVaR_95/99, tail_ratio, gain_to_pain. Also #771 benchmark plumbing.
- M5.2c risk-adjusted + drawdown analytics (PR #762, MERGED 2026-05-02) — Sharpe, Sortino, Calmar, MAR, Omega, ulcer/pain index, underwater_area.
- M5.2b trade aggregates + return basics (PR #758, MERGED 2026-05-02) — win_rate, avg_win/loss, profit_factor, expectancy, max_consecutive_*, etc.
- M5.2a config override + baseline + smoke catalog (PR #756, MERGED 2026-05-02) — `--override key=value`, `--baseline` dual-run mode, `--smoke` 3-window catalog; writes `dev/experiments/<name>/{baseline,variant,comparison.{sexp,md}}`.
- M5.2e per-trade context logging (PR #769, 2026-05-02) — 6 new columns on trades.csv; `Trade_context` module + `Stop_log.classify_stop_trigger_kind` + `Trade_audit.entry_decision.volume_ratio`. Trade audit + stop_log pure-projection join. Verify via `dune runtest trading/backtest/test --force` (passes 14/14 in test_trade_context.ml + 18/18 in test_stop_log.ml + 26/26 in test_result_writer.ml).
- M5.4 E3 stop-buffer sweep harness (PR #815, 2026-05-03) — 8-cell grid on `goldens-sp500/sp500-2019-2023` window (`{1.00, 1.02, 1.05, 1.08, 1.10, 1.12, 1.15, 1.20}`). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/buffer-1.XX.sexp`; hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`. Verify parse via `dune build && dune runtest trading/backtest/scenarios/test/`. Sweep itself is local-only follow-up (~5×2h budget).
- M5.4 E4 scoring-weight sweep harness (this PR, 2026-05-03) — 8-cell single-axis perturbation grid on `goldens-sp500/sp500-2019-2023` window (`baseline`, `equal-weights`, `stage-heavy`, `volume-heavy`, `rs-heavy`, `resistance-heavy`, `sector-heavy`, `late-stage-strict`). Each cell doubles a single weight from `Screener.default_scoring_weights`. Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/<axis>.sexp`; hypothesis + README at `dev/experiments/m5-4-e4-scoring-weight-sweep/`. Verify parse via `dune build && dune runtest trading/backtest/scenarios/test/`. Sweep itself is local-only follow-up (~5×2h budget).

## Next Steps

1. Run M5.4 E3 stop-buffer sweep locally (`scenario_runner.exe --dir .../experiments/m5-4-e3-stop-buffer-sweep --parallel 5`); write `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md` with verdict.
2. Run M5.4 E4 scoring-weight sweep locally; write `dev/experiments/m5-4-e4-scoring-weight-sweep/report.md` with verdict. Feeds M5.5 T-A grid setup.
3. M5.2 second-wave metrics (benchmark-relative + stability) when sweep results are available to compare.

## Out of scope

- Live trading wiring (M6.6).
- Tuning (M5.5) — separate `tuning` track.
- Scale infra (streaming + Norgate) — separate `data-foundations` track.
