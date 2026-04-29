(** Trade metrics computation for performance analysis. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** {1 Trade Metrics Types} *)

type trade_metrics = {
  symbol : string;
  side : Trading_base.Types.side;
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

let _side_label = function
  | Trading_base.Types.Buy -> "LONG"
  | Trading_base.Types.Sell -> "SHORT"

let show_trade_metrics m =
  Printf.sprintf
    "%s [%s]: %s -> %s (%d days), entry=%.2f exit=%.2f qty=%.0f, P&L=$%.2f \
     (%.2f%%)"
    m.symbol (_side_label m.side)
    (Date.to_string m.entry_date)
    (Date.to_string m.exit_date)
    m.days_held m.entry_price m.exit_price m.quantity m.pnl_dollars
    m.pnl_percent

let show_summary s =
  Printf.sprintf
    "Total P&L: $%.2f | Avg hold: %.1f days | Win rate: %.1f%% (%d/%d)"
    s.total_pnl s.avg_holding_days s.win_rate s.win_count
    (s.win_count + s.loss_count)

(** Compute (pnl_dollars, pnl_percent) for a closed round-trip, dispatching on
    the entry side. Long: profit when exit > entry. Short: profit when exit
    (cover) < entry. Both pnl_percent figures are expressed as a percentage of
    the entry price; the sign convention is that a positive reading always means
    profit, regardless of direction. *)
let _compute_pnl ~entry_side ~entry_price ~exit_price ~quantity =
  let dollars =
    match entry_side with
    | Trading_base.Types.Buy -> (exit_price -. entry_price) *. quantity
    | Trading_base.Types.Sell -> (entry_price -. exit_price) *. quantity
  in
  let percent =
    match entry_side with
    | Trading_base.Types.Buy ->
        (exit_price -. entry_price) /. entry_price *. 100.0
    | Trading_base.Types.Sell ->
        (entry_price -. exit_price) /. entry_price *. 100.0
  in
  (dollars, percent)

let _make_trade_metric symbol entry_date entry exit_date exit =
  let open Trading_base.Types in
  let days_held = Date.diff exit_date entry_date in
  let pnl_dollars, pnl_percent =
    _compute_pnl ~entry_side:entry.side ~entry_price:entry.price
      ~exit_price:exit.price ~quantity:entry.quantity
  in
  {
    symbol;
    side = entry.side;
    entry_date;
    exit_date;
    days_held;
    entry_price = entry.price;
    exit_price = exit.price;
    quantity = entry.quantity;
    pnl_dollars;
    pnl_percent;
  }

(** Recognise a paired round-trip by side direction. A long round-trip is
    Buy→Sell; a short round-trip is Sell→Buy (the entry is the short open, the
    exit is the buy-to-cover). The pairing is direction-only — quantities are
    not required to match because the simulator can in principle scale out;
    callers wanting a quantity-equality invariant assert that separately. *)
let _is_paired_round_trip entry exit =
  let open Trading_base.Types in
  match (entry.side, exit.side) with
  | Buy, Sell | Sell, Buy -> true
  | Buy, Buy | Sell, Sell -> false

(** Pair entry trades with subsequent close trades to form round-trips for a
    single symbol. Handles both Buy→Sell (long) and Sell→Buy (short) — see
    {!_is_paired_round_trip}. *)
let _pair_trades_for_symbol symbol
    (trades : (Date.t * Trading_base.Types.trade) list) : trade_metrics list =
  let rec pair_trades trades_list metrics =
    match trades_list with
    | (entry_date, entry) :: (exit_date, exit) :: rest
      when _is_paired_round_trip entry exit ->
        let m = _make_trade_metric symbol entry_date entry exit_date exit in
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
