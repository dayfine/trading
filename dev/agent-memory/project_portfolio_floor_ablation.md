---
name: project_portfolio_floor_ablation
description: "Portfolio_floor ablation 2026-07-09 (GME window): floor-OFF dominates all risk-adjusted metrics (1013.8→2223.3%, Sharpe .538→.610, Ulcer 33.9→23.6); floor's MaxDD 'win' = its own bottom-tick liquidation; no config ever shows a beneficial floor fire"
metadata: 
  node_type: memory
  type: project
  originSessionId: dbeb7536-3c56-4212-a532-4c2daa8dfc4b
---

`dev/backtest/floor-off-exp-2026-07-09/FINDINGS.md`. User-directed ablation on
sp500-2010-2026 long-only 0.30 (the [[project_rs_warmup_gap]] GME pathology
window): `min_portfolio_value_fraction_of_peak 0.0` (config-only disable).

- Floor-OFF: return 2223.3% vs 1013.8%, Sharpe 0.610 vs 0.538, Sortino 0.865
  vs 0.813, Calmar 0.271 vs 0.242, Ulcer 23.6 vs 33.9, 0 vs 32 floor liqs.
- Floor's only "win" (MaxDD 65.8 vs 78.3) is HOLLOW: both measured from the
  same unrealizable $28.9M squeeze MTM peak, and the floor's fire = sell-all
  at the collapse bottom + 31 re-liquidations = converts paper DD into
  realized loss then forecloses recovery (5y sterilization).
- **No observed window where the portfolio floor helps**: deep top-3000
  2000-2026 = 0 fires; only fires ever seen = these 32 pathological ones.
- Options recorded in FINDINGS (decision open): port P1b windowed-peak
  semantics to engine floor (recommended) / default trigger off (needs >1
  window per R3) / status quo. Single-window screen — calibrated as harm
  quantification on the worked example, not a promotion test.
  [[project_floor_quality_program]] [[project_deep_topline_364]]
