# Status: short-side-strategy

## Last updated: 2026-04-26

## Status
MERGED (MVP); Follow-up #1 (bear-window regression) BLOCKED by macro/breadth gap.

MVP slice landed via #420 on 2026-04-19; follow-ups tracked below.

**Reactivation attempted 2026-04-26 — bear-window regression in flight:** the
SP500 golden landed (#606) and Stage 4 work unblocked broad-universe scale, so
the orchestrator dispatched Follow-up #1. Investigation found a structural
blocker independent of universe size — see § Bear-window investigation.

**Prior reactivation cue (2026-04-24):** flip Status back to IN_PROGRESS once
the Tiered loader flip in `backtest-scale.md` lands. The three § Follow-ups
below practically require broad-universe backtest scale to be feasible
(bear-window regression test, full short cascade tuning, Ch.11 spot-check on
real data). They're not hard-blocked at the API level; the orchestrator should
pick them up as soon as the scale work is unblocked.

## Bear-window investigation (2026-04-26)

Tried adding a `test_bear_window_shorts_fire` to `test_weinstein_backtest.ml`
that runs the strategy over 2018-01 → 2023-12 on the existing 7-stock universe
(extended to include GOOGL — though GOOGL test_data is a 134-row stub and
yields no analysis). Pinned `n_short_entries > 0`. Test fails consistently —
no shorts ever fire. Diagnostics in the strategy's `_screen_universe`:

- Macro analyzer **never returns Bearish** across 2018-2023, even during the
  Mar-2020 COVID crash (-35%) or the 2022 bear (GSPC -25%, AAPL/MSFT/JPM/HD
  down 30-40%).
- Across 2022, macro oscillates between Bullish and Neutral. The screener's
  `_evaluate_shorts` IS called under Neutral macro — but produces zero short
  candidates per Friday tick because no stock in the universe satisfies
  `is_breakdown_candidate` (= Stage4 from Stage3 OR Stage4 with
  `weeks_declining ≤ 4`). The 30-week WMA-based Stage classifier with
  `slope_threshold = 0.005` doesn't register Stage4 reliably for these
  blue-chip names.

Root cause is two-layered:

1. **Breadth dataset ends 2020-02-14.** Both `test_data/breadth/` and the
   broader `data/breadth/` advancing/declining issue counts stop in February
   2020. After that the macro analyzer's A-D Line, Momentum Index, and global
   consensus indicators all return Neutral (no data). Confidence is computed
   from the remaining active indicators (Index Stage + NH-NL proxy). Without
   breadth, Bearish detection collapses to "GSPC must be in Stage 4 (weight
   3.0) AND NH-NL proxy must be Bearish (weight 1.5)" — and the slow weekly
   MA of GSPC frequently reads Flat/Stage3 rather than Stage4 even during the
   2022 bear (peak-to-trough -25% wasn't enough to flip the 30-week WMA's
   slope past `slope_threshold = 0.005` for sustained periods).
2. **Universe sparseness.** The 7-stock blue-chip set + GOOGL stub doesn't
   produce many breakdown candidates even when macro IS Neutral (the screener
   gate that admits shorts). Without scaled universe loading from broad data
   (separate scope: `backtest-scale.md`), in-process tests don't have enough
   short setups to trip the threshold.

Both blockers are independent of the short-side strategy code, which is
verified in unit tests at the candidate level
(`test_entries_from_candidates_emits_short` etc.). Decision: don't ship a
failing test or contrive a passing one with bespoke configs that don't
exercise the production path.

## Reactivation prerequisites

Before re-attempting the bear-window regression:

- **Either** breadth data extension past Feb 2020 — see
  `dev/notes/data-gaps.md` and the breadth loader's coverage; this is a
  data-layer + ingestion follow-up (the EODHD breadth feed has continued
  publishing, but the local snapshot is stale).
- **Or** macro analyzer rework that doesn't degrade so heavily when breadth
  is missing — e.g. fall back to a lower-weight, MA-direction-only signal so
  Bearish detection doesn't depend solely on the index's 30-week WMA slope
  crossing the (currently very tight) threshold.
- **Or** a synthetic-bar harness for `test_weinstein_backtest.ml` that
  generates declining bar series for a controlled subset (and a declining
  GSPC.INDX) so the test pin is decoupled from real data. Synthetic harness
  is the most contained option but requires an extension of
  `test_helpers.with_test_data` to feed the panel-backed bar reader rather
  than CSV, and the strategy `make` defaults need to be tweakable so
  `min_grade` and `slope_threshold` aren't load-bearing on real-data
  baselines.

Each unblock is a meaningful piece of work — none is single-PR-sized as a
side effect of the bear-window regression itself.

## Interface stable
YES

`Screener.scored_candidate.side` and public `Weinstein_strategy.entries_from_candidates` signature landed in main.

## Merged PR
- #420 (feat/short-side-strategy) — MVP vertical slice: side through screener → strategy → order_generator, with Ch.11 RS hard gate and unit tests for Short + Long entry transitions.

## Blocked on
- No hard interface block. Practical block: the three § Follow-ups
  need broad-universe Tiered-loader backtest scale to be feasible.
  Tracked in `backtest-scale.md` § Follow-up "Reciprocal short-side
  practical block".

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

1. **Bear-window backtest regression** (item 6 above) — BLOCKED on
   macro/breadth gap (see § Bear-window investigation 2026-04-26). Original
   intent: extend `test_weinstein_backtest.ml` with a Bearish-macro scenario
   that exercises short entries end-to-end. Empirical finding 2026-04-26:
   macro never registers Bearish on the local data because breadth ends
   Feb 2020 and the index-stage + NH-NL fallback doesn't flip Bearish even
   in 2022. Requires breadth data extension OR macro rework OR synthetic-bar
   harness — see § Reactivation prerequisites.
2. **Full short screener cascade** — current implementation emits short candidates via the existing cascade with the Ch.11 hard RS gate added. Full mirror of the long cascade (positive weight for negative RS trend, resistance-ceiling clean-space weighting for shorts, short-side volume confirmation rules) is a follow-up.
3. **Ch.11 spot-check** — qc-behavioral review against book examples (never-short-Stage-2 verified in unit tests; confirm Stage 4 + negative RS + bearish macro combination on real data). Same macro/breadth blocker applies — cannot spot-check "Bearish macro combination" without macro reliably registering Bearish.

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
