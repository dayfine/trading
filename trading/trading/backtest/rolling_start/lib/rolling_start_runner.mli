(** Drive a rolling-start dispersion evaluation: enumerate start dates at a
    fixed cadence, run one backtest per start to a common end date, project each
    run's terminal metrics into a {!Rolling_start_types.per_start}, and assemble
    the {!Rolling_start_types.report}.

    Plan: [dev/plans/evaluation-objective-and-metrics-2026-06-07.md] §2 P1. This
    is PR-2 of the rolling-start work — the executable layer on top of the pure
    {!Dispersion_stats} / {!Rolling_start_types} core (PR-1, #1472). The
    start-date enumeration and per-run metric extraction are split out as pure
    functions so they are unit-testable without forking a real backtest (the
    multi-start PIT run is data-gated); the orchestrating {!run} threads them
    through {!Backtest.Runner.run_backtest}. *)

open Core

val enumerate_starts :
  scenario_start:Date.t -> end_date:Date.t -> stride_days:int -> Date.t list
(** [enumerate_starts ~scenario_start ~end_date ~stride_days] is the ascending
    list of clipped start dates to run a backtest from. Starting at
    [scenario_start], it steps forward by [stride_days] calendar days (default
    quarterly = 91) and emits every start strictly before [end_date], so each
    enumerated start spans a non-empty window.

    - The first element is always [scenario_start] when
      [scenario_start < end_date].
    - A start equal to [end_date] is excluded (zero-length window); the last
      element is the greatest [scenario_start + k*stride_days] that is still
      [< end_date].
    - Returns the empty list when [scenario_start >= end_date].

    @raise Invalid_argument if [stride_days <= 0]. *)

val per_start_of_summary :
  start_date:Date.t ->
  end_date:Date.t ->
  Backtest.Summary.t ->
  Rolling_start_types.per_start
(** [per_start_of_summary ~start_date ~end_date summary] projects one backtest's
    {!Backtest.Summary.t} into a {!Rolling_start_types.per_start} tagged with
    the [start_date] it ran from. Pure — depends only on the summary, so it is
    unit-tested by constructing a [Summary.t] directly without a backtest.

    - [cagr_pct] is the annualised total return over [start_date .. end_date],
      computed via {!Walk_forward_runner.cagr_pct} from the summary's
      initial-cash / final-value total return and the inclusive day count
      (matching the walk-forward executor's CAGR convention).
    - [max_underwater_vs_initial_pct] is read from the summary's
      [MaxUnderwaterVsInitialPct] metric (capital-relative drawdown, #1471);
      [Float.nan] if absent.
    - [max_drawdown_pct] is read from the summary's [MaxDrawdown] metric (peak-
      relative); [Float.nan] if absent. *)

type config = {
  scenario : Scenario_lib.Scenario.t;
      (** The base scenario: supplies the universe path, config overrides,
          strategy choice, slippage, and the scenario's natural start date (the
          earliest start the sweep runs from). *)
  end_date : Date.t;
      (** The fixed end date every enumerated run terminates on. Overrides the
          scenario's own [period.end_date] so the sweep span is explicit. *)
  stride_days : int;
      (** Calendar-day cadence between successive start dates (91 = quarterly).
      *)
  fixtures_root : string;
      (** Directory the scenario's [universe_path] is resolved against (mirrors
          [scenario_runner --fixtures-root]). *)
  bar_data_source : Backtest.Bar_data_source.t option;
      (** Optional snapshot bar source, resolved once from [--snapshot-dir] via
          {!Scenario_lib.Bar_source_resolver.resolve} and reused for every
          start. [None] keeps the pre-snapshot CSV behaviour. *)
}
(** Everything {!run} needs to enumerate starts and run one backtest per start.
*)

val run : config -> Rolling_start_types.report
(** [run config] enumerates the start dates ({!enumerate_starts} over
    [config.scenario.period.start_date] / [config.end_date] /
    [config.stride_days]), runs {!Backtest.Runner.run_backtest} once per start
    (clipping the start, holding the end fixed, threading the scenario's
    overrides / strategy / slippage / cost model and the resolved sector-map
    override + optional snapshot source), projects each result via
    {!per_start_of_summary}, and assembles the {!Rolling_start_types.report} via
    {!Rolling_start_types.build}.

    Sequential — each backtest is run in-process, one after another. The cost is
    N backtests, so callers should keep the cadence coarse and only sweep on PIT
    universes (plan §2 P1). *)
