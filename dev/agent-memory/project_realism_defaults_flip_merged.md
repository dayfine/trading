---
name: project-realism-defaults-flip-merged
description: Realism flip MERGED
metadata: 
  node_type: memory
  type: project
  originSessionId: 3d8cc658-807d-4d9b-bbe3-8da048a636d9
---

Realism-defaults flip **MERGED 2026-07-11 (#1926)**: `min_entry_dollar_adv`
0.0→$1M + `stale_exit_after_days` None→Some 5 default-on;
`min_hold_dollar_adv` stays 0.0 (hold-exit promotion CLOSED as fold-horizon
artifact). Ledger `2026-07-10-realism-defaults-flip` (basis change, not alpha).
All goldens re-measured/re-pinned; full runtest + linters green; 3 gates green.

Key findings from the re-measure campaign:

- **Liquid universes near-inert**: sp500 tight goldens moved ≤2.8%; covid-recovery
  (broad warehouse) BIT-IDENTICAL; test_data deep sanity 5/5 PASS near-inert.
- **Stale-exit ghost-cash recycling is THE mover on delisted-heavy windows**,
  not the entry gate and NOT hold-exit: top3000-2000-2026-catstop went
  un-armed +2063% → flip +5729% (OPV $54M, $44.9M unrealized MTM-top-heavy —
  don't quote as tradeable). Most of the honest-tradeable +6889% arming lift
  was stale-exit. Trades UP on all moved windows (ghost slots recycle).
- **Broad goldens (top-1000 PIT warehouse) re-pinned with big path moves**:
  bull-crash 41→77%, decade 90→37%, six-year 22→104% — six-year and decade
  OVERLAP yet moved opposite directions (funding-path chaos, 5th
  path-flattery confirmation for [[project-honest-tradeable-baseline]]'s LAW).
- tier4-broad-1y/10y + sp500-30y-capacity-1996 structurally blocked (broad
  coverage 53.05% < 90%, no full-broad corpus, 30y needs pre-1999 bars +
  ~9.5GB RSS) — NA'd, flip-independent.
- Static $1M gate calibrated for $1-10M NAV; position-vs-ADV scaling is the
  documented follow-up capacity model.
- Post-merge follow-up: warehouse rebuild (S1 rebuilds to 2026-06-26 anyway).
