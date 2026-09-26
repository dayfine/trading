(** See .mli. Same-bar protective-stop exit fills (#2961). *)

open Core

(* position_id -> stop_price for every [TriggerExit] carrying [StopLoss]. *)
let _stop_prices transitions =
  List.fold transitions ~init:String.Map.empty
    ~f:(fun acc (tr : Trading_strategy.Position.transition) ->
      match tr.kind with
      | TriggerExit { exit_reason = StopLoss { stop_price; _ }; _ } ->
          Map.set acc ~key:tr.position_id ~data:stop_price
      | _ -> acc)

(* Whether [bar] trades through [stop_price] on the side [side] exits at. *)
let _bar_reaches_stop ~side ~stop_price (bar : Trading_engine.Types.price_bar) =
  match (side : Trading_base.Types.side) with
  | Sell -> Float.( <= ) bar.low_price stop_price
  | Buy -> Float.( >= ) bar.high_price stop_price

(* The [Stop] re-typing of [order], when it is a Market exit for a stop-loss
   position whose fresh bar reaches the stop; [None] otherwise. *)
let _as_stop_order ~stop_prices ~position_of ~bar_of
    (order : Trading_orders.Types.order) =
  let open Option.Let_syntax in
  let%bind () = match order.order_type with Market -> Some () | _ -> None in
  let%bind position_id = Map.find position_of order.id in
  let%bind stop_price = Map.find stop_prices position_id in
  let%bind bar = Map.find bar_of order.symbol in
  if _bar_reaches_stop ~side:order.side ~stop_price bar then
    Some { order with order_type = Trading_base.Types.Stop stop_price }
  else None

let _index_bars today_bars =
  List.fold today_bars ~init:String.Map.empty
    ~f:(fun acc (b : Trading_engine.Types.price_bar) ->
      Map.set acc ~key:b.symbol ~data:b)

let select ~enabled ~transitions ~order_links ~today_bars orders =
  let stop_prices =
    if enabled then _stop_prices transitions else String.Map.empty
  in
  if Map.is_empty stop_prices then ([], orders)
  else
    let position_of =
      List.fold order_links ~init:String.Map.empty
        ~f:(fun acc (order_id, position_id) ->
          Map.set acc ~key:order_id ~data:position_id)
    in
    let bar_of = _index_bars today_bars in
    let converted, rest =
      List.partition_map orders ~f:(fun order ->
          match _as_stop_order ~stop_prices ~position_of ~bar_of order with
          | Some stop_order -> First stop_order
          | None -> Second order)
    in
    (converted, rest)

(* Turn a converted order the engine did not fill back into a resting Market
   order, so it fills at the next fresh open as it would with the flag off. *)
let _revert_unfilled ~order_manager ~filled_ids
    (order : Trading_orders.Types.order) =
  if Set.mem filled_ids order.id then Ok ()
  else
    Trading_orders.Manager.update_order order_manager
      { order with order_type = Trading_base.Types.Market }

let _order_id (o : Trading_orders.Types.order) = o.id
let _report_id (r : Trading_engine.Types.execution_report) = r.order_id

(* Submit [stop_orders] and run one engine pass restricted to exactly them. *)
let _submit_and_fill ~engine ~order_manager stop_orders =
  let open Result.Let_syntax in
  let ids = String.Set.of_list (List.map stop_orders ~f:_order_id) in
  let%bind () =
    Trading_orders.Manager.submit_orders order_manager stop_orders
    |> Status.combine_status_list
  in
  Trading_engine.Engine.process_orders
    ~can_fill:(fun o -> Set.mem ids (_order_id o))
    engine order_manager

let _execute_nonempty ~engine ~order_manager ~date stop_orders =
  let open Result.Let_syntax in
  let%bind reports = _submit_and_fill ~engine ~order_manager stop_orders in
  let filled_ids = String.Set.of_list (List.map reports ~f:_report_id) in
  let%bind () =
    List.map stop_orders ~f:(_revert_unfilled ~order_manager ~filled_ids)
    |> Status.combine_status_list
  in
  return
    (List.concat_map reports ~f:(fun r -> r.trades)
    |> List.map ~f:(Fill_date_stamp.restamp ~date))

let execute ~engine ~order_manager ~date stop_orders =
  if List.is_empty stop_orders then Ok []
  else _execute_nonempty ~engine ~order_manager ~date stop_orders
