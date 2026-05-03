(** Bayesian optimisation tuner — sibling of {!Grid_search} under the [tuner]
    library.

    A {b small} Gaussian-process-based optimiser. The user provides
    per-parameter bounds + an acquisition function, then alternates
    {!suggest_next} (ask the BO loop "what should I evaluate next?") with
    {!observe} (record the evaluation outcome).

    The BO loop:

    1. For the first [config.initial_random] suggestions, return uniformly
    random points within the bounds. This seeds the GP. 2. Thereafter, fit a
    Gaussian-process posterior over the observations and return the point in
    [bounds] that maximises the configured acquisition function. The argmax
    search samples N candidate points uniformly from the bounds and picks the
    highest-acquisition candidate (no inner-loop gradient optimisation; for the
    dimensions BO is meaningful at — ≤10 — random search suffices).

    Decoupled from the actual backtest runner: callers thread observations
    through the state explicitly. The standard wiring is to call
    [Backtest.Runner.run_backtest] with the parameters from {!suggest_next} and
    feed the resulting metric back via {!observe}; tests substitute a synthetic
    objective (e.g. a 1D parabola).

    Determinism: every random draw goes through [config.rng]. Given the same RNG
    state and the same sequence of [observe] calls, the suggestion stream is
    byte-identical. Pinned by [test_determinism_same_seed_same_sequence]. *)

(** {1 Types} *)

type observation = {
  parameters : (string * float) list;
      (** Per-parameter values, in the same key order as [config.bounds]. *)
  metric : float;
      (** Objective value. {b Higher is better} — minimisation problems should
          negate the objective before observing. *)
}
(** A single evaluation: parameters fed in + metric obtained. *)

type acquisition = [ `Expected_improvement | `Upper_confidence_bound of float ]
(** Acquisition function selector.

    - [`Expected_improvement] — the standard EI acquisition.
      [EI(x) = σ(x) · (z · Φ(z) + φ(z))] where [z = (μ(x) − f_best) / σ(x)].
      Balances exploration + exploitation with no tunable.
    - [`Upper_confidence_bound β] — UCB. [UCB(x) = μ(x) + β · σ(x)]. Larger β
      explores more; β = 0 is greedy exploitation. *)

type config = {
  bounds : (string * (float * float)) list;
      (** Per-parameter bounds [(key, (min, max))]. The order of this list
          determines the order of [parameters] in {!suggest_next}'s return. *)
  acquisition : acquisition;
  initial_random : int;
      (** Number of initial uniformly-random samples before the GP kicks in.
          Must be [≥ 0]. Common values: 5–20. *)
  total_budget : int;
      (** Maximum total number of evaluations. Caller-enforced — the lib does
          not refuse [observe] calls past the budget; callers stop their own
          loop when [List.length (all_observations t) ≥ total_budget]. *)
  rng : Stdlib.Random.State.t;
      (** RNG for the random phase + acquisition candidate sampling. *)
}

val create_config :
  bounds:(string * (float * float)) list ->
  ?acquisition:acquisition ->
  ?initial_random:int ->
  ?total_budget:int ->
  ?rng:Stdlib.Random.State.t ->
  unit ->
  config
(** Builder for [config] with sensible defaults: [Expected_improvement],
    [initial_random = 5], [total_budget = 50], a fresh RNG seeded with [42]. *)

type t
(** Opaque BO state. Carries the observations + RNG state. *)

(** {1 State management} *)

val create : config -> t
(** Initialise BO state with empty observations.

    Raises [Invalid_argument] when [config.bounds = []], when any bound has
    [min > max], when [config.initial_random < 0], or when
    [config.total_budget < 0]. *)

val observe : t -> observation -> t
(** Record an evaluation outcome. Returns a new state with the observation
    appended. Pure — no mutation of [t]. *)

val all_observations : t -> observation list
(** All observations in evaluation order (oldest first). *)

val best : t -> observation option
(** Highest-metric observation seen so far, or [None] if no observations yet.
    Tie-break: first observation by evaluation order wins. *)

(** {1 Suggestion} *)

val suggest_next : t -> (string * float) list
(** Return the next parameter set to evaluate, in the same key order as
    [config.bounds].

    - For the first [config.initial_random] calls (counted by the number of
      observations so far), returns a uniformly random point within bounds.
    - Otherwise, fits a Gaussian-process posterior over the current
      observations, samples [n_acquisition_candidates] (default 1000) random
      candidate points within bounds, evaluates the configured acquisition
      function on each, and returns the candidate with the highest acquisition
      value.

    Every value is guaranteed within [config.bounds]. The RNG state inside [t]
    is mutated as a side effect (subsequent calls produce different
    suggestions). *)

val suggest_next_with_candidates :
  t -> n_candidates:int -> (string * float) list
(** Like {!suggest_next} but with an explicit candidate count for the GP-phase
    acquisition argmax. Must be [≥ 1]; raises [Invalid_argument] otherwise.
    Larger values give a finer search of the acquisition surface at linear cost
    per suggestion. *)

(** {1 Internal helpers exposed for testing} *)

(** All values below are exposed for unit-test scrutiny only — production code
    should use the high-level surface above. *)

val rbf_kernel :
  length_scales:float array ->
  signal_variance:float ->
  float array ->
  float array ->
  float
(** RBF (Gaussian) kernel: [k(x, x') = σ_f² · exp(-0.5 · Σᵢ((xᵢ − x'ᵢ) / ℓᵢ)²)].
    Inputs must have the same length; raises [Invalid_argument] otherwise. *)

type gp_posterior = {
  mean : float array -> float;  (** Posterior mean at any test point. *)
  variance : float array -> float;
      (** Posterior variance at any test point; always [>= 0]. *)
}
(** A fitted Gaussian-process posterior — closure-over-the-Cholesky factor of
    the kernel matrix. *)

val fit_gp :
  length_scales:float array ->
  signal_variance:float ->
  noise_variance:float ->
  observations_x:float array array ->
  observations_y:float array ->
  gp_posterior
(** Fit a GP to [(X, y)] with the given hyperparameters. [observations_x.(i)] is
    the i-th observation's normalised input vector; [observations_y.(i)] is its
    objective value (centred internally to mean 0).

    Raises [Invalid_argument] when [observations_x = [||]] or when row/value
    lengths disagree.

    Numerical: adds [noise_variance · I] to the kernel matrix before Cholesky.
    Use [noise_variance ~ 1e-6] for jitter on noise-free objectives. *)

val expected_improvement :
  posterior:gp_posterior -> f_best:float -> float array -> float
(** Expected improvement at a test point. [f_best] is the best observed metric
    so far. Returns [0.0] when [σ(x) ≈ 0]. *)

val upper_confidence_bound :
  posterior:gp_posterior -> beta:float -> float array -> float
(** UCB: [μ(x) + β · σ(x)]. *)
