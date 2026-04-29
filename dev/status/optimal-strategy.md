# Status: optimal-strategy

## Last updated: 2026-04-28 (post run-2)

## Status
IN_PROGRESS

PR-1 (#652), PR-2 (#659), and PR-3 (#663) all merged into `main`. PR-4
(`Optimal_strategy_report` renderer + smoke tests) is open as a partial
landing on branch `feat/optimal-strategy-pr4`. The renderer + smoke tests
ship in this PR; the binary (`optimal_strategy.exe`) and the deeper
fixture tests are deferred — see
`dev/notes/optimal-strategy-pr4-followups-2026-04-28.md` for the
follow-up surface (PR-4b for the bin, ~150–200 LOC; optional follow-up
B for fuller renderer fixture tests).

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

**PR-4 — `Optimal_strategy_report` + binary** — partial landing in
flight. Per plan §Phase D + §PR-4:

- `trading/trading/backtest/optimal/lib/optimal_strategy_report.{ml,mli}`
  — pure markdown renderer. Inputs: actual round-trips + summary +
  optimal round-trips + summary (constrained + relaxed). Output:
  markdown string with headline comparison table, per-Friday divergence
  table, "trades the actual missed", "trades the actual took",
  implications block. Disclaimer in header.
- `trading/trading/backtest/optimal/bin/optimal_strategy.ml` — thin
  binary: reads `output_dir/`'s artefacts (`trades.csv`,
  `summary.sexp`, panel), invokes
  `Stage_transition_scanner` →
  `Outcome_scorer` →
  `Optimal_portfolio_filler` (×2 variants) →
  `Optimal_summary` (×2) →
  `Optimal_strategy_report.render`. Writes
  `<output_dir>/optimal_strategy.md`.
- `trading/trading/backtest/optimal/bin/dune` — register exe.
- `trading/trading/backtest/optimal/test/test_optimal_strategy_report.ml`
  — fixture with seeded actual + counterfactual round-trips; assert
  rendered markdown contains expected divergence rows, outlier callouts,
  and the right implications-block narrative for the seeded ratio.

LOC estimate: 400.

The filler + summary types from PR-3 are already stable, so PR-4 is
ready to start once PR-3 lands.

## Phasing (per plan)

- [x] **PR-1**: `Optimal_types` data model + `Stage_transition_scanner`
      — PR #652 (merged), branch `feat/optimal-strategy-pr1`.
      Verify: `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`.
- [x] **PR-2**: `Outcome_scorer` — realized-outcome scorer per candidate
      (Stage3-transition vs stop-hit forward walk) — PR #659 (merged),
      branch `feat/optimal-strategy-pr2`. ~300 LOC.
- [x] **PR-3**: `Optimal_portfolio_filler` — greedy sizing-constrained
      fill + `Optimal_summary` aggregator — branch
      `feat/optimal-strategy-pr3`. ~1,073 LOC including tests
      (interface ~145, implementation ~315, tests ~575). 15 OUnit2
      cases (10 filler + 5 summary), all passing.
- [~] **PR-4**: `Optimal_strategy_report` markdown renderer + smoke
      tests landing on `feat/optimal-strategy-pr4`. Renderer ~538 LOC
      lib (already over the original 400-LOC plan estimate), 8 OUnit2
      smoke tests on the renderer (section presence, headline-3-variants,
      missed-trade-with-rejection-reason, three implications branches,
      determinism, trailing newline). 45/45 pass across the optimal track.
      The binary + deeper fixture tests are deferred to PR-4b — see
      `dev/notes/optimal-strategy-pr4-followups-2026-04-28.md`.
- [ ] **PR-4b**: `optimal_strategy.exe` binary (panel loading + pipeline
      orchestration), plus fuller per-Friday divergence + missed-trade
      ordering fixture tests. ~250 LOC. Deferred per PR-4 followups note.
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

- `feat/optimal-strategy-pr1` — PR #652 (merged).
- `feat/optimal-strategy-pr2` — PR #659 (merged).
- `feat/optimal-strategy-pr3` — current PR (READY_FOR_REVIEW).
- `feat/optimal-strategy-pr4` (next).

Plan branch: `docs/optimal-strategy-counterfactual-plan` (merged via
PR #650, 2026-04-28).

## Blocked on

None. The pure-functional stop walker (plan §Risks item 4) was resolved
in PR-2 by seeding `Weinstein_stops.update` directly with the
candidate's `suggested_stop`. PR-3 does not touch stops at all — it
consumes scorer output as opaque exit fields.

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
  - Branch / PR: `feat/optimal-strategy-pr1` / PR #652 (merged).

- **PR-2** (2026-04-28): `Outcome_scorer` realised-outcome walker.
  - Files added:
    - `trading/trading/backtest/optimal/lib/outcome_scorer.{ml,mli}`
    - `trading/trading/backtest/optimal/test/test_outcome_scorer.ml`
  - Coverage: 9 OUnit2 cases — one fixture per `exit_trigger` variant
    (`Stage3_transition`, `Stop_hit`, `End_of_run`); R-multiple
    arithmetic pin; empty-forward / immediate stop / invalid-candidate
    edges; Stage-3 streak reset on Stage-2 break; sensitivity at
    `stage3_confirm_weeks = 1`.
  - Verify: same as PR-1.
  - Branch / PR: `feat/optimal-strategy-pr2` / PR #659 (merged).

- **PR-3** (2026-04-28): `Optimal_portfolio_filler` greedy fill +
  `Optimal_summary` aggregator.
  - Files added:
    - `trading/trading/backtest/optimal/lib/optimal_portfolio_filler.{ml,mli}`
    - `trading/trading/backtest/optimal/lib/optimal_summary.{ml,mli}`
    - `trading/trading/backtest/optimal/test/test_optimal_portfolio_filler.ml`
    - `trading/trading/backtest/optimal/test/test_optimal_summary.ml`
  - `trading/trading/backtest/optimal/test/dune` updated to register
    the two new test executables.
  - Coverage:
    - 10 filler cases — empty input, Constrained-variant macro filter,
      Relaxed_macro admits both, R-descending tie ordering, concurrent
      cap forces lower-rank skip, sector cap forces skip, cash
      exhaustion forces skip, skip-already-held, end-of-run close-out,
      cash recycles after exit funds a later entry.
    - 5 summary cases — empty input -> zero summary with
      `profit_factor = +infinity`, seeded 2-winners + 1-loser pin
      (every metric value pinned), drawdown over multiple Fridays,
      same-Friday batching of equity steps, no-losers infinite profit
      factor.
  - Heuristic A only (earliest-Friday + R-descending). Heuristics B
    (knapsack) and C (Monte-Carlo) are PR-5 follow-ups per plan
    §Phase C.
  - Verify:
    - `dev/lib/run-in-env.sh dune build`
    - `dev/lib/run-in-env.sh dune runtest trading/backtest/optimal/`
    - `dev/lib/run-in-env.sh dune build @fmt`
  - Branch / PR: `feat/optimal-strategy-pr3` / PR #TBD.
