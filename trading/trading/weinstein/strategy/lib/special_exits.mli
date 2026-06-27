(** Special-exit channels for the Weinstein strategy's per-tick output.

    Runs the post-stops exit channels — force-liquidation, Stage-3 force-exit,
    laggard-rotation, and the liquidity-degradation exit — threading a single
    force-exit channel through them: each channel drops the positions already
    exiting via an earlier channel this tick and the running skip-id set
    accumulates. Each channel is Friday-gated and default-off, so the disabled
    path is bit-identical to baseline.

    Extracted from {!Weinstein_strategy} so the top-level strategy module stays
    within its file-length budget (mirrors {!Harvest_rotate_wiring}). *)

open Core
open Trading_strategy

val run :
  config:Weinstein_strategy_config.config ->
  record_force_exit:
    (last_stop_out_dates:Date.t Hashtbl.M(String).t ->
    positions:Position.t Map.M(String).t ->
    current_date:Date.t ->
    cooldown_weeks:int ->
    label:string ->
    Position.transition ->
    unit) ->
  positions:Position.t Map.M(String).t ->
  last_stop_out_dates:Date.t Hashtbl.M(String).t ->
  portfolio:Portfolio_view.t ->
  get_price:Strategy_interface.get_price_fn ->
  peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.t ->
  audit_recorder:Audit_recorder.t ->
  prior_macro_result:Macro.result option ref ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  prior_stage_ma_values:float Hashtbl.M(String).t ->
  stage3_streaks:int Hashtbl.M(String).t ->
  laggard_streaks:int Hashtbl.M(String).t ->
  bar_reader:Bar_reader.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  exit_transitions:Position.transition list ->
  current_date:Date.t ->
  Position.transition list
  * Position.transition list
  * Position.transition list
  * String.Set.t
  * String.Set.t
  * String.Set.t
(** Run the special-exit channels for one market day. Returns
    [(force_exit_transitions, stage3_force_exit_transitions,
     laggard_rotation_transitions, stop_exited_ids, stage3_exited_ids,
     laggard_exited_ids)].

    [exit_transitions] are this tick's stop-out transitions (their position-ids
    seed the skip set so force-liquidation never double-exits a stopped name).
    [record_force_exit] stamps the reentry-cooldown table for laggard / Stage-3
    / liquidity exits; it is supplied by the strategy so this module carries no
    dependency on the cooldown plumbing.

    The liquidity-degradation exits are merged (prepended) into the returned
    force-exit channel — same close-fill convention + audit path. No-op at the
    default config (every channel disabled / [min_hold_dollar_adv = 0.0]), so
    the returned transitions are bit-identical to baseline. *)
