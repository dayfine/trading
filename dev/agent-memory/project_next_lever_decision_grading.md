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
- **Phase 3 + Phase 4 SHIPPED (PR #1649, 2026-06-18).** The lens is usable
  end-to-end.
  - **Phase 3 `Decision_grading.Aggregate`** (pure lib + 6 tests):
    `graded_trade {exit_reason; realized_pnl_pct; continuation_pct; exit_grade;
    entry_capture_ratio}` → `aggregate_by_exit_reason : graded_trade list →
    group_stats list` (sorted by reason; per group n, mean realized pnl, mean
    post-exit continuation, % premature, % good-exit, **mean_net_value_add_pct =
    −mean_continuation_pct**, mean entry-capture ratio) + `to_markdown`.
  - **Phase 4 `decision_grading` CLI** (`bin/decision_grading_bin.ml`):
    `--scenario-dir --snapshot-dir [--horizons 4,13,26] [--grade-horizon 13]
    [--out]`. Joins `Trade_audit_report.load` + a snapshot Bar_reader
    (`Daily_panels.create` → `Snapshot_callbacks.of_daily_panels` →
    `Bar_reader.of_snapshot_views`), fetches post-exit weekly bars per closed
    trade (`weekly_bars_for ~n:(max_h+3) ~as_of:(exit_date+max_h*7d)`), grades
    each exit, aggregates, renders markdown.
  - **GOTCHA (load-bearing):** read `exit_reason` from **trades.csv** directly
    (the CSV `exit_trigger` column), NOT `Trade_audit_report.per_trade_row.exit_trigger`
    — the loader derives that from the audit record's exit_trigger, which is
    BLANK for laggard_rotation / stage3_force_exit in pre-#1506 runs (no
    `exit_decision` captured). Using the loader label collapses the very
    distinctions the lens exists for.
  - **First real report (top-3000 2011 Cell-E, an OLD pre-#1506 run):** stops
    n=440 realized −2.8% / post-exit +8.1% → **net value-add −8.1%** (stops fire,
    price recovers — net-negative in chop); laggard_rotation n=220 realized
    +12.8% → net +1.6% (profit engine); stage3_force_exit n=5 post-exit −9.4%,
    60% good exits → **net +9.4%** (dodges drops). Re-derives
    [[project_trade_forensics_2026_06_12]] as a repeatable instrument. `mean
    capture` = n/a because MFE=0 in that old run (the harness gap predates
    #1506) — the populated path IS unit-tested; a FRESH post-#1506 run populates
    it.
- **LENS COMPLETE + FIRST FULL REPORT (PR #1650, 2026-06-18).** Ran a FRESH
  Cell-E top-3000 PIT-2011 15y backtest (`SNAPSHOT_CACHE_MB=1024`,
  `/tmp/snap_top3000_2011_v2`; reproduces +790.5%/671 trades/29.2%MaxDD
  bit-identical) → graded it. **MFE-join bug found + fixed:** the CLI read MFE via
  `Trade_audit_report` ratings keyed by the AUDIT entry_date (Friday decision
  date), ~1 day off the trades.csv entry_date (fill date) → join always missed →
  capture always n/a. Fix = read `exit_decision.max_favorable_excursion_pct`
  straight from trade_audit.sexp, join nearest entry_date within 7 days (same
  tolerance `Trade_audit_ratings._nearest_within` uses). **Decision-level verdict
  (2011-26, one regime):** stop_loss n=440 net value-add **−8.1%** / capture
  **−2.83** (price recovers +8.1% after the stop AND the avg stopped trade was UP
  at peak then closed for a loss — the whipsaw/stop-premium, the value-destroying
  decision type); laggard_rotation n=220 net +1.6%, mean realized +12.8% (fat-tail
  profit channel, capture≈0 = typical rotated name had stalled); stage3 n=5 net
  +9.4% / 60% good-exit (dodges drops, tiny n). Re-derives
  [[project_trade_forensics_2026_06_12]] as a repeatable instrument; consistent
  with [[project_edge_is_the_fat_tail]] (stops = the tail-risk insurance premium,
  now priced per decision type). Caveat: ONE window/regime, descriptive not a
  promotion verdict; "stops cost −8.1%" is the post-exit continuation
  counterfactual, does NOT net the tail-risk stops insure — do NOT conclude
  "remove stops" (winner-touching → must go through WF-CV + confirmation grid).
  Report: `dev/experiments/decision-grading-first-report-2026-06-18/FINDINGS.md`.
  Tool gotcha for re-running: scenario_runner resolves `universe_path` RELATIVE
  to `--fixtures-root`; use leading-slash-stripped path + `--fixtures-root /`.
- **INSURANCE DECOMPOSITION + DEEP READ (PR #1652, 2026-06-18) — answers "do
  stops earn their keep avoiding disasters?"** User pushed: the −8.1% net was a
  MEAN that nets a stop's rare-large benefit (disaster dodged) against its
  common-small cost (whipsaw) into one number. Upgraded `Aggregate` to decompose
  per exit_reason: mean disaster-dodged (`post_exit_max_adverse`), mean
  upside-foregone (`post_exit_max_favorable`), continuation p10/p90,
  disaster-dodge rate (% with max_adverse ≤ −20%, configurable). Ran 2011 bull vs
  1998-2026 deep (dot-com+GFC, +1934%/48.7%DD). **stop_loss @26w:** disaster
  dodged −18.9%(bull)/−19.5%(deep), upside foregone +32.7%/+29.9%, dodge rate
  40%/36%, net value-add −9.4%/−6.2%. VERDICT: **stops DO avoid real drops,
  regime-robustly, but per-decision upside-foregone exceeds it in BOTH regimes —
  bear regime narrows the gap but never flips it** (broad-universe names recover =
  fat-tail thesis from the exit side). **NOT a remove/loosen-stops verdict:** the
  per-decision equal-weight mean is BLIND to the portfolio-path ruin-insurance a
  stop provides (capping one position so a Stage-4 collapse can't sink NAV) —
  removing stops changes the PORTFOLIO left tail this lens doesn't observe, and is
  a spine-#5 winner/risk-touching change → WF-CV+grid. stage3_force_exit is the
  ONLY net-positive exit (+2.2% deep, largest disaster-dodged −22%, smallest
  upside-foregone) — it targets genuine Stage-3 rollovers. Forward guidance:
  stop-distance already tuned (0.08); deprioritize exit-tuning, bias to a
  diversifying layer (long-short). Writeup:
  `dev/experiments/decision-grading-deep-2026-06-18/FINDINGS.md`. Lens gap to fix
  if exits become focus: a portfolio-path/ruin-weighted exit metric.
- **(b) Phase 5 SHIPPED (PR #1653, 2026-06-18).** `Decision_grading.Laggard_cf`
  + `laggard_cf` bin: per-event cohort counterfactual (no 1:1 sold→bought link
  exists — cash → shared pool — so each rotation exit is paired vs new entries in
  a 10-day window after it; forward = Post_exit continuation). **VERDICT: the swap
  is a COIN FLIP.** Funded cohort beats dumped laggard ~50-53% across 1998-2026
  deep (mean paired diff ≈+1%, huge dispersion p10 −20/−39%, p90 +13/+36%); pays
  more in bull-only 2011-26 (+5-6%, 56-57%) but that EVAPORATES with dot-com+GFC.
  Re-derives [[project_harvest_rotate_rejected]] (coin-flip per event) from the
  realized mechanism. RECONCILES with "laggard=profit engine": the +12.8-16.9%
  mean realized is gain ALREADY accumulated before stalling; rotation harvests it
  + recycles capital — its value is **freshness/recycling, NOT swap selection**
  (the rotation decision adds ~nothing reliable). Keep it ON, don't tune the
  selection. Third winner-touching mechanism confirmed "neutral selection, value
  elsewhere" — tightens [[project_edge_is_the_fat_tail]]. Writeup:
  `dev/experiments/decision-grading-phase5-2026-06-18/FINDINGS.md`.
  **LESSON (cost 2 nesting-rework cycles on #1653): the nesting linter fails on
  AVG (not just max) — a `List.map ~f:(fun -> {record with nested-call field})`
  trips it; extract the lambda body AND the inner filter to named helpers. Run
  FULL `dune runtest` before every push.**
- **NEXT — (c) Initiative B long-short** (the bigger profit lever; the lens is now
  the instrument to judge it at the decision level). HARNESS-GAP (non-blocking, carried):
  `_mfe_index`/`_find_mfe` + the bin's grade-horizon field extraction are
  untested bin-local glue over the pinned libs — factor into a tested shared
  helper if the lens becomes load-bearing.
- **PROCESS LESSON (cost 1 rework cycle on #1652):** I again skipped the FULL
  `dune runtest` before pushing — scoped runtest passed but the repo-wide nesting
  + magic-number linters caught `aggregate_by_exit_reason` (filter_map callback
  depth 6 > 5) and bare `0.10/0.90` literals. The GHA orchestrator auto-pushed an
  equivalent `fix(review)` second commit (`Docker <docker@example.com>`) before I
  finished my local fix → bookmark divergence; resolved by ADOPTING origin's tip
  (don't force a divergent fold over an orchestrator auto-fix). ALWAYS run full
  `dune runtest` before pushing any decision_grading change.

**Then B = long-short Phase 5** (tracker, the profit lever; short-selling is
Weinstein-faithful — Stage-4 shorting; oversight-gated, `[[project_short_side_reprioritize]]`).

**Do NOT** run more top-level grids as the primary activity. The 1998-2026 matrix
in flight is the last top-level confirmation cell (closes the grid) — fine to
finish, but not where the value is.
