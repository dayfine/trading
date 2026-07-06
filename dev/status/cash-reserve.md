# cash-reserve

Working percentage cash-reserve knob (`cash_reserve_pct`) — the **envelope-tightening**
capital-management lever. Holds back a fraction of portfolio value from NEW entry
funding each Friday. The honest, live-path replacement for the dead
`Portfolio_risk.min_cash_pct` (unwired; sole consumer `check_limits` has zero
production callers — `dev/notes/envelope-knobs-dead-2026-07-05.md`, #1861). Distinct
from the CLOSED intra-envelope scale-in reallocation track: this *tightens* deployment
(holds cash), it does not reallocate within a full envelope.

## Status
IN_PROGRESS

## Last updated: 2026-07-06

## Interface stable
NO

## Ownership
feat-weinstein (LOCAL session, 2026-07-06). Orchestrator QCs + merges.

## Completed
- Mechanism BUILT, default-off (`cash_reserve_pct : float [@sexp.default 0.0]` on
  `Weinstein_strategy.config`). Wired at the entry-walk seed in
  `weinstein_strategy_screening.ml`: `spendable = max 0 (cash - cash_reserve_pct *
  portfolio_value)` seeds the walk's `remaining_cash`. Reserve taken off the top-level
  budget once (short-sleeve split derives from the reduced budget). Scoped to NEW
  entries only — exits/covers/stops never blocked (#1553 lesson). experiment-flag
  R1 (default-off, bit-identical) + R2 (axis-reachable via `Overlay_validator`) PASS.
  Tests: config default/round-trip, behaviour off (3 longs) vs on (0.30 → 2 longs),
  exit-exempt under reserve 0.9, axis reachability. PR open on `feat/cash-reserve-pct`.

## Next Steps
- [non-blocking] WF-CV surface `cash_reserve_pct ∈ {0.0, 0.1, 0.2, 0.3}` (per
  `experiment-gap-closing`): does holding 10–30% cash buy enough DD/dispersion relief
  to justify the return cost? Note the standing prior — the edge is the fat tail
  (`project_edge_is_the_fat_tail`); a reserve reduces deployment, so expect a return
  cost. Default stays off pending a ledger ACCEPT + confirmation grid.

## Follow-up
None
