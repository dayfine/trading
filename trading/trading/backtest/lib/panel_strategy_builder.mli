(** Strategy dispatch for the panel runner.

    Extracted from [panel_runner.ml] so the runner module stays under the
    file-length limit. Pure dispatch: each branch maps a {!Strategy_choice.t}
    variant to its constructed strategy module, threading the runner's
    deps-loaded inputs through to the per-strategy constructor. *)

open Core

val build :
  ad_bars:Macro.ad_bar list ->
  ticker_sectors:(string, string) Hashtbl.t ->
  config:Weinstein_strategy.config ->
  strategy_choice:Strategy_choice.t ->
  bar_reader:Weinstein_strategy.Bar_reader.t ->
  audit_recorder:Weinstein_strategy.Audit_recorder.t ->
  ?fold_start_date:Date.t ->
  unit ->
  (module Trading_strategy.Strategy_interface.STRATEGY)
(** [build ~ad_bars ~ticker_sectors ~config ~strategy_choice ~bar_reader
     ~audit_recorder ?fold_start_date ()] constructs the strategy module the
    simulator will run.

    The [Weinstein] branch threads the runner's deps-loaded inputs (AD bars,
    sector map, config) through {!Weinstein_strategy.make}. The [Bah_benchmark]
    branch ignores all of that machinery — BAH is a single-symbol passive
    strategy that needs only its own [config.symbol]. The [bar_reader] /
    [audit_recorder] are dropped on the BAH branch: BAH reads prices via
    [get_price] (the snapshot-backed [Market_data_adapter]) and emits no audit
    events.

    @param fold_start_date
      Win #4 opt-in (production wiring; see
      [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4). When [Some d], the
      [Weinstein] branch forwards it to {!Weinstein_strategy.make}'s
      [?fold_start_date], enabling per-fold universe pre-pruning at the
      screener: symbols whose [Bar_reader]-exposed [active_through] is strictly
      before [d] are dropped before Phase-1 stage classification. This is
      point-in-time correct (removes symbols genuinely uninvestable at the fold
      start), NOT survivor bias. Default [None] preserves bit-equal baselines —
      no pre-pruning, every universe symbol is classified. Only the [Weinstein]
      branch consumes it; the other strategy constructors take no universe
      (Spy_only / BAH) or manage their own (Sector_rotation), so
      [fold_start_date] is irrelevant there and ignored. *)
