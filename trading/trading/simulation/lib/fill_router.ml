(** Side-aware routing of fill trades onto position lifecycles. See .mli. *)

open Core

(* Expected trade side for filling a position's entry / exit order. A long
   enters with a Buy and exits with a Sell; a short enters with a Sell
   (sell-to-open) and exits with a Buy (buy-to-cover). *)
let _entry_trade_side :
    Trading_base.Types.position_side -> Trading_base.Types.side = function
  | Long -> Buy
  | Short -> Sell

let _exit_trade_side :
    Trading_base.Types.position_side -> Trading_base.Types.side = function
  | Long -> Sell
  | Short -> Buy

let _is_entering_state = function
  | Trading_strategy.Position.Entering _ -> true
  | _ -> false

let _is_exiting_state = function
  | Trading_strategy.Position.Exiting _ -> true
  | _ -> false

(* Whether [pos] can receive a fill on [symbol] with [trade_side]: symbol
   matches, the position is in the expected state, and the trade side is the
   one that state's open order produces for the position's side. The side check
   keeps routing correct when an entry and an exit order coexist on one symbol
   (two sibling positions, e.g. a scale-in add entering while the original
   exits) — state alone would route a Sell fill to the Entering position. *)
let _fill_target_matches ~symbol ~trade_side ~state_match ~expected_side
    (pos : Trading_strategy.Position.t) =
  String.equal pos.symbol symbol
  && state_match (Trading_strategy.Position.get_state pos)
  && Trading_base.Types.equal_side (expected_side pos.side) trade_side

(* Find a position that can receive this fill, by symbol + state + side. *)
let _find_fill_position positions ~symbol ~trade_side ~state_match
    ~expected_side ~is_entry =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, pos) ->
      if
        _fill_target_matches ~symbol ~trade_side ~state_match ~expected_side pos
      then Some (id, pos, is_entry)
      else None)

let _find_fill_target positions ~symbol ~trade_side =
  match
    _find_fill_position positions ~symbol ~trade_side
      ~state_match:_is_entering_state ~expected_side:_entry_trade_side
      ~is_entry:true
  with
  | Some _ as r -> r
  | None ->
      _find_fill_position positions ~symbol ~trade_side
        ~state_match:_is_exiting_state ~expected_side:_exit_trade_side
        ~is_entry:false

let _no_risk_params =
  Trading_strategy.Position.
    { stop_loss_price = None; take_profit_price = None; max_hold_days = None }

(* Apply a fill to a position (works for both entry and exit fills). *)
let _apply_fill ~date ~position ~trade ~is_entry =
  let open Result.Let_syntax in
  let open Trading_strategy.Position in
  let qty = trade.Trading_base.Types.quantity in
  let price = trade.Trading_base.Types.price in
  let fill_kind =
    if is_entry then EntryFill { filled_quantity = qty; fill_price = price }
    else ExitFill { filled_quantity = qty; fill_price = price }
  in
  let fill_trans = { position_id = position.id; date; kind = fill_kind } in
  let%bind pos = apply_transition position fill_trans in
  let complete_kind =
    if is_entry then EntryComplete { risk_params = _no_risk_params }
    else ExitComplete
  in
  let complete_trans = { position_id = pos.id; date; kind = complete_kind } in
  apply_transition pos complete_trans

let set_or_drop_if_closed positions ~key ~data =
  if Trading_strategy.Position.is_closed data then Map.remove positions key
  else Map.set positions ~key ~data

(* Route one fill trade onto the position map: find the (symbol, state, side)
   target, apply the fill, install the updated position (or drop it when
   Closed). A trade whose side matches no open order on its symbol is a no-op. *)
let _apply_one_trade ~date positions trade =
  let open Result.Let_syntax in
  let symbol = trade.Trading_base.Types.symbol in
  match
    _find_fill_target positions ~symbol
      ~trade_side:trade.Trading_base.Types.side
  with
  | Some (id, pos, is_entry) ->
      let%bind updated = _apply_fill ~date ~position:pos ~trade ~is_entry in
      Ok (set_or_drop_if_closed positions ~key:id ~data:updated)
  | None -> Ok positions

let update_positions_from_trades ~date ~positions ~trades =
  List.fold_result trades ~init:positions ~f:(_apply_one_trade ~date)
