---
name: project_record_rebase_2026_09_03
description: "THE canonical record on the fixed exit basis = 302.65% / 723 trades / Sharpe 0.397 / MaxDD 36.26 (record-baseline spec, clock-0 pin, build e4984c5fe, salt 0, warehouse); the paired old arm at the same build read 312.74 (= the 08-27 clock cell-A null digit-for-digit), so the exit-basis effect on the record is −10pp and the 731.64% 08-24 figure is build drift (#2561, v2 of #2555), not basis"
metadata: 
  node_type: memory
  type: project
  originSessionId: c7c971d0-92c7-4c65-a853-b1c877ee64fa
  modified: 2026-09-04T00:33:25.365Z
---

**Measured 2026-09-03** (`dev/experiments/record-rebase-2026-09-03/`, chain
`rec0903`, pinned worktree @ e4984c5fe = main after #2648/#2652; **merged as PR
#2657 → 3a5e3667e** after both QC gates, one text-only rework):

| cell | old (both knobs false) | new (shipped default) | Δ |
|---|---|---|---|
| rec26y (top-3000-2000, 2000-01-01..2026-06-26) | 312.74% / 799 / 0.430 / 38.78 | **302.65% / 723 / 0.397 / 36.26** | −10.1pp, −76 trades, maxDD −2.5 |
| rec5y-2019 | 13.81 / 174 / 0.234 / 33.91 | 3.02 / 184 / 0.118 / 30.33 | −10.8pp |
| rec5y-2000 | 35.76 / 110 / 0.505 / 16.64 | 76.64 / 98 / 0.655 / 28.36 | +40.9pp (WNC) |

**Lineage.** rec26y-old = 312.74 / 0.430 / 38.78 is digit-for-digit the
clock-surface cell-A null (`clockA-0`, 2026-08-27, build 90dfd6e97) — the
record spec pins the clock at 0, so this is a free determinism cross-check
across three builds. The 08-24 record (731.64 at c7660cac3) predates #2555's
RS-trend fix (merged as #2561); that build delta, not the exit basis, is the 731 → 313 gap.

**26y decomposition.** Realised $2.95M → $2.21M (−$747k): shared 462
trades ≈ **neutral** (−$40k: stop tax −$565k over 306 stops, −0.5pp each,
offset by D2-saved laggard winners +$814k price effect); the gap is cohort
(old-only +$804k vs new-only +$97k), led by AEIS 2025-06-24 +$548k which the
new-basis book never entered. D2 saved 63 of the old arm's 108 entry-bar
deaths: −$368k → +$283k, 39 re-stopped within 14 days, 2 monsters (WNC
+160%, one more).

**How to apply:** every writeup after 2026-09-03 diffs against
`results/rec26y-new-s0-*` (params.sexp committed). Do not quote 731.64%,
312.74% or 302.65% against each other without naming the build AND the
exit basis. Related: [[project_d1d2_mechanism_decomposition]],
[[project_d1d2_default_flip_in_flight]], [[project_honest_tradeable_baseline]].
