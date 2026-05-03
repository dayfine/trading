# T-B Bayesian optimization tuner — clarifying plan

Date: 2026-05-03 — clarifies the binding M5.5 T-B spec in
`dev/plans/m5-experiments-roadmap-2026-05-02.md` for this PR's scope only.
The roadmap plan remains the authority; this file documents the design
decisions taken inside that scope.

## Scope

T-B library + tests only. CLI binary is deferred to a follow-up to keep the
PR ≤500 LOC of non-test code; the lib's interface is shaped so the binary
becomes a thin wrapper (mirrors T-A's choice).

## Library decision — `owl` for matrix ops

Investigation:

- `lacaml` — not installed.
- `oml` — not installed.
- `owl` — installed (1.2), already used by `analysis/technical/trend/`.
  Provides:
  - `Owl.Linalg.D.chol` — Cholesky decomposition (symmetric positive
    definite matrices)
  - `Owl.Linalg.D.triangular_solve` — triangular linear solve
  - `Owl.Mat` (= `Owl.Dense.Matrix.D`) — dense float64 matrices

Decision: use `owl` for all matrix math. Hand-rolled would be ~300 extra
LOC of dense linear algebra + numerical-stability gotchas. The `trend`
library precedent (`regression.ml`) shows the canonical pattern — open
`Owl`, use `Linalg.D.*` for solves.

Result: lib stays under 500 LOC; the BO loop is the only thing we
implement.

## Design decisions inside T-B

### D1 — Pure functional state, like T-A

`type t` is opaque; `create`, `observe`, `suggest_next`, `best`, and
`all_observations` are pure functions. `observe` returns a new `t`; the
caller threads state explicitly. No global state, no `Async`, no IO.

### D2 — Two-phase suggestion: initial random, then GP-driven

The first `initial_random` calls to `suggest_next` return random points
sampled uniformly from the per-parameter bounds. After that, `suggest_next`
fits a GP to all observations and returns the argmax of the acquisition
function over N candidate points sampled uniformly from the bounds (default
N = 1000).

### D3 — RBF kernel, fixed hyperparameters

`k(x, x') = σ_f² · exp(-0.5 · Σᵢ((xᵢ − x'ᵢ) / ℓᵢ)²)`. Default `ℓᵢ = 0.25`
in normalised `[0,1]` space. `σ_f² = 1.0`, noise `σ_n² = 1e-6`.

### D4 — Inputs scaled to [0, 1] internally

The GP operates on `[0, 1]^d` internally. The public surface is in raw
parameter space. `y` is centred to mean 0 before fitting; restored on
prediction.

### D5 — Acquisition functions

- `Expected_improvement` — standard EI. Default.
- `Upper_confidence_bound β` — `μ(x) + β · σ(x)`.

### D6 — Bounds enforcement

Every `suggest_next` return is guaranteed within bounds.

### D7 — Determinism

Same RNG state → same sequence of suggestions.

### D8 — `best` returns the highest-metric observation

Tie-break by first observation in eval order (mirrors T-A).

## Files

| Path | Lines | Status |
|---|---|---|
| `trading/trading/backtest/tuner/lib/dune` | (extend +1 lib) | edit (add owl) |
| `trading/trading/backtest/tuner/lib/bayesian_opt.mli` | ~115 | new |
| `trading/trading/backtest/tuner/lib/bayesian_opt.ml` | ~310 | new |
| `trading/trading/backtest/tuner/test/test_bayesian_opt.ml` | ~340 | new |
| `dev/status/tuning.md` | (small edit) | add Completed entry |
| `dev/plans/bayesian-opt-2026-05-03.md` | this file | new |

## Acceptance gates

- [ ] `dune build && dune runtest trading/backtest/tuner/` passes
- [ ] ≥15 tests, all use `assert_that` + matchers
- [ ] LOC <800 (lib + tests)
- [ ] Determinism property tested
- [ ] No Python; no `Async`
- [ ] qc-structural A2/A3 clean

## Out of scope

- CLI binary (deferred; mirrors T-A)
- Hyperparameter learning (deferred; D3)
- Multi-objective Pareto-front BO
- Async / parallel candidate evaluation
