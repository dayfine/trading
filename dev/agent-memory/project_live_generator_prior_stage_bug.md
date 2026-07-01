---
name: project_live_generator_prior_stage_bug
description: "Live weekly-snapshot generator passed prior_stage:None → reset weeks_advancing to ~1 for every Stage-2 stock → live picks were ~55% extended advancers the ≤4-week gate should reject. FIXED + MERGED #1818."
metadata: 
  node_type: memory
  type: project
  originSessionId: b69b7ea0-879e-4b35-a918-38f2e67d75e2
---

**Defect (found 2026-07-01, doc `dev/notes/live-generator-prior-stage-bug-2026-07-01.md`, PR #1816):**
`Weekly_snapshot_generator._analyze_ticker` (`weekly_snapshot_generator.ml:63`) calls
`Stock_analysis.analyze ~prior_stage:None`. Without a prior stage, `Stage.classify`
**resets `weeks_advancing` to ~1 for EVERY Stage-2 stock** (it can't count how long
the stock has advanced without the chain). Consequences: (1) grades collapse — every
advancer scores as "Early Stage2" (this is why all 2026 live picks pin to score 70 /
grade A); (2) **admission pollution** — `Stock_analysis._initial_breakout_arm`'s
`weeks_advancing ≤ 4` early gate never bites, so the live list is ~55% *extended*
advancers (AIP ~44wk, ATRO ~45wk ≈ 11 months into Stage 2) the strategy's own rule
should reject.

**Backtests are UNAFFECTED** — they chain prior_stage via
`weinstein_trading_state.prior_stages`. This is a **live-generator-only fidelity bug.**

**FIX MERGED (#1818, 2026-07-01, main `4662e768b`):** chain the stage
classifier in the generator (roll `Stage.classify` over the weekly prefix threading
prior, feed the chained prior into `analyze`). Re-ran on the 50 pick symbols at
as-of 2026-05-29: candidates **22 → 10**, dropping exactly the w5–w45 extended names;
survivors are the genuinely-early breakouts; corrected `weeks_advancing` matches the
`stage_dump` reference exactly. Landed via option-1 (correctness fix): the 2 tests
that encoded the buggy prior=None behavior were re-anchored (as_of 2022-10-07→09-16, a
w6 stale breakout is now rightly rejected) + a `test_stale_breakout_not_admitted`
regression pins it. qc-structural + qc-behavioral APPROVED (5/5; faithfulness
IMPROVEMENT, backtest parity confirmed — backtest chains via trading_state, never calls
this generator, so no golden re-pin). **OPEN follow-up (deferred):** now that the ≤4
admission gate actually bites, is ≤4 the right threshold vs the 8wk breakout-event
window? Separate tuning decision, not yet done.

**Tooling:** `analysis/scripts/stage_dump/` (MERGED #1816) — a prior-chained
stage-timeline inspector: `stage_dump <data_dir> <sym> <end_date> <from_date>`.

Relates to [[project_weekly_snapshot_generator_caveats]] (the "top 3 alphabetical /
all-tie-70" caveats — this is the root cause of the all-70) and
[[project_decision_audit_faithful]] (the faithfulness thread that started this).
