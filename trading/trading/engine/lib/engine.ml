open Core
open Trading_base.Types
open Trading_orders.Manager
open Trading_orders.Types
open Types

type t = {
  config : engine_config;
  market_state : Market_state.t;
      (** Per-symbol bars + lazy intraday-path generation; see {!Market_state}.
      *)
  stop_limit_blocked_count : int ref;
      (** Cap-refusal tally; contract in the .mli. Observational only. *)
}

let create config =
  {
    config;
    market_state = Market_state.create ();
    stop_limit_blocked_count = ref 0;
  }

let stop_limit_blocked_count engine = !(engine.stop_limit_blocked_count)

(* Store today's bars; intraday [Price_path] generation is deferred to
   [Market_state.path_for] at order-processing time, so paths are materialized
   only for the few symbols an order references rather than the whole universe.
   See {!Market_state}. *)
let update_market ?(path_config = Price_path.default_config) engine bars =
  Market_state.update engine.market_state ~path_config bars

let _calculate_commission config quantity =
  Float.max (quantity *. config.commission.per_share) config.commission.minimum

(** Apply explicit basis-points slippage to a clean fill price. Buys pay up
    (price increases), sells receive less (price decreases) — symmetric around
    the underlying execution mid. [bps = 0] is a pure pass-through. Pure /
    referentially transparent. *)
let _apply_slippage ~slippage_bps ~side fill_price =
  if slippage_bps = 0 then fill_price
  else
    let factor = 1.0 +. (Float.of_int slippage_bps /. 10_000.0) in
    match side with Buy -> fill_price *. factor | Sell -> fill_price /. factor

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

(** Adjust [fill.price] by the configured [slippage_bps]. Centralised so every
    order-type path applies the same cost in lockstep. *)
let _apply_slippage_to_fill engine ~side (fill : fill_result) : float =
  _apply_slippage ~slippage_bps:engine.config.slippage_bps ~side fill.price

(* Execute market order - returns Some trade if successful, None otherwise *)
let _execute_market_order engine (ord : Trading_orders.Types.order) =
  let open Option.Let_syntax in
  let%bind path =
    Market_state.path_for engine.market_state ~symbol:ord.symbol
  in
  let%bind fill = Fill_rules.would_fill_market path in
  let commission = _calculate_commission engine.config ord.quantity in
  let price = _apply_slippage_to_fill engine ~side:ord.side fill in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity price commission)

(* Execute limit order - returns Some trade if successful, None otherwise *)
let _execute_limit_order engine (ord : Trading_orders.Types.order) limit_price =
  let open Option.Let_syntax in
  let%bind path =
    Market_state.path_for engine.market_state ~symbol:ord.symbol
  in
  let%bind fill =
    Fill_rules.would_fill_limit ~path ~side:ord.side ~limit_price
  in
  let commission = _calculate_commission engine.config ord.quantity in
  let price = _apply_slippage_to_fill engine ~side:ord.side fill in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity price commission)

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
  let%bind path =
    Market_state.path_for engine.market_state ~symbol:ord.symbol
  in
  let%bind fill = Fill_rules.would_fill_stop ~path ~side:ord.side ~stop_price in
  let commission = _calculate_commission engine.config ord.quantity in
  let price = _apply_slippage_to_fill engine ~side:ord.side fill in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity price commission)

let _process_stop_order engine order_mgr order stop_price =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_stop_order engine order stop_price)

(* Execute stop-limit order - checks stop trigger, then delegates to limit execution.
   - Buy StopLimit: triggers when last >= stop_price, then executes as limit order
   - Sell StopLimit: triggers when last <= stop_price, then executes as limit order *)
let _execute_stop_limit_order engine (ord : Trading_orders.Types.order)
    stop_price limit_price =
  let open Option.Let_syntax in
  let%bind path =
    Market_state.path_for engine.market_state ~symbol:ord.symbol
  in
  (* Tally the cap-refusal case before collapsing to an option: past this
     [%bind] the two non-fill reasons are indistinguishable. *)
  let%bind fill =
    match
      Fill_rules.classify_stop_limit ~path ~side:ord.side ~stop_price
        ~limit_price
    with
    | Fill_rules.Fills fill -> Some fill
    | Fill_rules.Stop_not_triggered -> None
    | Fill_rules.Limit_blocked ->
        Int.incr engine.stop_limit_blocked_count;
        None
  in
  let commission = _calculate_commission engine.config ord.quantity in
  let price = _apply_slippage_to_fill engine ~side:ord.side fill in
  return
    (_create_trade ord.id ord.symbol ord.side ord.quantity price commission)

let _process_stop_limit_order engine order_mgr order stop_price limit_price =
  _process_order_with_execution order_mgr order (fun () ->
      _execute_stop_limit_order engine order stop_price limit_price)

let _process_order engine order_mgr order =
  match order.order_type with
  | Market -> _process_market_order engine order_mgr order
  | Limit limit_price -> _process_limit_order engine order_mgr order limit_price
  | Stop stop_price -> _process_stop_order engine order_mgr order stop_price
  | StopLimit (stop_price, limit_price) ->
      _process_stop_limit_order engine order_mgr order stop_price limit_price

let process_orders ?can_fill engine order_mgr =
  let pending = list_orders order_mgr ~filter:ActiveOnly in
  (* [can_fill] lets a caller hold specific orders back from matching this
     tick without cancelling them: an order for which it returns [false] is
     skipped, stays active in the manager, and is re-offered next call. [None]
     (the default) fills every active order exactly as before — bit-identical. *)
  let pending =
    match can_fill with None -> pending | Some f -> List.filter pending ~f
  in
  let reports = List.filter_map pending ~f:(_process_order engine order_mgr) in
  Result.Ok reports
