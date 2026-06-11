(** Strategy-integration layer for {!Harvest_rotate_runner}.

    Builds the pure runner's inputs from the live strategy context — the
    screening-day (Friday) gate and the [config.harvest_fraction] dial — and
    emits the exit-side audit for the resulting trims. Extracted from
    {!Weinstein_strategy} so the top-level strategy module stays within its
    length budget (mirrors {!Macro_bearish_trim_wiring}). *)

open Core
open Trading_strategy

val run :
  config:Weinstein_strategy_config.config ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  audit_recorder:Audit_recorder.t ->
  prior_macro_result:Macro.result option ref ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Position.transition list
(** Run the harvest-rotate pass. No-op [[]] unless
    [config.enable_harvest_rotate] is set; otherwise, on a screening (Friday)
    day, trims [config.harvest_fraction] of every held [Stage2 { late = true }]
    long via {!Harvest_rotate_runner.update} (a [TriggerPartialExit] per
    position) and emits the exit-side audit for the resulting transitions.

    The exit audit ({!Exit_audit_capture.emit_exit_audit}) is currently a no-op
    on [TriggerPartialExit] (partial-exit MFE/MAE capture is deferred); it is
    piped through for uniformity with the other exit runners and must run while
    [positions] still holds the (un-trimmed) position. Default-off preserves all
    baselines — the disabled path is byte-identical to baseline regardless of
    [config.harvest_fraction]. *)
