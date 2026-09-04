open Core
module Sim_types = Trading_simulation_types.Simulator_types

exception
  Empty_measurement_window of {
    start_date : Date.t;
    end_date : Date.t;
    n_sim_steps : int;
    n_steps_in_range : int;
  }

(** Human-readable rendering of an {!Empty_measurement_window} payload. Shared
    by the [Printexc] printer below and available to callers via
    [Printexc.to_string]. *)
let _empty_window_message ~start_date ~end_date ~n_sim_steps ~n_steps_in_range =
  sprintf
    "Backtest.Window_filter: measurement window %s..%s contains no trading day \
     (simulator produced %d step(s) including warmup, %d at or after \
     start_date, none of which saw market bars). The requested start_date is \
     most likely past the last bar in the loaded data, so there is nothing to \
     measure over this window."
    (Date.to_string start_date)
    (Date.to_string end_date) n_sim_steps n_steps_in_range

let () =
  Stdlib.Printexc.register_printer (function
    | Empty_measurement_window
        { start_date; end_date; n_sim_steps; n_steps_in_range } ->
        Some
          (_empty_window_message ~start_date ~end_date ~n_sim_steps
             ~n_steps_in_range)
    | _ -> None)

type window = {
  steps_in_range : Sim_types.step_result list;
  steps : Sim_types.step_result list;
  final_portfolio_value : float;
}

let is_trading_day (step : Sim_types.step_result) = step.had_market_bars

let _empty_window_exn ~start_date ~end_date ~all_steps ~steps_in_range =
  let n_sim_steps = List.length all_steps in
  let n_steps_in_range = List.length steps_in_range in
  Empty_measurement_window
    { start_date; end_date; n_sim_steps; n_steps_in_range }

let of_steps (all_steps : Sim_types.step_result list) ~start_date ~end_date =
  (* Steps in the requested date range, all days included. Round-trip
     extraction derives trades from position-state transitions recorded on
     these steps, so it must see *every* step where a trade fill happened —
     including days the [is_trading_day] mark-to-market heuristic would
     otherwise discard. *)
  let steps_in_range =
    List.filter all_steps ~f:(fun s -> Date.( >= ) s.Sim_types.date start_date)
  in
  (* Steps on real trading days only — used for [OpenPositionsValue] /
     [UnrealizedPnl] consumers and anything else that needs a meaningful
     mark-to-market portfolio value. Simulator reports [portfolio_value = cash]
     on weekends/holidays even when positions are open, so filter them out
     before mark-to-market consumers use the series. *)
  let steps = List.filter steps_in_range ~f:is_trading_day in
  match List.last steps with
  | None ->
      raise (_empty_window_exn ~start_date ~end_date ~all_steps ~steps_in_range)
  | Some (last : Sim_types.step_result) ->
      { steps_in_range; steps; final_portfolio_value = last.portfolio_value }

let round_trips_in_window ?order_links all_steps ~start_date =
  Trading_simulation.Metrics.extract_round_trips ?order_links all_steps
  |> List.filter ~f:(fun (t : Trading_simulation.Metrics.trade_metrics) ->
      Date.( >= ) t.entry_date start_date)

let filter_stop_infos_in_window stop_infos ~start_date =
  List.filter stop_infos ~f:(fun (info : Stop_log.stop_info) ->
      match info.entry_date with
      | Some d -> Date.( >= ) d start_date
      | None -> true)

let filter_force_liquidations_in_window events ~start_date =
  List.filter events ~f:(fun (e : Portfolio_risk.Force_liquidation.event) ->
      Date.( >= ) e.date start_date)

let filter_audit_records_in_window records ~start_date =
  List.filter records ~f:(fun (r : Trade_audit.audit_record) ->
      Date.( >= ) r.entry.entry_date start_date)

let filter_cascade_summaries_in_window summaries ~start_date =
  List.filter summaries ~f:(fun (s : Trade_audit.cascade_summary) ->
      Date.( >= ) s.date start_date)

let filter_stale_holds_in_window events ~start_date =
  List.filter events ~f:(fun (e : Trading_simulation.Stale_hold.event) ->
      Date.( >= ) e.date start_date)
