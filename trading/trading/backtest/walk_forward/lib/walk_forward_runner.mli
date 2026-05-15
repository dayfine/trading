(** Pure scenario generation for walk-forward CV.

    Given a base {!Scenario_lib.Scenario.t} (the template — its period gets
    overridden), a {!Window_spec.t} (the rolling windows), and a list of
    {!variant}s (variant_label → extra config overrides), produces the list of
    {!Scenario_lib.Scenario.t} the walk-forward harness instantiates.

    Pure: same inputs → same output sexps. No backtest invocation here; the CLI
    binary feeds these scenarios to [Backtest.Runner.run_backtest] in the same
    shape {!Tuner_bin.Bayesian_runner_evaluator.build} does. *)

open Core

type variant = {
  label : string;
      (** Human-readable variant identifier. Becomes part of the generated
          scenario name and the report's column header. Must be unique within a
          single walk-forward run. *)
  overrides : Sexp.t list;
      (** Partial config sexps deep-merged into the scenario's existing
          [config_overrides], in order. Mirrors
          {!Scenario_lib.Scenario.config_overrides}. *)
}
[@@deriving sexp]

val build_fold_scenario :
  base:Scenario_lib.Scenario.t ->
  fold:Window_spec.fold ->
  variant:variant ->
  Scenario_lib.Scenario.t
(** [build_fold_scenario ~base ~fold ~variant] produces a scenario suitable for
    {!Backtest.Runner.run_backtest}.

    Mapping:
    - [name = base.name ^ "-" ^ variant.label ^ "-" ^ fold.name]
    - [description] preserved from [base] but prefixed with the fold label.
    - [period = fold.test_period] — the OOS evaluation window.
    - [universe_path] preserved.
    - [config_overrides = base.config_overrides @ variant.overrides] — variant
      overrides are APPENDED last so they win on conflicts (last-writer-wins per
      {!Tuner_bin.Bayesian_runner_evaluator.build} and
      {!Backtest.Runner.run_backtest}).
    - [strategy] preserved.
    - [slippage_bps] preserved.
    - [expected] preserved — note this means range checks may fail per-fold; the
      walk-forward report's comparison is across variants, not against pinned
      ranges. *)

val build_all :
  base:Scenario_lib.Scenario.t ->
  spec:Window_spec.t ->
  variants:variant list ->
  Scenario_lib.Scenario.t list
(** [build_all ~base ~spec ~variants] = the flat list of all
    [{!build_fold_scenario}] outputs across
    [variants × WindowSpec.generate spec]. Ordering: outer = variants in input
    order, inner = folds in generation order. Empty variant list → empty result.
*)
