(** GARCH(1,1) variance simulation.

    Bollerslev (1986). The GARCH(1,1) variance recursion is:
    {v
      σ²_t = ω + α · ε²_{t-1} + β · σ²_{t-1}
      ε_t  = σ_t · z_t,    z_t ~ N(0, 1)
    v}
    where [ω > 0], [α >= 0], [β >= 0]. A finite long-run variance requires
    [α + β < 1]; otherwise variance is non-stationary and grows without bound.
    The long-run (unconditional) variance is [ω / (1 - α - β)].

    This module exposes a single sampler [sample_returns] that emits a list of
    GARCH-driven log-returns of arbitrary length, deterministic in the seed. The
    variance recursion is updated using the realised shock at each step; the
    returned series is the [ε_t] sequence (not [σ²_t]).

    Numerical safety: the recursion is clamped to a non-negative variance and a
    hard upper bound to keep generated returns finite even when callers pass
    near-explosive parameters [α + β ≈ 1]. The clamps trip only when caller
    parameters violate [α + β < 1]; well-behaved parameters never reach them. *)

type params = {
  omega : float;  (** Baseline variance term, must be > 0. *)
  alpha : float;  (** Shock weight ([ε²_{t-1}] coefficient), must be >= 0. *)
  beta : float;
      (** Persistence weight ([σ²_{t-1}] coefficient), must be >= 0. *)
}
[@@deriving sexp, eq, show]

val long_run_variance : params -> float option
(** [long_run_variance p] returns [Some (omega / (1 - alpha - beta))] when
    [alpha + beta < 1] (stationary regime) and [None] otherwise. Useful as the
    natural [initial_variance] when a caller has no prior estimate. *)

val validate : params -> (unit, Status.t) Result.t
(** Returns [Error Status.Invalid_argument] for non-finite, negative, or
    non-stationary parameters. Stationarity check is [alpha + beta < 1]. *)

val sample_returns :
  params -> n_steps:int -> seed:int -> initial_variance:float -> float list
(** [sample_returns params ~n_steps ~seed ~initial_variance] generates [n_steps]
    GARCH-driven returns. The variance at step 0 is [initial_variance]; the
    shock at step 0 is drawn against that variance. For [k >= 1] the variance at
    step [k] uses the recursion above with the realised [ε²_{k-1}] and
    [σ²_{k-1}].

    Returns the empty list when [n_steps <= 0]. Raises [Invalid_argument] if
    [params] fails [validate] or if [initial_variance < 0]; callers should
    validate up front. *)
