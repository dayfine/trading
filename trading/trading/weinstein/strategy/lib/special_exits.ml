open Core
open Trading_strategy
open Weinstein_strategy_config

(* The special-exit channels run after the daily stops pass: force-liquidation,
   Stage-3 force-exit, laggard-rotation, and the liquidity-degradation exit.
   [run] threads a single force-exit channel through them, dropping positions
   already exiting via an earlier channel this tick and accumulating the skip-id
   set. Each [_run_*] channel is Friday-gated and default-off (returns [[]] at
   the default config), so the disabled path is bit-identical to baseline.

   [record_force_exit] is supplied by the strategy (it stamps the reentry
   cooldown table) so this module carries no dependency on the cooldown plumbing.
   Extracted from [weinstein_strategy.ml] to keep that coordinator under the
   file-length cap. *)

let _run_laggard_rotation ~config ~record_force_exit ~positions
    ~last_stop_out_dates ~bar_reader ~get_price ~laggard_streaks ~is_friday
    ~skip_ids ~current_date =
  let laggard_ts =
    if config.enable_laggard_rotation then
      Laggard_rotation_runner.update ~config:config.laggard_rotation_config
        ~benchmark_symbol:config.indices.primary ~is_screening_day:is_friday
        ~positions ~bar_reader ~get_price ~laggard_streaks
        ~skip_position_ids:skip_ids ~current_date
    else []
  in
  List.iter laggard_ts
    ~f:
      (record_force_exit ~last_stop_out_dates ~positions ~current_date
         ~cooldown_weeks:config.laggard_reentry_cooldown_weeks
         ~label:"laggard_rotation");
  laggard_ts

let _run_liquidity_exit ~config ~record_force_exit ~positions
    ~last_stop_out_dates ~bar_reader ~get_price ~is_friday ~skip_ids
    ~current_date =
  let liquidity_ts =
    Liquidity_exit_runner.update ~config:config.liquidity_config
      ~is_screening_day:is_friday ~positions ~bar_reader ~get_price
      ~skip_position_ids:skip_ids ~current_date
  in
  List.iter liquidity_ts
    ~f:
      (record_force_exit ~last_stop_out_dates ~positions ~current_date
         ~cooldown_weeks:0 ~label:"liquidity_exit");
  liquidity_ts

let _run_stage3_force_exit ~config ~record_force_exit ~positions
    ~last_stop_out_dates ~prior_stage_ma_values ~stage3_streaks ~get_price
    ~prior_stages ~is_friday ~stop_exited_ids ~current_date =
  let stage3_ts =
    if config.enable_stage3_force_exit then
      Stage3_force_exit_runner.update ~config:config.stage3_force_exit_config
        ~exit_margin_pct:config.stage3_exit_margin_pct
        ~prior_stage_ma_values:(Some prior_stage_ma_values)
        ~is_screening_day:is_friday ~positions ~get_price ~prior_stages
        ~stage3_streaks ~stop_exit_position_ids:stop_exited_ids ~current_date
    else []
  in
  List.iter stage3_ts
    ~f:
      (record_force_exit ~last_stop_out_dates ~positions ~current_date
         ~cooldown_weeks:config.stage3_reentry_cooldown_weeks
         ~label:"stage3_force_exit");
  stage3_ts

(* Emit a special-exit channel's transitions to audit, then drop the positions
   it exited from the force-exit channel. Returns the channel's exited-id set
   (so callers can accumulate the running skip set) and the trimmed force-exit
   list. *)
let _apply_exit_channel ~emit_audit ts ~force_exit_ts =
  emit_audit ts;
  let exited_ids = Transition_assembly.trigger_exit_ids_of ts in
  ( exited_ids,
    Transition_assembly.filter_out_exited_ids exited_ids force_exit_ts )

(* Liquidity-degradation exit: emitted last among the special exits and merged
   into the force-exit channel (same close-fill convention + audit path). Skips
   every position already exiting this tick via ANY of the four prior channels:
   stop, force-liquidation, Stage-3 force-exit, and laggard-rotation. The caller
   passes their union as [skip_ids] — it cannot be reconstructed from
   [force_exit_ts] alone, because [_apply_exit_channel] FILTERS the Stage-3 and
   laggard ids OUT of [force_exit_ts] (they are returned in their own id sets),
   so [trigger_exit_ids_of force_exit_ts] omits them. Without all four channels
   in this skip set, a position exited via stop / force-liq / Stage-3 / laggard
   AND below the held-liquidity floor on the same tick would also get a
   liquidity [TriggerExit] — two exits merged into one channel, which the
   Position state machine rejects from a non-Holding state. No-op at the default
   config (min_hold_dollar_adv = 0.0). Returns the force-exit channel with the
   liquidity exits prepended. *)
let _run_liquidity_special_exit ~config ~record_force_exit ~positions
    ~last_stop_out_dates ~bar_reader ~get_price ~is_friday ~emit_audit ~skip_ids
    ~force_exit_ts ~current_date =
  let liquidity_ts =
    _run_liquidity_exit ~config ~record_force_exit ~positions
      ~last_stop_out_dates ~bar_reader ~get_price ~is_friday ~skip_ids
      ~current_date
  in
  emit_audit liquidity_ts;
  liquidity_ts @ force_exit_ts

(* The union of every position-id already exiting this tick via any of the four
   prior channels (stop, force-liq, Stage-3, laggard) — the liquidity exit's
   skip set. Stage-3/laggard ids are NOT recoverable from [force_exit_ts] (they
   were filtered out of it by [_apply_exit_channel]), so the union is assembled
   from the channel id sets directly. *)
let _liquidity_skip_ids ~force_exit_ts ~stop_exited_ids ~stage3_exited_ids
    ~laggard_exited_ids =
  Set.union
    (Transition_assembly.trigger_exit_ids_of force_exit_ts)
    (Set.union stop_exited_ids (Set.union stage3_exited_ids laggard_exited_ids))

(* Build the base force-liquidation channel: run the force-liq runner, then drop
   positions already exiting via a stop this tick. Returns the trimmed channel
   plus the stop-exited id set used to seed the running skip set. *)
let _build_force_exit_channel ~config ~positions ~get_price ~cash ~peak_tracker
    ~audit_recorder ~exit_transitions ~current_date =
  let raw_force_exit_ts =
    Force_liquidation_runner.update
      ~config:config.portfolio_config.force_liquidation ~positions ~get_price
      ~cash ~current_date ~peak_tracker ~audit_recorder
  in
  let stop_exited_ids =
    Transition_assembly.trigger_exit_ids_of exit_transitions
  in
  ( Transition_assembly.filter_out_exited_ids stop_exited_ids raw_force_exit_ts,
    stop_exited_ids )

let run ~config ~record_force_exit ~positions ~last_stop_out_dates
    ~(portfolio : Portfolio_view.t) ~get_price ~peak_tracker ~audit_recorder
    ~prior_macro_result ~prior_stages ~prior_stage_ma_values ~stage3_streaks
    ~laggard_streaks ~bar_reader ~index_view ~exit_transitions ~current_date =
  let emit_audit =
    Exit_audit_capture.emit_for_list ~config ~audit_recorder ~prior_macro_result
      ~bar_reader ~prior_stages ~positions
  in
  let apply_exit_channel = _apply_exit_channel ~emit_audit in
  let force_exit_ts, stop_exited_ids =
    _build_force_exit_channel ~config ~positions ~get_price ~cash:portfolio.cash
      ~peak_tracker ~audit_recorder ~exit_transitions ~current_date
  in
  let is_friday =
    Weinstein_strategy_screening.is_screening_day_view index_view
  in
  let stage3_ts =
    _run_stage3_force_exit ~config ~record_force_exit ~positions
      ~last_stop_out_dates ~prior_stage_ma_values ~stage3_streaks ~get_price
      ~prior_stages ~is_friday ~stop_exited_ids ~current_date
  in
  let stage3_exited_ids, force_exit_ts =
    apply_exit_channel stage3_ts ~force_exit_ts
  in
  let laggard_ts =
    _run_laggard_rotation ~config ~record_force_exit ~positions
      ~last_stop_out_dates ~bar_reader ~get_price ~laggard_streaks ~is_friday
      ~skip_ids:(Set.union stop_exited_ids stage3_exited_ids)
      ~current_date
  in
  let laggard_exited_ids, force_exit_ts =
    apply_exit_channel laggard_ts ~force_exit_ts
  in
  emit_audit force_exit_ts;
  let skip_ids =
    _liquidity_skip_ids ~force_exit_ts ~stop_exited_ids ~stage3_exited_ids
      ~laggard_exited_ids
  in
  let force_exit_ts =
    _run_liquidity_special_exit ~config ~record_force_exit ~positions
      ~last_stop_out_dates ~bar_reader ~get_price ~is_friday ~emit_audit
      ~skip_ids ~force_exit_ts ~current_date
  in
  ( force_exit_ts,
    stage3_ts,
    laggard_ts,
    stop_exited_ids,
    stage3_exited_ids,
    laggard_exited_ids )
