# Status: Trade Autopsy

## Last updated: 2026-05-29

## Status
MERGED

## Interface stable
NO

`Trade_autopsy_lib.Trade_autopsy.{classify_trades, summarize,
breakdown_for_symbol}` are the public surface, but threshold defaults and
per-mode flag semantics are likely to evolve as the diagnostic informs
strategy fixes. Sexp output schema may also extend (new fields, new modes).
Treat as v0 until at least one downstream consumer (e.g. PR-A Stage-3
hysteresis sweep) lands.

## What it is

`analysis/scripts/trade_autopsy/` — a diagnostic OCaml tool that consumes
the trade list from the per-symbol Weinstein stage strategy (PR #1353,
`analysis/scripts/per_symbol_stage_strategy/`) and classifies each closed
trade against four gain-capture failure modes:

1. `Stage3_false_positive` — exit on Stage 2→3 that resolved back to
   Stage-2 territory (price ≥ +5% within 12 weeks).
2. `Late_reentry` — > 8 weeks between exit and next same-side entry AND
   the symbol ran ≥ +10% during the wait.
3. `Late_stage2_admission` — entry > 8 weeks after the prior cyclical
   low (12-week lookback).
4. `Stop_out_whipsaw` — stop-loss exit that recovered ≥ +5% within 4
   weeks (INERT under the per-symbol stage strategy; reserved for
   future strategies that have stops).

Output: a structured `autopsy.sexp` (per-trade records + per-symbol
breakdown + panel-wide mode summary) and a Markdown report (canonical
form: `dev/notes/trade-autopsy-<date>.md`).

All thresholds are config knobs in
`Trade_autopsy_lib.Trade_autopsy_config.t`; defaults match the dispatch
brief (`dev/notes/next-session-priorities-2026-05-29.md` §P3).

## Files

Library (`trading/analysis/scripts/trade_autopsy/lib/`):
- `trade_autopsy_config.{ml,mli}` — threshold record + defaults.
- `missed_gain.{ml,mli}` — bar lookup + cyclical-low helpers.
- `exit_reason.{ml,mli}` — `Exit_reason.t` + `derive` (rework-1 split).
- `classifiers.{ml,mli}` — the four per-mode classifiers + missed-gain
  computation helpers (rework-1 split).
- `trade_autopsy.{ml,mli}` — public types (`trade_autopsy`,
  `mode_summary`, `per_symbol_breakdown`) and orchestration
  (`classify_trades`, `summarize`, `breakdown_for_symbol`).

Tests (`trading/analysis/scripts/trade_autopsy/lib/test/`, split per
failure-mode category in rework-1):
- `test_helpers.{ml,mli}` — shared synthetic-bar / trade builders.
- `test_missed_gain.ml` — `Missed_gain` unit tests.
- `test_exit_reason.ml` — exit-reason derivation tests.
- `test_failure_modes.ml` — Stage3 / late re-entry / late Stage-2 /
  stop-out whipsaw classifiers.
- `test_aggregation.ml` — `summarize` + `breakdown_for_symbol` numerics.

Runner + report:
- `trading/analysis/scripts/trade_autopsy/bin/autopsy_runner.ml`
- `dev/notes/trade-autopsy-2026-05-29.md` — diagnostic report on the
  197-trade canonical panel.

## Findings (2026-05-29 run)

| Rank | Failure mode | # trades flagged | Total missed gain | Avg / trade |
|---|---|---|---|---|
| 1 | **late_reentry** | 48 | **+1557.83%** | +32.45% |
| 2 | **stage3_false_positive** | 71 | **+1176.23%** | +16.57% |
| 3 | late_stage2_admission | 100 | +505.01% | +5.05% |
| 4 | stop_out_whipsaw | 0 | +0.00% | +0.00% (inert) |

**Mechanism diagnosis:** ranks 1 and 2 share a common cause — false
Stage 2→3 transitions that immediately resolve back to Stage 2. The
strategy exits prematurely, then waits for a fresh Stage 1→2 cycle,
which can take years (concrete SPY examples: 2012-2016 +58.5%,
2022-2025 +56.3%). Recommended fix: Stage 3 hysteresis (require N
consecutive Stage-3 weeks before exit) and/or price-action confirmation
(exit only when price has actually declined below the MA by some
margin). See report §Recommended targeted fix.

## QC

NOT YET REVIEWED. Awaiting:
- `qc-structural` (P6 test-pattern conformance, A1/A2/A3 architecture
  rules — A1 NA since this PR touches only `analysis/` not any core
  module; A2 NA since no new `analysis/`→`trading/trading/` imports).
- `qc-behavioral` (CP1-CP4 — the .mli docstrings + report claims need
  pinning against the test surface; the four S*/L*/C*/T* domain rows
  are NA because this is a diagnostic tool, not a Weinstein domain
  feature itself).

## Verify

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build && dune runtest analysis/scripts/trade_autopsy/'
```

14 OUnit2 cases pass against synthetic bar series — one per
failure-mode positive/negative edge case, two for `Missed_gain`
lookups, one for cyclical-low detection, two for aggregation.

To regenerate the diagnostic report against real bars:

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec analysis/scripts/trade_autopsy/bin/autopsy_runner.exe -- \
     -data-dir /workspaces/trading-1/data \
     -out-sexp /tmp/autopsy.sexp'
```

## Follow-ups (proposed sequence — out of scope for this PR)

1. **PR-A: Stage 3 hysteresis** in per-symbol strategy (`stage3_confirmation_weeks`
   + `stage3_exit_margin_pct` knobs). Expect ranks 1+2 to collapse.
2. **PR-B: Sweep the Stage-3 knobs** for the CAGR-vs-Sharpe optimum.
3. **PR-C: Promote winning Stage-3 hysteresis to production strategy** and
   re-run `promote_config.sh` gate.
4. (Deferred) **PR-D: Late Stage 2 admission fix.** Different mechanic
   (breakout-override admission); defer until after Stage 3 fix lands.
