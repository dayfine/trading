[@@@warning "-69"]
(* Suppress unused field warnings for market_data.symbol and market_data.timestamp:
   These fields are semantically important for debugging and future enhancements
   (e.g., checking data freshness), even though not currently read. *)

open Core
open Trading_base.Types
open Trading_orders.Manager
open Trading_orders.Types
open Types

(* Internal market data type - not exposed in public API *)
type market_data = {
  symbol : symbol;
  bid : price option;
  ask : price option;
  last : price option;
  timestamp : Time_ns_unix.t;
}

(* Engine state *)
type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
}

let create config = { config; market_state = Hashtbl.create (module String) }

let update_market engine symbol ~bid ~ask ~last =
  let data = { symbol; bid; ask; last; timestamp = Time_ns_unix.now () } in
  Hashtbl.set engine.market_state ~key:symbol ~data

let get_market_data engine symbol =
  match Hashtbl.find engine.market_state symbol with
  | Some data -> Some (data.bid, data.ask, data.last)
  | None -> None

(* Helper to calculate commission *)
let _calculate_commission config quantity =
  let calculated = quantity *. config.commission.per_share in
  Float.max calculated config.commission.minimum

(* Helper to generate a trade ID *)
let _generate_trade_id order_id = "trade_" ^ order_id

(* Helper to execute a market order *)
let _execute_market_order engine (ord : Trading_orders.Types.order) =
  match Hashtbl.find engine.market_state ord.symbol with
  | None -> None (* No market data available, skip *)
  | Some mkt_data -> (
      match mkt_data.last with
      | None -> None (* No last price available, skip *)
      | Some last_price ->
          (* Calculate commission *)
          let commission = _calculate_commission engine.config ord.quantity in
          (* Generate trade *)
          let trade =
            {
              id = _generate_trade_id ord.id;
              order_id = ord.id;
              symbol = ord.symbol;
              side = ord.side;
              quantity = ord.quantity;
              price = last_price;
              commission;
              timestamp = Time_ns_unix.now ();
            }
          in
          Some trade)

let process_orders engine order_mgr =
  (* 1. Get pending orders *)
  let pending = list_orders order_mgr ~filter:ActiveOnly in
  (* 2. Process each order *)
  let reports =
    List.filter_map pending ~f:(fun order ->
        match order.order_type with
        | Market -> (
            (* Execute market order *)
            match _execute_market_order engine order with
            | None -> None (* Skip if no market data *)
            | Some trade ->
                (* Update order status to Filled *)
                let updated_order = { order with status = Filled } in
                let _ = update_order order_mgr updated_order in
                (* Create execution report *)
                Some
                  { order_id = order.id; status = Filled; trades = [ trade ] })
        | _ ->
            (* TODO: Phase 4 - Implement limit order execution *)
            (* TODO: Phase 5 - Implement stop order execution *)
            None)
  in
  Result.Ok reports
