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

val cagr_pct : test_days:int -> total_return_pct:float -> float
(** [cagr_pct ~test_days ~total_return_pct] annualises a per-fold total return
    over a calendar window of length [test_days] (inclusive).

    Formula: [((1 + total_return_pct/100) ^ (1/years) - 1) * 100] where
    [years = test_days /. 365.25].

    Properties:
    - When [test_days = 365], the result equals [total_return_pct] within
      sub-percentage-point tolerance — full year is the identity case modulo the
      365.25 leap-year averaging.
    - For [test_days < 365] (sub-year window), CAGR > total return when total
      return is positive (annualising up); < total return when negative.
    - Returns [Float.nan] when [test_days <= 0].

    Calendar-based, not trading-day based — close enough for a stability metric.
*)
