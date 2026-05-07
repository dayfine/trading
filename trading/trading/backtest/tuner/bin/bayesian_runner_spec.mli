(** Parse a Bayesian-optimisation spec sexp file into the inputs the BO loop
    consumes. The CLI binary's only job is to wire this spec to a
    {!Backtest.Runner.run_backtest}-backed evaluator and the
    {!Tuner.Bayesian_opt} state machine; this module pins the on-disk shape so
    the binary stays a thin wrapper.

    Mirror of {!Tuner_bin.Grid_search_spec} — same scenarios + objective shape;
    differs only in the search-surface description (per-parameter bounds +
    acquisition + budget knobs). *)

(** Sexp-friendly mirror of {!Tuner.Grid_search.objective}. The objective shape
    is shared with grid search; the BO binary scalarises the metric set the same
    way so the two binaries are interchangeable on the same scenarios +
    objective subset. *)
type objective_spec =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of
      (Trading_simulation_types.Metric_types.metric_type * float) list
[@@deriving sexp]

(** Sexp-friendly mirror of {!Tuner.Bayesian_opt.acquisition}. The library's
    acquisition type uses polymorphic variants, which don't admit ppx-derived
    sexp converters; we re-declare here as a tagged variant and convert via
    {!to_acquisition}. *)
type acquisition_spec = Expected_improvement | Upper_confidence_bound of float
[@@deriving sexp]

type t = {
  bounds : (string * (float * float)) list;
      (** Per-parameter bounds [(key, (min, max))]. Sexp:
          [((bounds (("key.path1" (0.0 1.0)) ("key.path2" (-1.0 2.0)))) ...)].
      *)
  acquisition : acquisition_spec;
      (** Acquisition function selector. Default in {!Tuner.Bayesian_opt} is
          [Expected_improvement] but the spec carries it explicitly so runs are
          self-describing. *)
  initial_random : int;
      (** Number of initial uniformly-random samples before GP-driven
          suggestions kick in. Must be [≥ 0]; passes through to
          [Bayesian_opt.config.initial_random]. *)
  total_budget : int;
      (** Maximum total number of evaluations. Caller-enforced — the BO loop
          stops once [List.length (all_observations t) ≥ total_budget]. *)
  seed : int option;
      (** Optional RNG seed. When [Some n], a fresh
          [Stdlib.Random.State.make [| n |]] seeds the BO state for
          reproducibility. When [None], {!Tuner.Bayesian_opt.create_config}'s
          default RNG (seed 42) is used. *)
  n_acquisition_candidates : int option;
      (** Optional override for the number of candidate points sampled in the
          GP-phase acquisition argmax. When [None], the lib's default (1000) is
          used via {!Tuner.Bayesian_opt.suggest_next}. When [Some n], the binary
          calls {!Tuner.Bayesian_opt.suggest_next_with_candidates}. *)
  objective : objective_spec;  (** Scoring objective. *)
  scenarios : string list;
      (** Paths to scenario sexp files, resolved relative to the current working
          directory and loaded via {!Scenario_lib.Scenario.load} when the binary
          runs the evaluator. *)
}
[@@deriving sexp]
(** A Bayesian-optimisation spec on disk. Example sexp:
    {[
    (bounds
       (("screening.weights.rs" (0.1 0.5))
          ("screening.weights.volume" (0.1 0.5))))
      (acquisition Expected_improvement)
      (initial_random 5) (total_budget 30) (seed 17)
      (n_acquisition_candidates ())
      (objective Sharpe)
      (scenarios "trading/test_data/backtest_scenarios/smoke/bull-2019.sexp")
    ]} *)

val load : string -> t
(** Load and parse a spec sexp file. Raises [Failure] on malformed input. *)

val to_grid_objective : objective_spec -> Tuner.Grid_search.objective
(** Convert the parsed objective into the lib-side
    {!Tuner.Grid_search.objective} variant. Reused so the binary scalarises
    metric sets identically to T-A's grid_search. *)

val to_acquisition : acquisition_spec -> Tuner.Bayesian_opt.acquisition
(** Convert the parsed acquisition variant into the lib's polymorphic-variant
    [acquisition]. *)

val to_bo_config : t -> Tuner.Bayesian_opt.config
(** Project a parsed spec into the {!Tuner.Bayesian_opt.config} record the
    library consumes. [seed] becomes [rng]; [n_acquisition_candidates] is
    {b not} threaded into the config (the lib reads it via the explicit
    [suggest_next_with_candidates] entry point) — callers should consult
    [t.n_acquisition_candidates] separately when invoking [suggest_next]. *)
