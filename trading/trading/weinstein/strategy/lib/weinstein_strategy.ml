open Core
open Trading_strategy
module Bar_reader = Bar_reader
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
module S = Weinstein_strategy_screening

let held_symbols = S.held_symbols
let entries_from_candidates = S.entries_from_candidates
let survivors_for_screening = S.survivors_for_screening

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

let _maybe_reset_halt ~peak_tracker
    ~(macro_trend : Weinstein_types.market_trend) =
  match macro_trend with
  | Weinstein_types.Bearish -> ()
  | Weinstein_types.Bullish | Weinstein_types.Neutral ->
      Portfolio_risk.Force_liquidation.Peak_tracker.reset peak_tracker

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

let _run_stops_pass ~config ~positions ~stop_states ~bar_reader ~prior_stages
    ~get_price ~last_stop_out_dates ~audit_recorder ~prior_macro_result
    ~current_date =
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader
    ~as_of:current_date;
  let exit_transitions, adjust_transitions =
    Stops_runner.update
      ?ma_cache:(Bar_reader.ma_cache bar_reader)
      ~stop_update_cadence:config.stop_update_cadence
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

let _run_special_exits ~config ~positions ~(portfolio : Portfolio_view.t)
    ~get_price ~peak_tracker ~audit_recorder ~prior_stages ~stage3_streaks
    ~laggard_streaks ~bar_reader ~index_view ~exit_transitions ~current_date =
  let cash = portfolio.cash in
  let raw_force_exit_ts =
    Force_liquidation_runner.update
      ~config:config.portfolio_config.force_liquidation ~positions ~get_price
      ~cash ~current_date ~peak_tracker ~audit_recorder
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
        ~is_screening_day:is_friday ~positions ~get_price ~prior_stages
        ~stage3_streaks ~stop_exit_position_ids:stop_exited_ids ~current_date
    else []
  in
  let stage3_exited_ids = _trigger_exit_ids_of stage3_ts in
  let force_exit_ts = _filter_out_exited_ids stage3_exited_ids force_exit_ts in
  let laggard_ts =
    if config.enable_laggard_rotation then
      let skip_ids = Set.union stop_exited_ids stage3_exited_ids in
      Laggard_rotation_runner.update ~config:config.laggard_rotation_config
        ~benchmark_symbol:config.indices.primary ~is_screening_day:is_friday
        ~positions ~bar_reader ~get_price ~laggard_streaks
        ~skip_position_ids:skip_ids ~current_date
    else []
  in
  let laggard_exited_ids = _trigger_exit_ids_of laggard_ts in
  let force_exit_ts = _filter_out_exited_ids laggard_exited_ids force_exit_ts in
  ( force_exit_ts,
    stage3_ts,
    laggard_ts,
    stop_exited_ids,
    stage3_exited_ids,
    laggard_exited_ids )

let _run_macro_and_entries ~config ~ad_bars ~stop_states ~last_stop_out_dates
    ~prior_macro ~prior_macro_result ~peak_tracker ~bar_reader ~prior_stages
    ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio ~current_date
    ~index_view ~audit_recorder =
  let is_screening_day =
    Weinstein_strategy_screening.is_screening_day_view index_view
  in
  let macro_result_opt =
    if is_screening_day then
      Some
        (Weinstein_strategy_macro.run_macro_only ~config ~ad_bars ~prior_macro
           ~prior_macro_result ~bar_reader ~prior_stages ~current_date
           ~index_view)
    else None
  in
  if is_screening_day then
    _maybe_reset_halt ~peak_tracker ~macro_trend:!prior_macro;
  let halted =
    match
      Portfolio_risk.Force_liquidation.Peak_tracker.halt_state peak_tracker
    with
    | Halted -> true
    | Active -> false
  in
  Weinstein_strategy_macro.entry_transitions_if_active ~halted ~is_screening_day
    ~macro_result_opt ~config ~stop_states ~last_stop_out_dates ~bar_reader
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
    ~current_date ~index_view ~audit_recorder

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

let _process_market_day ~config ~ad_bars ~stop_states ~last_stop_out_dates
    ~prior_macro ~prior_macro_result ~peak_tracker ~bar_reader ~prior_stages
    ~sector_prior_stages ~ticker_sectors ~stage3_streaks ~laggard_streaks
    ~audit_recorder ~get_price ~(portfolio : Portfolio_view.t) ~current_date =
  let positions = portfolio.positions in
  let exit_transitions, adjust_transitions =
    _run_stops_pass ~config ~positions ~stop_states ~bar_reader ~prior_stages
      ~get_price ~last_stop_out_dates ~audit_recorder ~prior_macro_result
      ~current_date
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
    _run_special_exits ~config ~positions ~portfolio ~get_price ~peak_tracker
      ~audit_recorder ~prior_stages ~stage3_streaks ~laggard_streaks ~bar_reader
      ~index_view ~exit_transitions ~current_date
  in
  let entry_transitions =
    _run_macro_and_entries ~config ~ad_bars ~stop_states ~last_stop_out_dates
      ~prior_macro ~prior_macro_result ~peak_tracker ~bar_reader ~prior_stages
      ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio ~current_date
      ~index_view ~audit_recorder
  in
  _assemble_output ~exit_transitions ~stage3_force_exit_transitions
    ~laggard_rotation_transitions ~force_exit_transitions ~adjust_transitions
    ~entry_transitions ~stop_exited_ids ~stage3_exited_ids ~laggard_exited_ids

let _on_market_close ~config ~ad_bars ~stop_states ~last_stop_out_dates
    ~prior_macro ~prior_macro_result ~peak_tracker ~bar_reader ~prior_stages
    ~sector_prior_stages ~ticker_sectors ~stage3_streaks ~laggard_streaks
    ~audit_recorder ~get_price ~get_indicator:_ ~(portfolio : Portfolio_view.t)
    =
  match get_price config.indices.primary with
  | None -> Ok { Strategy_interface.transitions = [] }
  | Some primary_bar ->
      let current_date = primary_bar.Types.Daily_price.date in
      _process_market_day ~config ~ad_bars ~stop_states ~last_stop_out_dates
        ~prior_macro ~prior_macro_result ~peak_tracker ~bar_reader ~prior_stages
        ~sector_prior_stages ~ticker_sectors ~stage3_streaks ~laggard_streaks
        ~audit_recorder ~get_price ~portfolio ~current_date

let _init_strategy_state ~initial_stop_states ~ad_bars =
  let stop_states = ref initial_stop_states in
  let last_stop_out_dates : Date.t Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let prior_macro : Weinstein_types.market_trend ref =
    ref Weinstein_types.Neutral
  in
  let peak_tracker = Portfolio_risk.Force_liquidation.Peak_tracker.create () in
  let prior_macro_result : Macro.result option ref = ref None in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
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
    sector_prior_stages,
    stage3_streaks,
    laggard_streaks,
    weekly_ad_bars )

let make ?(initial_stop_states = String.Map.empty) ?(ad_bars = [])
    ?(ticker_sectors = Hashtbl.create (module String)) ?bar_reader
    ?(audit_recorder = Audit_recorder.noop) config =
  let bar_reader =
    match bar_reader with Some r -> r | None -> Bar_reader.empty ()
  in
  let ( stop_states,
        last_stop_out_dates,
        prior_macro,
        peak_tracker,
        prior_macro_result,
        prior_stages,
        sector_prior_stages,
        stage3_streaks,
        laggard_streaks,
        weekly_ad_bars ) =
    _init_strategy_state ~initial_stop_states ~ad_bars
  in
  let module M = struct
    let name = name

    let on_market_close =
      _on_market_close ~config ~ad_bars:weekly_ad_bars ~stop_states
        ~last_stop_out_dates ~prior_macro ~prior_macro_result ~peak_tracker
        ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors
        ~stage3_streaks ~laggard_streaks ~audit_recorder
  end in
  (module M : Strategy_interface.STRATEGY)

module Internal_for_test = struct
  let on_market_close = _on_market_close
  let maybe_reset_halt = _maybe_reset_halt
  let positions_minus_exited = _positions_minus_exited
end
