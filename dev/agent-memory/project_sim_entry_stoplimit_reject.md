---
name: sim-entry-stoplimit-reject
description: "#2158 do-not-chase entry cap WF-CV REJECT — entry-side fat-tail tax; live cap15 plausibly costs live expectancy vs backtest basis (user decision open)"
metadata: 
  node_type: memory
  type: project
  originSessionId: b2f0f179-e194-4bcc-956f-27560b15d067
---

2026-08-04 surface (31-fold sp500 2010-26, ledger
`2026-08-04-sim-entry-stoplimit-surface`): `enable_sim_entry_stoplimit` caps
{10,15,20}pp all REJECT decisively — baseline Sharpe .789 vs ~.52, wins 2/2/1
of 31, MaxDD WORSE with caps (13.4→14.6), frontier = baseline alone.

Why (transferable): **entry-side fat-tail tax** (11th
[[project_edge_is_the_fat_tail]] confirmation, first on the fill side) — the
cap refuses gap-and-go launches = right-tail seeds; no DD relief shows up, so
it's pure lost return. Cap-insensitive 10-20pp ⇒ harm is in >20pp gaps (the
monsters). No more entry-timing/entry-price levers without beating this +
[[project_entry_selection_closed_powered]].

**OPEN USER DECISION:** live tickets already ship StopLimit(E, cap15) (#2171
armed) while records assume Market fills — surface measures that divergence
at ≈ −0.26 fold Sharpe / −3.9pp fold return. Live cap = execution-honesty vs
expectancy tradeoff; sim number directional (weekly live cadence differs).

CORRECTION 2026-08-05 ([[bke-order-diagnosis]]): sim entry triggers = CURRENT
CLOSE (G14 effective_entry_price), never the audit E — the deep-pair ladder
attribution (base-buys below E, expired orders) was mis-specified; 2x gap =
path divergence + close-trigger mechanics. Report prints E, sim fills close:
NO sim arm models live tickets. Open user decision: entry trigger = close vs
E (prereq flag before any GTC work). sp500 fold REJECT unaffected.

Mechanism stays default-off realism axis (live-parity studies). Ops gotcha:
walk_forward_runner loads base_scenario CWD-RELATIVE — run from
`test_data/backtest_scenarios/`, not the trading root.
