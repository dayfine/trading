---
name: project_envelope_knobs_dead
description: min_cash_pct / max_long_exposure_pct / max_positions are DEAD in the sim path (check_limits has zero callers); backtests run 89-99% deployed — no 70% envelope exists; P0 pair-sweep cancelled 2026-07-05
metadata: 
  node_type: memory
  type: project
  originSessionId: a4913a17-4c87-4fe1-a48a-94a54200cdb5
---

**Envelope knobs are dead code (verified 2026-07-05, code trace + smoke A/B):**

- `Portfolio_risk.check_limits` has ZERO production callers (test-only API) →
  `min_cash_pct`, `max_positions`, aggregate long/short exposure, sector-count
  caps all UNWIRED in backtests.
- `max_long_exposure_pct`'s only live use: per-position `min()` vs
  `max_position_pct_long` in `compute_position_size` — never binds at prod
  values (0.70 vs 0.30). The 2026-06-25 ledger "exposure {0.70,0.90}
  bit-identical" was this.
- Empirical: smoke A/B `min_cash_pct=0.90` vs 0.10 → bit-identical, 3/3
  windows; deployment 89–99% invested (bull 2019H2: 98.6%).
  `dev/experiments/envelope-knob-liveness-2026-07-05/`.
- Entry walk seeds `remaining_cash = portfolio.cash` (full balance, no
  reserve); portfolio floor = absolute-dollar solvency only.
- "Production caps 0.30/0.70" overrides in scenario fixtures are inert
  decoration.

**Consequences:** envelope cannot be LOOSENED (already ~100%; only margin
expands it) → continuation-add revisit precondition unsatisfiable → scale-in
stays closed ([[project_capital_mgmt_scale_in_design]]). Only buildable
envelope experiment = TIGHTENING (working cash-reserve flag, default-off);
fat-tail law predicts breadth tax ([[project_edge_is_the_fat_tail]]).
Decision item: wire or delete `check_limits`.

**Rule reinforced:** before sweeping any knob, grep consumers to the sim-path
call site. `.mli` deprecation notes + ledger "inert" rows = smoke; dead knob =
fire. Writeup: `dev/notes/envelope-knobs-dead-2026-07-05.md`.
