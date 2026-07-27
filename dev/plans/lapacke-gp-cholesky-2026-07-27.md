# Plan — root-cause and fix the LAPACKE GP-Cholesky failure

Date: 2026-07-27
Track: backtest-infra / tuner
Branch: `fix/lapacke-gp-cholesky`
Backlog item: `dev/status/cleanup.md` §Backlog `flake_root_cause`

## Context

`Tuner.Bayesian_opt:11` (`suggest_next GP phase respects bounds`) and
`Tuner.Bayesian_opt:17` (`BO converges on 2D Branin`) fail with
`Failure("LAPACKE: 9")` on *some* CI runner hosts and pass on others. The
failure bounced across four orchestrator runs without diagnosis because it did
not reproduce on the hosts where anyone looked. It reproduces deterministically
(3/3) on this runner, an `Intel(R) Xeon(R) 6973P-C` (AVX-512 / AMX class part).

Two hypotheses were eliminated by source reading in run 4 and remain eliminated:

- **Partial-overwrite on retry** — FALSE. `Owl.Linalg.D.chol`
  (`owl_linalg_generic.ml:288`) copies before `potrf`, so every nugget retry
  sees a clean matrix.
- **Jitter cap collapsing to ~0** — FALSE. `_signal_variance = 1.0`
  (`bayesian_opt.ml:219`) makes the cap `1e-2` absolute.

The two surviving hypotheses were (a) non-finite kernel entries, and (b) a
genuine BLAS/LAPACK kernel defect on this CPU generation.

## Diagnosis (completed before this plan was written)

Instrumented `Bayesian_opt_cholesky.chol_with_nugget_escalation` to dump the
kernel matrix at the moment the retry budget is exhausted, and ran a standalone
LAPACK/BLAS probe against the same Owl/OpenBLAS build.

Observed at the failure point (test 11, `n = 33`):

```
nonfinite = 0        maxabs = 1.0111119999999998        asymmetry = 0
diag[i]   = 1.0111119999999998  for every i   (jitter fully applied)
pure-OCaml unblocked Cholesky (same recurrence as LAPACK dpotf2): SUCCESS
  min pivot = 0.011810966838653458, max pivot = 1.0111119999999998
```

**Hypothesis (a) is eliminated**: zero non-finite entries, exact symmetry, and
the matrix is comfortably numerically positive-definite — a textbook OCaml
Cholesky factors it with a healthy minimum pivot of ~1.2e-2.

**Hypothesis (b) is confirmed, and is broader than the Cholesky.** The probe
shows, on this host:

| probe | result |
|---|---|
| `chol ~upper:false (4·I)` | fails for **every** `33 ≤ n ≤ 63`; info code is exactly `n/4 + 1` (verified for all n in the band) |
| `chol ~upper:true` on well-conditioned SPD | returns `info = 0` but a **silently wrong factor**: `‖LLᵀ − A‖∞ / ‖A‖∞ ≈ 5–7 %` for `n ≥ 33`, 98 % at `n = 120` |
| `chol` at `n ≤ 32` | correct to 1.5e-16 in both `uplo` modes |
| `Mat.dot` (dgemm) | correct to 3e-15 for `n ≤ 64`; **wrong by 19.5 absolute** at `n = 120`, 29.3 at `n = 200` |
| `Linalg.inv` at `n = 120` | aborts the process with `double free or corruption (!prev)` — heap corruption |
| `Linalg.triangular_solve` (dtrtrs) | correct to 6e-16 for all tested `n` up to 120 |
| `Mat.dot` at the shapes `fit_gp` actually uses — `(1×n)·(n×1)` inner products and `(n×n)·(n×1)` matrix–vector | correct to ≤2.7e-15 at every `n` tested (8, 32, 33, 64, 100, 120, 200, 400). The `n = 120` breakage above is the **square** `(n×n)·(n×n)` kernel only. |
| `OPENBLAS_NUM_THREADS=1` | does not fix it; only moves the band (`n ≥ 64` now fails too) — so it is not a thread race |

The mechanism: `OPENBLAS_VERBOSE=2` reports `Core: Cooperlake`. OpenBLAS
mis-detects this CPU and dispatches its Cooperlake (AVX-512-BF16) kernels,
which are wrong on this part. Forcing **any** other core type repairs every
probe:

```
OPENBLAS_CORETYPE=<auto>      gemm n=120 maxdiff = 19.5      inv → heap corruption
OPENBLAS_CORETYPE=Haswell     gemm n=120 maxdiff = 8.88e-15  inv ‖AA⁻¹−I‖ = 1.33e-15
OPENBLAS_CORETYPE=SkylakeX    gemm n=120 maxdiff = 5.88e-15  inv ‖AA⁻¹−I‖ = 1.33e-15
OPENBLAS_CORETYPE=Zen         gemm n=120 maxdiff = 8.88e-15
OPENBLAS_CORETYPE=Nehalem     gemm n=120 maxdiff = 7.11e-15
```

Library: `/lib/x86_64-linux-gnu/libopenblas.so.0` (distro package, vendored via
the opam `owl` 1.2 → `lapacke` chain). The defect is in that binary, not in
this repository.

### Why this matters more than the red test

The `~upper:true` path returns `info = 0` with a factor that is 5–7 % wrong.
Had the fix been "switch to the upper factorisation", the two tests would have
gone green while `fit_gp` silently produced garbage GP posteriors on this
host — strictly worse than the current loud failure. Any design that keeps
calling `dpotrf` must *verify* its output, and verification costs an O(n³)
`gemm` which is itself unreliable at `n ≥ 120` on this host.

## Approach

**Replace the LAPACK `dpotrf` call in the GP path with a pure-OCaml Cholesky**
inside `bayesian_opt_cholesky.ml`, keeping the module's public signature and
its nugget-escalation semantics unchanged.

Justification:

- The only broken primitive in `fit_gp` is `dpotrf`. Its other LAPACK/BLAS
  calls were probed **at the shapes it actually issues** — `triangular_solve`
  (`bayesian_opt.ml:124-125`), the `(1×n)·(n×1)` inner products
  (`Mat.dot (transpose k_star) alpha`, `Mat.dot (transpose v) v`), and the
  `(n×n)·(n×1)` matrix–vector products — and all are correct to ≤6e-16 at every
  `n` up to 200+. The square-`gemm` breakage at `n ≥ 120` is a different kernel
  path that `fit_gp` never takes. So nothing else needs to move.
- `n` is the number of BO observations, bounded by `total_budget` (largest
  value in any committed spec: 100, `trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp`).
  An O(n³/3) OCaml factorisation at n = 100 is ~3.3e5 flops (sub-millisecond),
  and is dwarfed by the 1000 posterior evaluations per `suggest_next`
  (O(1000·n²) ≈ 1e7). The Cholesky is not, and will not become, the bottleneck.
- It is host-independent and deterministic — the flake cannot return on a
  future runner generation.
- The unblocked recurrence detects genuine non-positive-definiteness exactly
  (at the first non-positive pivot), which is a *better* signal than
  `LAPACKE: 9`: we can report the failing pivot index and value.

### Alternatives rejected

- **Switch to `chol ~upper:true` and transpose.** Mathematically identical and
  it makes the tests green — but proven to return a silently wrong factor for
  `n ≥ 33` on this host. Rejected: trades a loud failure for a silent one.
- **Verify-and-fall-back (call LAPACK, check `‖LLᵀ − K‖`, retry in OCaml).**
  Correct but costs an extra O(n³) `gemm` — itself unreliable at n ≥ 120 here —
  for no speed benefit at the n we actually run.
- **Widen the jitter.** Explicitly not the problem: the matrix at failure has a
  minimum pivot of 1.2e-2 and factors fine. Adding jitter would only perturb a
  healthy kernel.
- **Set `OPENBLAS_CORETYPE` in CI / the devcontainer.** This *does* fix every
  probe and is worth doing, but it is an environment change owned by
  `harness-maintainer` (workflows + `.devcontainer/`), it silently depends on an
  env var being present at every invocation, and it does not make the library
  correct for anyone running a built binary directly. Recorded as a follow-up,
  not done here.

## Files to change

| File | Change |
|---|---|
| `trading/trading/backtest/tuner/lib/bayesian_opt_cholesky.ml` | Replace the `Linalg.chol` call with a pure-OCaml lower Cholesky; add a non-finite input guard; raise a legible error naming the failing pivot when escalation is exhausted. Keep the public function signature and the jitter schedule. |
| `trading/trading/backtest/tuner/lib/bayesian_opt_cholesky.mli` | Rewrite the doc comment: describe the OCaml factorisation, the non-finite guard, the two exception cases, and record why LAPACK is not used here. No signature change. |
| `trading/trading/backtest/tuner/test/test_bayesian_opt_cholesky.ml` | New. Direct unit tests of `chol_with_nugget_escalation`: reconstruction `L Lᵀ ≈ K` across the LAPACK-broken band, lower-triangularity, genuine non-PD detection, non-finite guard, near-duplicate rows. |
| `trading/trading/backtest/tuner/test/test_bayesian_opt.ml` | Add an end-to-end regression: `fit_gp` succeeds and interpolates for observation counts inside the broken band (n = 33, n = 40). |
| `trading/trading/backtest/tuner/test/dune` | Register the new test executable. |
| `dev/status/cleanup.md` | Tick `flake_root_cause`, record the root cause. |
| `dev/status/backtest-infra.md` | Completed entry + the OpenBLAS follow-up. |

No changes to `bayesian_opt.ml` (its call site is unchanged), and none to
strategy or stop-machine code.

## Risks / unknowns

- **Performance.** Quantified above as negligible at the `n` we run. If a
  future spec pushes `total_budget` past ~1000, the O(n³) OCaml factorisation
  would start to cost ~0.3 s per `suggest_next`; noted in the `.mli` so it is
  not a surprise.
- **Behaviour change on healthy hosts.** The factorisation is no longer
  bit-identical to LAPACK's on hosts where LAPACK works — a different summation
  order gives differences at the 1e-16 level, which can in principle change a
  BO `argmax` tie-break. BO runs are already only reproducible per-seed within a
  build; no committed golden pins GP posterior values. Accepted.
- **The broader OpenBLAS defect is not fixed.** Square `Mat.dot` at n ≥ 120 and
  `Linalg.inv` remain wrong/unsafe on this host class.

  The in-repo exposure is **small and was mis-stated in an earlier draft of this
  plan**. Grepped call sites, not just module aliases:

  - `trading/trading/backtest/tuner/lib/bayesian_opt.ml` — the only genuinely
    live exposure. After this PR its remaining LAPACK/BLAS calls are
    `Linalg.triangular_solve` (`:124-125`) and the `Mat.dot` inner products in
    `fit_gp`; all were probed at their real shapes and are correct here (table
    above). Live, but measured clean.
  - `trading/analysis/technical/trend/lib/segmentation.ml` — declares
    `module Linalg = Owl.Linalg.S` and **never calls it**. Zero
    `Linalg.` / `Mat.` / `Arr.` call sites beyond the alias. A dead alias.
  - `trading/analysis/technical/trend/lib/visualization.ml` — same dead
    `Linalg` alias; its only Owl use is `Mat.of_array _ 1 n` row vectors
    (`:51-53, 61-62, 67-68`) feeding `Owl_plplot`. No factorisation, no `inv`,
    no product at n ≥ 33.

  So the follow-up is about *future* exposure and about CI trustworthiness, not
  about a currently-broken in-repo call site. Flagged with the
  `OPENBLAS_CORETYPE` mitigation.

## Acceptance criteria

- `dev/lib/run-in-env.sh dune runtest trading/backtest/tuner/` exits **0** on
  this host (where it currently exits 1).
- `dev/lib/run-in-env.sh dune build` exits 0; `dune build @fmt` clean.
- Neither failing test is weakened, skipped, or marked expected-failure — both
  keep their original assertions.
- New tests fail against the pre-fix implementation on this host (they exercise
  the 33–63 band) and pass after.
- Every public function exported in the `.mli` with a doc comment; no function
  over 50 lines; no magic numbers outside named constants.
- All temporary instrumentation removed.

## Out of scope

- Changing CI workflows, `.devcontainer/`, or any environment variable
  (`harness-maintainer` owns those).
- Fixing or replacing the vendored OpenBLAS.
- Removing the dead `Owl.Linalg.S` aliases in `analysis/technical/trend/`
  (they are unused, so they are a tidiness item, not a correctness one).
- Any change to `weinstein_strategy.ml` or stop-machine code.
- Any change to `dev/status/_index.md` (orchestrator reconciles it).
