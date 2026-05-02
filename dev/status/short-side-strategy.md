# Status: short-side-strategy

## Last updated: 2026-05-02

## Status
MERGED

Track wrapped on the MVP + initial follow-up axis. New follow-ups surfaced overnight in `dev/notes/force-liq-cascade-findings-2026-05-01.md` (G14 split-adjustment on Position.t Holding state) and `dev/notes/g14-deep-dive-2026-05-01.md` (Option 1 fix recommendation). G15 (short-side risk control) also filed. Both are `feat-weinstein` — strategy + position state machine; current `feat-weinstein` scope is closed. See §Follow-ups below for the new items.

All four follow-ups landed via PRs #617 (bear-window regression test),
#623 (live-cascade Bearish macro plumbing fix), #630 (full short
screener cascade), and #631 (Ch.11 spot-check on real data). MVP
originally landed via #420 on 2026-04-19. Track wraps; future
short-side work is performance-driven (e.g., revisiting the cascade
parameters once the trade-audit track ships) rather than feature
build-out.

**2026-04-30 (evening) update**: shorts now live in the sp500
regression scenario. After G1-G5 + G7-G9 closed (PRs #689-#710),
`goldens-sp500/sp500-2019-2023.sexp` has the `enable_short_side =
false` override removed and ranges re-pinned to the with-shorts
baseline (32 trades / -0.01% / 0 force-liquidations / 43d avg holding
/ 5.8% MaxDD). See `dev/notes/sp500-shortside-reenabled-2026-04-30.md`.
The 5-year sp500 scenario is now the standing regression gate for
short-side correctness; the 4 short trades the strategy emits during
the 2019 Bearish-macro window all exit via stop_loss with the correct
sign convention.

**Historical: live-cascade bug (resolved by #623)**: real-data SP500
verification (PR #612) revealed 0 short trades + 37 long entries in
2022 bear despite `Macro.analyze` correctly returning Bearish at the
unit level. Root cause: `Weinstein_strategy.make` loaded composer-AD
bars covering ~1973 to April 2026 and passed them to every Friday's
`_on_market_close` without filtering by `current_date`. Future-leaking
synthetic A-D disagreed with the real 2022 Stage 4 GSPC index,
flipping the macro composite from Bearish to Neutral/Bullish. Fix:
`Macro_inputs.ad_bars_at_or_before` called in `_run_screen`.

Pinned by `trading/trading/weinstein/strategy/test/test_macro_panel_callbacks_real_data.ml`:
- Real 2022 GSPC + empty AD bars + panel-callbacks → Bearish (mirrors
  `test_macro_2022_bear_market` in macro/test/test_macro_e2e.ml).
- Real 2022 GSPC + synthetic AD bars filtered to `<= 2022-10-14`
  → Bearish, confidence < 0.5 (the fix's contract).
- Real 2022 GSPC + synthetic AD bars extending through 2026 unfiltered
  → non-Bearish (the bug, double-pinned to catch regressions from
  either direction).

Run-2 (2026-04-27): the second commit on `feat/short-side-bear-window-fix-cascade-plumbing`
swaps `Ad_bars.load`/`Ad_bars_aggregation.daily_to_weekly` in the test for
a deterministic two-phase synthetic series so the contract pins on CI runs
where `TRADING_DATA_DIR=trading/test_data` ships only Unicorn breadth
2017-2020 (no synthetic CSV). Same commit pulls the parent commit's
`weinstein_strategy.ml` back to the 500-line `@large-module` ceiling and
splits `Macro_inputs.ad_bars_at_or_before` so neither helper exceeds the
nesting limit.

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

1. ~~**Bear-window backtest regression** (item 6 above)~~ — landed in PR #617 (`feat/short-side-bear-window-regression`). New file `trading/trading/weinstein/strategy/test/test_short_side_bear_window.ml` pins both directions of the bear-window contract through the public `Screener.screen` -> `Weinstein_strategy.entries_from_candidates` seam (synthetic-mocked candidates, not full simulator). Pivoted from the `test_weinstein_backtest.ml` end-to-end approach because the synthetic Declining pattern still does not trigger a clean Stage 3 → Stage 4 transition under the default screener — the right primitive seam is the screener -> entries_from_candidates pipeline, which catches regressions deterministically. Live-cascade gap (PR #612 — 0 short trades and 37 long entries opened in 2022 bear on real SP500 data) remains; diagnosis is upstream of this seam, in `_run_screen`'s `macro_callbacks` construction. Tracked separately.
2. ~~**Full short screener cascade**~~ — DONE via `feat/short-side-cascade-rules` (this PR). Adds three weighted signals to the short cascade: (a) `_volume_short_signal` boosts Strong / Adequate breakdown volume by `w_strong_volume` / `w_adequate_volume`, mirroring the long-side breakout-volume signal; (b) new `Support` module under `analysis/weinstein/support/` grades below-breakdown clean space (Virgin / Clean / Moderate_resistance / Heavy_resistance) and `Screener._support_signal` weights Virgin and Clean by `w_clean_resistance`, Moderate by half; (c) the Ch.11 hard RS gate stays load-bearing, with `_rs_short_signal` already weighting `Bearish_crossover > Negative_declining > Negative_improving` from prior MVP. Stock_analysis.t now carries `support : Support.result option` and `breakdown_price : float option`. Pinned values updated: VOL_STRONG synthetic 70→85 (+Clean), e2e bear-window JPM 65→72 / CVX 45→52 (+Moderate support), backtest 6-year n_buys/n_sells 36/33→39/36 (+3 trades, symbols unchanged). 22 screener unit tests + 8 new Support tests + 5 e2e tests all pass.
3. ~~**Ch.11 spot-check**~~ — DONE via `feat/short-side-ch11-spotcheck`. Two new tests in `analysis/weinstein/screener/test/test_screener_e2e.ml` pin the Stage 4 + negative RS + Bearish macro combination on real 2022 bear data (7-stock universe, `Test_data_loader` cached bars): `test_ch11_spotcheck_2022_bear` pins MSFT (Stage 4 + RS bearish crossover, score 45, entry $351.42) and JPM (Stage 4 + Adequate breakdown volume + RS negative & declining, score 45, entry $173.82) at the 2022-07-15 mid-bear cut; `test_ch11_no_shorts_under_bullish_macro_2022` pins the negation (Bullish macro emits zero shorts even with Stage 4 stocks present). The per-Ch.11-pattern → test mapping is in `dev/notes/short-side-ch11-spotcheck-2026-04-27.md`. Universe limitation noted: known archetypal 2022 Stage 4 names (CVNA, COIN, PTON, AFRM) not in test fixture; universe-level expansion would belong to a separate follow-up (extend `Scenario.expected` with `total_short_trades` metric).
4. ~~**Live-cascade Bearish macro plumbing** (new, ex-#612)~~ — fixed
   in `feat/short-side-bear-window-fix-cascade-plumbing`. Root cause was
   upstream of `Panel_callbacks.macro_callbacks_of_weekly_views`: the
   composer-loaded AD breadth series was time-unfiltered, so the macro
   analyzer's `get_cumulative_ad ~week_offset:0` returned the cumulative
   as of the last loaded synthetic bar (~April 2026), date-misaligned by
   ~3 years against the index close at the simulator's current 2022 tick.
   Fix: `Macro_inputs.ad_bars_at_or_before` filters AD bars to dates
   `<= current_date` inside `_run_screen` before they reach the panel
   callbacks. Pinned by `test_macro_panel_callbacks_real_data.ml`.

5. **Verify SP500 5y backtest emits non-zero shorts in 2022** — follow-up
   to (4): rerun the full SP500 2019-2023 scenario with the fix to
   confirm the symptom (0 shorts, 37 long entries in 2022) is resolved.
   Out of scope for the fix PR per cost (~2.5 min wall, full backtest);
   covered by the next nightly Tier-3 perf run.

6. **G14 — split-adjustment on Position.t Holding state** (filed 2026-05-01,
   merged 2026-05-01 via PR #736). Fixed both interlocked bugs together
   per Option 1 (raw close-price space + lookback truncation):
   - **Bug A**: `_scan_max_high_callback` / `_scan_min_low_callback` in
     `analysis/weinstein/stock_analysis/lib/stock_analysis.ml` now truncate
     at the most recent split boundary using a `_no_split_between`
     guard keyed off the per-bar `adjusted_close / close_price` factor
     (threshold 0.20 — distinguishes splits from dividend drift).
   - **Bug B**: `entry_audit_capture._effective_entry_price` reads the
     most recent close from `bar_reader` and threads it through sizing,
     stop computation, the `CreateEntering` transition, and audit-row
     dollar fields. The audit row's `candidate.suggested_entry` is
     preserved verbatim so consumers can reconcile screener intent vs
     realised entry.
   - **Result on sp500-2019-2023-long-only**: force-liqs 6 → 0;
     return +65.0% → +21.6%; MaxDD 31.8% → 43.0% (the shifts reflect
     underlying short-side risk previously masked by inflated
     entry_price values; G15 is the follow-up).
   - **Acceptance tests**: `test_breakout_truncates_at_split_boundary`,
     `test_breakdown_truncates_at_split_boundary`,
     `test_no_split_no_truncation` (stock_analysis);
     `test_effective_entry_overrides_suggested_entry`,
     `test_empty_bar_reader_falls_back_to_suggested_entry`
     (entry_audit_capture).
   - 2026-05-02 redispatch (this session) was a no-op — verified the
     fix is on `origin/main` and all acceptance criteria from the
     dispatch prompt are met by code already merged. No PR opened.
     See `dev/notes/g14-deep-dive-2026-05-01.md` for the full
     root-cause writeup.

7. **G15 — short-side risk control** (filed 2026-05-01, `feat-weinstein`
   scope). With G12 (#725) + G13 (#726) eliminating the spurious
   `Portfolio_floor` cascade, sp500-2019-2023 portfolio goes negative
   (-$175K minimum 2021-11-04, -66.7% return, 117.5% MaxDD). The phantom
   floor was acting as an unintended risk control. Real candidates:
   (a) max total short notional as fraction of portfolio; (b) tighter
   per-position short stop-loss threshold (Weinstein recommends tighter
   stops on shorts than longs); (c) honest portfolio-floor based on real
   peak observations (now correct post-G13). Combination of (a) + (b)
   likely needed. See `dev/notes/force-liq-cascade-findings-2026-05-01.md`
   §G15. Owner: `feat-weinstein` — same scope-extension prereq as G14.

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
