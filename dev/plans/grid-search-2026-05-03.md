# T-A grid_search — clarifying plan

Date: 2026-05-03 — clarifies the binding M5.5 T-A spec in
`dev/plans/m5-experiments-roadmap-2026-05-02.md` for this PR's scope only.
The roadmap plan remains the authority; this file documents the design
decisions taken inside that scope.

## Scope

T-A library + tests only. CLI binary is deferred to a follow-up to keep the
PR ≤500 LOC; the lib's interface is shaped so the binary becomes a thin
wrapper.

## Design decisions inside T-A

### D1 — Evaluator is a callback, not a hard-wired runner call

The roadmap names `Backtest.Runner.run_backtest` as the cell-evaluation
target. Hard-wiring it has two costs:

- Tests would have to spin up a real backtest (slow, fragile, requires
  scenario fixtures, panel data, etc.) just to verify Cartesian-product
  enumeration and argmax correctness.
- The lib would inherit the runner's giant transitive dependency closure,
  making `tuner` impossible to consume from a smaller context.

Resolved: the lib exposes `type evaluator = cell -> scenario:string ->
metric_set` and accepts it as a `~evaluator` argument to `run`. The CLI
binary (follow-up) wires it to `Backtest.Runner.run_backtest`; tests
substitute pure stubs (constant, sum-of-cell-values, table-keyed).

### D2 — Argmax averages across scenarios

The roadmap doesn't specify how to aggregate per-cell scores when there
are multiple scenarios. Options:

- max-of-max (cell wins if it beats every scenario's best score)
- min-of-max (cell wins if its WORST scenario score is the highest of all
  cells' worst — robust optimisation)
- mean (symmetric average across scenarios)

Resolved: mean. Symmetric, simplest, matches Sharpe's "average across
samples" semantics. The roadmap's authority is silent on this; we'll
revisit if T-A's flagship sweep produces a "good on average, terrible on
crash scenario" config.

### D3 — Tie-break by enumeration order

Two cells with identical scores: pick the first cell in lex order. Pinned
in `test_run_tie_break_picks_first_cell`. Determinism guarantee is the
goal — stable results across re-runs.

### D4 — Empty `param_spec` is a single empty cell, NOT zero cells

A spec with no params yields `[[]]` — the cartesian product of zero sets
is the singleton set containing the empty tuple. This means
`run [] ~scenarios:["s"] ~objective:Sharpe ~evaluator` evaluates the
default config once on each scenario. Useful for sanity checks and
default-runs. Pinned in `test_cartesian_empty_spec_yields_one_empty_cell`.

A spec where ANY param has an empty values list yields zero cells (the
product is empty). Pinned in `test_cartesian_with_empty_values_yields_zero_cells`.

### D5 — `Composite` weights are raw, not normalised

For `Composite [(Sharpe, 1.0); (Calmar, 0.5)]`, the score is
`1.0 × Sharpe + 0.5 × Calmar` — no min-max normalisation. Callers can
normalise their inputs (or use the underlying metric_type definitions —
Sharpe and Calmar are both dimensionless ratios already comparable).
Documented in the `objective` doc comment.

Negative weights work as expected: `Composite [(MaxDrawdown, -1.0)]`
prefers shallower drawdowns.

## Files

| Path | Lines | Status |
|---|---|---|
| `trading/trading/backtest/tuner/lib/dune` | 5 | new |
| `trading/trading/backtest/tuner/lib/grid_search.mli` | 190 | new |
| `trading/trading/backtest/tuner/lib/grid_search.ml` | 252 | new |
| `trading/trading/backtest/tuner/test/dune` | 12 | new |
| `trading/trading/backtest/tuner/test/test_grid_search.ml` | 406 | new |
| `dev/status/tuning.md` | (small edit) | flip Status + Interface stable; add Completed |
| `dev/plans/grid-search-2026-05-03.md` | this file | new |

Total: ~442 LOC of lib code (mli + ml), ~406 LOC of tests. The lib is
within the roadmap's ~400 LOC target; tests don't count toward the
PR-sizing budget per `feat-agent-template.md`. Net non-test diff is
under the 500-LOC PR cap.

## Acceptance gates

- [x] Cartesian product correctness pinned (3×3×3=27, 3×3×3×3=81, lex order).
- [x] Argmax correctness pinned (sum-evaluator picks max-sum cell).
- [x] Composite objective weighted-sum pinned.
- [x] Sensitivity table holds-others-at-best pinned.
- [x] CSV writer schema pinned (header + N+1 lines for N rows).
- [x] best.sexp + sensitivity.md emit pinned.
- [x] Determinism pinned (two identical runs match).
- [x] Edge cases pinned (empty spec, empty values, empty scenarios → raise).
- [ ] **Deferred** — 81-cell wall-time gate (<2hr on smoke scenarios) requires
  a real evaluator + smoke scenarios; not feasible in a unit-test PR.
  Verify locally once the CLI binary lands.
