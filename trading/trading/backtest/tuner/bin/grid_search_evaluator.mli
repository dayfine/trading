(** Build a {!Tuner.Grid_search.evaluator} that runs a real backtest per cell ×
    scenario via {!Backtest.Runner.run_backtest}.

    Factored out of [grid_search.ml] so the binary's argument parsing / output
    writing path stays separately testable from the per-cell backtest
    invocation. *)

open Core

type scenario = Scenario_lib.Scenario.t
(** A loaded scenario from {!Scenario_lib.Scenario.load}. The evaluator indexes
    scenarios by their file path; this record carries the date range, universe
    path, and base [config_overrides] each cell run inherits before the cell's
    overrides are merged on top. *)

val build :
  fixtures_root:string ->
  scenarios_by_path:(string, scenario) Hashtbl.t ->
  Tuner.Grid_search.evaluator
(** [build ~fixtures_root ~scenarios_by_path] returns an evaluator suitable for
    passing as {!Tuner.Grid_search.run}'s [~evaluator] argument.

    For each [(cell, ~scenario:path)] call:
    - looks up [path] in [scenarios_by_path] (raises [Failure] on miss);
    - resolves the scenario's [universe_path] against [fixtures_root] via
      {!Scenario_lib.Universe_file};
    - builds the cell's overrides via {!Tuner.Grid_search.cell_to_overrides} and
      APPENDS them to the scenario's [config_overrides] (so cell overrides win
      on conflicts — the deep-merge in {!Backtest.Runner._apply_overrides} is
      last-writer-wins);
    - calls {!Backtest.Runner.run_backtest} with the merged overrides;
    - returns the run's [summary.metrics] (the {!Metric_types.metric_set}
      consumed by {!Tuner.Grid_search.evaluate_objective}). *)
