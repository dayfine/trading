(* @large-module: top-level strategy entry point — on_market_close orchestrates
   stops + macro + screener + force-liquidation + stage3-exit + laggard-rotation
   passes through closure-scoped state; closes 2026-05-12 Portfolio_floor
   death-loop fix in _maybe_reset_halt + _run_macro_and_entries *)
open Core
open Trading_strategy
module Bar_reader = Bar_reader
module Spy_only_weinstein_strategy = Spy_only_weinstein_strategy
module Stops_runner = Stops_runner
module Stops_split_runner = Stops_split_runner
module Force_liquidation_runner = Force_liquidation_runner
module Stage3_force_exit_runner = Stage3_force_exit_runner
module Laggard_rotation_runner = Laggard_rotation_runner
module Stage3_force_exit = Stage3_force_exit
module Laggard_rotation = Laggard_rotation
module Ad_bars = Ad_bars
module Macro_inputs = Macro_inputs
module Panel_callbacks = Panel_callbacks
module Weekly_ma_cache = Weekly_ma_cache
module Audit_recorder = Audit_recorder
module Entry_audit_capture = Entry_audit_capture
module Exit_audit_capture = Exit_audit_capture
include Weinstein_strategy_config
module Weinstein_strategy_macro = Weinstein_strategy_macro
module Weinstein_strategy_config = Weinstein_strategy_config
module S = Weinstein_strategy_screening

let held_symbols = S.held_symbols
let entries_from_candidates = S.entries_from_candidates
let survivors_for_screening = S.survivors_for_screening
let prune_universe_by_active_through = S.prune_universe_by_active_through

let _trigger_exit_ids_of (ts : Position.transition list) : String.Set.t =
  List.filter_map ts ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.TriggerExit _ -> Some t.position_id
      | _ -> None)
  |> String.Set.of_list

let _filter_out_exited_ids exited_ids (ts : Position.transition list) :
    Position.transition list =
  if Set.is_empty exited_ids then ts
  else
    List.filter ts ~f:(fun (t : Position.transition) ->
        not (Set.mem exited_ids t.position_id))

let _positions_minus_exited ~(positions : Position.t Map.M(String).t)
    ~(stop_exit_transitions : Position.transition list) :
    Position.t Map.M(String).t =
  let exited_ids = _trigger_exit_ids_of stop_exit_transitions in
  if Set.is_empty exited_ids then positions
  else
    Map.filter positions ~f:(fun (p : Position.t) ->
        not (Set.mem exited_ids p.id))

(* Transition-only reset — see .mli for full contract. *)
let _maybe_reset_halt ~peak_tracker ~prior_macro ~current_macro =
  let open Weinstein_types in
  match (prior_macro, current_macro) with
  | Bearish, (Bullish | Neutral) ->
      Portfolio_risk.Force_liquidation.Peak_tracker.reset peak_tracker
  | _ -> ()

let _symbol_of_position_id ~(positions : Position.t Map.M(String).t) id =
  Map.data positions
  |> List.find ~f:(fun (p : Position.t) -> String.equal p.id id)
  |> Option.map ~f:(fun (p : Position.t) -> p.symbol)

let _handle_stop_out_transition ~last_stop_out_dates ~positions ~current_date
    (t : Position.transition) =
  match t.kind with
  | Position.TriggerExit { exit_reason = Position.StopLoss _; _ } -> (
      match _symbol_of_position_id ~positions t.position_id with
      | Some symbol ->
          Hashtbl.set last_stop_out_dates ~key:symbol ~data:current_date
      | None -> ())
  | _ -> ()

(* Stamp the cooldown table for one position-id, no-op when the position has
   already been pruned. Extracted from [_record_force_exit] so the nested
   match against [_symbol_of_position_id] doesn't push depth past the linter's
   max-5 ceiling. *)

(** Record stage3 / laggard force-exit dates into [last_stop_out_dates] when the
    corresponding reentry cooldown knob is enabled. Re-uses the existing
    [Screener.screen_with_cooldown] gate (which keys on [last_stop_out_dates])
    instead of adding a separate map / cooldown knob. When the per-source
    cooldown knob is [0] (default), this is a no-op — preserves the pre-feature
    goldens bit-equal. Decoupling from the screener-level
    [cascade_post_stop_cooldown_weeks] is the responsibility of a follow-up: the
    screener applies a single window today; widening that to a per-source window
    is out of scope for the continuation-buys PR (issue #889). *)
let _stamp_cooldown ~last_stop_out_dates ~positions ~current_date position_id =
  match _symbol_of_position_id ~positions position_id with
  | Some symbol ->
      Hashtbl.set last_stop_out_dates ~key:symbol ~data:current_date
  | None -> ()

let _record_force_exit ~last_stop_out_dates ~positions ~current_date
    ~cooldown_weeks ~(label : string) (t : Position.transition) =
  if cooldown_weeks <= 0 then ()
  else
    match t.kind with
    | Position.TriggerExit
        { exit_reason = Position.StrategySignal { label = l; _ }; _ }
      when String.equal l label ->
        _stamp_cooldown ~last_stop_out_dates ~positions ~current_date
          t.position_id
    | _ -> ()

let _run_stops_pass ~config ~positions ~stop_states ~bar_reader ~prior_stages
    ~prior_stage_ma_values ~get_price ~last_stop_out_dates ~audit_recorder
    ~prior_macro_result ~current_date =
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:current_date;
  let exit_transitions, adjust_transitions =
    Stops_runner.update
      ?ma_cache:(Bar_reader.ma_cache bar_reader)
      ~stop_update_cadence:config.stop_update_cadence ~prior_stage_ma_values
      ~stops_config:config.stops_config ~stage_config:config.stage_config
      ~lookback_bars:config.lookback_bars ~positions ~get_price ~stop_states
      ~bar_reader ~as_of:current_date ~prior_stages ()
  in
  List.iter exit_transitions
    ~f:
      (_handle_stop_out_transition ~last_stop_out_dates ~positions ~current_date);
  List.iter exit_transitions
    ~f:
      (Exit_audit_capture.emit_exit_audit ~audit_recorder ~prior_macro_result
         ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
         ~bar_reader ~prior_stages ~positions);
  (exit_transitions, adjust_transitions)

let _run_laggard_rotation ~config ~positions ~last_stop_out_dates ~bar_reader
    ~get_price ~laggard_streaks ~is_friday ~skip_ids ~current_date =
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
      (_record_force_exit ~last_stop_out_dates ~positions ~current_date
         ~cooldown_weeks:config.laggard_reentry_cooldown_weeks
         ~label:"laggard_rotation");
  laggard_ts

let _run_special_exits ~config ~positions ~last_stop_out_dates
    ~(portfolio : Portfolio_view.t) ~get_price ~peak_tracker ~audit_recorder
    ~prior_stages ~prior_stage_ma_values ~stage3_streaks ~laggard_streaks
    ~bar_reader ~index_view ~exit_transitions ~current_date =
  let raw_force_exit_ts =
    Force_liquidation_runner.update
      ~config:config.portfolio_config.force_liquidation ~positions ~get_price
      ~cash:portfolio.cash ~current_date ~peak_tracker ~audit_recorder
  in
  let stop_exited_ids = _trigger_exit_ids_of exit_transitions in
  let force_exit_ts =
    _filter_out_exited_ids stop_exited_ids raw_force_exit_ts
  in
  let is_friday =
    Weinstein_strategy_screening.is_screening_day_view index_view
  in
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
      (_record_force_exit ~last_stop_out_dates ~positions ~current_date
         ~cooldown_weeks:config.stage3_reentry_cooldown_weeks
         ~label:"stage3_force_exit");
  let stage3_exited_ids = _trigger_exit_ids_of stage3_ts in
  let force_exit_ts = _filter_out_exited_ids stage3_exited_ids force_exit_ts in
  let laggard_ts =
    _run_laggard_rotation ~config ~positions ~last_stop_out_dates ~bar_reader
      ~get_price ~laggard_streaks ~is_friday
      ~skip_ids:(Set.union stop_exited_ids stage3_exited_ids)
      ~current_date
  in
  let laggard_exited_ids = _trigger_exit_ids_of laggard_ts in
  let force_exit_ts = _filter_out_exited_ids laggard_exited_ids force_exit_ts in
  ( force_exit_ts,
    stage3_ts,
    laggard_ts,
    stop_exited_ids,
    stage3_exited_ids,
    laggard_exited_ids )

let _run_macro_and_entries ~fold_start_date ~config ~ad_bars ~stop_states
    ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
    ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price
    ~portfolio ~current_date ~index_view ~audit_recorder =
  let is_screening_day =
    Weinstein_strategy_screening.is_screening_day_view index_view
  in
  let macro_result_opt =
    if is_screening_day then (
      let prev = !prior_macro in
      let r =
        Weinstein_strategy_macro.run_macro_only ~config ~ad_bars ~prior_macro
          ~prior_macro_result ~bar_reader ~prior_stages ~current_date
          ~index_view
      in
      _maybe_reset_halt ~peak_tracker ~prior_macro:prev ~current_macro:r.trend;
      Some r)
    else None
  in
  let halted =
    match
      Portfolio_risk.Force_liquidation.Peak_tracker.halt_state peak_tracker
    with
    | Halted -> true
    | Active -> false
  in
  Weinstein_strategy_macro.entry_transitions_if_active ~fold_start_date ~halted
    ~is_screening_day ~macro_result_opt ~config ~stop_states
    ~last_stop_out_dates ~bar_reader ~prior_stages ~sector_prior_stages
    ~ticker_sectors ~get_price ~portfolio ~current_date ~index_view
    ~audit_recorder

let _assemble_output ~exit_transitions ~stage3_force_exit_transitions
    ~laggard_rotation_transitions ~force_exit_transitions ~adjust_transitions
    ~entry_transitions ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids =
  let force_liq_exited_ids = _trigger_exit_ids_of force_exit_transitions in
  let all_exited_ids =
    Set.union_list
      (module String)
      [
        stop_exited_ids;
        stage3_exited_ids;
        laggard_exited_ids;
        force_liq_exited_ids;
      ]
  in
  let adjust_transitions =
    _filter_out_exited_ids all_exited_ids adjust_transitions
  in
  Ok
    {
      Strategy_interface.transitions =
        exit_transitions @ stage3_force_exit_transitions
        @ laggard_rotation_transitions @ force_exit_transitions
        @ adjust_transitions @ entry_transitions;
    }

let _process_market_day ~fold_start_date ~config ~ad_bars ~stop_states
    ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
    ~bar_reader ~prior_stages ~prior_stage_ma_values ~sector_prior_stages
    ~ticker_sectors ~stage3_streaks ~laggard_streaks ~audit_recorder ~get_price
    ~(portfolio : Portfolio_view.t) ~current_date =
  let positions = portfolio.positions in
  let exit_transitions, adjust_transitions =
    _run_stops_pass ~config ~positions ~stop_states ~bar_reader ~prior_stages
      ~prior_stage_ma_values ~get_price ~last_stop_out_dates ~audit_recorder
      ~prior_macro_result ~current_date
  in
  let index_view =
    Bar_reader.weekly_view_for bar_reader ~symbol:config.indices.primary
      ~n:config.lookback_bars ~as_of:current_date
  in
  let ( force_exit_transitions,
        stage3_force_exit_transitions,
        laggard_rotation_transitions,
        stop_exited_ids,
        stage3_exited_ids,
        laggard_exited_ids ) =
    _run_special_exits ~config ~positions ~last_stop_out_dates ~portfolio
      ~get_price ~peak_tracker ~audit_recorder ~prior_stages
      ~prior_stage_ma_values ~stage3_streaks ~laggard_streaks ~bar_reader
      ~index_view ~exit_transitions ~current_date
  in
  let entry_transitions =
    _run_macro_and_entries ~fold_start_date ~config ~ad_bars ~stop_states
      ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
      ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price
      ~portfolio ~current_date ~index_view ~audit_recorder
  in
  _assemble_output ~exit_transitions ~stage3_force_exit_transitions
    ~laggard_rotation_transitions ~force_exit_transitions ~adjust_transitions
    ~entry_transitions ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids

let _on_market_close ~fold_start_date ~config ~ad_bars ~stop_states
    ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
    ~bar_reader ~prior_stages ~prior_stage_ma_values ~sector_prior_stages
    ~ticker_sectors ~stage3_streaks ~laggard_streaks ~audit_recorder ~get_price
    ~get_indicator:_ ~(portfolio : Portfolio_view.t) =
  match get_price config.indices.primary with
  | None -> Ok { Strategy_interface.transitions = [] }
  | Some primary_bar ->
      let current_date = primary_bar.Types.Daily_price.date in
      _process_market_day ~fold_start_date ~config ~ad_bars ~stop_states
        ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
        ~bar_reader ~prior_stages ~prior_stage_ma_values ~sector_prior_stages
        ~ticker_sectors ~stage3_streaks ~laggard_streaks ~audit_recorder
        ~get_price ~portfolio ~current_date

let _init_strategy_state ~initial_stop_states ~ad_bars =
  let stop_states = ref initial_stop_states in
  let last_stop_out_dates : Date.t Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let prior_macro = ref Weinstein_types.Neutral in
  let peak_tracker = Portfolio_risk.Force_liquidation.Peak_tracker.create () in
  let prior_macro_result : Macro.result option ref = ref None in
  let prior_stages = Hashtbl.create (module String) in
  let prior_stage_ma_values : float Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let sector_prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let stage3_streaks : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let laggard_streaks : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let weekly_ad_bars = Ad_bars_aggregation.daily_to_weekly ad_bars in
  ( stop_states,
    last_stop_out_dates,
    prior_macro,
    peak_tracker,
    prior_macro_result,
    prior_stages,
    prior_stage_ma_values,
    sector_prior_stages,
    stage3_streaks,
    laggard_streaks,
    weekly_ad_bars )

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = [])
    ?(ticker_sectors = Hashtbl.create (module String)) ?bar_reader
    ?(audit_recorder = Audit_recorder.noop) ?fold_start_date config =
  let bar_reader =
    match bar_reader with Some r -> r | None -> Bar_reader.empty ()
  in
  let ( stop_states,
        last_stop_out_dates,
        prior_macro,
        peak_tracker,
        prior_macro_result,
        prior_stages,
        prior_stage_ma_values,
        sector_prior_stages,
        stage3_streaks,
        laggard_streaks,
        weekly_ad_bars ) =
    _init_strategy_state ~initial_stop_states ~ad_bars
  in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~fold_start_date ~config ~ad_bars:weekly_ad_bars
        ~stop_states ~last_stop_out_dates ~prior_macro ~prior_macro_result
        ~peak_tracker ~bar_reader ~prior_stages ~prior_stage_ma_values
        ~sector_prior_stages ~ticker_sectors ~stage3_streaks ~laggard_streaks
        ~audit_recorder
  end in
  (module M : Strategy_interface.STRATEGY)

module Internal_for_test = struct
  let on_market_close = _on_market_close
  let maybe_reset_halt = _maybe_reset_halt
  let positions_minus_exited = _positions_minus_exited
  let record_force_exit = _record_force_exit
end
