# Status: floor-quality

## Last updated: 2026-07-09

## Status
IN_PROGRESS

## Interface stable
NO

## Scope
The floor-quality program (P0 per `memory/project_floor_quality_program`): build
a better SPY floor sleeve than raw stage-timed SPY — a long-only sleeve with a
quick, accurate circuit breaker that matches TOTAL-RETURN SPY over 2000-2026
while cutting the deep-crash left tail. Design authority:
`dev/plans/fast-circuit-breaker-spy-sleeve-2026-07-08.md` (P1b).

## Completed
- **Portfolio-floor trigger default OFF** (branch
  `feat/portfolio-floor-default-off`, PR pending; user mandate 2026-07-09):
  `Force_liquidation.default_config.min_portfolio_value_fraction_of_peak`
  0.4 -> 0.0 (0.0 = documented disable). The per-position triggers (0.25
  long / 0.15 short) are unchanged — they are the real protection. Evidence:
  the floor-off ablation (`dev/backtest/floor-off-exp-2026-07-09/FINDINGS.md`,
  merged #1903) — on the only window it ever fired (GME meme-squeeze) floor-OFF
  dominates every risk-adjusted metric (return 1013.8->2223.3%, Sharpe
  .538->.610, Calmar .242->.271, Ulcer 33.9->23.6, 32->0 floor liqs); zero
  fires anywhere else in tested history. Re-pinned the sp500-2010-2026 golden
  floor-OFF; ledger `2026-07-09-portfolio-floor-default-off` (Accept). The
  true-death-spiral protective case is untested (never occurs in 26+y), so the
  knob stays config-expressed; the P1b circuit-breaker below is the
  squeeze-immune re-design if a portfolio brake is wanted back.
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
