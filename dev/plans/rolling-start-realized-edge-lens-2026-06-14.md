# Plan — rolling-start realized-edge + forward-index-DD lens (2026-06-14)

## Context

The factor-decomposition lens design (`dev/notes/factor-decomposition-lens-design-2026-06-14.md`)
names **realized-edge** as the *primary* outcome column for the rolling-start
matrix and **forward index max-DD** as the H1 ("dodge-a-correction") factor.
Today the matrix emits MTM `edge_pct` (annualised strategy CAGR − benchmark
CAGR) — contaminated by terminal mark-to-market on still-open positions
(post-2020 starts show +MTM-edge with deeply −realized; the AXTI effect). It
does NOT emit the design's honest primary outcome.

Both new columns are *pure projections* of data the runner already owns: the
`Summary.t` already yields `realized_return_pct` (MTM stripped), and the runner
already resolves the full benchmark close series once and threads a scalar
`benchmark_cagr_pct` per start. This increment adds the two columns as strict
additions; it is GHA-buildable + GHA-testable with no external data (tests
construct `Summary.t` directly and call `per_start_of_summary`).

## Approach

Add two fields to `Rolling_start_types.per_start`:

1. **`realized_edge_pct : float`** — `annualized_realized_cagr − benchmark_cagr_pct`.
   `annualized_realized_cagr` is `realized_return_pct` (a *total* realized return)
   run through the **same** `Walk_forward_runner.cagr_pct ~test_days ~total_return_pct`
   convention `cagr_pct`/`bah_cagr_pct` use, so it is directly comparable to
   `benchmark_cagr_pct`. `Float.nan` when `benchmark_cagr_pct` is nan (mirror the
   existing `edge_pct` nan discipline exactly). The honest counterpart to the
   contaminated MTM `edge_pct`.

2. **`forward_index_max_dd_pct : float`** — the benchmark's worst peak-to-trough
   drawdown over `[start_date, end_date]`, as a **negative** percent (matching the
   existing `max_drawdown_pct` sign convention: tests pin it negative, e.g.
   `-42.0`). Computed from the benchmark close series clipped to the window.
   `Float.nan` when no benchmark / unpriceable window (same nan discipline as
   `bah_cagr_pct`).

### Seam plumbing

- New pure runner fn `bench_max_dd_pct ~start_date ~end_date ~close_series : float`
  mirroring `bah_cagr_pct`: clip the series to `[start,end]`, compute worst
  peak-to-trough decline as a negative percent, `nan` when fewer than 2 usable
  bars in-window.
- `per_start_of_summary` gains two optional params `?benchmark_cagr_pct` (exists)
  + new `?benchmark_max_dd_pct` (default `Float.nan`). `realized_edge_pct` is
  computed internally from the already-computed `realized_return_pct` + `test_days`.
  `forward_index_max_dd_pct` is recorded verbatim from `?benchmark_max_dd_pct`.
- `_run_one` computes the windowed max-DD via `bench_max_dd_pct` from the
  already-resolved `benchmark_series` and passes it through.

### Report superset

- `Rolling_start_types.build` gains two new `Dispersion_stats.summary` columns
  (`realized_edge`, `forward_index_max_dd`), computed over the same eligible
  subset. `realized_edge` skips nan rows like `edge`.
- Markdown: add the two columns to the per-start detail table + the dispersion
  table + the robustness summary, all as ADDITIONS after the existing columns.
- `[@@deriving sexp]` on `per_start`/`report` re-pins the *internal* sexp shape
  (new fields appended) — acceptable per the dispatch (new-field reality). No
  checked-in backtest golden consumes `rolling_start_types` sexp (verified:
  `grep -r rolling_start trading/test_data/` empty), so this is backtest-golden
  bit-equal.

## Files to change

- `trading/trading/backtest/rolling_start/lib/rolling_start_types.{mli,ml}` — two
  new `per_start` fields + two new `report` summary fields + `build` + renderers.
- `trading/trading/backtest/rolling_start/lib/rolling_start_runner.{mli,ml}` —
  new `bench_max_dd_pct`; `per_start_of_summary` gains `?benchmark_max_dd_pct`;
  `_run_one` threads the windowed max-DD.
- `trading/trading/backtest/rolling_start/test/test_rolling_start_runner.ml` — new
  cases (realized-edge value, nan-without-benchmark, forward-DD known peak→trough,
  forward-DD nan empty window, realized-vs-MTM divergence).
- `trading/trading/backtest/rolling_start/test/test_rolling_start_types.ml` —
  extend `make_start`, sexp round-trip, markdown-contains-sections for new cols.
- `dev/status/rolling-start-lens.md` (new), one new `dev/status/_index.md` row.

## Risks

- **Sign convention.** `forward_index_max_dd_pct` must match `max_drawdown_pct`
  (negative). Pin with a test (100→120→90 → −25%).
- **cagr_pct on negative realized return.** `realized_return_pct` ≥ −100% always
  (can't lose more than the stake on a long-only banked basis), so
  `1 + r/100 ≥ 0` and `cagr_pct` is well-defined. If a synthetic test pushes
  below −100% the result is nan — not exercised here.
- **Golden churn.** Mitigated: no golden consumes the sexp. If a hidden one
  surfaces, STOP and report (do not re-pin a backtest golden).

## Acceptance

- `dune build && dune runtest` green, zero warnings; `dune fmt` clean.
- New columns covered by domain-value tests (one `assert_that` per value,
  composed via `field`/`all_of`/`float_equal`).
- Backtest goldens bit-equal (verified by grep — no consumer).
- `.mli` doc comments for every new public surface.

## Out of scope (data-gated / local-session — NOT in this PR)

- The three external-data factor columns: SPY/macro stage at start, Stage-2
  candidate count at start, sector-RS dispersion at start (need the snapshot
  warehouse + screener — maintainer-local / GHA-data-gated).
- The actual 31-start causal analysis / hypothesis confirm-refute / deployment
  rule (needs the top-3000 PIT warehouse — not in GHA).
- Any new `bin/` driver beyond the existing `rolling_start_eval`. No Python.
