# Reconciler-producer CSVs (2026-04-30)

Wires three new per-scenario artefacts that the external
`trading-reconciler` tool consumes to verify cash-floor / held-through-split
/ unrealized-P&L accounting independently of the backtest's own metrics
pipeline. Schemas are pinned by `~/Projects/trading-reconciler/PHASE_1_SPEC.md`
§3 + §4 + §3.3.

## What landed

`Result_writer.write` now emits, alongside the existing `trades.csv` /
`equity_curve.csv` / `summary.sexp` / `trade_audit.sexp` /
`force_liquidations.sexp` artefacts:

- `open_positions.csv` — one row per Holding position at run end.
  Columns: `symbol,side,entry_date,entry_price,quantity`. `side` is
  `LONG` / `SHORT` (case-sensitive, derived from net quantity sign).
  `entry_price` is the per-share average cost; `quantity` is the absolute
  share count.

- `final_prices.csv` — one row per symbol present in `open_positions.csv`.
  Columns: `symbol,price`. Price is the close on the run's final
  calendar day, snapshotted from the panel runner's `Bar_panels.t` at
  `n_days - 1`. Symbols held at run end without a final-day bar (delisted
  / suspended / pre-IPO on that day) are silently dropped — the reconciler
  surfaces the gap via its left-anti join.

- `splits.csv` — one row per split event during the run window.
  Columns: `symbol,date,factor`. Sourced from `step_result.splits_applied`
  across all steps (the simulator only logs splits for symbols actively
  held that day, so no further filtering is needed).

All three CSVs are header-only when there is nothing to record. The
reconciler accepts the empty-with-header form (treats it as "zero
records to verify").

## How the price snapshot threads through

`Panel_runner.run` was extended to return a fifth tuple element
`final_close_prices : (string * float) list`. After the simulation loop
completes, it iterates the universe via `Symbol_index.symbols` and reads
cell `(row, n_days - 1)` of `Ohlcv_panels.close`. NaN cells are dropped.

`Runner.run_backtest` filters that alist to symbols still held in the
last step's portfolio and stores the result in `Runner.result.final_prices`.
Filtering happens at the runner level, not the writer level, so callers
that don't need the CSV (e.g. ad-hoc scripts using `Runner.run_backtest`
without `Result_writer.write`) still pay only the universe-scan cost
once.

## Test coverage

`trading/trading/backtest/test/test_result_writer.ml` was extended with
six tests pinning the artefact schemas end-to-end:

- `open_positions.csv` header + rows for one LONG + one SHORT
- `open_positions.csv` empty case writes header-only
- `final_prices.csv` header + rows; entries for non-held symbols dropped
- `final_prices.csv` empty case writes header-only
- `splits.csv` header + rows for forward (4.0) + reverse (0.125) splits
- `splits.csv` empty case writes header-only

Reconciler validates files on header match and exits 2 on any drift, so
tests assert both the literal header text and the row format strictly.

## Files touched

- `trading/trading/backtest/lib/runner.{ml,mli}` — `final_prices` field
  on `Runner.result`; `_final_prices_for_held_symbols` helper.
- `trading/trading/backtest/lib/panel_runner.{ml,mli}` — fifth tuple
  element from `run`; `_final_close_prices` helper.
- `trading/trading/backtest/lib/result_writer.{ml,mli}` — three new
  writers (`_write_open_positions`, `_write_final_prices`,
  `_write_splits`) wired into `Result_writer.write`.
- `trading/trading/backtest/test/test_result_writer.ml` — six new tests.
- `trading/trading/backtest/test/test_trade_audit_report.ml` — one-line
  fix to add `final_prices = []` to a record literal.

## Out of scope

None of the existing artefacts changed. `trades.csv` schema is
unchanged. Splits sourced from `step_result.splits_applied` so no new
plumbing through `Runner.result.steps` was needed.
