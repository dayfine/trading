(** In-process walk-forward CV execution. Library entry point shared by the
    [walk_forward_runner.exe] binary and the Phase-3 Bayesian optimizer
    evaluator.

    Hoists the per-fold + cross-grid execution loop out of
    [bin/walk_forward_runner.ml] so the Bayesian tuner can run a walk-forward
    sweep per BO iteration without spawning a subprocess. The binary becomes a
    thin wrapper that calls {!execute_spec} and writes its three output files;
    the tuner consumes {!result.aggregate} directly to score the cell via
    {!Tuner_bin.Bayesian_runner_scoring.score_cell}.

    Pure orchestration on top of {!Backtest.Runner.run_backtest} plus
    {!Walk_forward_report.compute}. No filesystem writes here — the caller
    persists results when it chooses to. *)

open Core

type result = {
  fold_actuals : Walk_forward_report.fold_actual list;
      (** Flat list of per-(variant, fold) measurement rows, in the same order
          {!Walk_forward_runner.build_all} produces scenarios: outer = variants
          in input order, inner = folds in generation order. The binary persists
          this verbatim as [fold_actuals.sexp] for replay; the tuner ignores it
          and reads {!aggregate} instead. *)
  aggregate : Walk_forward_report.aggregate;
      (** The structured cross-fold summary, computed via
          {!Walk_forward_report.compute} from [fold_actuals] using the spec's
          [baseline_label] and [gate]. The Bayesian-optimizer scorer reads this
          field directly. *)
}
(** What an end-to-end walk-forward CV produces, before any output writer
    decides whether to serialise it. *)

type progress_callback =
  variant_label:string ->
  fold_name:string ->
  test_start:Date.t ->
  test_end:Date.t ->
  unit
(** Called once per (variant, fold) pair immediately before
    {!Backtest.Runner.run_backtest} fires. Implementations may log to stderr
    (the binary does this) or ignore the call (the tuner does this). *)

val noop_progress : progress_callback
(** A {!progress_callback} that does nothing. Default for callers that don't
    want progress noise. *)

val execute_spec :
  base:Scenario_lib.Scenario.t ->
  spec:Spec.t ->
  fixtures_root:string ->
  ?progress:progress_callback ->
  unit ->
  result
(** [execute_spec ~base ~spec ~fixtures_root ?progress ()] runs the full
    walk-forward CV grid:

    + For each [variant] in [spec.variants] (outer loop), and for each [fold] in
      [Window_spec.generate spec.window_spec] (inner loop):
    + Build a per-fold {!Scenario_lib.Scenario.t} via
      {!Walk_forward_runner.build_fold_scenario}.
    + Resolve the scenario's universe via
      {!Scenario_lib.Universe_file.to_sector_map_override} against
      [fixtures_root].
    + Call [progress ~variant_label ~fold_name ~test_start ~test_end] (no-op by
      default).
    + Run {!Backtest.Runner.run_backtest} on that scenario and convert its
      summary metrics into a {!Walk_forward_report.fold_actual}.
    + Tag the result with the fold name and variant label.

    After every (variant, fold) is run, compute the
    {!Walk_forward_report.aggregate} by calling {!Walk_forward_report.compute}
    with [spec.baseline_label] and [spec.gate]. Returns the combined {!result}.

    Sequential execution. Parallelisation is a follow-up that does not change
    this signature.

    The [base] scenario is loaded by the caller (typically
    {!Scenario_lib.Scenario.load} on [spec.base_scenario]); accepted as an
    argument so the Bayesian-optimizer evaluator can load it once and reuse it
    across many BO iterations without re-parsing.

    Raises [Failure] when the underlying backtest raises, when the universe file
    is malformed, or when {!Walk_forward_report.compute} finds no folds or a
    missing baseline (see its docstring). *)
