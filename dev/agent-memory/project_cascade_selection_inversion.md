---
name: project_cascade_selection_inversion
description: "Cascade score is anti-predictive at the top grade — confirmed Stage1→2 breakout (+30) underperforms early-Stage2 (+15); validated across breadth, but return edge non-stationary"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5fcb588e-0fe8-4d61-ac09-7315a7496370
---

P0 2026-06-10 (trade-forensics lead) VALIDATED. On Cell-E (2011-2026, snapshot
mode), the cascade score we rank/select on is anti-predictive at the top end.

**Real, not noise:** replicates on top-3000/1000/500 and STRENGTHENS on narrower
breadth (opposite of the fat-tail/top-3000-only signature that sank laggard /
stage2-ma-hold / stage3-force-exit-off). Cascade `score==85` (grade A+) is the
WORST bucket on win-rate AND mean return on all 3 breadths — net-negative total
pnl on top-1000 (−51%) & top-500 (−39%).

**Locus = the stage signal.** A+ (85) is ~100% confirmed `Stage1→Stage2 breakout`
(`w_stage2_breakout=+30` in `screener_scoring.ml`); the higher-win-rate trades are
`score==70` `Early Stage2` (`weeks_advancing≤4`, +15). The textbook breakout has
the LOWER win-rate on every breadth + both eras, yet is scored +30 vs +15 → under
cash constraint the strategy prefers the worse entries. (Mechanism caveat: "early"
= Stage2 ≤4wk with prior_stage≠Stage1, i.e. we lacked history to confirm the base
— partly an observability confound, needs causal validation.)

**The catch — return edge is non-stationary.** early ≫ breakout on RETURN in
2011-18; in 2019-26 it collapses/reverses (breakouts caught the bull's fat-tail
winners; top-3000 breakout mean +2.32 vs early +0.30). The WIN-RATE inversion
persists into 2019-26 across breadths; the RETURN case for a reweight does not.
→ a naive `scoring_weights` reweight is unlikely to clear WF-CV; budget no-promote.

**Next:** breakout/early reweight as an `experiment-gap-closing` surface
(`w_stage2_breakout ∈ {30,22,15}`), WF-CV + confirmation grid, NOT a default flip.
A consistency (win-rate/DD) gain may be worth it even if mean return is flat.

Method note: the selection signal is trade_audit_report behavioural metric (d)
entering-losers-too-often (buckets by `cascade_score`), NOT the decision-quality
matrix (buckets by r_multiple → trivially monotonic). Writeup:
`dev/notes/cascade-selection-inversion-2026-06-10.md`; specs:
`dev/experiments/cascade-selection-inversion-2026-06-10/`. Builds on the resurrected
[[project_stage_late_flag_discarded]] tool family + breadth lessons
[[project_laggard_broad_recheck]].
