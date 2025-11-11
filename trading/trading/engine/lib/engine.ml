[@@@warning "-69"]
(* Suppress unused field warning for market_data.timestamp:
   This field is semantically important for future enhancements
   (e.g., checking data freshness), even though not currently read. *)

open Core
open Trading_base.Types
open Trading_orders.Manager
open Trading_orders.Types
open Types

(* Internal market data with timestamp for freshness tracking *)
type market_data = { quote : price_quote; timestamp : Time_ns_unix.t }

type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
}

let create config = { config; market_state = Hashtbl.create (module String) }

let update_market engine quotes =
  let now = Time_ns_unix.now () in
  List.iter quotes ~f:(fun quote ->
      let data = { quote; timestamp = now } in
      Hashtbl.set engine.market_state ~key:quote.symbol ~data)

let get_market_data engine symbol =
  Hashtbl.find engine.market_state symbol
  |> Option.map ~f:(fun data -> data.quote)

let _calculate_commission config quantity =
  Float.max (quantity *. config.commission.per_share) config.commission.minimum

let _generate_trade_id order_id = "trade_" ^ order_id

let _create_trade order_id symbol side quantity price commission =
  {
    id = _generate_trade_id order_id;
    order_id;
    symbol;
    side;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.now ();
  }

(* Execute market order - returns Some trade if successful, None otherwise *)
let _execute_market_order engine (ord : Trading_orders.Types.order) =
  let open Option.Let_syntax in
  let%bind mkt_data = Hashtbl.find engine.market_state ord.symbol in
  let%bind last_price = mkt_data.quote.last in
  let commission = _calculate_commission engine.config ord.quantity in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity last_price commission)

let _create_execution_report order_id trade =
  { order_id; status = Filled; trades = [ trade ] }

let _process_market_order engine order_mgr order =
  match _execute_market_order engine order with
  | None -> None
  | Some trade ->
      let updated_order = { order with status = Filled } in
      let _ = update_order order_mgr updated_order in
      Some (_create_execution_report order.id trade)

let process_orders engine order_mgr =
  let pending = list_orders order_mgr ~filter:ActiveOnly in
  let reports =
    List.filter_map pending ~f:(fun order ->
        match order.order_type with
        | Market -> _process_market_order engine order_mgr order
        | _ -> None (* TODO: Phase 4-5 - Limit/Stop orders *))
  in
  Result.Ok reports
