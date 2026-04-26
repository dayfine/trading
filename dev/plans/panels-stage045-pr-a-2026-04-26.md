# Plan: Stage 4.5 PR-A — two-phase lazy stage filter in `_screen_universe` (2026-04-26)

## Status

IMPLEMENTING. Companion to
`dev/plans/panels-stage045-lazy-tier-cascade-2026-04-26.md` §"PR-A".
Branch: `feat/panels-stage045-pr-a-lazy-stage-filter`.

## Wedge (recap)

`_screen_universe` runs the full per-symbol heavy work
(`weekly_view_for` + `stock_analysis_callbacks_of_weekly_views` +
`Stock_analysis.analyze_with_callbacks`) for **every** loaded symbol on
every Friday, then filters to survivors via the screener cascade.
That ordering pays full per-symbol allocation regardless of regime.
Per-symbol RSS slope at N=292 T=6y is 5.12 MB/symbol; goal is to drive
it toward ≤ 1.5 MB/symbol via lazy allocation.

## Two-phase design

```
Phase 1 (universe-wide, cheap):
  for ticker in config.universe:
    weekly_view = Bar_reader.weekly_view_for(ticker, n=lookback_bars)   (* small: 5 float arrays *)
    stage_callbacks = Panel_callbacks.stage_callbacks_of_weekly_view    (* cache-aware via PR-D *)
                        ~ma_cache ~symbol:ticker ~weekly:weekly_view
    stage_result = Stage.classify_with_callbacks(stage_callbacks, prior_stage)
    Hashtbl.set prior_stages ~key:ticker ~data:stage_result.stage      (* always update *)
    if stage_result.stage matches Stage2 or Stage4:
      yield (ticker, weekly_view, stage_result)                         (* survives Phase 2 *)

Phase 2 (survivors only, heavy):
  for (ticker, weekly_view, _) in survivors:
    full_callbacks = Panel_callbacks.stock_analysis_callbacks_of_weekly_views
                       ~ma_cache ~stock_symbol:ticker
                       ~stock:weekly_view ~benchmark:index_view
    stock_analysis = Stock_analysis.analyze_with_callbacks(...)         (* the expensive step *)
    yield stock_analysis

Screener.screen ~stocks:phase2_results ...
```

## Filter predicate

Long: `Stock_analysis.is_breakout_candidate` requires `stage = Stage2 _`
(any sub-state). Short: `Stock_analysis.is_breakdown_candidate` requires
`stage = Stage4 _` (any sub-state). The screener's `_long_candidate` and
`_short_candidate` further filter via `is_breakout_candidate` /
`is_breakdown_candidate`, which gate-check on Stage2 / Stage4. The
screener's watchlist gate also requires `is_breakout_candidate`
(Stage2). Symbols in Stage1 / Stage3 cannot produce a candidate.

So Phase 1's predicate is:

```ocaml
match stage_result.stage with
| Stage2 _ | Stage4 _ -> true   (* survive *)
| Stage1 _ | Stage3 _ -> false  (* drop — screener would reject anyway *)
```

This is over-broad relative to the screener's actual rules
(Stage2 also needs prior_stage = Stage1 or weeks_advancing ≤ 4 +
volume + RS in `is_breakout_candidate`; Stage4 needs prior_stage =
Stage3 or weeks_declining ≤ 4) but staying broad keeps Phase 1
cheap (no Volume / RS reads) and guarantees parity with the bar-list
output.

## Pragmatic deviation from dispatch

The dispatch suggested Phase 1 read panel cells directly without
`weekly_view_for` allocation. The cleanest implementation that
preserves bit-equality with the existing callbacks (and with the
`test_panel_loader_parity` golden) reuses `weekly_view_for` for
Phase 1 — which still allocates 5 float arrays per symbol per Friday
(~ 5 × 52 × 8 ≈ 2 KB, negligible compared to the Stock_analysis
bundle and `analyze_with_callbacks` work).

The load-bearing wedge is **Phase 2 elimination** (the full callback
bundle + Stock_analysis analyze). Phase 1's `weekly_view_for` cost is
small and the cache-aware MA path (PR-D #594) means MA computation is
amortised across Fridays. If the post-PR-A matrix shows
`weekly_view_for` is still a wedge, a follow-up PR can add a
panel-row-direct stage callback (Closes-only Bigarray slice +
`Weekly_ma_cache` MA reads, no `Bar_panels.weekly_view` materialisation).

## Files

- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` —
  `_screen_universe` and `_analyze_ticker` split into Phase 1
  (`_classify_stage_for_screening`) and Phase 2
  (`_full_analysis_of_survivor`).
- `trading/trading/weinstein/strategy/test/test_weinstein_strategy.ml`
  — new counter test asserting Phase 2 invocation count matches
  survivor count, not loaded count.

`Panel_callbacks` is unchanged — Phase 1 uses the existing
`stage_callbacks_of_weekly_view`; Phase 2 uses the existing
`stock_analysis_callbacks_of_weekly_views`. No new public API.

## Parity gates

- `test_panel_loader_parity` round_trips golden — bit-equal trades
  (load-bearing).
- `test_weinstein_backtest` (3 simulation tests) — relaxed structural
  invariants must still hold.
- `test_weinstein_strategy{,_smoke}`, `test_macro_inputs`,
  `test_stops_runner`, `test_panel_callbacks`, `test_weekly_ma_cache`
  — green.

Plus PR-A specific:

- New counter test in `test_weinstein_strategy.ml` — synthetic Stage-4-
  heavy fixture, count Phase 2 invocations, assert equals survivor
  count.

## LOC

~80 production, ~70 tests. Net minor change to `_screen_universe`.
