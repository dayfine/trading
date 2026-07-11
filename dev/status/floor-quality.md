# Status: floor-quality

## Last updated: 2026-07-10

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
- **Realism-defaults flip = the new measurement basis** (branch
  `feat/realism-defaults-flip`, PR pending; user mandate 2026-07-10):
  `liquidity_config.min_entry_dollar_adv` 0.0 -> 1e6 and `stale_exit_after_days`
  None -> Some 5 are now DEFAULT-ON (`min_hold_dollar_adv` stays 0.0). The two
  realism dials the honest-tradeable baseline
  (`dev/notes/honest-tradeable-baseline-2026-07-10.md`) armed as a measurement
  convention are the default going forward — a faithfulness basis change (no
  fake fills, no held ghosts), not an alpha promotion. Goldens re-pinned; ledger
  `2026-07-10-realism-defaults-flip`. Comparators here stay TOTAL-RETURN.
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
- **P1b step 2 — thin breaker sleeve strategy** (branch
  `feat/breaker-spy-sleeve`, PR pending): new
  `trading/trading/weinstein/strategy/lib/breaker_spy_strategy.{ml,mli}` +
  OUnit2 tests, alongside `Spy_only_weinstein_strategy`. Consumes the merged
  `Index_circuit_breaker` (#1904): long-only, default-in-market (deploys cash
  into SPY whenever flat + `In_market`, so it buys on the first tradable bar),
  weekly (Friday) breaker `step` over the symbol's own weekly bars — Exit sells
  to flat, Re_enter buys all-cash, Hold falls through to deploy. No per-position
  trailing stop; the only exit is a breaker exit. Macro read for the character
  classifier is `Macro.analyze` with empty A-D/global inputs (the documented
  single-instrument degradation → A-D `Neutral`, no breadth lead) +
  `Macro.default_config` (no new tunable; the breaker's thresholds all route
  through `config.breaker`). Cadence note: the lib is weekly-bars-only, so
  daily-cadence fast exits are parked as a future dial (documented in the .mli).
  **Framing (user steer 2026-07-09, `feedback_no_reversal_timing`): not a
  reversal timer** — slow-grind exit is doctrine-faithful step-aside; fast
  exit + fast re-entry are tail-RISK insurance whose whipsaw cost is accepted
  and measured (that measurement is step 3). Runner wired: additive
  `Breaker_spy_sleeve of { symbol }` variant in `Strategy_choice.t`
  (`warmup_days_for` = 364), constructed in `panel_strategy_builder`. Zero
  behaviour change to existing strategies (new variant, default-off per
  experiment-flag-discipline — no scenario selects it yet).

## In Progress
- (none — awaiting review/merge of P1b step 2)

## Next Steps
1. **P1b step 3 — lens screen** vs TR-SPY 2000-2026 (per-episode drawdown
   captured/avoided, days out, intervention count, whipsaw cost distribution).
   Consumes the `Breaker_spy_sleeve` runner variant from step 2.
2. **P1b step 4 — WF-CV surface** over the breaker thresholds, then a deep
   bear-regime promotion grid (`promotion-confirmation.md`) before any default.
