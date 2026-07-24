---
name: project-margin-m4-leverage-reject
description: "M4 complete — priced leverage REJECT every cell (Sharpe collapses monotonically, 2x has 89% DD + less return than 1.33x); parity gates all bit-identical; margin stack = certified no-op at defaults"
metadata: 
  node_type: memory
  type: project
  originSessionId: b35c182a-e425-4272-bbfd-9aa328dd5455
---

Margin M4 validation protocol COMPLETE 2026-07-23/24 (ledger
`2026-07-24-margin-m4-leverage-surface` Reject; full record
`dev/notes/margin-m4-validation-2026-07-23.md`).

- **Stage 1**: 3 parity gates bit-identical (13/13 files each) — HEAD w/ full
  M1-M3 stack at defaults ≡ 07-22 +8,689% record; explicit no-ops ≡ absent;
  req=1.0/rate=0 ≡ E-capped. New E-capped anchor on promoted bundle:
  +10,589%/Sharpe .906/DD 31.1 (MTM-heavy).
- **Stage 2**: squeeze cells zero spurious events (stops fire at 7-15% adverse,
  tiered maintenance needs 30-83% — force-cover is a dead letter on faithful
  paths; short costs live in borrow fees + collateral locks). Forced cell:
  engagement/timing proven 33/33.
- **Stage 3 REJECT**: broad 13×2y priced surface (8%/yr, M2 maintenance 0.30,
  tiers). req=0.75 → Sharpe .827→.56, DD 14→50; req=0.5 → .34, DD 89, LESS raw
  return than 1.33× (vol drag + force-reduce selling into weakness). **Why:
  leverage amplifies the whipsaw premium in every chop fold but monster folds
  were already fully invested (min_cash 0.30 binds) — asymmetric amplification.
  The fat tail cannot be scaled, only taxed** ([[project_edge_is_the_fat_tail]]
  extends to leverage). Cash-account long-short Sharpe .883 (6/13, not robust)
  = only faint positive; invariant to long leverage (hedges tape, not leverage).

Issues filed during M4: #2057 margin exit labels don't propagate to outputs;
#2059 LH phantom-short + dup row in record basis (−$607k immaterial); #2060
mean-ADV entry gate spoofed by single block-print (LINK −$1.58M specimen).
