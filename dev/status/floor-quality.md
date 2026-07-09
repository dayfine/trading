# Status: floor-quality

## Last updated: 2026-07-09

## Status
IN_PROGRESS

## Scope
The floor-quality program (P0 per `memory/project_floor_quality_program`): build
a better SPY floor sleeve than raw stage-timed SPY — a long-only sleeve with a
quick, accurate circuit breaker that matches TOTAL-RETURN SPY over 2000-2026
while cutting the deep-crash left tail. Design authority:
`dev/plans/fast-circuit-breaker-spy-sleeve-2026-07-08.md` (P1b).

## Completed
- **P1b step 1 — pure index circuit-breaker lib** (branch
  `feat/circuit-breaker-lib`): new module
  `analysis/weinstein/macro/lib/index_circuit_breaker.{ml,mli}` + OUnit2 tests.
  A pure, lookahead-free two-state machine (`In_market` / `Out_of_market`) with
  three exit triggers (T1 fast-crash, T2 confirmed breadth-led slow-grind, T3
  absolute-floor on a **trailing-window** high) and asymmetric self-contained
  re-entry (fast recovery off post-exit low after fast/floor exits;
  Weinstein-style price-above-turning-MA after a grind exit). Reuses
  `Decline_character.classify` for the fast-V / slow-grind character read. Every
  threshold is a config field with `[@sexp.default …]` → axis-ready. No consumer
  wiring; changes no behaviour anywhere. Encodes the two GME-pathology lessons
  (decaying windowed peak, no halt-until-external-reset) per
  `dev/notes/warmup-364-repin-2026-07-08.md` §Findings.

## In Progress
- (none — awaiting review/merge of P1b step 1)

## Next Steps
1. **P1b step 2 — thin sleeve strategy** consuming the breaker (buy-and-hold SPY
   + breaker), alongside `Spy_only_weinstein_strategy`, adjusted-close bars for
   both sleeve and comparator. Follow-up dispatch.
2. **P1b step 3 — lens screen** vs TR-SPY 2000-2026 (per-episode drawdown
   captured/avoided, days out, intervention count, whipsaw cost distribution).
3. **P1b step 4 — WF-CV surface** over the breaker thresholds, then a deep
   bear-regime promotion grid (`promotion-confirmation.md`) before any default.
