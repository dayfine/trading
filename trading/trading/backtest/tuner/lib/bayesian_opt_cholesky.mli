(** Adaptive-nugget Cholesky retry for {!Bayesian_opt.fit_gp}.

    LAPACK's [potrf] occasionally reports the GP kernel matrix as not
    positive-definite ([Failure "LAPACKE: <n>"], n > 0) when observations are
    duplicated or near-duplicated in the [0, 1]-scaled input space — a rare
    numerical edge case, not a modeling error. Rather than let [fit_gp] crash,
    {!chol_with_nugget_escalation} retries the factorisation with an escalating
    diagonal jitter ("nugget") until it succeeds or attempts are exhausted, in
    which case the original failure is re-raised. *)

val chol_with_nugget_escalation :
  Owl.Mat.mat ->
  n:int ->
  noise_variance:float ->
  signal_variance:float ->
  Owl.Mat.mat
(** [chol_with_nugget_escalation k ~n ~noise_variance ~signal_variance] factors
    the [n x n] kernel matrix [k] (in place) via lower Cholesky.

    The first attempt runs on [k] exactly as built by the caller — when it
    succeeds (every currently-passing run), this is bit-identical to a bare
    [Owl.Linalg.D.chol ~upper:false k]. Only on a caught non-positive-definite
    LAPACKE failure is an additive diagonal jitter applied to [k] and the
    factorisation retried, starting at [max(noise_variance, initial_jitter)] and
    growing geometrically per retry, capped at a fraction of [signal_variance]
    so escalation cannot swamp the kernel. Re-raises the original exception once
    the retry budget is exhausted, and re-raises immediately (no retry) for any
    exception that is not the non-PD LAPACKE failure. *)
