---
name: project_cash_reserve_rejected
description: "cash_reserve_pct {10/20/30%} WF-CV REJECT 2026-07-06 — 30% reserve = clear loss (Sharpe .44 vs .60, worse in 2022 bear); response NON-monotonic (funding-reshuffle chaos); envelope program closed BOTH directions"
metadata: 
  node_type: memory
  type: project
  originSessionId: a4913a17-4c87-4fe1-a48a-94a54200cdb5
---

**Cash-reserve surface REJECTED (2026-07-06, ledger
`2026-07-06-cash-reserve-surface`):** mechanism #1867 (`cash_reserve_pct`,
working entry-funding reserve, default 0.0, exits exempt) — built same day at
user direction after [[project_envelope_knobs_dead]] showed the old
`min_cash_pct 0.30` was dead decoration. Broad top-3000 13×2y WF-CV
{0.10, 0.20, 0.30}: gate FAIL all (Sharpe wins 4/6/4 of 13).

**Answer to "cash reserve = 30%?":** clear loss — Sharpe 0.441 vs 0.597,
return 12.7 vs 19.9%/fold, WORSE in the 2022 bear fold (−15.5 vs −10.2%);
~2pp mean-MaxDD relief for ~7pp return cost.

**WHYs:**
1. Response NON-MONOTONIC (r10 worse than both neighbors; r20 spike
   Sharpe 0.620 driven by ONE flipped fold f011 2022 +12.7% while r30 got the
   OPPOSITE −15.5% in the same fold). Funding-budget changes reshuffle WHICH
   candidates fund at the cash boundary = path-dependent chaos, not a risk
   dial. Same class as concentration-0.25 knife-edge — do not promote.
2. 10th [[project_edge_is_the_fat_tail]] confirmation: monster fold f010
   (2020-21) return cut at EVERY reserve level (72 → 45/56/49) — marginal
   cash-boundary entries are net-positive; cutting them costs more than the
   cushion returns.
3. **Envelope program closed BOTH directions**: loosening impossible (~100%
   deployed), tightening rejected. Capital-protection lever of record =
   barbell overlay ([[project_barbell_on_stocks]]).
4. Lens candidate (not build): fold chaos under small funding perturbation =
   more evidence cash-boundary selection is noise-dominated
   ([[project_screener_alphabetical_tiebreak]]).

Writeup: `dev/notes/cash-reserve-wfcv-2026-07-06.md`.
