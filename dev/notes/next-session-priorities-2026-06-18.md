# Next-session priorities — 2026-06-18

**Supersedes** `next-session-priorities-2026-06-17.md`. Check main CI green first
(`.claude/rules/session-rampup.md`).

## What shipped this session (2026-06-17/18, autonomous)

### 1. Factor-lens confirmation grid — CLOSED (4 cells)
The descriptive question "what governs the strategy's edge vs the index" is now
answered and robust. H1 dodge-correction (realized edge ~ forward index max-DD):

| cell | H1 Pearson r | deepest-DD tercile | shallow-DD tercile | PR |
|---|---|---|---|---|
| t1k 2000-26 | −0.79 | −4.98 | −15.01 | (earlier) |
| t3k 2000-26 | −0.744 | −4.21 | −16.39 | #1639 |
| t3k 2011-26 (bull-dom) | −0.892 | −7.79 | −23.40 | #1642 |
| t3k 1998-26 (deepest) | −0.820 | −3.52 | −16.45 | #1645 |

**Conclusion:** regime (depth of forward drawdown) governs the edge, universe- AND
macro-regime-robust. The edge is a **drawdown-avoidance instrument** — it crosses
into POSITIVE realized edge only for the deepest-DD starts (1998-01 +1.20%,
1999-05 +0.46%, both facing dot-com+GFC ahead; reproduces the deep-contiguous beat
`project_deep_1998_2026_contiguous`), and is a relative drag in bull regimes.
Entry-supply (H3) confounded in every cell — not a lever. Memory:
`project_factor_lens_regime_governs_edge`.

**DEAD END (user direction 2026-06-18):** a "regime-gated deploy rule" (turn the
strategy on only before crashes) is NOT a lever — it is market-timing on SPY,
already shown worse, and the crash-dodging is already built into the Stage-3/4
exits. Do not pursue. The deploy signal (forward DD) is ex-post anyway.

### 2. Decision-grading lens — Phases 1 + 2 MERGED
New pure libs at `trading/trading/backtest/decision_grading/`:
- **Phase 1 `Post_exit`** (#1646): post-exit continuation metrics — for a closed
  trade, reads weekly bars AFTER the exit and computes `continuation_pct` +
  post-exit MFE/MAE per horizon. Pure (takes a bar list).
- **Phase 2 `Grade`** (#1647): classifies an exit `Premature | Good_exit |
  Neutral` from its `Post_exit` continuation vs configurable thresholds
  (default ±10% at 13w); `entry_capture_ratio` (pnl/MFE). Pure.

These are the per-DECISION measurement + grading primitives — the instrument the
user asked for ("stop judging configs by top-level Sharpe/DD; grade decisions by
results"). Memory: `project_next_lever_decision_grading`.

## P0 NEXT — finish the decision-grading lens (Phases 3-4), WITH the user

These need a REAL backtest `scenario_dir` to smoke-test (data-gated) + a sanity
check on the first real report, so do them with the user available (not unattended):

- **Phase 3 — aggregate by exit_reason.** Group per-trade grades by exit reason
  (`stop_loss` / `stage3_force_exit` / `laggard_rotation` / `force_liquidation` /
  `end_of_period`); report n, mean realized pnl, mean post-exit continuation,
  **% premature**, **net value-add** (realized − counterfactual-if-held). This is
  the repeatable, systematized version of the one-off `trade-forensics-2026-06-12`
  finding (stops ≈ net-zero in chop; laggard = profit engine).
- **Phase 4 — CLI exe.** `decision_grading/bin/` reading a scenario_dir via
  `Trade_audit_report.load` (joins trades.csv + trade_audit.sexp + summary.sexp)
  + a snapshot bar source for the post-exit bars (same resolver as
  `rolling_start_eval`). `--scenario-dir --snapshot-dir --horizons 4,13,26 --out`.
- **Then USE it:** grade the stops / laggard / stage3 exits on a real Cell-E
  top-3000 run → which decision types add vs destroy value → that drives the next
  strategy change (judged at the decision level, not by aggregate Sharpe).
- Phase 5 stretch: paired laggard-rotation counterfactual (did the funded buy beat
  the rotated-out name?).

Design + full detail: `dev/plans/decision-grading-lens-2026-06-17.md`.

## P1 — Initiative B: long-short Phase 5 (queued, oversight-gated)
The profit lever, still oversight-gated (`project_short_side_reprioritize`).
Short-selling is Weinstein-faithful (Stage-4 shorting). Take up after the lens is
usable end-to-end (so it can be judged at the decision level).

## Operational lessons this session
- **Scoped `dune runtest <dir>` does NOT run the repo-wide linters** (nesting,
  magic-number, mli-coverage, fn-length, file-length) — only a FULL `dune runtest`
  does. QC agents using the scoped form let 3 linter FAILs through on Phase 1
  (cost 2 rework cycles). Phase 2 ran the full runtest before push → clean first
  try. Put test files in a SIBLING `test/` dir, never `lib/test/`.
- **feat-agents keep finishing without pushing/PR'ing** (built Phase 2, left files
  on disk, ended mid-self-review). Recover from the worktree + finish by hand;
  don't re-dispatch (`feedback_feat_agents_lose_commits`).

## State
- All PRs merged, main green, 0 open PRs.
- v2 columnar-mmap warehouses at `/tmp/snap_top3000_{2000,2011,1998_2026}_v2`
  (top-3000 backtests run clean at cache=1024; the memory ceiling is gone).
