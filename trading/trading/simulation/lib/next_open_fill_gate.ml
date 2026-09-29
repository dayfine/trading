(** See .mli. Fix #1 / #1b next-bar-open Market fill gate. *)

open Core

let _is_entering (p : Trading_strategy.Position.t) =
  match Trading_strategy.Position.get_state p with
  | Trading_strategy.Position.Entering _ -> true
  | _ -> false

let _is_exiting (p : Trading_strategy.Position.t) =
  match Trading_strategy.Position.get_state p with
  | Trading_strategy.Position.Exiting _ -> true
  | _ -> false

(* Whether [p] is a position in [state_match] that [order] would fill: symbol
   and the side that state's own order carries both match. Mirrors
   {!Fill_router._fill_target_matches} — state alone would confuse an entry and
   an exit coexisting on one symbol (a scale-in add entering while the original
   exits). *)
let _is_routing_match ~state_match ~expected_side
    (order : Trading_orders.Types.order) (p : Trading_strategy.Position.t) =
  String.equal p.symbol order.symbol
  && state_match p
  && Trading_base.Types.equal_side (expected_side p.side) order.side

let _is_entry_order positions (order : Trading_orders.Types.order) =
  Map.exists positions
    ~f:
      (_is_routing_match ~state_match:_is_entering
         ~expected_side:Fill_router.entry_trade_side order)

let _is_exit_order positions (order : Trading_orders.Types.order) =
  Map.exists positions
    ~f:
      (_is_routing_match ~state_match:_is_exiting
         ~expected_side:Fill_router.exit_trade_side order)

(* Whether [order] is an order this gate should defer past stale steps, given
   which classes the caller armed. A [StopLimit] entry is deferrable too
   ([defer_stoplimit_entries]): its trigger does not protect it from a stale
   bar. A ticket placed at Friday's close is checked on the Saturday step
   against the RETAINED Friday bar, so it fills inside a range that traded
   before the ticket existed (measured: 99 of 100 Saturday-dated entries on
   the 26y record sit inside Friday's own bar). *)
let _is_deferrable ~defer_entries ~defer_exits ~defer_stoplimit_entries
    ~positions (order : Trading_orders.Types.order) =
  match order.order_type with
  | Trading_base.Types.Market ->
      (defer_entries && _is_entry_order positions order)
      || (defer_exits && _is_exit_order positions order)
  | Trading_base.Types.StopLimit _ ->
      defer_stoplimit_entries && _is_entry_order positions order
  | _ -> false

let make ~defer_entries ~defer_exits ?(defer_stoplimit_entries = false)
    ~positions ~today_bars =
  let fresh =
    String.Set.of_list
      (List.map today_bars ~f:(fun (b : Trading_engine.Types.price_bar) ->
           b.symbol))
  in
  fun (order : Trading_orders.Types.order) ->
    if
      _is_deferrable ~defer_entries ~defer_exits ~defer_stoplimit_entries
        ~positions order
    then Set.mem fresh order.symbol
    else true

type flags = {
  defer_entries : bool;
  defer_exits : bool;
  defer_stoplimit_entries : bool;
}

let gate { defer_entries; defer_exits; defer_stoplimit_entries } ~positions
    ~today_bars =
  if defer_entries || defer_exits || defer_stoplimit_entries then
    Some
      (make ~defer_entries ~defer_exits ~defer_stoplimit_entries ~positions
         ~today_bars)
  else None
