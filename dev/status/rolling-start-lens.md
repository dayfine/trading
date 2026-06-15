# Status: rolling-start-lens

## Last updated: 2026-06-15

## Status
IN_PROGRESS

## Interface stable
YES

## Owner

feat-backtest

The factor-decomposition lens on the rolling-start matrix: decompose **when**
and **why** the strategy beats the benchmark, per start, joining each start to
causal factors that steer deployment. Design authority:
`dev/notes/factor-decomposition-lens-design-2026-06-14.md`.

First deliverable (the two GHA-buildable outcome/factor columns) in review as
PR #1586. The data-gated factor columns + the causal analysis are
maintainer-local follow-ups.

### Interface

`Rolling_start_types.per_start` gains two fields (`realized_edge_pct`,
`forward_index_max_dd_pct`) and `Rolling_start_types.report` gains two
dispersion summaries (`realized_edge`, `forward_index_max_dd`). Pure additions;
existing columns/ordering preserved as a strict superset. `Rolling_start_runner`
gains `bench_max_dd_pct` and a `?benchmark_max_dd_pct` param on
`per_start_of_summary`.

Stage 5b (PR (feat/rolling-start-lens-5b)) adds two new modules — `Rolling_start_factors`
(the pure factor projections) and `Rolling_start_factor_reader` (the thin
snapshot-warehouse I/O that feeds them; split out so the runner stays under the
file-length limit) — and a `factors : Rolling_start_factors.factors` field on
`per_start` (default `Rolling_start_factors.empty` via the new `?factors` param
on `per_start_of_summary`). Four detail-table columns appended (SPY stage /
Macro composite / Stage-2 count / Sector-RS dispersion) — strict superset, no
churn for non-readers.

### Completed

- [x] **Realized-edge + forward-index-DD lens columns** (PR #1586). Adds the
      design's *primary* outcome (`realized_edge_pct` = annualised
      MTM-stripped realized return − benchmark CAGR, the honest counterpart to
      the contaminated MTM `edge_pct`) and the H1 "dodge-a-correction" factor
      (`forward_index_max_dd_pct` = benchmark worst peak-to-trough over the
      window, negative-percent sign convention). Both are pure projections of
      data the runner already owns (`Summary.t` realized return + the
      once-resolved benchmark close series). Superset additions to the sexp +
      markdown report. Backtest goldens bit-equal (no golden consumes the
      `rolling_start_types` sexp — verified by grep over `trading/test_data/`).
      Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/rolling_start/test/`.
      Files: `trading/trading/backtest/rolling_start/lib/rolling_start_{types,runner}.{ml,mli}`,
      `trading/trading/backtest/rolling_start/test/test_rolling_start_{types,runner}.ml`.

- [x] **Screener-based factor columns (stage 5b)** (PR (feat/rolling-start-lens-5b)). New pure module
      `Rolling_start_factors` + four per-start factor columns, all read from the
      *precomputed* snapshot-warehouse fields (cheap point reads, no classifier
      re-run): (1) **SPY/macro stage at start** — decodes the benchmark index's
      `Stage` cell as-of `start_date` (1/2/3/4); (2) **Macro_composite at start**
      — the benchmark's `Macro_composite` cell verbatim; (3) **Stage-2 candidate
      count** — counts universe symbols whose `Stage` cell decodes to 2 as-of
      `start_date`; (4) **sector-RS dispersion** — IQR of per-sector mean
      `RS_line` across the universe as-of `start_date`. Factors are resolved once
      in the parent over a single shared `Daily_panels` handle, then threaded into
      each forked start's row. Unavailable factors emit `None`/`nan` (the report
      renders blank) — universe-scan factors are blank for a `Full_sector_map`
      universe (sectors.csv fallback not resolved here — documented gap) and for
      CSV mode (no panels handle). The pure projections (stage decode, Stage-2
      count, sector-RS IQR) are pinned by `test_rolling_start_factors.ml`
      (known input → expected value); the superset render is pinned by
      `test_rolling_start_types.ml`.
      Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/rolling_start/`.
      Files: `trading/trading/backtest/rolling_start/lib/rolling_start_{factors,factor_reader}.{ml,mli}`,
      `.../rolling_start/lib/rolling_start_{types,runner}.{ml,mli}`,
      `.../rolling_start/test/test_rolling_start_factors.ml`,
      `.../rolling_start/test/{test_rolling_start_types.ml,dune}`.

### In-progress

- (none — PR (feat/rolling-start-lens-5b) awaiting QC)

### Next steps (data-gated / local-session — NOT GHA)

These need the top-3000 PIT snapshot warehouse + screener, so they are
maintainer-local, not GHA-dispatchable. Tag `[blocking: by warehouse build]`
when a downstream decision starts to depend on them.

- [ ] **31-start causal analysis** — per-factor Spearman vs realized-edge +
      tercile contingency, 3-4 traced starts (one clean beat, one melt-up miss,
      one bear-start), confirm/refute H1/H2/H3, and the resulting deployment
      rule. Persist as a `project_*` memory + experiment writeup
      (`dev/experiments/...`). Needs the top-3000 PIT warehouse.

### Commits

- Plan: `dev/plans/rolling-start-realized-edge-lens-2026-06-14.md`
- PR #1586 `feat/rolling-start-realized-edge-lens`
- PR (feat/rolling-start-lens-5b) `feat/rolling-start-lens-5b` (screener-based factor columns)
