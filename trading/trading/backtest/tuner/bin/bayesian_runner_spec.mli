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

(** Per-knob bound shape. PR-D introduces Option-typed knobs via a sentinel
    encoding (plan §2.5). [Plain (lo, hi)] is the existing form — the BO samples
    uniformly from [[lo, hi]] and the override is always emitted.
    [Sentinel { threshold; upper }] expands the BO sampling range to
    [[threshold - margin, upper]] (where [margin = (upper - threshold) * 0.25]
    by convention); samples below [threshold] decode as [None] (override
    omitted), samples in [[threshold, upper]] decode as [Some sample].

    Sexp encoding (round-trip stable):
    - [Plain (lo, hi)] is written as [(lo hi)] — preserves the legacy shape.
    - [Sentinel { threshold; upper }] is written as
      [(sentinel threshold upper)].

    Cell-to-overrides conversion lives in the evaluator (PR-C/PR-E); PR-D only
    pins the on-disk shape. *)
type bound_spec =
  | Plain of float * float
  | Sentinel of { threshold : float; upper : float }
[@@deriving sexp]

val plain_range : bound_spec -> float * float
(** Project a [bound_spec] to the [(min, max)] pair the BO samples from. For
    [Plain (lo, hi)] returns [(lo, hi)]. For [Sentinel { threshold; upper }]
    returns [(threshold - margin, upper)] where
    [margin = (upper - threshold) * sentinel_margin_fraction] — the expanded
    lower bound gives the GP one normalised slot's worth of "off" mass. *)

val sentinel_margin_fraction : float
(** Fraction of the active [(threshold, upper)] span allocated below [threshold]
    as the "off" slot in {!plain_range}. Pinned at [0.25]: a candidate's draw in
    [\[threshold - 0.25 * (upper - threshold), threshold)] decodes as [None].
    Exposed so tests can assert exact bounds. *)

val decode_sentinel_sample : bound_spec -> float -> float option
(** [decode_sentinel_sample spec sampled] interprets a BO-sampled value against
    a [bound_spec].

    - For [Plain _], always returns [Some sampled].
    - For [Sentinel { threshold; _ }], returns [None] when
      [sampled < threshold], [Some sampled] otherwise. *)

type t = {
  bounds : (string * (float * float)) list;
      (** Per-parameter bounds [(key, (min, max))]. Sexp:
          [((bounds (("key.path1" (0.0 1.0)) ("key.path2" (-1.0 2.0)))) ...)].

          Each binding optionally carries an [(int)] marker as a third element —
          [("key" (lo hi) (int))] — which flags the knob as integer-typed. The
          marker is stripped at parse time and the key is recorded in
          {!int_keys}; the field type stays [(string * (float * float)) list] so
          existing consumers (BO [create_config], CSV header writer) are
          unchanged. *)
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
  holdout_folds : int list option;
      (** Phase-3 walk-forward holdout (PR-B). When [Some [k1; ...; kn]], the
          listed 1-indexed fold positions are reserved as out-of-sample
          validation and excluded from BO scoring per plan §6.2 of
          [dev/plans/bayesian-multi-param-scaling-2026-05-16.md]. When [None]
          (or omitted from the sexp), the BO uses every fold as in-sample. PR-B
          only pins the parsed shape; PR-C will thread the list through the
          walk-forward executor's fold filter, and PR-E will re-run the best
          cell on the held-out folds. *)
  sentinel_bounds : (string * bound_spec) list option;
      (** Phase-3 Option-typed knobs (PR-D, plan §2.5). When [Some bs], each
          element is an extra knob the BO tunes whose decoded form is
          [float option] — used for [max_sector_exposure_pct],
          [min_score_override], and similar Option config fields. The BO
          consumes a sampling range derived via {!plain_range}; the evaluator
          decodes each sample via {!decode_sentinel_sample}.

          PR-D pins the parsed shape + the decode helpers; the cell-to-overrides
          translation that emits or omits the override on a per-sample basis
          lives in PR-C/PR-E's evaluator. The field is [\@sexp.option] so
          omission parses as [None]. *)
  length_scales : float list option;
      (** Phase-3 GP length-scale override (PR-D, plan §5.2 response 2). When
          [Some xs], the BO config sets
          [length_scales = Some (Array.of_list xs)] — used to widen the kernel
          bandwidth at high dimensionality. When [None] (or omitted), the lib's
          [sqrt(d) * 0.25] default applies. List length must match
          [List.length bounds]; the BO library raises [Invalid_argument] at
          create-time otherwise. *)
  early_stop : (int * float) option;
      (** Phase-3 early-stop config (PR-D, plan §5.4). When
          [Some (window, epsilon)], the runner monitors the running-best curve
          and stops the BO loop when
          [running_best[i] - running_best[i - window] < epsilon] for the
          trailing [window] iterations (after the random-seed phase). When
          [None] (or omitted), the loop runs to [total_budget] without early
          termination. Sexp form: [(early_stop (20 0.02))] for
          [Some (20, 0.02)]; omit the tag for [None]. *)
  gate_penalty_value : float option;
      (** Soft-penalty magnitude applied when the walk-forward
          [Fold_gate.verdict] is [Fail]. The scorer subtracts
          [lambda_gate * gate_penalty_value] from the cell's metric (lambda_gate
          is fixed at 1.0 in {!Tuner_bin.Bayesian_runner_scoring}). When [None]
          (or omitted), the runner uses the historical default of [10.0] —
          preserved for backward compatibility with V1/V2 spec sexp files.

          {b Why this is tunable:} V1 + V2 sweeps both failed because every
          random cell triggered the gate, so every iter's score was dominated by
          the [-10.0] penalty. The composite metric signal (typical magnitude
          0.1–0.5) was drowned out, leaving the GP no gradient to climb. V3+ can
          override with a smaller value (e.g. [2.0]) to keep the gate
          informative as a tiebreaker without overwhelming the composite. Sexp
          form: [(gate_penalty_value 2.0)] for [Some 2.0]; omit the tag for
          [None] (= legacy [10.0]). *)
  int_keys : string list;
      (** Names of {!bounds} keys whose downstream config field is integer-typed
          (e.g. [stage3_force_exit_config.hysteresis_weeks],
          [screening_config.weights.w_positive_rs]). Threaded into
          {!Tuner.Grid_search.cell_to_overrides} so BO-sampled floats are
          rounded to the nearest integer before being emitted as override atoms
          — without this, [int_of_sexp] downstream throws on continuous floats
          like [3.8004…] (see
          [dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md] for the
          observed crash).

          Two on-disk encodings, both round-trip:
          - {b Per-binding sugar (preferred):} write
            [("knob.path" (lo hi) (int))] inside the [bounds] list. The marker
            is stripped at parse time and the key is recorded here.
          - {b Explicit field:} [(int_keys ("k1" "k2"))] at the top level. Used
            internally when {!sexp_of_t} round-trips a spec that originated as a
            value rather than a parse.

          When both forms appear, keys from both are merged (explicit first,
          per-binding markers appended). Empty list (default) is omitted from
          the emitted sexp. *)
}
[@@deriving sexp]
(** A Bayesian-optimisation spec on disk. Example sexp (verbatim — the [(int)]
    marker on the third binding must be parenthesised; the bare atom [int] is
    rejected by {!t_of_sexp}'s pre-processor — see {!int_keys}):
    {v
    (bounds
       (("screening.weights.rs" (0.1 0.5))
          ("screening.weights.volume" (0.1 0.5))
          ("screening.weights.w_positive_rs" (5.0 40.0) (int))))
      (acquisition Expected_improvement)
      (initial_random 5) (total_budget 30) (seed 17)
      (n_acquisition_candidates ())
      (objective Sharpe)
      (scenarios "trading/test_data/backtest_scenarios/smoke/bull-2019.sexp")
      (holdout_folds (27 28 29 30))
    v}
    The [holdout_folds] tag is optional ([\@sexp.option]): omit it entirely for
    [None]; write [(holdout_folds (k1 ... kn))] for [Some [k1; ...; kn]]; write
    [(holdout_folds ())] for [Some []]. *)

(** The auto-derived [sexp_of_t] / [t_of_sexp] are shadowed in the [.ml]:
    parsing accepts the per-binding sugar [(key (lo hi) (int))] in the [bounds]
    list and the explicit top-level [(int_keys ...)] field (both populate
    {!t.int_keys}); emission rewrites each binding whose key is in {!t.int_keys}
    as [(key (lo hi) (int))] and drops the now-redundant top-level
    [(int_keys ...)] field. Round-trip [t_of_sexp ∘ sexp_of_t = id] holds for
    any [t] — checkpoint validation in the BO runner depends on this. *)

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
