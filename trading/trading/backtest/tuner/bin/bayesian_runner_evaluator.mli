(** Per-BO-iteration evaluator that drives the walk-forward CV harness once per
    suggestion and scores the cell via
    {!Tuner_bin.Bayesian_runner_scoring.score_cell}.

    Replaces the per-scenario-mean shape of the prior {!build} surface (kept
    here for the old [bayesian_runner.exe] callers until PR-E flips the binary
    over). The walk-forward path is the Phase-3 default: each BO iteration is a
    two-variant walk-forward comparison [(baseline, bo-iter-N)] over the pinned
    30-fold spec, and the BO loop's "higher is better" metric is the scorer's
    output.

    Authority: plan [dev/plans/bayesian-multi-param-scaling-2026-05-16.md] §4.

    Sibling of {!Tuner_bin.Grid_search_evaluator} — same cell-to-overrides
    plumbing (see {!Tuner.Grid_search.cell_to_overrides}); differs in that the
    BO evaluator runs a full walk-forward CV per call (not a single backtest)
    and scalarises via the Bayesian scoring formula rather than the spec's
    [objective]. *)

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
    [scenarios] argument passed to {!build} (legacy path) or contains exactly
    one synthetic metric_set per BO iteration projected from the candidate
    variant's stability stats (walk-forward path). *)

val build :
  fixtures_root:string ->
  scenarios:string list ->
  scenarios_by_path:(string, scenario) Hashtbl.t ->
  objective:Tuner.Grid_search.objective ->
  t
(** Legacy per-scenario evaluator. Kept for the [bayesian_runner.exe] binary
    until PR-E flips it to the walk-forward path; PR-C does not remove this
    surface. New BO sweeps should use {!build_walk_forward}.

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

type executor =
  base:Scenario_lib.Scenario.t ->
  spec:Walk_forward.Spec.t ->
  fixtures_root:string ->
  Walk_forward.Walk_forward_executor.result
(** Injectable walk-forward executor. The production wiring is
    {!Walk_forward.Walk_forward_executor.execute_spec} (partially applied to
    drop the labelled [~progress] argument); tests pass a stub that returns a
    hand-built {!Walk_forward.Walk_forward_executor.result} so the per-BO
    iteration scoring path can be exercised without invoking
    {!Backtest.Runner.run_backtest}. *)

val default_executor : executor
(** Production executor: thin wrapper that calls
    {!Walk_forward.Walk_forward_executor.execute_spec} with
    {!Walk_forward.Walk_forward_executor.noop_progress}. *)

val build_walk_forward :
  executor:executor ->
  base:Scenario_lib.Scenario.t ->
  walk_forward_spec:Walk_forward.Spec.t ->
  baseline_aggregate:Walk_forward.Walk_forward_types.aggregate ->
  fixtures_root:string ->
  unit ->
  t
(** [build_walk_forward ~executor ~base ~walk_forward_spec ~baseline_aggregate
     ~fixtures_root ()] returns a per-iteration walk-forward evaluator.

    Each [~parameters] call:

    + Synthesises a fresh, monotonically-increasing candidate label
      [bo-iter-<N>] (the first call uses N=0; the counter is internal to the
      closure). N is decoupled from any BO-loop iteration counter — the contract
      is "unique within a single [t]'s lifetime", which suffices for the
      [stability]/[verdicts] lookups in
      {!Tuner_bin.Bayesian_runner_scoring.score_cell}.

    + Builds a two-variant walk-forward spec ([Walk_forward.Spec.t]) by
      shallow-copying [walk_forward_spec] and replacing its [variants] list with
      [[ baseline; candidate ]]: the baseline carries [overrides = []] and label
      [walk_forward_spec.baseline_label]; the candidate carries
      [overrides = Tuner.Grid_search.cell_to_overrides parameters] and label
      [bo-iter-<N>]. The spec's [baseline_label] is left as
      [walk_forward_spec.baseline_label]; the gate is preserved.

    + Calls [executor ~base ~spec ~fixtures_root] to obtain the
      {!Walk_forward.Walk_forward_executor.result}.

    + Calls {!Tuner_bin.Bayesian_runner_scoring.score_cell} with the result's
      [aggregate] as the candidate aggregate and the configured
      [baseline_aggregate] as the baseline aggregate. Raises [Failure] when the
      scorer returns a [Status.Error] — the BO loop cannot consume a non-finite
      or absent score, and a propagated structured error is more useful than a
      NaN that silently corrupts the GP posterior.

    + Projects the candidate variant's per-metric stability statistics (mean
      Sharpe / MaxDD / Calmar / TotalReturn / CAGR across folds) into a single
      synthetic {!Trading_simulation_types.Metric_types.metric_set} for logging.
      Returns [(score, [ metric_set ])]: one-element list, in keeping with the
      legacy {!t} type's "one metric_set per scenario" convention (here, one
      walk-forward run per iteration, so one metric_set).

    The [baseline_aggregate] argument is the Cell E reference run aggregate on
    the SAME walk-forward spec (same window, same gate). PR-E reads this from a
    pre-computed [aggregate.sexp]; PR-C unit tests pass a hand-built aggregate
    directly.

    The [executor] is injectable to keep the unit tests fast: a stub returning a
    hand-built {!Walk_forward.Walk_forward_executor.result} exercises the
    scoring path without invoking the real backtest. Production wiring uses
    {!default_executor}. *)
