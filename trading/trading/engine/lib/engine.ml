open Core
open Trading_base.Types
open Trading_orders.Manager
open Trading_orders.Types
open Types

type market_data = { quote : price_quote }

type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
}

let create config = { config; market_state = Hashtbl.create (module String) }

let update_market engine quotes =
  List.iter quotes ~f:(fun quote ->
      let data = { quote } in
      Hashtbl.set engine.market_state ~key:quote.symbol ~data)

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

(* Execute limit order - returns Some trade if successful, None otherwise *)
let _execute_limit_order engine (ord : Trading_orders.Types.order) limit_price =
  let open Option.Let_syntax in
  let%bind mkt_data = Hashtbl.find engine.market_state ord.symbol in
  match ord.side with
  | Buy ->
      (* Buy limit: execute when ask <= limit_price, at ask price *)
      let%bind ask_price = mkt_data.quote.ask in
      if Float.(ask_price <= limit_price) then
        let commission = _calculate_commission engine.config ord.quantity in
        return
          (_create_trade ord.id ord.symbol ord.side ord.quantity ask_price
             commission)
      else None
  | Sell ->
      (* Sell limit: execute when bid >= limit_price, at bid price *)
      let%bind bid_price = mkt_data.quote.bid in
      if Float.(bid_price >= limit_price) then
        let commission = _calculate_commission engine.config ord.quantity in
        return
          (_create_trade ord.id ord.symbol ord.side ord.quantity bid_price
             commission)
      else None

let _create_execution_report order_id trade =
  { order_id; status = Filled; trades = [ trade ] }

(* Common pattern for processing orders: execute and create report *)
let _process_order_with_execution order_mgr order execute_fn =
  execute_fn ()
  |> Option.map ~f:(fun trade ->
         let updated_order =
           ({ order with status = Filled } : Trading_orders.Types.order)
         in
         let _ = update_order order_mgr updated_order in
         _create_execution_report order.id trade)

let _process_market_order engine order_mgr order =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_market_order engine order)

let _process_limit_order engine order_mgr order limit_price =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_limit_order engine order limit_price)

(* Execute stop order - returns Some trade if triggered, None otherwise *)
let _execute_stop_order engine (ord : Trading_orders.Types.order) stop_price =
  let open Option.Let_syntax in
  let%bind mkt_data = Hashtbl.find engine.market_state ord.symbol in
  let%bind last_price = mkt_data.quote.last in
  (* Check if stop is triggered based on side *)
  let triggered =
    match ord.side with
    | Buy ->
        (* Buy stop: triggered when last >= stop_price (breakout/upward) *)
        Float.(last_price >= stop_price)
    | Sell ->
        (* Sell stop: triggered when last <= stop_price (stop-loss/downward) *)
        Float.(last_price <= stop_price)
  in
  if triggered then
    let commission = _calculate_commission engine.config ord.quantity in
    return
      (_create_trade ord.id ord.symbol ord.side ord.quantity last_price
         commission)
  else None

let _process_stop_order engine order_mgr order stop_price =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_stop_order engine order stop_price)

(* Execute stop-limit order - checks stop trigger, then delegates to limit execution.
   - Buy StopLimit: triggers when last >= stop_price, then executes as limit order
   - Sell StopLimit: triggers when last <= stop_price, then executes as limit order *)
let _execute_stop_limit_order engine (ord : Trading_orders.Types.order)
    stop_price limit_price =
  let open Option.Let_syntax in
  let%bind mkt_data = Hashtbl.find engine.market_state ord.symbol in
  let%bind last_price = mkt_data.quote.last in
  let triggered =
    match ord.side with
    | Buy -> Float.(last_price >= stop_price)
    | Sell -> Float.(last_price <= stop_price)
  in
  if triggered then _execute_limit_order engine ord limit_price else None

let _process_stop_limit_order engine order_mgr order stop_price limit_price =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_stop_limit_order engine order stop_price limit_price)

let process_orders engine order_mgr =
  let pending = list_orders order_mgr ~filter:ActiveOnly in
  let reports =
    List.filter_map pending ~f:(fun order ->
        match order.order_type with
        | Market -> _process_market_order engine order_mgr order
        | Limit limit_price ->
            _process_limit_order engine order_mgr order limit_price
        | Stop stop_price ->
            _process_stop_order engine order_mgr order stop_price
        | StopLimit (stop_price, limit_price) ->
            _process_stop_limit_order engine order_mgr order stop_price
              limit_price)
  in
  Result.Ok reports
