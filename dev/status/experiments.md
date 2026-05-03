# Status: experiments

## Last updated: 2026-05-03

## Status
IN_PROGRESS — M5.2e per-trade context logging shipped (PR #769, READY_FOR_REVIEW); M5.4 E3 sweep harness landed (this PR); M5.2a–d still PLANNED, sweep runs blocked on M5.1.

Track created 2026-05-02 to absorb M5.2 (experiment infra) + M5.4 (mechanical experiments). Plan: `dev/plans/m5-experiments-roadmap-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.2 + M5.4 (added 2026-05-02).

## Interface stable
NO — track is brand-new.

## Blocked on
- M5.1 foundation hardening (CI red on `main`: `split_day_stop_exit:1:post_split_exit_no_orphan_equity`; G14 split-adjust + G15 short-side risk surfaces). No experiment runs are interpretable until the foundation stops leaking.

## Scope

### M5.2 — Experiment infrastructure (5 sub-PRs)

- **2a — Config override + baseline + smoke flags** (~700 LOC). New: `backtest/lib/config_override.{ml,mli}`, `backtest/lib/comparison.{ml,mli}`, `backtest/scenarios/smoke_catalog.{ml,mli}`. Modifies: `backtest/bin/backtest_runner.ml`. Output: `dev/experiments/<name>/{baseline,variant,comparison.{sexp,md}}`.
- **2b — Trade aggregates + return basics** (~300 LOC). Extend `metric_computers.ml` + `metric_types.ml` with win_rate, avg_win/loss, profit_factor, expectancy, max_consecutive_*, etc.
- **2c — Risk-adjusted + drawdown analytics** (~300 LOC). Sharpe, Sortino, Calmar, MAR, Omega, ulcer/pain index, underwater area.
- **2d — Distributional / antifragility** (~250 LOC). Skewness, kurtosis, **concavity_coef** (γ from quadratic regression), bucket_asymmetry, CVaR, tail_ratio, gain_to_pain.
- [x] **2e — Per-trade context logging** (PR #769, ~600 LOC incl. tests). Extends trade-audit (#638/#642/#643/#651) with entry_stage, entry_volume_ratio, stop_initial_distance_pct, stop_trigger_kind, days_to_first_stop_trigger, screener_score_at_entry. New `Trade_context` module (`trading/trading/backtest/lib/trade_context.{ml,mli}`) does the pure projection; `Stop_log.classify_stop_trigger_kind` distinguishes gap-down from intraday stops; `Trade_audit.entry_decision` gains `volume_ratio : float option`; `Result_writer` extends trades.csv with the 6 new columns (header pinned by test_result_writer; full join pinned by test_trade_context). Verify: `dune runtest trading/backtest/test --force`.

### M5.4 — Mechanical experiments

- **E1 — Short on/off A/B** (uses 2a `--baseline`)
- **E2 — Segmentation-driven Stage classifier** (`stage_method = MaSlope | Segmentation` enum; lib already exists at `analysis/technical/trend/segmentation.{ml,mli}`)
- [x] **E3 — Stop-buffer sweep harness** (8 cells: 1.00 / 1.02 / 1.05 / 1.08 / 1.10 / 1.12 / 1.15 / 1.20 on `goldens-sp500/sp500-2019-2023`). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/`; hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`. Run via `dune exec backtest/scenarios/scenario_runner.exe -- --dir trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep --parallel 5` (local-only; ~5×2h tier-3 budget). Sweep run + report.md is the follow-up.
- **E4 — Scoring-weight sweep** (4-dim grid; manual prequel to M5.5 tuning)

## In Progress
- M5.2e per-trade context logging — PR #769 awaiting review.

## Completed
- M5.2e per-trade context logging (PR #769, 2026-05-02) — 6 new columns on trades.csv; `Trade_context` module + `Stop_log.classify_stop_trigger_kind` + `Trade_audit.entry_decision.volume_ratio`. Trade audit + stop_log pure-projection join. Verify via `dune runtest trading/backtest/test --force` (passes 14/14 in test_trade_context.ml + 18/18 in test_stop_log.ml + 26/26 in test_result_writer.ml).
- M5.4 E3 stop-buffer sweep harness (this PR, 2026-05-03) — 8-cell grid on `goldens-sp500/sp500-2019-2023` window (`{1.00, 1.02, 1.05, 1.08, 1.10, 1.12, 1.15, 1.20}`). Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/buffer-1.XX.sexp`; hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`. Verify parse via `dune build && dune runtest trading/backtest/scenarios/test/`. Sweep itself is local-only follow-up (~5×2h budget).

## Next Steps

1. M5.1 hardening: bring docker up, repro `split_day_stop_exit:1:post_split_exit_no_orphan_equity`, fix, re-pin sp500-2019-2023 baseline.
2. Open M5.2a PR (`--override` + `--baseline` + `--smoke` flags) — smallest unblock with biggest downstream multiplier.
3. M5.2b–e in sequence (PRs depend on each other only by the metric types).
4. M5.4 E1 (short on/off) as the first hypothesis run after 2a lands — mechanically simplest, tests the infra.

## Out of scope

- Live trading wiring (M6.6).
- Tuning (M5.5) — separate `tuning` track.
- Scale infra (streaming + Norgate) — separate `data-foundations` track.
