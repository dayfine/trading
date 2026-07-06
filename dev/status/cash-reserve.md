# cash-reserve

Working percentage cash-reserve knob (`cash_reserve_pct`) — the **envelope-tightening**
capital-management lever. Holds back a fraction of portfolio value from NEW entry
funding each Friday. The honest, live-path replacement for the dead
`Portfolio_risk.min_cash_pct` (unwired; sole consumer `check_limits` has zero
production callers — `dev/notes/envelope-knobs-dead-2026-07-05.md`, #1861). Distinct
from the CLOSED intra-envelope scale-in reallocation track: this *tightens* deployment
(holds cash), it does not reallocate within a full envelope.

## Status
MERGED

Track closed: mechanism merged (#1867, default-off); surface verdict REJECT
(ledger `2026-07-06-cash-reserve-surface`). Envelope program closed both
directions (loosening impossible per #1861; tightening rejected here).

## Last updated: 2026-07-06

## Interface stable
YES

## Ownership
Closed. No dispatchable work — do not dispatch.

## Completed
- Mechanism BUILT, default-off (`cash_reserve_pct : float [@sexp.default 0.0]` on
  `Weinstein_strategy.config`). Wired at the entry-walk seed in
  `weinstein_strategy_screening.ml`: `spendable = max 0 (cash - cash_reserve_pct *
  portfolio_value)` seeds the walk's `remaining_cash`. Reserve taken off the top-level
  budget once (short-sleeve split derives from the reduced budget). Scoped to NEW
  entries only — exits/covers/stops never blocked (#1553 lesson). experiment-flag
  R1 (default-off, bit-identical) + R2 (axis-reachable via `Overlay_validator`) PASS.
  Tests: config default/round-trip, behaviour off (3 longs) vs on (0.30 → 2 longs),
  exit-exempt under reserve 0.9, axis reachability. **MERGED #1867** (2026-07-06 12:45Z;
  run-2 behavioral finding — short-sleeve reserve under-honoring + docstring — addressed by
  the human before merge).

## Completed (verdict)
- WF-CV surface `{0.0, 0.1, 0.2, 0.3}` broad top-3000 13×2y: **REJECT all**
  (gate FAIL 4/6/4 Sharpe wins; 30% reserve = Sharpe 0.441 vs 0.597, worse in
  the 2022 bear fold). Non-monotonic response (r10 worse than both neighbors;
  r20 aggregate spike driven by one flipped fold) = path-dependent funding
  reshuffle, not a risk dial. 10th fat-tail confirmation: monster-fold return
  cut at every reserve level. Writeup:
  `dev/notes/cash-reserve-wfcv-2026-07-06.md`.

## Next Steps
None — track closed. `cash_reserve_pct` stays a searchable axis; no standalone
re-sweep. Capital-protection lever class of record: barbell overlay
(`project_barbell_on_stocks`).

## Follow-up
None
