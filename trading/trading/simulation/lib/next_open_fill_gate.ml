(** See .mli. Fix #1 next-bar-open Market-entry fill gate. *)

open Core

(* The order side that opens a position of [side]: a long enters with a Buy, a
   short enters (sell-to-open) with a Sell. Mirrors {!Fill_router}. *)
let _entry_side_of : Trading_base.Types.position_side -> Trading_base.Types.side
    = function
  | Long -> Buy
  | Short -> Sell

(* Whether [order] is a Market order that would open ([Entering]) a position:
   symbol + entry-side match an [Entering] position in [positions]. Exits, stops,
   and StopLimit entries never match. *)
let _is_market_entry_order positions (order : Trading_orders.Types.order) =
  match order.order_type with
  | Trading_base.Types.Market ->
      Map.exists positions ~f:(fun (p : Trading_strategy.Position.t) ->
          String.equal p.symbol order.symbol
          && (match Trading_strategy.Position.get_state p with
            | Trading_strategy.Position.Entering _ -> true
            | _ -> false)
          && Trading_base.Types.equal_side (_entry_side_of p.side) order.side)
  | _ -> false

let make ~positions ~today_bars =
  let fresh =
    String.Set.of_list
      (List.map today_bars ~f:(fun (b : Trading_engine.Types.price_bar) ->
           b.symbol))
  in
  fun (order : Trading_orders.Types.order) ->
    if _is_market_entry_order positions order then Set.mem fresh order.symbol
    else true
