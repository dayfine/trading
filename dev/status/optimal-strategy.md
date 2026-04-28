# Status: optimal-strategy

## Last updated: 2026-04-28

## Status
PLANNING

Plan-only PR open against `docs/optimal-strategy-counterfactual-plan`.
No implementation work yet.

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

Plan-only PR awaiting human review. No implementation branch yet.

## Phasing (per plan)

- [ ] **PR-1**: `Optimal_types` data model + `Stage_transition_scanner`
      (enumerate breakout candidates over the panel). ~300 LOC.
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

`docs/optimal-strategy-counterfactual-plan` for the plan.
Implementation branches per phase: `feat/optimal-strategy-pr1`,
`feat/optimal-strategy-pr2`, etc.

## Blocked on

Human plan review before any implementation begins. Possibly: a
pure-functional walker for `Weinstein_stops` (PR-2 §Risks item 4 — may
require a small refactor of stops to expose a non-stateful API; that
decision belongs to `feat-weinstein` if invoked).

## Authority docs

- User quote (2026-04-28) captured in plan §Context
- Sister plan: `dev/plans/trade-audit-2026-04-28.md`
- Perf framework: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Stage classifier: `trading/analysis/weinstein/stage/lib/stage.{ml,mli}`
- Screener cascade: `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Stops: `trading/trading/weinstein/portfolio_risk/`
- Book ref: `docs/design/weinstein-book-reference.md`

## Completed

(none yet — plan-only)
