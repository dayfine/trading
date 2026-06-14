# Status: rolling-start-lens

## Last updated: 2026-06-14

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

### In-progress

- (none — PR #1586 awaiting QC)

### Next steps (data-gated / local-session — NOT GHA)

These need the top-3000 PIT snapshot warehouse + screener, so they are
maintainer-local, not GHA-dispatchable. Tag `[blocking: by warehouse build]`
when a downstream decision starts to depend on them.

- [ ] **Macro-stage-at-start column** — stage classifier on GSPC at each
      `start_date` (1/2/3/4) + `Macro_composite` continuous value (already in the
      snapshot warehouse per date).
- [ ] **Stage-2-candidate-count-at-start column** — screener candidate count on
      `start_date` (the H3 fresh-supply factor).
- [ ] **Sector-RS-dispersion-at-start column** — spread of sector relative
      strength on `start_date`.
- [ ] **31-start causal analysis** — per-factor Spearman vs realized-edge +
      tercile contingency, 3-4 traced starts (one clean beat, one melt-up miss,
      one bear-start), confirm/refute H1/H2/H3, and the resulting deployment
      rule. Persist as a `project_*` memory + experiment writeup
      (`dev/experiments/...`). Needs the top-3000 PIT warehouse.

### Commits

- Plan: `dev/plans/rolling-start-realized-edge-lens-2026-06-14.md`
- PR #1586 `feat/rolling-start-realized-edge-lens`
