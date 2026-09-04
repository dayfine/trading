---
name: project_d1d2_mechanism_decomposition
description: "On the record convention the fixed exit basis decomposes cleanly — D1 (Monday-open fill) costs ≈ −1pp per stop_loss exit in every window; D2 (no entry-bar stop-out) removes the entry-bar stop-outs (10–21% of trades; 8–16% survive as the same entry) but most die within days at a worse price — the artifact was a LUCKY exit; a saved monster (WNC +160%) is what flips a window's sign"
metadata: 
  node_type: memory
  type: project
  originSessionId: c7c971d0-92c7-4c65-a853-b1c877ee64fa
  modified: 2026-09-03T18:39:46.973Z
---

**Measured 2026-09-03**, `dev/experiments/record-rebase-2026-09-03/` (record
convention, paired old/new at build e4984c5fe, salt 0, warehouse basis):

| window | old → new return | shared-trade price effect | D2 saved / fate |
|---|---|---|---|
| 2019–23 top-3000-2019 | 13.8% → 3.0% | stops −$134k over 96 (−1.0pp each); laggards +$23k | 18 of 174 saved; 16 survivors −$49k → −$99k, 13 re-stopped ≤14d, no monster |
| 2000–04 top-3000-2000 | 35.8% → 76.6% | stops −$111k over 58 (−1.2pp each); laggards +$322k (WNC ≈ +$290k) | 23 of 110 saved; 18 survivors −$9k → +$225k, **−$46k ex-WNC** |

**Why:** the Friday-open stale fill (D1) flattered stop exits — the record
convention's dominant exit — by about one percentage point each. The
entry-bar stop-out (D2) sold breakouts whose entry-day low pierced the stop;
those were mostly *about to fail*, so the artifact exit at −2% was cheaper
than the honest −4…−12% real stop days later. Book-faithful behaviour holds
them (§5.1) and pays that; occasionally one becomes the window's monster
(WNC 2003-05-09 → 2004-03-01, +160%, +$271k, 44% of the window's realised).

**How to apply:** when a fixed-basis number is below the old one by roughly
(number of stop exits × 1pp of notional) plus a small D2 hold cost, that is
the basis, not a strategy change. When it is far ABOVE, look for a
D2-saved monster before crediting anything. Predicts the 26y record drops by
≈ −$0.5M realised (≈ 500 stops) unless a saved monster lands. Related:
[[project_lever_reads_invert_on_fixed_sim]], [[project_top500_composition_golden_is_gme]],
[[project_edge_is_the_fat_tail]].
