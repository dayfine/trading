(** Tiered [loader_strategy] execution path for {!Runner}.

    Split out of [runner.ml] so the file-length linter stays under 300 lines and
    the Legacy vs Tiered paths are obviously parallel at the module boundary.
    The public entry point is {!run} — everything else is private to the module.

    Flow per plan §3f-part3 (see
    [dev/plans/backtest-tiered-loader-2026-04- 19.md]):

    1. Build a [Bar_loader] over the runner-provided universe with a
    [trace_hook] that bridges [Bar_loader.tier_op] onto [Trace.Phase.t]. 2.
    Bulk-promote the universe to [Metadata_tier] under a [Load_bars] wrap. 3.
    Drive the simulator with a [Tiered_strategy_wrapper]-wrapped Weinstein
    strategy. The wrapper adds Friday Summary-promote + Shadow_screener +
    Full-promote-top-N, per-[CreateEntering] Full promote, and
    per-newly-[Closed] Metadata demote.

    The simulator transitions are byte-identical to the Legacy path — the
    wrapper is purely additive. The 3g parity gate locks this in. *)

open Core

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}
(** Minimal [_deps] subset Tiered_runner needs. Kept as a plain record so
    [Runner] can build it without threading its private [_deps] type through the
    public surface. *)

val tier_op_to_phase : Bar_loader.tier_op -> Trace.Phase.t
(** Map a [Bar_loader.tier_op] (the library-internal tier-op tag) onto the
    corresponding [Trace.Phase.t] emitted by the Tiered runner path. Exposed so
    the trace bridging is observable from unit tests without reaching into
    private helpers. Pure — depends only on the input variant. *)

val run :
  input:input ->
  start_date:Core.Date.t ->
  end_date:Core.Date.t ->
  warmup_days:int ->
  initial_cash:float ->
  commission:Trading_engine.Types.commission_config ->
  ?trace:Trace.t ->
  unit ->
  Trading_simulation_types.Simulator_types.run_result * Stop_log.t
(** [run ~input ~start_date ~end_date ~warmup_days ~initial_cash ~commission]
    runs the Tiered simulator cycle and returns [(sim_result, stop_log)] — the
    same shape [Runner] expects from the Legacy path.

    Internally:
    - Builds a [Bar_loader] with a trace_hook bridging [tier_op] → phase.
    - Bulk-promotes [input.all_symbols] to Metadata under a [Load_bars] trace
      wrap.
    - Constructs a Weinstein strategy wrapped by [Tiered_strategy_wrapper] and
      runs [Simulator.run] under a [Fill] trace wrap.

    Raises [Failure] if the loader's bulk promote fails with a hard data error,
    or if [Simulator.create] / [Simulator.run] errors. *)
