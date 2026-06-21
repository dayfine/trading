(** End-to-end call-site wiring for the deployable barbell overlay (gate #2,
    follow-up to PR #1683).

    The pure orchestration — split capital, blend the two sleeves' equity
    curves, write the combined NAV — already lives in {!Barbell.Barbell_runner}.
    What this module adds is the {b call site}: it builds the two
    {!Barbell.Barbell_runner.leg_result} thunks from a real
    {!Scenario_lib.Scenario.t} (period + universe + snapshot context) by running
    {!Backtest.Runner.run_backtest} once per leg — a FLOOR leg (the SPY-timing
    floor strategy) and an ENGINE leg (the full Weinstein Cell-E engine) — then
    hands both thunks to {!Barbell.Barbell_runner.run}.

    {b No core-module edits.} Each leg reuses {!Backtest.Runner} unchanged
    (Option A of [dev/plans/barbell-deployable-overlay-2026-06-21.md]); this
    module only orchestrates two of its runs and projects each result's [steps]
    into the [(date, value)] equity series the blend core consumes. It is a thin
    library mirroring {!Rolling_start.Rolling_start_runner}'s split: a bin
    ([barbell_overlay_runner]) is a CLI shim over {!run}, which is unit-testable
    on a tiny fixture universe without a CLI.

    Default-off per [.claude/rules/experiment-flag-discipline.md]: {!run} is
    only invoked when a caller opts in; the {!Barbell.Barbell_config.t} it
    threads through still defaults to the pure-engine no-op. *)

open Core

type leg_spec = {
  name : string;
      (** Human-readable leg label threaded into the resulting
          {!Barbell.Barbell_runner.leg_result}, e.g. ["floor"] / ["engine"]. *)
  strategy : Backtest.Strategy_choice.t;
      (** Which strategy {!Backtest.Runner.run_backtest} instantiates for this
          leg. *)
  overrides : Sexp.t list;
      (** Per-leg partial-config sexps deep-merged into the default Weinstein
          config, in order — the same shape as
          {!Scenario_lib.Scenario.t.config_overrides}. Empty list = the leg's
          default config. *)
}
(** One barbell leg's run recipe: a label, a strategy choice, and config
    overrides. The scenario supplies the shared period / universe / snapshot
    context; the leg supplies what differs between the FLOOR and ENGINE runs. *)

val spy_floor_leg :
  ?symbol:string ->
  ?ma_period_weeks:int ->
  ?overrides:Sexp.t list ->
  unit ->
  leg_spec
(** [spy_floor_leg ()] is the canonical FLOOR leg: a single-instrument
    {!Backtest.Strategy_choice.Spy_only_weinstein} run on [symbol] (default
    ["SPY"]) at [ma_period_weeks] (default [30], Weinstein's investor preset).
    This is the SPY-timing floor the validated barbell pairs with the engine
    (see [dev/backtest/barbell-grid-2026-06-20/FINDINGS.md]). [overrides]
    (default [[]]) are extra per-leg config sexps. Named ["floor"]. *)

val engine_leg :
  ?strategy:Backtest.Strategy_choice.t ->
  ?overrides:Sexp.t list ->
  unit ->
  leg_spec
(** [engine_leg ()] is the canonical ENGINE leg: the full Weinstein Cell-E
    engine ([strategy] defaults to {!Backtest.Strategy_choice.Weinstein}) with
    [overrides] (default [[]]). Named ["engine"]. Pass [~strategy] /
    [~overrides] to run a different engine preset (e.g. a scenario's own
    [strategy] + [config_overrides]). *)

val run :
  scenario:Scenario_lib.Scenario.t ->
  fixtures_root:string ->
  bar_data_source:Backtest.Bar_data_source.t option ->
  config:Barbell.Barbell_config.t ->
  floor:leg_spec ->
  engine:leg_spec ->
  Barbell.Barbell_runner.t
(** [run ~scenario ~fixtures_root ~bar_data_source ~config ~floor ~engine] runs
    the barbell overlay end-to-end:

    + resolves the [scenario]'s [universe_path] (relative to [fixtures_root])
      into the sector-map override both legs trade over — mirrors
      [scenario_runner]'s universe resolution, so the two sleeves see the same
      universe;
    + builds a thunk per leg that calls {!Backtest.Runner.run_backtest} over the
      [scenario]'s period with that leg's [strategy] + [overrides] (and the
      shared [sector_map_override] + [bar_data_source]), then projects the run's
      [steps] into an equity curve via
      {!Barbell.Barbell_runner.equity_curve_of_steps};
    + hands both thunks + [config] to {!Barbell.Barbell_runner.run}, which
      forces them, blends the two curves at [config]'s cadence, and returns the
      combined {!Barbell.Barbell_runner.t}.

    The returned value carries the per-leg results and the blended NAV path;
    write the combined curve with {!Barbell.Barbell_runner.write_equity_curve}.

    @raise Invalid_argument
      if [config] fails {!Barbell.Barbell_config.validate} (raised by
      {!Barbell.Barbell_runner.run}). *)
