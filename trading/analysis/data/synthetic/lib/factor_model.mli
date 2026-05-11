(** Single-factor cross-section model — Synth-v3's per-symbol layer.

    Each symbol's log-return is composed as
    {v   r_i_t = β_i · r_market_t + ε_i_t v}
    where [r_market_t] is the common market return (supplied by the caller,
    typically a [Synth_v2] output) and [ε_i_t] is per-symbol idiosyncratic noise
    drawn from a per-symbol GARCH(1,1) process. The model is therefore a
    single-factor regression: market exposure is captured by [β_i], all residual
    structure is owned by [ε_i].

    This module is intentionally agnostic to where the market series comes from.
    [Synth_v3] is the orchestrator that pairs the market with the cross-section.

    Cross-symbol correlation arises mechanically from the shared market factor:
    with [β_i ≈ 1] and idiosyncratic vol of similar magnitude to the market vol
    the average pairwise daily-return correlation lands near 0.5, matching the
    M7.0 acceptance target.

    Determinism: every sampler is seeded explicitly. Callers should partition
    seeds across distributions and per-symbol streams (see [Synth_v3]). *)

type loading_distribution = {
  mean : float;  (** Center of the Normal draw, typically ≈ 1.0. *)
  stddev : float;  (** Standard deviation of the Normal draw, must be > 0. *)
  min_value : float;  (** Inclusive lower truncation bound. *)
  max_value : float;  (** Inclusive upper truncation bound, > [min_value]. *)
}
(** Distribution governing β-factor loading draws across the cross-section.

    [mean] / [stddev] parameterise a Normal distribution; draws outside
    [[min_value, max_value]] are resampled until in range (rejection sampling).
    The default range [[0.2, 2.5]] covers the bulk of the historical equity beta
    cross-section: defensive utilities near 0.3, levered cyclicals around 2.0.
*)

val default_loading_distribution : loading_distribution
(** Hand-set defaults: [mean = 1.0], [stddev = 0.4], [min = 0.2], [max = 2.5].
    Calibration TODO: re-fit from real EODHD cross-section. *)

val validate_loading_distribution :
  loading_distribution -> (unit, Status.t) Result.t
(** [Error Status.Invalid_argument] when any of:
    - [stddev <= 0] or non-finite;
    - [min_value], [max_value], [mean] non-finite;
    - [min_value >= max_value];
    - [mean] outside [[min_value, max_value]] (the truncated range would reject
      most draws). *)

type idio_distribution = {
  omega_mean : float;
      (** Median of the log-normal omega distribution, must be > 0. *)
  omega_lognormal_sigma : float;
      (** Log-scale (stddev of [log omega]), must be >= 0. Zero means all
          symbols share the same omega. *)
  alpha : float;  (** Shared GARCH α coefficient. Must satisfy α + β < 1. *)
  beta : float;  (** Shared GARCH β coefficient. *)
}
(** Distribution governing per-symbol idiosyncratic GARCH(1,1) parameters.

    Each symbol gets its own GARCH process. To keep the parameter surface
    tractable we share [(alpha, beta)] across symbols and only draw the
    unconditional-variance scale [omega] per symbol. [omega] is drawn from a
    log-normal centered on [omega_mean] with log-scale [omega_lognormal_sigma] —
    multiplicative noise on the variance baseline keeps it strictly positive. *)

val default_idio_distribution : idio_distribution
(** Hand-set defaults: [omega_mean = 1e-5], [omega_lognormal_sigma = 0.3],
    [alpha = 0.05], [beta = 0.90]. Stationary with mild persistence. *)

val validate_idio_distribution : idio_distribution -> (unit, Status.t) Result.t
(** [Error Status.Invalid_argument] when any of:
    - [omega_mean <= 0] or non-finite;
    - [omega_lognormal_sigma < 0] or non-finite;
    - [alpha < 0] or [beta < 0];
    - [alpha + beta >= 1] (non-stationary GARCH). *)

val sample_betas : loading_distribution -> n:int -> seed:int -> float list
(** [sample_betas dist ~n ~seed] returns [n] β-loading samples drawn from the
    truncated Normal. Returns the empty list when [n <= 0]. Deterministic given
    [seed]. Raises [Invalid_argument] if [dist] fails
    [validate_loading_distribution]; callers should validate up front. *)

val sample_idio_params :
  idio_distribution -> n:int -> seed:int -> Garch.params list
(** [sample_idio_params dist ~n ~seed] returns [n] per-symbol GARCH parameter
    triples; the [omega] field varies per symbol, the [alpha] and [beta] fields
    are shared from [dist]. Deterministic given [seed]. Returns the empty list
    when [n <= 0]. Raises [Invalid_argument] if [dist] fails
    [validate_idio_distribution]; callers should validate up front. *)

val generate_symbol_returns :
  market_returns:float list ->
  beta:float ->
  idio_params:Garch.params ->
  seed:int ->
  float list
(** [generate_symbol_returns ~market_returns ~beta ~idio_params ~seed] composes
    a per-symbol log-return series:
    {v   r_i_t = beta · market_returns_t + ε_t v}
    where [ε_t] is a GARCH(1,1) shock under [idio_params] driven by a fresh RNG
    seeded with [seed]. The output list has the same length as [market_returns].
    Returns the empty list when [market_returns] is empty. Raises
    [Invalid_argument] if [idio_params] fails [Garch.validate]. *)
