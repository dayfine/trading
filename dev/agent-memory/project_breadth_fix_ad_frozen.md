---
name: project_breadth_fix_ad_frozen
description: "A-D fixture froze 2 macro votes 2000-16 (#270→#3252); fixing it = salt noise on the record (capital-bound tail swap); earlier macro verdicts ran on frozen input"
metadata:
  type: project
---

The NYSE A-D fixture held one 1965 row then 2017+ from #270 (2026-04-11) to #3252 (2026-10-11). Over 2000–16 the macro
composite carried a constant "Momentum negative (−11.0)" Bearish vote and no A-D Line vote (below `ad_min_bars`).

Fix measured 2026-10-12 (`dev/experiments/breadth-fix-rb1-2026-10-11/`, PR #3261): Bearish weeks 398 → 233, but the
record moved only by salt noise (mean +0.030 log). **Why:** capital binds (~1.6 cash-skips per extra placement); the
unlocked cohort is ordinary (median −$8k, sum = 3 trades); the tail swaps 3-for-3. Real breadth re-enters V-rebounds
earlier (2010–16 +0.10 log) but buys into tops/bear rallies because the NYSE A-D line "diverged bullishly" in 2001, 2007
and 2008 (−0.10 log).

**How to apply:**
- Don't propose macro-gate dials (A-D weights/thresholds included) as return levers at this capacity.
- Index-stage veto mechanism (c), shorts Phase B exposure timing, macro-suspend 5d and the 06-23 A-D-flip grid all ran
  on the frozen input; re-read before citing. The 06-23 grid's provenance contradicts the fixture history — dig first.
- The 2009 sit-out and the 2025–26 picks diagnosis are not A-D artifacts.
- Follow-ups: pack defects #3262, fixture holiday rows #3263.

Record numbers: [[project_investor_preset_broad]]. Related: [[project_macro_suspend_investor_dilutes]],
[[project_index_stage_veto_verdict]], [[project_shorts_liveness_dead]], [[project_ad_default_flip]],
[[project_edge_is_the_fat_tail]].
