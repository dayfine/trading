(** Read-only loader for [bo_checkpoint.sexp] files produced by
    {!Tuner_bin.Bayesian_runner_runner.run_and_write}.

    Splits the on-disk parser out of {!Tuner_bin.Bayesian_runner_runner} so
    post-sweep analysis tools ({!Tuner_bin.Bayesian_runner_runner}'s sibling
    exes [holdout_eval] and [sensitivity_sweep]) can read the checkpoint without
    depending on the writer's internal types.

    {b Why duplicate the sexp shape?} The {!Tuner_bin.Bayesian_runner_runner}
    module declares [_saved_iteration] / [_checkpoint] with leading-underscore
    names that are not exposed in its [.mli]. Rather than widen the runner's
    surface — which would couple the writer's internal evolution to every reader
    — we re-declare the same record shape here. The on-disk format is pinned by
    [schema_version]; a mismatch raises a clear error rather than silently
    corrupting downstream tools.

    Pure: no I/O beyond a single [Sexp.load_sexp] in {!load}; no environment
    reads; no side effects.

    Plan: post-sweep analysis tooling for the v7 production sweep
    ([dev/experiments/bayesian-production-sweep-2026-05-25/]). *)

type saved_iteration = {
  parameters : (string * float) list;
      (** Knob assignment the BO emitted for this iteration. Order matches the
          spec's [bounds] list. *)
  metric : float;
      (** Scalar score (higher is better) the BO recorded — output of the
          objective scorer
          ({!Tuner_bin.Bayesian_runner_scoring.score_cell_with_penalty}) for
          this iteration's walk-forward result. *)
  per_scenario_metrics : Trading_simulation_types.Metric_types.metric_set list;
      (** Per-scenario metric sets emitted alongside the score. In walk-forward
          mode this list contains exactly one synthetic metric_set projected
          from the candidate variant's stability stats — see
          {!Tuner_bin.Bayesian_runner_evaluator.build_walk_forward}'s
          [_stability_to_metric_set]. Surfaced for diagnostic logging; the
          post-sweep tools currently use only [metric] + [parameters]. *)
}
[@@deriving sexp]
(** Mirror of {!Tuner_bin.Bayesian_runner_runner._saved_iteration} (which is
    private). The sexp shape is identical so a [bo_checkpoint.sexp] written by
    the runner round-trips through this type without modification. *)

type t = {
  schema_version : int;
      (** Pinned to {!current_schema_version}. {!load} raises on mismatch. *)
  spec : Bayesian_runner_spec.t;
      (** The BO spec that produced this checkpoint. Re-emitted verbatim by the
          writer, so reading it back recovers the exact bounds / objective /
          int_keys the BO ran with. Post-sweep tools consume [spec.bounds] +
          [spec.int_keys] to interpret the per-iteration [parameters] and
          (sensitivity_sweep) to clip perturbations to the original bounds. *)
  iterations : saved_iteration list;
      (** Every iteration the BO completed, in evaluation order (oldest first).
          The list may be shorter than [spec.total_budget] when the sweep was
          killed mid-run or hit early-stop. *)
}
[@@deriving sexp]
(** Mirror of {!Tuner_bin.Bayesian_runner_runner._checkpoint} (which is
    private). Carries the BO spec plus every completed iteration. *)

val current_schema_version : int
(** Current [schema_version] for {!t}. Files written today carry this value;
    {!load} rejects files with any other value. Pinned to match
    {!Tuner_bin.Bayesian_runner_runner}'s internal version so a tool reading a
    fresh checkpoint succeeds without further hand-tuning. *)

val load : string -> t
(** [load path] reads + parses [bo_checkpoint.sexp] from [path].

    Raises [Failure] if the file is missing, malformed, or carries a
    [schema_version] other than {!current_schema_version}. *)

val best_iteration : t -> saved_iteration option
(** [best_iteration t] returns the iteration with the maximum [metric] across
    [t.iterations], or [None] when [t.iterations = []]. Ties resolve to the
    earliest-emitted (lowest position in [t.iterations]).

    {b Why earliest on ties?} A BO sweep can hit the same score twice via
    distinct parameter sets; picking the earliest gives the operator a stable
    pointer they can correlate to a specific iteration number in [bo_log.csv] /
    [convergence.md]. *)

val best_iteration_index : t -> int option
(** [best_iteration_index t] returns the 0-based position of the
    {!best_iteration} in [t.iterations], or [None] when the list is empty.
    Surfaced so the post-sweep tools can quote the iteration number in their
    markdown reports (e.g. "best at iter 25 of 60"). *)
