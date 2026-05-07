(** Build a per-suggestion evaluator that runs a real backtest per
    [(parameters, scenario)] pair via {!Backtest.Runner.run_backtest},
    aggregates the metric set across scenarios, and scalarises with the
    configured objective.

    Sibling of {!Tuner_bin.Grid_search_evaluator} — same cell-to-overrides
    plumbing, same per-scenario backtest invocation, same mean-across-scenarios
    aggregation. The two are interchangeable on their shared
    [(scenarios, objective)] subset; the only difference is that the BO
    evaluator scalarises directly to a [float] (the metric the BO loop consumes)
    whereas the grid evaluator returns the raw metric set and delegates
    scalarisation to {!Tuner.Grid_search.evaluate_objective}. *)

open Core

type scenario = Scenario_lib.Scenario.t
(** A loaded scenario from {!Scenario_lib.Scenario.load}. *)

type t =
  parameters:(string * float) list ->
  float * Trading_simulation_types.Metric_types.metric_set list
(** A BO-friendly evaluator: given a parameter assignment, returns the scalar
    metric the BO loop consumes plus the per-scenario metric sets (exposed for
    logging — the [bo_log.csv] writer formats one row per BO iteration with
    these metrics). The list of metric sets is in the same order as the
    [scenarios] argument passed to {!build}. *)

val build :
  fixtures_root:string ->
  scenarios:string list ->
  scenarios_by_path:(string, scenario) Hashtbl.t ->
  objective:Tuner.Grid_search.objective ->
  t
(** [build ~fixtures_root ~scenarios ~scenarios_by_path ~objective] returns an
    evaluator suitable for driving the BO loop.

    For each [~parameters] call:
    - iterates [scenarios] in order (preserves spec ordering);
    - looks up each scenario path in [scenarios_by_path] (raises [Failure] on
      miss);
    - resolves each scenario's [universe_path] against [fixtures_root] via
      {!Scenario_lib.Universe_file};
    - converts the parameter assignment to override sexps via
      {!Tuner.Grid_search.cell_to_overrides} and APPENDS them to the scenario's
      [config_overrides] (so cell overrides win on conflicts — last-writer-wins
      per {!Backtest.Runner._apply_overrides});
    - calls {!Backtest.Runner.run_backtest} for each scenario;
    - scalarises each scenario's metric set with [objective] via
      {!Tuner.Grid_search.evaluate_objective};
    - returns the mean scalar across scenarios + the per-scenario metric sets
      (in scenarios-list order). *)
