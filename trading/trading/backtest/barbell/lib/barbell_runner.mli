(** Sleeve-orchestration runner for the deployable barbell overlay (gate #2).

    Drives the two-leg barbell: run a FLOOR leg and an ENGINE leg, each as an
    independent backtest on its own capital sleeve, then blend their equity
    curves via {!Barbell_blend} into a combined NAV path + metrics. Reuses the
    existing {!Backtest.Runner} for each leg {b unchanged} — the orchestrator
    never modifies Portfolio / Orders / Position / Strategy / Engine / Simulator
    (Option A of [dev/plans/barbell-deployable-overlay-2026-06-21.md]).

    The leg runs are supplied as thunks rather than executed here, so the
    orchestration (split, blend, combined-NAV write) is unit-testable without
    forking a real backtest — the same pure/executable split
    {!Backtest.Rolling_start_runner} uses. A caller (a bin or scenario) builds
    each thunk from {!Backtest.Runner.run_backtest} with that leg's strategy
    choice + config, then hands both to {!run}. *)

open Core

type leg_result = {
  name : string;  (** Human-readable leg label, e.g. ["floor"] / ["engine"]. *)
  equity_curve : (Date.t * float) list;
      (** The leg's chronological [(date, portfolio_value)] NAV series — e.g.
          {!equity_curve_of_steps} applied to its [Runner.result.steps]. *)
}

type t = {
  config : Barbell_config.t;
  floor : leg_result;
  engine : leg_result;
  blend : Barbell_blend.t;
      (** The combined blended NAV path + metrics, from {!Barbell_blend.blend}
          over the two legs' equity curves at [config]'s cadence. *)
}

val equity_curve_of_steps :
  Trading_simulation_types.Simulator_types.step_result list ->
  (Date.t * float) list
(** [equity_curve_of_steps steps] projects a {!Backtest.Runner.result.steps}
    list into the [(date, portfolio_value)] series {!Barbell_blend.blend}
    consumes — the same projection [Result_writer] uses to emit
    [equity_curve.csv]. Pure. *)

val run :
  config:Barbell_config.t ->
  floor_leg:(unit -> leg_result) ->
  engine_leg:(unit -> leg_result) ->
  t
(** [run ~config ~floor_leg ~engine_leg] forces both leg thunks, blends their
    equity curves at [config]'s cadence, and returns the combined {!t}.

    @raise Invalid_argument
      if [config] fails {!Barbell_config.validate} (a weight outside [[0,1]] or
      [rebalance_weeks < 1]) — callers should validate a scenario's config
      before running. [config.enable] is not consulted here; the caller decides
      whether to invoke the overlay at all (when [false] it should run a single
      engine leg instead). *)

val write_equity_curve : t -> output_dir:string -> unit
(** [write_equity_curve t ~output_dir] writes the combined blended NAV path to
    [output_dir/equity_curve.csv] in the canonical [date,portfolio_value] format
    (same header and row shape as {!Backtest.Result_writer}'s per-run equity
    curve), so downstream tooling (e.g. [blend.awk], the rolling-start reader)
    consumes it identically. The blended NAV is normalised to start at [1.0];
    multiply externally by initial capital if a dollar curve is wanted. *)
