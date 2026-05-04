# sp500-2019-2023 F-phase parity bisect (2026-05-04)

Closes #843. Phase F.2 default-flip + F.3.a-c wiring produces materially
different metrics on `goldens-sp500/sp500-2019-2023.sexp` vs the pinned
pre-F.2 baseline. This log records each candidate commit's metrics.

## Pinned baseline (target)

From `goldens-sp500/sp500-2019-2023.sexp` header (measured 2026-05-02
on commit 5a20c1cb, post-#789 re-pin, pre-F.2):

- total_return_pct +60.86
- total_trades 86
- sharpe_ratio 0.55
- max_drawdown 34.15
- win_rate ~22.35
- avg_holding_days unspecified, expected band [65, 115]

## Current main metrics (per #843)

- total_return_pct +40.29 (-20.6pp)
- total_trades 93 (+7)
- sharpe_ratio 0.45 (-0.10)
- max_drawdown 29.59 (-4.6pp)

## Bisect targets

| PR  | Commit   | Description                                                         |
|-----|----------|---------------------------------------------------------------------|
| -   | 5a20c1cb | Pinned baseline (post #789 repin, pre-F.2)                          |
| 797 | dd061cdb | F.2 PR 1 — Snapshot_bar_views shim over Snapshot_callbacks         |
| 800 | 2aae9a0c | F.2 PR 2 — wire snapshot mode through strategy bar reads           |
| 802 | fc493d69 | F.2 PR 3 — default-flip snapshot mode + --csv-mode opt-out         |
| 825 | fadec364 | F.3.a-1 — Bar_reader.of_in_memory_bars + panel-independent empty   |
| 827 | c2b8f467 | F.3.a-2 — migrate strategy tests off Bar_reader.of_panels          |
| 828 | 9a184d40 | F.3.a-3 — Panel_runner CSV path builds snapshot in-process         |
| 829 | 768f9f0c | F.3.a-4 — delete Bar_reader.of_panels                              |
| 833 | 9ad1badc | F.3.b-1 — Weekly_ma_cache snapshot-views port                      |
| 837 | 4ad4785e | F.3.c — Panel_callbacks snapshot-views port                        |
| 845 | b6d1d1b7 | perf(snapshot): O(log N) reads + 1 GiB cache (current main)        |

## Run protocol

1. `jj new -r <commit>` (working copy switch only, no commit).
2. `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe 2>&1 | tail -20'`
3. Run scenario_runner over goldens-sp500 (`--dir trading/test_data/backtest_scenarios/goldens-sp500`).
4. Read summary.sexp from the output dir; record total_return_pct, total_trades, sharpe_ratio, max_drawdown.

## Results

| Commit | PR  | Return  | Trades | WinRate | MaxDD  | Notes                          |
|--------|-----|---------|--------|---------|--------|--------------------------------|
| 5a20c1cb | 789 | 60.9%  | 86     | 22.1%   | 34.2%  | Baseline (pinned target). PASS                     |
| dd061cdb | 797 | 60.9%  | 86     | 22.1%   | 34.2%  | F.2 PR 1 — shim only, no behavior change. PASS    |
| 2aae9a0c | 800 | 60.9%  | 86     | 22.1%   | 34.2%  | F.2 PR 2 — wire-through, default still legacy. PASS |
| fc493d69 | 802 | 60.9%  | 86     | 22.1%   | 34.2%  | F.2 PR 3 — default-flip in single-CLI; multi-runner unaffected. PASS |
| fadec364 | 825 | 60.9%  | 86     | 22.1%   | 34.2%  | F.3.a-1 — Bar_reader.of_in_memory_bars; default legacy. PASS |
| 9a184d40 | 828 | 22.2%  | 112    | 19.6%   | 31.1%  | **F.3.a-3 — Panel_runner CSV path builds snapshot in-process. FIRST DIVERGENCE.** Output now says "in-process snapshot built (506 symbols)" instead of "panels built (506 symbols × 1453 days)". |
| 9ad1badc | 833 | 22.2%  | 112    | 19.6%   | 31.1%  | F.3.b-1 — Weekly_ma_cache port; same as #828                       |
| 4ad4785e | 837 | 22.2%  | 112    | 19.6%   | 31.1%  | F.3.c — Panel_callbacks port; same as #828                         |
| b6d1d1b7 | 845 | 22.2%  | 112    | 19.6%   | 31.1%  | Current main (perf O(log N) reads); same as #828 with pinned 491-universe |

## Conclusion

**Root-cause commit: #828 (9a184d40, "F.3.a-3 — Panel_runner CSV path builds snapshot in-process").**

The code regression is ~38.7pp (return) / +26 trades, all introduced at #828. Subsequent F.3.b/c/perf PRs are bit-equal to #828 on this fixture. The 40.3%/93 number cited in #843 came from running on the refreshed 503-symbol sp500.sexp (PR #807, 2026-05-03); with the universe pinned at 491 symbols (matching the baseline), every commit from #828 onward shows 22.2%/112.

The drop from 22.2% (pinned-universe) to 40.3% (refreshed-universe) under the snapshot path means the +12 symbols partially mask the snapshot-mode-vs-panel-mode regression — not eliminate it.

## Followup: where in #828 is the divergence

#828 made two coupled changes in `panel_runner.ml`:
1. The simulator's `Market_data_adapter` switched from `Bar_data_source.Csv`
   (Price_cache + Indicator_manager) to `Bar_data_source.Snapshot`
   (Snapshot_bar_source over Daily_panels).
2. The strategy's `Bar_reader` switched from `of_panels` (over a Bar_panels.t
   built from Ohlcv_panels.load_from_csv_calendar) to `of_snapshot_views`
   (over Snapshot_callbacks.of_daily_panels).

To isolate which side carries the regression I patched #828 in two
independent ways:

- **Force simulator adapter back to CSV-mode** (Market_data_adapter via
  Price_cache), keeping `Bar_reader.of_snapshot_views` for the strategy:
  result UNCHANGED at 22.2% / 112 trades.
- **Force strategy bar_reader back to `of_panels`** (Bar_panels built from
  Ohlcv_panels.load_from_csv_calendar), keeping the snapshot-backed
  Market_data_adapter: result RESTORES baseline at **60.9% / 86 trades**.

So the divergence is on the strategy side — the change from `of_panels`
to `of_snapshot_views` for the strategy's bar reads causes the regression.

## But the bar-reader primitives test bit-equal in isolation

A new diagnostic exec
(`trading/trading/backtest/test/diag_real_csv_parity.exe`) loads real CSV
data for the full sp500-2019-2023 universe (491 universe symbols + GSPC.INDX
+ 11 SPDR sector ETFs + 3 global indices = 506 symbols), builds both a
`Bar_panels.t` (via Ohlcv_panels.load_from_csv_calendar) and a snapshot dir
(via Snapshot_pipeline.Pipeline + Snapshot_format), and compares the two
readers cell-by-cell for `weekly_view_for ~n:52` and `daily_bars_for`
across all 261 weekdays of 2019:

```
Universe: 491 symbols
Calendar: 1453 trading days (2018-06-06..2023-12-29)
Test dates: 261 weekdays in 2019
Total weekly_view: 0/132066 (symbol, weekday) cells differ
Total daily_bars: 0/132066 cells differ
```

Bit-equal. So the divergence is NOT in `Snapshot_bar_views.weekly_view_for`
or `daily_bars_for` semantics in isolation — those primitives produce
bit-identical outputs to `Bar_panels` on every (symbol, weekday) cell the
strategy queries.

This means the bug is **path-dependent or stateful** — possibly:
- LRU eviction order in `Daily_panels` causing different shared state
  between simulator-side and strategy-side reads of the same symbol.
- A `Hashtbl` ordering effect somewhere downstream of the bar reads.
- A bar-reader closure captured incorrectly across `_run_macro_only` and
  `_classify_stage_for_screening` calls within the same Friday cycle.
- Or a primitive I haven't tested (e.g., `daily_view_for` is only used by
  `entry_audit_capture.ml` so isn't on the trading hot path; `low_window`
  is only referenced by `Snapshot_bar_views` itself; `weekly_bars_for` is
  used only by `Weekly_ma_cache._snapshot_weekly_history`).

## Recommendation

This is the situation the dispatch prompt's "STOP and surface as a decision
item" guidance covers: the fix is non-obvious and would constitute a
partial revert of an F-phase PR (#828) on the strategy side. Two viable
paths:

1. **Partial revert (safest, smallest LOC):** revert only the strategy's
   `Bar_reader` initialization to the pre-#828 path
   (`Bar_reader.of_panels` over a Bar_panels.t built from
   `Ohlcv_panels.load_from_csv_calendar`). Keep the
   `Market_data_adapter.Snapshot` simulator adapter (preserves F.2's
   per-tick RAM benefits). Empirically restores baseline 60.9% / 86
   trades. Adds back the panel allocation for the strategy's universe ×
   calendar OHLCV — tier-3 sized, ~tens of MB.
2. **Forward fix:** root-cause the path-dependent divergence in
   `Snapshot_bar_views` / `Snapshot_callbacks` / `Daily_panels` and patch
   it. Requires deeper investigation than fits a single agent session.

Both options leave F.2 PR 1/2/3 (#797/#800/#802), F.3.a-1 (#825), F.3.a-2
(#827), F.3.a-4 (#829), F.3.b-1 (#833), F.3.c (#837), F.3.d (#842), and
the perf PR (#845) intact.

The diagnostic exec stays in the tree as a regression test future F.3.x
work can extend.
