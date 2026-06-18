---
name: project_next_lever_decision_grading
description: "User direction 2026-06-17 — stop judging configs by TOP-LEVEL metrics (Sharpe/DD/edge); that's all the grids this past month did. Real lever = per-DECISION grading lens: grade each entry/stop/stage-exit/laggard-rotation vs its realized outcome + counterfactual. Regime-gating/deploy-timing is DEAD (= adding timing to SPY, already shown worse). Crash-dodging is already built in via Stage-3/4 exits. Priorities: A=decision-grading lens (fix MFE/MAE harness gap, make it a repeatable tool), then B=long-short Phase 5."
metadata: 
  node_type: memory
  type: project
  originSessionId: 400a42eb-61cb-40c7-91b6-5264cc922ba2
---

**The pivot (user, 2026-06-17, while AFK — "counting on you"):**

1. **Regime-gated deploy / "turn the strategy on only before crashes" is a DEAD
   END.** It is just *adding market-timing to SPY* = the SPY-only Weinstein we
   already studied, which is WORSE (timing is hard). Do not build it. The
   factor-lens (`[[project_factor_lens_regime_governs_edge]]`) established the
   regime-shape descriptively; the *lever* it implies is not tradeable. Stop here
   on regime-gating.

2. **Crash-dodging is NOT a missing feature — it's already the strategy.** Stopping
   out near Stage 3 / ahead of Stage 4 IS the built-in drawdown-avoidance.
   Imperfect only because stage classification is sometimes wrong.

3. **The real, unaddressed lever = DECISION-LEVEL analysis.** Every grid/experiment
   this past month judged configs on **top-level aggregate metrics** (Sharpe,
   MaxDD, edge-vs-index). That is shallow. The whole point of a *lens* is to go
   **decision by decision** — grade each entry, stop, stage-exit, and
   laggard-rotation against (a) what actually happened afterward and (b) the
   counterfactual of not taking that action — and learn which DECISION TYPES add
   vs destroy value, then fix them. We have only done this once, ad-hoc
   (`[[project_trade_forensics_2026_06_12]]`: laggard-rotation = profit engine,
   stops ≈ net-zero in chop, give-back measured) — never turned into a repeatable
   instrument.

**Concrete next work (A, prioritized):** build the decision-grading lens.
CODE-MAP CORRECTION (2026-06-17): the "MFE/MAE always 0" premise is STALE — it was
already fixed (PR #1506: weekly- not daily-bars; emit audit on stage3/laggard
exits too). MFE/MAE per trade are live in `trade_audit.sexp`. A ratings layer
already exists: `trading/trading/backtest/trade_audit_report/` =
`trade_audit_report` (loads+joins trades.csv + trade_audit.sexp + summary.sexp)
and `trade_audit_ratings` (R-multiple, MFE%/MAE%, behavioral metrics, cascade
win-rate matrix). Entry context fully captured in `entry_decision`; exit context +
MFE/MAE in `exit_decision`. (Only `weeks_macro_was_bearish` / `weeks_stage_left_2`
still hardcoded 0 — minor.)
- **The REAL gap = the COUNTERFACTUAL: nothing grades an EXIT by what the stock
  did AFTER we sold.** Build post-exit continuation capture (read K weeks of bars
  after exit_date via `Bar_reader.weekly_bars_for`) → grade each exit: price kept
  rising = premature (gave up a winner); price fell = good exit (dodged a drop).
  Pattern already exists per-symbol in `analysis/scripts/trade_autopsy`
  (`missed_gain_pct`). Never built for the full-portfolio engine (planned as
  "PR-3 post-exit capture-ratio", not started).
- Aggregate the grade BY decision type (stop_loss / stage3_force_exit /
  laggard_rotation / force_liquidation / end_of_period) → systematize the one-off
  `[[project_trade_forensics_2026_06_12]]` finding (stops ≈ net-zero in chop,
  laggard = profit engine). Make it a **repeatable exe**. New lib+bin at
  `trading/trading/backtest/decision_grading/`. Read-only lens, changes NO
  strategy behavior (no flag-discipline gate). Design:
  `dev/plans/decision-grading-lens-2026-06-17.md`.
- This is the instrument that makes every subsequent change (incl. long-short)
  judgeable at the decision level instead of by aggregate Sharpe.

**STATUS 2026-06-18:**
- **Phase 1 SHIPPED (#1646).** Pure `Decision_grading.Post_exit` lib at
  `trading/trading/backtest/decision_grading/lib/` (`post_exit.ml`/`.mli`) +
  sibling `test/` (11 OUnit tests). API: `post_exit_metrics ~side ~exit_price
  ~exit_date ~bars ~horizons_weeks → horizon_result list` where `horizon_result`
  = {horizon_weeks; continuation_pct; post_exit_max_favorable_pct;
  post_exit_max_adverse_pct}. Pure (takes a bar list; no Bar_reader/IO dep).
- **LESSON (cost 2 rework cycles):** the QC agents' scoped `dune runtest
  <dir>` does NOT run the repo-wide linters (nesting / magic-number /
  mli-coverage / fn-length / file-length) — only a FULL `dune runtest` does.
  CI caught 3 FAILs the agents missed. ALSO: put test files in a SIBLING
  `test/` dir (like `rolling_start/test/`), NEVER `lib/test/` — under lib they
  get scanned as lib code by magic-number + mli-coverage. For Phase 2+: run
  `dune build @fmt && dune build && dune runtest` (FULL, or the linter aliases)
  before pushing.
- **Phase 2 SHIPPED (#1647).** Pure `Decision_grading.Grade` module
  (`grade.ml`/`.mli` + sibling `test/test_grade.ml`): `exit_grade = Premature |
  Good_exit | Neutral`; `grade_config {premature_threshold_pct;
  good_exit_threshold_pct; grade_horizon_weeks}` + `default_config` (0.10/0.10/
  13w); `grade_exit ~config ~post_exit:Post_exit.horizon_result list →
  exit_grade` (picks the matching horizon; continuation already side-adjusted;
  missing horizon → Neutral); `entry_capture_ratio ~realized_pnl_pct
  ~max_favorable_pct → float option` (None when MFE≤0). Pure (Post_exit + Core
  only). The Phase-1 lesson held — full runtest run before push, linters clean
  first try, both QC APPROVED first try. (Note: the feat-agent built it but
  never pushed/PR'd — recovered the 4 files from its worktree + finished by
  hand; recurring feat-agent failure mode per [[feedback_feat_agents_lose_commits]].)
- **NEXT (data-gated, next session w/ oversight): Phase 3** (aggregate grades by
  `exit_reason`: stop_loss / stage3_force_exit / laggard_rotation /
  force_liquidation / end_of_period → % premature, net value-add vs counterfactual
  — systematizes [[project_trade_forensics_2026_06_12]]) + **Phase 4** (CLI exe
  reading a scenario_dir via `Trade_audit_report.load` + a snapshot bar source
  for post-exit bars). These need a REAL backtest scenario_dir to smoke-test, so
  do them with the user available. Phase 5 stretch = paired laggard-rotation
  counterfactual (did the funded buy beat the rotated-out name?).

**Then B = long-short Phase 5** (tracker, the profit lever; short-selling is
Weinstein-faithful — Stage-4 shorting; oversight-gated, `[[project_short_side_reprioritize]]`).

**Do NOT** run more top-level grids as the primary activity. The 1998-2026 matrix
in flight is the last top-level confirmation cell (closes the grid) — fine to
finish, but not where the value is.
