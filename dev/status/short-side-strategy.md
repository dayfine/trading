# Status: short-side-strategy

## Last updated: 2026-04-19

## Status
MERGED

MVP slice landed via #420 on 2026-04-19; follow-ups tracked below.

## Interface stable
YES

`Screener.scored_candidate.side` and public `Weinstein_strategy.entries_from_candidates` signature landed in main.

## Merged PR
- #420 (feat/short-side-strategy) — MVP vertical slice: side through screener → strategy → order_generator, with Ch.11 RS hard gate and unit tests for Short + Long entry transitions.

## Blocked on
- None.

## Goal

Wire short-side entries into `Weinstein_strategy` so the simulation emits short positions in bearish macro regimes. The end-to-end infra (portfolio signed quantities, orders Buy/Sell, simulator order_generator with `_entry_order_side`/`_exit_order_side` for Short, `Weinstein_stops` parameterised by `side`) already supports shorts. Gap is isolated to the strategy entry path.

## Completed (MVP slice)

- Plan committed: `dev/plans/short-side-strategy-2026-04-18.md`.
- `Screener.scored_candidate` carries `side : Trading_base.Types.position_side`. Populated in `_build_candidate` based on whether the cascade path is buy or short. Ch.11 hard RS gate blocks shorts when RS trend is `Positive_rising`, `Positive_flat`, or `Bullish_crossover` (never short a stock with positive/rising RS).
- `Weinstein_strategy._make_entry_transition` parameterised by `cand.side`. Threads through to `Weinstein_stops.compute_initial_stop_with_floor` and `Position.CreateEntering { side; _ }`. Sizing adapter (`_normalised_entry_stop_for_sizing`) uses `Float.max`/`min` so the `entry - stop` diff is positive for both sides.
- `Weinstein_strategy.entries_from_candidates` is now public (was `_entries_from_candidates`). Full docstring covers candidate side threading, sizing, stop initialisation, and cash-tracking behaviour.
- `Bearish` macro branch now emits shorts: `_screen_universe` concatenates `buy_candidates @ short_candidates`; the earlier `Bearish → []` short-circuit in `_run_screen` is removed.
- Screener tests: `test_buy_candidates_are_long`, `test_short_candidates_are_short`, `test_positive_rs_blocks_short` — all 18 screener tests pass.
- Strategy tests: `test_entries_from_candidates_emits_short` + `test_entries_from_candidates_emits_long` direct unit tests that inject a synthetic `scored_candidate` and assert `CreateEntering.side` matches — 15 total strategy tests pass.
- `dune build && dune runtest trading/weinstein/strategy/test --force` green; `dune build @fmt` applied.

## Scope

1. ~~**Screener candidate carries side.**~~ Done.
2. ~~**`_make_entry_transition` parameterised by side.**~~ Done.
3. ~~**Macro branch for shorts.**~~ Done (Bearish → short candidates emitted).
4. ~~**Screener short-side rules.**~~ Ch.11 hard RS gate done. Mirror of long-side Stage-2 breakout rules (Stage 4 breakdown, resistance ceiling, negative RS as positive signal rather than just hard gate) is a follow-up.
5. ~~**Position sizing for shorts.**~~ Done (sizing adapter handles signed entry/stop).
6. **Backtest regression pins** — **follow-up**. Bear-market-window scenario in `test_weinstein_backtest.ml` exercising short entries. Deferred — the integration smoke test proved harder to set up than expected (synthetic Declining pattern did not trigger a Stage 3 → Stage 4 transition through accumulated `prior_stage` under default screener `min_grade = C`); pivoted to direct unit tests for the MVP.

## Not in scope

- Buy-to-cover trailing stop tuning beyond what `Weinstein_stops` already does (resistance ceiling → rally stop).
- Margin / borrow cost modelling — separate simulation track if it matters.
- Hard-to-borrow filtering.

## Follow-ups

1. **Bear-window backtest regression** (item 6 above) — extend `test_weinstein_backtest.ml` with a Bearish macro scenario that exercises short entries end-to-end. Requires a synthetic Declining-stock scenario that produces a proper Stage 3 → Stage 4 transition under the default screener (or a lower `min_grade` config on the test harness side).
2. **Full short screener cascade** — current implementation emits short candidates via the existing cascade with the Ch.11 hard RS gate added. Full mirror of the long cascade (positive weight for negative RS trend, resistance-ceiling clean-space weighting for shorts, short-side volume confirmation rules) is a follow-up.
3. **Ch.11 spot-check** — qc-behavioral review against book examples (never-short-Stage-2 verified in unit tests; confirm Stage 4 + negative RS + bearish macro combination on real data).

## References

- `docs/design/weinstein-book-reference.md` Ch. 11 — bear-market shorting rules (never short Stage 2; only Stage 4 with negative RS + bearish macro).
- `docs/design/eng-design-3-portfolio-stops.md:152` — trade-log schema already has `` `Short | `Cover `` actions.
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` — `_make_entry_transition` now takes `cand.side`; `_screen_universe` concatenates buy + short candidates.
- `trading/trading/simulation/lib/order_generator.ml:9-18` — `_entry_order_side` / `_exit_order_side` already handle Short.
- `trading/trading/portfolio/lib/types.mli:20` — signed position quantities (long/short).
- `trading/trading/weinstein/stops/lib/support_floor.mli` — `find_recent_level ~side` handles both sides (merged via support-floor-stops PR A #382).
- `dev/plans/short-side-strategy-2026-04-18.md` — plan.

## Ownership
`feat-weinstein` agent (dispatched 2026-04-18).

## QC
overall_qc: APPROVED (merged)
structural_qc: APPROVED
behavioral_qc: APPROVED

Review artifacts (run-4): side parameterisation clean through screener → strategy → order_generator; no hardcoded Long remaining. Ch.11 hard RS gate tested via `test_positive_rs_blocks_short`.
