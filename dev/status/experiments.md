# Status: experiments

## Last updated: 2026-05-22

## Status
MERGED

## Notes
**2026-07-07 — `feature_screen` multivariate entry-selection screen (P0b).** New module tree `trading/trading/backtest/feature_screen/{lib,bin,test}` — a read-only exe that jointly regresses the counterfactual trade outcome (`return_pct`, and win = `return_pct>0`) on the full decision-time feature vector over the all-eligible trades CSV (from `All_eligible_runner.write_trades_csv`). Standardized OLS with HC1-robust SE + R², logistic (Newton/IRLS) with z-stats + rank AUC, one-hot categoricals (observed-only, drop-first reference), complete-case filter + None-coverage report, and an era-split (2000-08/2009-17/2018-26) coefficient sign-stability table. Hand-rolled dense linalg (no owl) per `.claude/rules/no-python.md`. IN-SAMPLE read-only screen only — the report footer forbids causal/deployable-alpha claims (feeds a no-build vs escalate-to-WF-CV decision per `.claude/rules/mechanism-validation-rigor.md`). Verify: `dune runtest trading/backtest/feature_screen`; run: `dune exec trading/backtest/feature_screen/bin/feature_screen_bin.exe -- --trades-csv <path> --out <report.md>`. Plan: `dev/plans/feature-screen-2026-07-07.md`. The 26y broad all-eligible generation half (PR #1878 feature columns) feeds it; the session driver runs it on real data.

M5.2a–e all MERGED (config-override + comparison + smoke catalog #756, trade aggregates #758, risk-adjusted + drawdown #762, distributional/antifragility #765, per-trade context #769). M5.4 E1–E4 harnesses all MERGED (#777/#754/#815/#816). **E3 + E4 sweep reports BOTH PRESENT** on `main`: `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md` (buffer 1.00 wins, PR #999 2026-05-08) and `dev/experiments/m5-4-e4-scoring-weight-sweep/report.md` (resistance-heavy wins, PR #1000 2026-05-08). M5.2 second-wave benchmark-relative metrics (alpha/beta/IR/TE/corr) shipped via #1021 (2026-05-10). **Stability + turnover metrics — MERGED #1073 (2026-05-13)** — M5.2 second-wave catch-all closed.

**81-cell flagship grid result (PR #1051, 2026-05-12)** — first run produced bit-identical metrics across all 81 cells and was published with a "weights are inert" verdict. PR #1061 (2026-05-13) reopened that: root cause was a **key-path bug** in the sweep overlays — they targeted `weights.{rs,volume,breakout,sector}` but the real `Screener.scoring_weights` fields are `w_positive_rs/w_strong_volume/w_stage2_breakout/w_sector_strong`. `_apply_overrides` silently dropped the unrecognized keys, so every cell ran identical config. **Weights ARE load-bearing** — counter-evidence: the M5.4-E4 sweep (using correct field paths) moved metrics by 22 pp return / 0.12 Sharpe. PR #1068 added `.mli` clarifications. **Path validator** MERGED #1069 (2026-05-13). Corrected sweep work was absorbed by the `tuning` track (Bayesian Phase 3 + V1→V7 sweep stack); see `dev/status/tuning.md`.

**Track wraps 2026-05-22.** Successor surfaces:
- M5.5 4-axis parameter sweep ran to completion 2026-05-13..14 (#1079..#1087); verdict in `memory/project_m5-5-tuning-exhausted.md`: single-lever Cell E tuning exhausted.
- P4 per-stage hold-period decomposition (#1219, 2026-05-21) + P5 AvgHoldingDays Composite wiring (#1220) absorbed under `tuning`.
- Random-universe selection-bias sweep (#1180/#1191, 2026-05-17) absorbed under `data-foundations`.
- M5.5 cross-window inversions (PR #1086 axis-2 + PR #1095 continuation combined) drove the 2026-05-15 strategic pivot to walk-forward CV (MERGED 2026-05-16) + Bayesian Phase 3 (MERGED 2026-05-17) — both surfaces now live under `walk-forward-cv` and `tuning` respectively.

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
- None. Track WRAPPED. M5.2a–e + M5.4 E1–E4 harnesses + benchmark-relative metrics (#1021) + stability/turnover metrics (#1073) all MERGED. M5.5 4-axis sweep verdict locked (`memory/project_m5-5-tuning-exhausted.md`). Successor work routed under `tuning` (Bayesian Phase 3 + V1→V7) and `walk-forward-cv` per the 2026-05-15 strategic pivot.

## Completed
- 81-cell flagship grid first run + result interpretation (PRs #1044 spec, #1051 run, #1061 interpretation, #1068 `.mli` clarifications, 2026-05-12..13) — the run itself completed but its "weights are inert" verdict was REOPENED in #1061 once the key-path bug was found. Counter-evidence (M5.4-E4) shows weights ARE load-bearing.
- Benchmark-relative metrics (alpha, beta, info ratio, tracking error, correlation) via PR #1021 (2026-05-10). Mirrors the existing computer pattern; closes the second-wave benchmark-relative slot in M5.2.
- M5.4 E3 stop-buffer sweep results (PR #999, MERGED 2026-05-08) — buffer 1.00 wins; `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md`.
- M5.4 E4 scoring-weight sweep results (PR #1000, MERGED 2026-05-08) — resistance-heavy wins; `dev/experiments/m5-4-e4-scoring-weight-sweep/report.md`.
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

1. ~~Run M5.4 E3 stop-buffer sweep~~ — DONE via PR #999 (2026-05-08; `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md`, buffer 1.00 wins).
2. ~~Run M5.4 E4 scoring-weight sweep~~ — DONE via PR #1000 (2026-05-08; `dev/experiments/m5-4-e4-scoring-weight-sweep/report.md`, resistance-heavy wins).
3. ~~Benchmark-relative metrics (alpha, beta, IR, TE, corr)~~ — DONE via #1021 (2026-05-10).
4. ~~Run 81-cell flagship grid on `screening.weights.*`~~ — first run DONE via #1051 (2026-05-12) but invalidated by key-path bug (PR #1061, 2026-05-13). Rerun absorbed by `tuning` track via Bayesian Phase 3 PR-B (#1132) — corrected `w_positive_rs/...` field paths now BO knobs.
5. ~~Stability + turnover metrics~~ — DONE via #1073 (2026-05-13; rolling-Sharpe stability, trade-frequency, position-turnover, sector-rotation; M5.2 second-wave catch-all closed).

**Track wraps 2026-05-22.** All Next Steps shipped. Successor surfaces under `tuning`, `walk-forward-cv`, and `data-foundations`.

## Out of scope

- Live trading wiring (M6.6).
- Tuning (M5.5) — separate `tuning` track.
- Scale infra (streaming + Norgate) — separate `data-foundations` track.
