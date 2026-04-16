# Status: short-side-strategy

## Last updated: 2026-04-16

## Status
PENDING

## Interface stable
N/A — not started

## Open PR
—

## Blocked on
- PR A of support-floor-stops split (`feat/support-floor-stops`) must merge first — introduces the long+short `find_recent_level` primitive this track depends on.

## Goal

Wire short-side entries into `Weinstein_strategy` so the simulation emits short positions in bearish macro regimes. The end-to-end infra (portfolio signed quantities, orders Buy/Sell, simulator order_generator with `_entry_order_side`/`_exit_order_side` for Short, `Weinstein_stops` parameterised by `side`) already supports shorts. Gap is isolated to the strategy entry path.

## Scope

1. **Screener candidate carries side.** Today the screener emits long candidates implicitly. Extend its output record with `side : Trading_base.Types.position_side`.
2. **`_make_entry_transition` parameterised by side.** Today line 84 hard-codes `~side:Long`. Take side from the screener candidate.
3. **Macro branch for shorts.** Today `weinstein_strategy.ml:206` returns `[]` on `Bearish`. Replace with: generate short candidates when macro is Bearish (rules per `docs/design/weinstein-book-reference.md` Ch. 11 — Stage 4 breakdown + negative RS + bearish market).
4. **Screener short-side rules.** Mirror the long-side Stage 2 breakout rules: Stage 4 breakdown, resistance ceiling as reference level (support_floor with `~side:Short`), negative RS line.
5. **Position sizing for shorts.** Confirm portfolio risk limits work on signed exposure. Likely already symmetric — verify with a test.
6. **Backtest regression pins.** Extend `test_weinstein_backtest.ml` with a bear-market-window scenario that exercises short entries.

## Not in scope

- Buy-to-cover trailing stop tuning beyond what `Weinstein_stops` already does (resistance ceiling → rally stop).
- Margin / borrow cost modelling — separate simulation track if it matters.
- Hard-to-borrow filtering.

## References

- `docs/design/weinstein-book-reference.md` Ch. 11 — bear-market shorting rules (never short Stage 2; only Stage 4 with negative RS + bearish macro).
- `docs/design/eng-design-3-portfolio-stops.md:152` — trade-log schema already has `` `Short | `Cover `` actions.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:84` — long-only entry (to parameterise).
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:206` — bearish macro short-circuit (to replace).
- `trading/trading/simulation/lib/order_generator.ml:9-18` — `_entry_order_side` / `_exit_order_side` already handle Short.
- `trading/trading/portfolio/lib/types.mli:20` — signed position quantities (long/short).
- `trading/trading/weinstein/stops/lib/support_floor.mli` — after PR A, `find_recent_level ~side` handles both sides.

## Ownership
Unassigned. Candidate: `feat-weinstein` once PR A lands.

## QC
overall_qc: PENDING
structural_qc: PENDING
behavioral_qc: PENDING

Reviewers when work lands:
- qc-structural — side parameterisation clean through screener → strategy → order_generator; no hardcoded Long remaining.
- qc-behavioral — Ch. 11 rules encoded faithfully (Stage 4 + negative RS + bearish macro); no shorting Stage 2 stocks.
