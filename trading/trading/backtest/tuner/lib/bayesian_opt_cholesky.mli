(** Adaptive-nugget Cholesky factorisation for {!Bayesian_opt.fit_gp}.

    The GP kernel matrix can sit on the edge of positive-definiteness when
    observations are duplicated or near-duplicated in the [0, 1]-scaled input
    space — a numerical edge case, not a modeling error. Rather than let
    [fit_gp] crash, {!chol_with_nugget_escalation} retries the factorisation
    with an escalating diagonal jitter ("nugget") until it succeeds or attempts
    are exhausted.

    {2 Why the factorisation is done in OCaml rather than via LAPACK}

    This module deliberately does not call [Owl.Linalg.D.chol] (LAPACKE
    [dpotrf]). On 2026-07-27 the vendored OpenBLAS
    ([/lib/x86_64-linux-gnu/libopenblas.so.0]) was measured mis-detecting an
    [Intel Xeon 6973P-C] runner as [Cooperlake] and dispatching AVX-512 kernels
    that are wrong on that part. The observed behaviour of [dpotrf] there:

    - with [~upper:false] it reports a spurious non-positive-definite failure
      for every [33 <= n <= 63] — including on [4 * I];
    - with [~upper:true] it returns success and a {e silently wrong} factor,
      with [|L L^T - A|] around 5-7% of [|A|] for [n >= 33].

    A silently wrong Cholesky is far worse than a loud one, so switching [uplo]
    is not a fix and neither is retrying. The unblocked recurrence used here is
    short, runs in O(n^3 / 3), and is host-independent. At the observation
    counts this optimiser reaches (bounded by [total_budget]; the largest value
    in any committed spec is 100) it costs well under a millisecond, and is
    dominated by the O(candidates * n^2) acquisition scan in
    {!Bayesian_opt.suggest_next}. Revisit only if [total_budget] grows past
    ~1000. *)

val chol_with_nugget_escalation :
  Owl.Mat.mat ->
  n:int ->
  noise_variance:float ->
  signal_variance:float ->
  Owl.Mat.mat
(** [chol_with_nugget_escalation k ~n ~noise_variance ~signal_variance] returns
    the lower-triangular Cholesky factor [L] of the symmetric [n x n] kernel
    matrix [k], such that [L * L^T = k]. Entries above the diagonal of the
    result are exactly [0.0].

    [k] is not modified: the factorisation and any jitter escalation run on an
    internal copy.

    The first attempt factors [k] exactly as the caller built it. Only when a
    column yields a non-positive pivot is an additive diagonal jitter applied
    and the factorisation retried, starting at [max(noise_variance, 1e-9)] and
    growing geometrically per retry, each increment capped at
    [1e-2 * signal_variance] so escalation cannot swamp the kernel.

    @raise Invalid_argument
      if any entry of [k] is [nan] or infinite. No jitter can rescue a
      non-finite kernel, so this is reported immediately, naming the offending
      position and value. It signals degenerate observations or length scales in
      the caller, not a numerical edge case.
    @raise Failure
      if [k] is still not positive definite once the retry budget is exhausted.
      The message names the matrix order, the number of attempts, the cumulative
      jitter applied, and the 1-based index and value of the pivot that failed.
*)
