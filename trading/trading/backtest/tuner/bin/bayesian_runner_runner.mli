(** The wire-up loop used by [bayesian_runner.exe]: take a parsed spec, an
    evaluator, and an output directory; drive the BO ask/tell loop for the full
    [total_budget] iterations and write all three artefacts. Factored out so a
    unit test can drive the same code path against a stub evaluator without
    spinning up a real backtest.

    Mirrors {!Tuner_bin.Grid_search_runner.run_and_write} in shape — both take
    [~spec ~out_dir ~evaluator] and return a result record holding the optimum.
*)

(** Reason the BO ask/tell loop terminated. [Budget_exhausted] means the loop
    ran for the full [spec.total_budget] iterations; [Early_stopped { iter }]
    means the early-stop predicate fired at iteration [iter] (0-indexed). PR-D
    surfaces this on {!result} so callers / tests can detect early-stop without
    re-reading [convergence.md]. *)
type stop_reason = Budget_exhausted | Early_stopped of { iter : int }

type result = {
  best_params : (string * float) list;
      (** Parameter assignment of the highest-metric observation. [[]] when
          [total_budget = 0]. *)
  best_score : float;
      (** Highest observed scalar metric. [Float.neg_infinity] when
          [total_budget = 0]. *)
  observations : Tuner.Bayesian_opt.observation list;
      (** Every observation in evaluation order (oldest first). Length ≤
          [total_budget] — strictly less when [stop_reason = Early_stopped _].
      *)
  per_iteration_metrics :
    Trading_simulation_types.Metric_types.metric_set list list;
      (** Per-iteration list of per-scenario metric sets, in evaluation order.
          [List.nth_exn per_iteration_metrics i] is a list with one [metric_set]
          per scenario for the [i]-th BO iteration. Used to render the
          [bo_log.csv] columns beyond the scalar metric. *)
  stop_reason : stop_reason;
      (** Why the loop terminated. PR-D: [Early_stopped _] when
          [spec.early_stop = Some _] fires; [Budget_exhausted] otherwise. *)
}
(** Outcome of a BO run: the argmax + the full observation history + the raw
    per-scenario metric sets. *)

type evaluator =
  parameters:(string * float) list ->
  float * Trading_simulation_types.Metric_types.metric_set list
(** A BO-friendly evaluator: given a parameter assignment, returns the scalar
    metric the BO loop consumes plus the per-scenario metric sets. Identical to
    {!Tuner_bin.Bayesian_runner_evaluator.t}. Tests can substitute a closure
    (e.g. a 1D parabola) without invoking a real backtest. *)

val run_and_write :
  spec:Bayesian_runner_spec.t -> out_dir:string -> evaluator:evaluator -> result
(** [run_and_write ~spec ~out_dir ~evaluator] drives the Bayesian-optimisation
    ask/tell loop for [spec.total_budget] iterations, then writes:
    - [<out_dir>/bo_log.csv] — one row per iteration, columns: [iter], each
      parameter name from the spec's bounds, every metric label from
      {!Backtest.Comparison.metric_label} in order, [scenario] (the first
      scenario in the spec; subsequent rows for additional scenarios share the
      iter), and [objective_<label>] (the scalar fed to the BO loop, identical
      across rows for the same iteration);
    - [<out_dir>/best.sexp] — the argmax parameters rendered as the partial
      config-override sexp consumed by [Backtest.Runner.run_backtest], same
      shape as {!Tuner_bin.Grid_search_runner.run_and_write}'s [best.sexp];
    - [<out_dir>/convergence.md] — the running-best curve over iterations, one
      row per iteration with [iter] + [score] + [running_best]; PR-D appends a
      trailing [(stop_reason ...)] sexp line: [(stop_reason budget_exhausted)]
      when the loop ran the full budget, or
      [(stop_reason early_stopped (iter <N>))] when early-stop fired.

    Creates [out_dir] via [mkdir -p] if it does not exist. Returns the {!result}
    record so callers can log [best_score] without re-reading the artefacts. *)
