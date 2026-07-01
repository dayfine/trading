---
name: project_live_generator_prior_stage_bug
description: "Live weekly-snapshot generator passes prior_stage:None → resets weeks_advancing to ~1 for every Stage-2 stock → live picks are ~55% extended advancers the ≤4-week gate should reject. Fix validated, awaiting decision."
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

**Fix (validated, NOT yet landed — surfaced as a decision):** chain the stage
classifier in the generator (roll `Stage.classify` over the weekly prefix threading
prior, feed the chained prior into `analyze`). Re-ran on the 50 pick symbols at
as-of 2026-05-29: candidates **22 → 10**, dropping exactly the w5–w45 extended names;
survivors are the genuinely-early breakouts; corrected `weeks_advancing` matches the
`stage_dump` reference exactly. Held back because it changes live admission ~55%,
needs 2 generator tests updated (they encode the buggy prior=None behavior — their
synthetic breakout is 5–8wk stale so the corrected ≤4 gate rejects it), and exposes a
tuning question: the breakout-*event* window is 8wk but the *admission* gate is ≤4 —
is ≤4 right now that it actually bites? Decision options: (1) land as correctness fix,
(2) fix + retune ≤4, (3) validate the corrected set forward-returns better first.

**Tooling:** `analysis/scripts/stage_dump/` (MERGED #1816) — a prior-chained
stage-timeline inspector: `stage_dump <data_dir> <sym> <end_date> <from_date>`.

Relates to [[project_weekly_snapshot_generator_caveats]] (the "top 3 alphabetical /
all-tie-70" caveats — this is the root cause of the all-70) and
[[project_decision_audit_faithful]] (the faithfulness thread that started this).
