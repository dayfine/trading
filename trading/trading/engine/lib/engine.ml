open Core
open Trading_base.Types
open Trading_orders.Manager
open Trading_orders.Types
open Types

type market_data = { quote : price_quote }

type stop_order_state = {
  order_id : string; [@warning "-69"]
  stop_price : float; [@warning "-69"]
  triggered : bool;
  triggered_at : float option; [@warning "-69"]
      (** time_fraction when triggered *)
}
(** Stop order state tracking for backtesting. When a stop order is triggered
    during mini-bar processing, we record:
    - Which bar triggered it (time_fraction)
    - That it has been converted to market/limit order *)

type t = {
  config : engine_config;
  market_state : (symbol, market_data) Hashtbl.t;
  stop_states : (string, stop_order_state) Hashtbl.t;
      (** Track stop order trigger states (order_id -> state) *)
}

let create config =
  {
    config;
    market_state = Hashtbl.create (module String);
    stop_states = Hashtbl.create (module String);
  }

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

(** {1 Mini-Bar Processing for Backtesting} *)

(* Check if a stop order should trigger based on mini-bar price and side *)
let _should_stop_trigger side stop_price close_price =
  match side with
  | Buy -> Float.(close_price >= stop_price)
  | Sell -> Float.(close_price <= stop_price)

(* Check if limit order would fill in a mini-bar.
   Returns Some fill_price if it fills, None otherwise. *)
let _check_limit_fill side limit_price (bar : mini_bar) =
  match side with
  | Buy ->
      (* Buy limit: can fill if price drops to or below limit *)
      if Float.(bar.open_price <= limit_price) then
        (* Already at or below limit at open *)
        Some bar.open_price
      else if Float.(bar.close_price <= limit_price) then
        (* Crossed down through limit during bar *)
        Some limit_price
      else None
  | Sell ->
      (* Sell limit: can fill if price rises to or above limit *)
      if Float.(bar.open_price >= limit_price) then
        (* Already at or above limit at open *)
        Some bar.open_price
      else if Float.(bar.close_price >= limit_price) then
        (* Crossed up through limit during bar *)
        Some limit_price
      else None

(* Process a single mini-bar for a specific order *)
let _process_order_mini_bar engine order_mgr (ord : order) (bar : mini_bar) =
  let commission = _calculate_commission engine.config ord.quantity in
  match ord.order_type with
  | Market ->
      (* Market orders execute at bar close price *)
      let trade =
        _create_trade ord.id ord.symbol ord.side ord.quantity bar.close_price
          commission
      in
      let updated_order = { ord with status = Filled } in
      let _ = update_order order_mgr updated_order in
      Some (_create_execution_report ord.id trade)
  | Limit limit_price -> (
      (* Limit orders execute if price crosses limit *)
      match _check_limit_fill ord.side limit_price bar with
      | Some fill_price ->
          let trade =
            _create_trade ord.id ord.symbol ord.side ord.quantity fill_price
              commission
          in
          let updated_order = { ord with status = Filled } in
          let _ = update_order order_mgr updated_order in
          Some (_create_execution_report ord.id trade)
      | None -> None)
  | Stop stop_price ->
      (* Check if stop triggers, if so execute as market at close *)
      if _should_stop_trigger ord.side stop_price bar.close_price then (
        (* Record trigger in stop_states *)
        let stop_state =
          {
            order_id = ord.id;
            stop_price;
            triggered = true;
            triggered_at = Some bar.time_fraction;
          }
        in
        Hashtbl.set engine.stop_states ~key:ord.id ~data:stop_state;
        (* Execute as market order at close *)
        let trade =
          _create_trade ord.id ord.symbol ord.side ord.quantity bar.close_price
            commission
        in
        let updated_order = { ord with status = Filled } in
        let _ = update_order order_mgr updated_order in
        Some (_create_execution_report ord.id trade))
      else None
  | StopLimit (stop_price, limit_price) ->
      (* Check if already triggered *)
      let already_triggered =
        match Hashtbl.find engine.stop_states ord.id with
        | Some state -> state.triggered
        | None -> false
      in
      if already_triggered then
        (* Already triggered, process as limit order *)
        match _check_limit_fill ord.side limit_price bar with
        | Some fill_price ->
            let trade =
              _create_trade ord.id ord.symbol ord.side ord.quantity fill_price
                commission
            in
            let updated_order = { ord with status = Filled } in
            let _ = update_order order_mgr updated_order in
            Some (_create_execution_report ord.id trade)
        | None -> None
      else if _should_stop_trigger ord.side stop_price bar.close_price then (
        (* Stop triggers now at bar close *)
        let stop_state =
          {
            order_id = ord.id;
            stop_price;
            triggered = true;
            triggered_at = Some bar.time_fraction;
          }
        in
        Hashtbl.set engine.stop_states ~key:ord.id ~data:stop_state;
        (* Check if the trigger price itself meets limit condition *)
        let trigger_meets_limit =
          match ord.side with
          | Buy -> Float.(bar.close_price <= limit_price)
          | Sell -> Float.(bar.close_price >= limit_price)
        in
        if trigger_meets_limit then
          (* Fill immediately at trigger price *)
          let trade =
            _create_trade ord.id ord.symbol ord.side ord.quantity
              bar.close_price commission
          in
          let updated_order = { ord with status = Filled } in
          let _ = update_order order_mgr updated_order in
          Some (_create_execution_report ord.id trade)
        else
          (* Stop triggered but limit not met yet, wait for next bar *)
          None)
      else None

let process_mini_bars engine symbol order_mgr mini_bars =
  (* Process each mini-bar sequentially, checking active orders at each step *)
  let reports =
    List.concat_map mini_bars ~f:(fun bar ->
        (* Get currently active orders for the symbol before processing this bar *)
        let pending = list_orders order_mgr ~filter:ActiveOnly in
        let symbol_orders =
          List.filter pending ~f:(fun ord -> String.equal ord.symbol symbol)
        in
        List.filter_map symbol_orders ~f:(fun ord ->
            _process_order_mini_bar engine order_mgr ord bar))
  in
  Result.Ok reports
