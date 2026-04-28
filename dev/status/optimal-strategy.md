# Status: optimal-strategy

## Last updated: 2026-04-28

## Status
IN_PROGRESS

PR-1 (data model + `Stage_transition_scanner`) implemented and opened
as draft PR #652 on branch `feat/optimal-strategy-pr1`. PR-2
(`Outcome_scorer`) is the next slice.

## Goal

Quantify the gap between the strategy's actual performance and the
*theoretical optimum reachable under the same structural constraints*
(universe, sizing, stops). Replays each backtest with perfect-hindsight
candidate selection (still gated by Stage-1→2 breakout + Weinstein stop
discipline) and emits a counterfactual report showing actual vs ideal
P&L per scenario, surfacing per-Friday opportunity cost.

Sister track to `trade-audit`: the audit answers *why* a trade was
chosen and *what alternatives existed*; the counterfactual answers
*what was the best achievable across all alternatives* given the same
constraints.

Motivated by the same `goldens-sp500/sp500-2019-2023` baseline gap that
motivates trade-audit (+18.49% strategy vs ~+95% SPY); audit + counterfactual
together diagnose whether the gap is cascade-ranking error
(closeable) vs structural strategy limitation (requires deeper changes).

## Plan

`dev/plans/optimal-strategy-counterfactual-2026-04-28.md` — full design:
goal definition (constrained vs relaxed-macro variants), 4-phase
algorithm (scanner → outcome scorer → greedy filler → report renderer),
4–5 PR phasing, ~1,600 LOC total.

## Interface stable
NO

## Open work

**PR-2 — `Outcome_scorer`** is next. Per plan §Phase B + §PR-2:

- `trading/trading/backtest/optimal/lib/outcome_scorer.{ml,mli}` —
  pure scorer. Input: `candidate_entry + Bar_panel.t`. Output:
  `scored_candidate`. Implements the counterfactual exit rule
  (`Stage3_transition` / `Stop_hit` / `End_of_run`, whichever first).
  Reuses `Weinstein_stops.compute_initial_stop_with_floor` for the
  initial stop and the existing trailing-stop walker for subsequent
  weeks.
- `trading/trading/backtest/optimal/test/test_outcome_scorer.ml` —
  three exit-trigger fixtures + an R-multiple computation pin test.

LOC estimate: 300.

The `scored_candidate` schema already lives in `Optimal_types` (PR-1),
so PR-2 is type-stable and can land independently.

## Phasing (per plan)

- [x] **PR-1**: `Optimal_types` data model + `Stage_transition_scanner`
      — PR #652 (draft), branch `feat/optimal-strategy-pr1`.
      Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`.
- [ ] **PR-2**: `Outcome_scorer` — realized-outcome scorer per candidate
      (Stage3-transition vs stop-hit forward walk). ~300 LOC.
- [ ] **PR-3**: `Optimal_portfolio_filler` — greedy sizing-constrained
      fill + `Optimal_summary` aggregator. ~400 LOC.
- [ ] **PR-4**: `Optimal_strategy_report` markdown renderer +
      `optimal_strategy.exe` binary. ~400 LOC.
- [ ] **PR-5** (optional): wire into `release_perf_report` so each
      scenario emits the counterfactual delta. ~200 LOC.

## Ownership

`feat-backtest` agent — sibling of backtest-infra, backtest-perf,
trade-audit. Consumes existing screener cascade
(`Stock_analysis.is_breakout_candidate`, `Screener.scored_candidate`),
stop machinery (`Weinstein_stops`), and panel infrastructure
(`Bar_panel`). Does not modify strategy logic — counterfactual is a
pure-functional analysis layer over backtest outputs.

## Branch

Implementation branches per phase:

- `feat/optimal-strategy-pr1` — PR #652 (draft, READY_FOR_REVIEW pending QC).
- `feat/optimal-strategy-pr2` (next).

Plan branch: `docs/optimal-strategy-counterfactual-plan` (merged via
PR #650, 2026-04-28).

## Blocked on

PR-2 may need a **pure-functional walker for `Weinstein_stops`** (plan
§Risks item 4 — may require a small refactor of stops to expose a
non-stateful API; that decision belongs to `feat-weinstein` if invoked).
PR-1 does not touch stops, so PR-1 is unblocked.

## Authority docs

- User quote (2026-04-28) captured in plan §Context
- Sister plan: `dev/plans/trade-audit-2026-04-28.md`
- Perf framework: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Stage classifier: `trading/analysis/weinstein/stage/lib/stage.{ml,mli}`
- Screener cascade: `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Stops: `trading/trading/weinstein/portfolio_risk/`
- Book ref: `docs/design/weinstein-book-reference.md`

## Completed

- **PR-1** (2026-04-28): `Optimal_types` data model +
  `Stage_transition_scanner`.
  - Files added:
    - `trading/trading/backtest/optimal/lib/dune`
    - `trading/trading/backtest/optimal/lib/optimal_types.{ml,mli}`
    - `trading/trading/backtest/optimal/lib/stage_transition_scanner.{ml,mli}`
    - `trading/trading/backtest/optimal/test/dune`
    - `trading/trading/backtest/optimal/test/test_stage_transition_scanner.ml`
  - Coverage: 13 OUnit2 cases — sexp round-trip on each record type;
    scanner emits one per breakout in arrival order; non-breakouts
    dropped; `passes_macro` tagging across Bullish/Neutral/Bearish;
    missing-sector fallback to "Unknown"; entry/stop/risk match screener
    formulas; multi-week scan_panel concatenation; empty-input edge
    cases.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr1` / PR #652.
