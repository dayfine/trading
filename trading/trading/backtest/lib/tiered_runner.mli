(** Tiered [loader_strategy] execution path for {!Runner}.

    Split out of [runner.ml] so the file-length linter stays under 300 lines and
    the Legacy vs Tiered paths are obviously parallel at the module boundary.
    The public entry point is {!run} — everything else is private to the module.

    This extraction (3f-part3a) is a refactor-only slice: the body of [run] is
    byte-identical in observable behaviour to the previous inline
    [Runner._run_tiered_backtest] — it bulk-promotes to Metadata under a
    [Load_bars] trace wrap and then raises [Failure] at the simulator-cycle
    step. The real Friday Summary-promote / Shadow_screener / Full-promote cycle
    and the per-transition promote/demote bookkeeping land in 3f-part3b via a
    [Tiered_strategy_wrapper] atop [Weinstein_strategy]. See
    [dev/plans/backtest-tiered-loader-2026-04-19.md]. *)

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
    public surface. [ad_bars] and [config] are unused in 3f-part3a (the
    simulator cycle is still [failwith]'d) but part of the stable shape — they
    get threaded into the inner Weinstein strategy once 3f-part3b lands. *)

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

    In 3f-part3a this function only performs the pre-simulator bootstrap —
    builds a [Bar_loader] with a [trace_hook] bridging [tier_op] → phase,
    bulk-promotes [input.all_symbols] to Metadata under a [Load_bars] trace
    wrap, and then raises [Failure] at the simulator-cycle step. The
    [warmup_days], [initial_cash], and [commission] arguments are accepted as
    part of the stable interface but unused until 3f-part3b drops the [failwith]
    and wires a real [Simulator.run] through a [Tiered_strategy_wrapper].

    Raises [Failure] on any of: loader bulk-promote hard error, the intentional
    simulator-cycle step placeholder. *)
