(** Trade metrics computation for performance analysis. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** {1 Trade Metrics Types} *)

type trade_metrics = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
}
[@@deriving show, eq]

type summary_stats = {
  total_pnl : float;
  avg_holding_days : float;
  win_count : int;
  loss_count : int;
  win_rate : float;
}
[@@deriving show, eq]

(** {1 Trade Metrics Functions} *)

let show_trade_metrics m =
  Printf.sprintf
    "%s: %s -> %s (%d days), entry=%.2f exit=%.2f qty=%.0f, P&L=$%.2f (%.2f%%)"
    m.symbol
    (Date.to_string m.entry_date)
    (Date.to_string m.exit_date)
    m.days_held m.entry_price m.exit_price m.quantity m.pnl_dollars
    m.pnl_percent

let show_summary s =
  Printf.sprintf
    "Total P&L: $%.2f | Avg hold: %.1f days | Win rate: %.1f%% (%d/%d)"
    s.total_pnl s.avg_holding_days s.win_rate s.win_count
    (s.win_count + s.loss_count)

(** Pair buy trades with sells to form round-trips for a single symbol. *)
let _pair_trades_for_symbol symbol
    (trades : (Date.t * Trading_base.Types.trade) list) : trade_metrics list =
  let rec pair_trades trades_list metrics =
    match trades_list with
    | (entry_date, entry) :: (exit_date, exit) :: rest
      when Trading_base.Types.(
             equal_side entry.side Buy && equal_side exit.side Sell) ->
        let days_held = Date.diff exit_date entry_date in
        let pnl_dollars =
          (exit.Trading_base.Types.price -. entry.Trading_base.Types.price)
          *. entry.Trading_base.Types.quantity
        in
        let pnl_percent =
          (exit.Trading_base.Types.price -. entry.Trading_base.Types.price)
          /. entry.Trading_base.Types.price *. 100.0
        in
        let m =
          {
            symbol;
            entry_date;
            exit_date;
            days_held;
            entry_price = entry.Trading_base.Types.price;
            exit_price = exit.Trading_base.Types.price;
            quantity = entry.Trading_base.Types.quantity;
            pnl_dollars;
            pnl_percent;
          }
        in
        pair_trades rest (m :: metrics)
    | _ :: rest -> pair_trades rest metrics
    | [] -> List.rev metrics
  in
  pair_trades trades []

let extract_round_trips (steps : Simulator_types.step_result list) :
    trade_metrics list =
  let all_trades =
    List.concat_map steps ~f:(fun step ->
        List.map step.trades ~f:(fun trade -> (step.date, trade)))
  in
  let by_symbol =
    List.fold all_trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (date, trade) ->
        let symbol = trade.Trading_base.Types.symbol in
        let existing = Map.find acc symbol |> Option.value ~default:[] in
        Map.set acc ~key:symbol ~data:((date, trade) :: existing))
  in
  Map.fold by_symbol ~init:[] ~f:(fun ~key:symbol ~data:trades acc ->
      let sorted =
        List.sort trades ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
      in
      _pair_trades_for_symbol symbol sorted @ acc)

let compute_summary (trades : trade_metrics list) : summary_stats option =
  match trades with
  | [] -> None
  | _ ->
      let total_pnl =
        List.fold trades ~init:0.0 ~f:(fun acc m -> acc +. m.pnl_dollars)
      in
      let total_days =
        List.fold trades ~init:0 ~f:(fun acc m -> acc + m.days_held)
      in
      let avg_holding_days =
        Float.of_int total_days /. Float.of_int (List.length trades)
      in
      let win_count =
        List.count trades ~f:(fun m -> Float.(m.pnl_dollars > 0.0))
      in
      let loss_count = List.length trades - win_count in
      let win_rate =
        Float.of_int win_count /. Float.of_int (List.length trades) *. 100.0
      in
      Some { total_pnl; avg_holding_days; win_count; loss_count; win_rate }

(** {1 Conversion Functions} *)

let summary_stats_to_metrics (stats : summary_stats) : Metric_types.metric_set =
  Metric_types.of_alist_exn
    [
      (TotalPnl, stats.total_pnl);
      (AvgHoldingDays, stats.avg_holding_days);
      (WinCount, Float.of_int stats.win_count);
      (LossCount, Float.of_int stats.loss_count);
      (WinRate, stats.win_rate);
    ]
