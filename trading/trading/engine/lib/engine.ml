open Core
open Trading_base.Types
open Trading_orders.Manager
open Trading_orders.Types
open Types

type t = {
  config : engine_config;
  market_state : (symbol, intraday_path) Hashtbl.t;
}

let create config = { config; market_state = Hashtbl.create (module String) }

let update_market engine bars =
  List.iter bars ~f:(fun bar ->
      let path = Price_path.generate_path bar in
      Hashtbl.set engine.market_state ~key:bar.symbol ~data:path)

let _calculate_commission config quantity =
  Float.max (quantity *. config.commission.per_share) config.commission.minimum

let _generate_trade_id order_id = "trade_" ^ order_id

(** {1 Path-based Fill Checking}

    The following functions check if orders would fill on a given intraday path.
    These implement hybrid fill logic:
    - If price crosses threshold within a bar, fill at threshold (conservative)
    - If price gaps beyond threshold, fill at observed price (captures slippage)

    This logic was previously in simulation/price_path.ml but has been moved
    here as it's fundamentally the engine's responsibility to determine order
    execution.

    TODO: Add more sophisticated fill models (partial fills, realistic slippage)
*)

let _would_fill_market (path : intraday_path) : fill_result option =
  (* Market orders always fill at open *)
  match List.hd path with
  | Some point -> Some { price = point.price }
  | None -> None

let _meets_limit ~side ~limit_price price =
  match side with
  | Buy -> Float.(price <= limit_price)
  | Sell -> Float.(price >= limit_price)

let _crosses_limit ~side ~limit_price ~prev_price ~curr_price =
  match side with
  | Buy -> Float.(prev_price > limit_price && curr_price <= limit_price)
  | Sell -> Float.(prev_price < limit_price && curr_price >= limit_price)

let rec _search_order_fill ~(crosses : float -> float -> bool)
    ~(meets : float -> bool) ~cross_price ~(prev_point : path_point) = function
  | [] -> None
  | (curr_point : path_point) :: tail ->
      if crosses prev_point.price curr_point.price then
        Some { price = cross_price }
      else if meets curr_point.price then Some { price = curr_point.price }
      else
        _search_order_fill ~crosses ~meets ~cross_price ~prev_point:curr_point
          tail

let _would_fill_limit ~(path : intraday_path) ~side ~limit_price :
    fill_result option =
  match path with
  | [] -> None
  | (first : path_point) :: rest ->
      let meets = _meets_limit ~side ~limit_price in
      if meets first.price then Some { price = first.price }
      else
        let crosses prev curr =
          _crosses_limit ~side ~limit_price ~prev_price:prev ~curr_price:curr
        in
        _search_order_fill ~crosses ~meets ~cross_price:limit_price
          ~prev_point:first rest

let _meets_stop ~side ~stop_price price =
  match side with
  | Buy -> Float.(price >= stop_price)
  | Sell -> Float.(price <= stop_price)

let _crosses_stop ~side ~stop_price ~prev_price ~curr_price =
  match side with
  | Buy -> Float.(prev_price < stop_price && curr_price >= stop_price)
  | Sell -> Float.(prev_price > stop_price && curr_price <= stop_price)

let rec _search_stop_with_path ~(crosses : float -> float -> bool)
    ~(meets : float -> bool) ~cross_price ~(prev_point : path_point) = function
  | [] -> None
  | (curr_point : path_point) :: _tail as remaining ->
      if crosses prev_point.price curr_point.price then
        Some ({ price = cross_price }, remaining)
      else if meets curr_point.price then
        Some ({ price = curr_point.price }, remaining)
      else
        _search_stop_with_path ~crosses ~meets ~cross_price
          ~prev_point:curr_point _tail

let _stop_activation_path ~(path : intraday_path) ~side ~stop_price :
    (fill_result * intraday_path) option =
  match path with
  | [] -> None
  | (first : path_point) :: _rest ->
      let meets = _meets_stop ~side ~stop_price in
      if meets first.price then
        let fill = { price = first.price } in
        Some (fill, path)
      else
        let crosses prev curr =
          _crosses_stop ~side ~stop_price ~prev_price:prev ~curr_price:curr
        in
        _search_stop_with_path ~crosses ~meets ~cross_price:stop_price
          ~prev_point:first _rest

let _would_fill_stop ~(path : intraday_path) ~side ~stop_price :
    fill_result option =
  match _stop_activation_path ~path ~side ~stop_price with
  | Some (fill, _) -> Some fill
  | None -> None

let _would_fill_stop_limit ~(path : intraday_path) ~side ~stop_price
    ~limit_price : fill_result option =
  (* Two-stage: first stop triggers, then limit must be reached *)
  match _stop_activation_path ~path ~side ~stop_price with
  | None -> None
  | Some (stop_fill, activation_path) ->
      let meets_limit = _meets_limit ~side ~limit_price in
      if meets_limit stop_fill.price then Some stop_fill
      else
        (* Limit not satisfied immediately; wait for the limit price after stop
           activation. *)
        _would_fill_limit ~path:activation_path ~side ~limit_price

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
  let%bind path = Hashtbl.find engine.market_state ord.symbol in
  let%bind fill = _would_fill_market path in
  let commission = _calculate_commission engine.config ord.quantity in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity fill.price commission)

(* Execute limit order - returns Some trade if successful, None otherwise *)
let _execute_limit_order engine (ord : Trading_orders.Types.order) limit_price =
  let open Option.Let_syntax in
  let%bind path = Hashtbl.find engine.market_state ord.symbol in
  let%bind fill = _would_fill_limit ~path ~side:ord.side ~limit_price in
  let commission = _calculate_commission engine.config ord.quantity in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity fill.price commission)

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
  let%bind path = Hashtbl.find engine.market_state ord.symbol in
  let%bind fill = _would_fill_stop ~path ~side:ord.side ~stop_price in
  let commission = _calculate_commission engine.config ord.quantity in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity fill.price commission)

let _process_stop_order engine order_mgr order stop_price =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_stop_order engine order stop_price)

(* Execute stop-limit order - checks stop trigger, then delegates to limit execution.
   - Buy StopLimit: triggers when last >= stop_price, then executes as limit order
   - Sell StopLimit: triggers when last <= stop_price, then executes as limit order *)
let _execute_stop_limit_order engine (ord : Trading_orders.Types.order)
    stop_price limit_price =
  let open Option.Let_syntax in
  let%bind path = Hashtbl.find engine.market_state ord.symbol in
  let%bind fill =
    _would_fill_stop_limit ~path ~side:ord.side ~stop_price ~limit_price
  in
  let commission = _calculate_commission engine.config ord.quantity in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity fill.price commission)

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
