# Status: trade-audit

## Last updated: 2026-04-28

## Status
PLANNED

Plan landed; implementation pending.

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

None yet — implementation begins on next dispatch.

## Phasing (per plan)

- [ ] **PR-1**: `Trade_audit` module — types + collector + persistence
      (`trade_audit.sexp` alongside `trades.csv`). ~350 LOC.
- [ ] **PR-2**: Capture sites in `Weinstein_strategy._run_screen` /
      `_screen_universe` / `entries_from_candidates` + exit capture
      via `Stop_log` extension. Includes audit-on vs audit-off parity
      test. ~500 LOC; may split into PR-2a (entry) + PR-2b
      (exit/alternatives).
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
