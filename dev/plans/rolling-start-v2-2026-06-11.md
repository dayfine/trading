# Rolling-start robustness runner v2 — start-date × edge-vs-benchmark matrix

**Date:** 2026-06-11
**Track:** backtest-perf (P0 per `dev/notes/next-session-priorities-2026-06-11-PM.md`)
**Branch:** `feat/rolling-start-v2` (+ module sub-bookmarks for jst)
**Extends:** `trading/trading/backtest/rolling_start/` (PR-2 of
`dev/plans/evaluation-objective-and-metrics-2026-06-07.md`).

## Why

The single-start headline numbers we quote ("2011-start +761% / 15.3% CAGR,
modestly beats SPY") are misleading — that is one of the *better* starts. The
honest evaluation is: across many start dates each held to today, does the
strategy robustly beat buy-and-hold of the benchmark? The existing rolling-start
runner does fixed-stride sequential starts with `{CAGR, capital-DD, MaxDD}` only
— no benchmark overlay, no edge column, no jitter, sequential-only. This builds
the start-date × edge-vs-benchmark matrix as the new headline evaluation.

## Spine (do not change)

This is pure evaluation infrastructure. It changes **no strategy behaviour**.
Existing report fields, default behaviour, goldens stay bit-identical. Every new
field is additive; every new param defaults to the prior behaviour.

## Increments (each a stacked PR < 500 lines, module sub-bookmark for jst)

### 1. Jittered start enumeration — `feat/rolling-start-v2/jitter`

New pure function `enumerate_starts_jittered` alongside `enumerate_starts`
(keep the latter untouched for back-compat):

```
val enumerate_starts_jittered :
  scenario_start:Date.t -> end_date:Date.t -> stride_days:int -> jitter_seed:int
  -> Date.t list
```

- Base grid is `scenario_start + k*stride_days` (same as `enumerate_starts`).
- Each base point `b` (except the first, pinned to `scenario_start`) gets a
  deterministic offset `uniform [0, stride_days)` drawn from a seeded
  `Random.State.t` so calendar-boundary artifacts (always 1/1) are avoided.
- A jittered start that lands `>= end_date` is dropped (preserve the
  strictly-before-end invariant).
- Deterministic given `(scenario_start, end_date, stride_days, jitter_seed)`.
- Unit tests pin exact dates for a fixed seed.

### 2. Benchmark overlay — `feat/rolling-start-v2/benchmark`

Pure projection + a panels-backed close-series reader.

```
val bah_cagr_pct :
  start_date:Date.t -> end_date:Date.t -> close_series:(Date.t * float) list
  -> float
```

- `close_series` is the benchmark's adjusted-close series (chronological).
- First close at/after `start_date` = entry; last close at/before `end_date` =
  exit. Annualise total return via `Walk_forward_runner.cagr_pct` with the same
  inclusive-day convention `per_start_of_summary` uses.
- Returns `Float.nan` when fewer than two usable closes span the window
  (documented; flows through to the matrix as a blank cell, never crashes).
- Series source (runner-internal, snapshot path): `Daily_panels.read_history`
  + reuse `Snapshot_bar_source`'s snapshot→close (adjusted_close) extraction.
  Designed so any symbol present in the manifest works (SPY, BRK-B, GSPC.INDX).
- Add `benchmark_cagr_pct` + `edge_pct` (= `cagr_pct - benchmark_cagr_pct`) to
  `per_start`.

### 3. Richer per-start columns + matrix rendering — `feat/rolling-start-v2/matrix`

- Add to `per_start`: `sharpe` (from summary `SharpeRatio`),
  `time_underwater_pct` (via `Convexity_stats.time_underwater_pct` over the
  run's equity curve), `realized_return_pct` (a realized-basis return so an
  AXTI-style terminal unrealized mark can't flatter recent-start rows —
  `(final_value - UnrealizedPnl - initial_cash) / initial_cash * 100`; the
  simplest honest realized metric, documented in the `.mli`).
- `per_start_of_summary` extends to take the equity curve + benchmark series.
- `report`/`to_markdown`/sexp: matrix = start × {strategy CAGR, benchmark CAGR,
  edge, Sharpe, capital-DD, time-underwater, realized basis} + summary
  distribution rows: median edge, % of starts beating benchmark, worst start.
- Additive: keep existing fields + dispersion table renderers intact.

### 4. Parallel fork-per-start — `feat/rolling-start-v2/parallel`

- Mirror the walk-forward fork-per-fold pattern (`Fork_pool.run_each_forked`
  for `parallel=1` broad-universe; `Fork_pool.run_parallel ~parallel` for
  `parallel>1`). Each start is an independent full backtest → marshallable
  `per_start` result → fits `Fork_pool`'s contract.
- Wire CLI flags into `bin/rolling_start_eval.ml`: `--parallel`,
  `--stride-days` (alias for existing `--start-stride-days`), `--jitter-seed`,
  `--benchmark SYMBOL`. `--snapshot-dir` exists.

## Invariants

- TDD; OCaml only; all params config/CLI — nothing hardcoded.
- Additive only: defaults reproduce current behaviour bit-identically.
- No full matrix backtest in this work — runner + tests only. The dispatcher
  runs the matrix after merge (P1 universe dependency).
