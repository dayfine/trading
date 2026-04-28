# Status: trade-audit

## Last updated: 2026-04-28

## Status
IN_PROGRESS

PR-1 merged (#638) — types + collector + persistence. PR-2 in flight on
`feat/trade-audit-pr2-capture` — capture sites at entry / exit decision
sites, plus parity + smoke tests.

## Goal

Capture the strategy's per-trade decision trail (macro / stage / RS /
cascade / alternatives) and per-trade exit context (state at exit,
trigger, MAE/MFE during hold), and emit a markdown audit report that
rates trades on R-multiple + decision-quality. Built so we can answer
*why* a trade fired and *what alternative existed at decision-time*,
not just *what happened*.

Motivated by the `goldens-sp500/sp500-2019-2023` baseline showing the
strategy under-performs buy-and-hold by a wide margin (+18.49% vs
~+95%), 28.57% win rate, 47.64% max drawdown, Sharpe 0.26 — see
`dev/notes/sp500-golden-baseline-2026-04-26.md`.

## Plan

`dev/plans/trade-audit-2026-04-28.md` — full design: data model,
capture-strategy choice (Option A — in-strategy observer, sibling
sexp file), 4–5 PR phasing, ~1,800 LOC total.

## Interface stable
NO

## Open work

PR-2 (capture sites) in flight on
`feat/trade-audit-pr2-capture`. After it merges, PR-3 (markdown
renderer + binary) can begin.

## Phasing (per plan)

- [x] **PR-1**: `Trade_audit` module — types + collector + persistence
      (`trade_audit.sexp` alongside `trades.csv`). Merged as #638.
      Verify: `dune exec backtest/test/test_trade_audit.exe`.
- [x] **PR-2**: Capture sites in `Weinstein_strategy._run_screen` /
      `_screen_universe` / `entries_from_candidates` + exit capture
      in `_on_market_close`. Threaded via a strategy-side
      `Audit_recorder` callback bundle (no Backtest dep on
      Weinstein_strategy and vice versa); backtest-side
      `Trade_audit_recorder.of_collector` translates events into the
      `Trade_audit` records. Bit-equivalence pinned by the existing
      panel-loader golden parity test. End-to-end smoke at
      `trading/backtest/test/test_trade_audit_capture.ml` (5 tests):
      audit non-empty after a run with round-trips, every entry block
      well-formed, round-trip symbols match audit entries, ≥1 exit_
      block populated, position_ids unique. Verify:
      `TRADING_DATA_DIR=$PWD/test_data dune exec backtest/test/test_trade_audit_capture.exe`.
- [ ] **PR-3**: `trade_audit.exe` + markdown renderer. Per-trade table
      + outlier callouts + aggregate breakdowns. ~400 LOC.
- [ ] **PR-4**: `Trade_rating` heuristics (R-multiple,
      decision-quality cells, hold-time anomaly, counterfactual
      looser stop, alternative coverage) + insight aggregator. ~450
      LOC.
- [ ] **PR-5** (optional): wire into `release_perf_report`. ~100 LOC.

## Ownership

`feat-backtest` agent — sibling of backtest-infra and backtest-perf.
Consumes `Stop_log` (predecessor pattern), `Trace` (predecessor
pattern), and `Weinstein_strategy` capture surfaces but does not
modify strategy logic itself (audit is observer-only).

## Branch

`docs/trade-audit-plan` for the plan. Implementation branches per
phase: `feat/trade-audit-pr1`, `feat/trade-audit-pr2`, etc.

## Blocked on

Nothing structurally; implementation can begin immediately.

## Decision items (need human or QC sign-off)

1. Capture-strategy choice: plan picks Option A (in-strategy observer,
   sibling sexp file). Alternatives B (simulator event bus) and C
   (post-hoc replay) rejected; rationale in §Approach of the plan.
2. `alternatives_considered` retention: only at screen calls where ≥1
   entry actually fires (avoids ~5K wasted captures over a 5y
   backtest). Cheap to revisit if needed.
3. `counterfactual_looser_stop`: persist forward-N bars at exit time
   (Option A in §Risks item 5) vs renderer reads from data dir
   (Option B). Plan picks A — keeps the renderer's input set bounded
   to `<output_dir>/`. PR-4 implements.

## References

- Plan: `dev/plans/trade-audit-2026-04-28.md`
- Baseline: `dev/notes/sp500-golden-baseline-2026-04-26.md`
- Predecessor patterns:
  - `trading/trading/backtest/lib/stop_log.{ml,mli}` — observer shape
  - `trading/trading/backtest/lib/trace.{ml,mli}` — collector shape
- Capture surfaces:
  - `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`
    — `_run_screen` (line 393), `_screen_universe` (line 344),
    `entries_from_candidates` (line 202)
  - `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Sibling tracks:
  - `dev/status/backtest-infra.md` — strategy-tuning experiments that
    will *react* to audit findings (regime-aware stops, drawdown
    circuit breaker, segmentation classifier)
  - `dev/status/backtest-perf.md` — release report renderer that may
    consume `trade_audit.md` per PR-5
