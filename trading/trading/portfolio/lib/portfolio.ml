open Core
open Result.Let_syntax
open Status
open Types

type t = {
  initial_cash : cash_value;
  trade_history : trade_with_pnl list;
  (* Computed state - maintained for performance *)
  current_cash : cash_value;
  positions : (Trading_base.Types.symbol, portfolio_position) Hashtbl.t;
  accounting_method : accounting_method;
      (* Default accounting method for new positions *)
}

let create ?(accounting_method = AverageCost) ~initial_cash () =
  {
    initial_cash;
    trade_history = [];
    current_cash = initial_cash;
    positions = Hashtbl.create (module String);
    accounting_method;
  }

(* Constants *)
let negligible_quantity_epsilon = 1e-9

(* Helper functions *)
let _is_quantity_negligible (qty : float) : bool =
  Float.(abs qty < negligible_quantity_epsilon)

let _is_same_direction (qty1 : float) (qty2 : float) : bool =
  if _is_quantity_negligible qty1 || _is_quantity_negligible qty2 then false
  else Bool.equal Float.O.(qty1 >= 0.0) Float.O.(qty2 >= 0.0)

let _sort_lots_by_date (lots : position_lot list) : position_lot list =
  List.sort lots ~compare:(fun lot1 lot2 ->
      Core.Date.compare lot1.acquisition_date lot2.acquisition_date)

(* Helper functions for position updates *)

let _calculate_cost_basis_with_commission (trade : Trading_base.Types.trade) =
  let open Trading_base.Types in
  let commission_per_share = trade.commission /. trade.quantity in
  match trade.side with
  | Buy -> trade.price +. commission_per_share
  | Sell -> trade.price -. commission_per_share

let _calculate_average_cost (existing : portfolio_position)
    (trade_quantity : float) (effective_cost : float) (new_quantity : float) :
    float =
  let existing_qty = Calculations.position_quantity existing in
  let same_direction = _is_same_direction existing_qty new_quantity in
  let adding_to_position = _is_same_direction existing_qty trade_quantity in
  let existing_avg_cost = Calculations.avg_cost_of_position existing in

  if same_direction && adding_to_position then
    (* Adding to existing position in same direction - weighted average *)
    ((existing_avg_cost *. existing_qty) +. (effective_cost *. trade_quantity))
    /. new_quantity
  else if not same_direction then
    (* Direction changed - use new effective cost as basis *)
    effective_cost
  else
    (* Reducing position in same direction - keep existing average cost *)
    existing_avg_cost

(* FIFO lot matching helpers *)

let _partially_consume_lot (lot : position_lot) (consume_qty : float) :
    position_lot * position_lot =
  (* consume_qty and lot.quantity have opposite signs *)
  let remaining_qty = lot.quantity +. consume_qty in
  let lot_qty_abs = Float.abs lot.quantity in
  let consumed_qty_abs = Float.abs consume_qty in
  let remaining_cost =
    lot.cost_basis /. lot_qty_abs *. Float.abs remaining_qty
  in
  let consumed_cost = lot.cost_basis /. lot_qty_abs *. consumed_qty_abs in
  let remaining_lot =
    { lot with quantity = remaining_qty; cost_basis = remaining_cost }
  in
  let consumed_lot =
    { lot with quantity = consume_qty; cost_basis = consumed_cost }
  in
  (remaining_lot, consumed_lot)

let rec _match_single_lot (remaining_qty : float) (lot : position_lot)
    (rest : position_lot list) : position_lot list * position_lot list =
  if _is_same_direction lot.quantity remaining_qty then
    (* Lot in same direction - keep it, continue matching *)
    let remaining_lots, matched = _match_lots_rec remaining_qty rest in
    (lot :: remaining_lots, matched)
  else
    (* Lot in opposite direction - consume it *)
    let lot_qty_abs = Float.abs lot.quantity in
    let remaining_qty_abs = Float.abs remaining_qty in
    if Float.(lot_qty_abs <= remaining_qty_abs) then
      (* Fully consume this lot *)
      let new_remaining_qty = remaining_qty +. lot.quantity in
      let remaining_lots, matched = _match_lots_rec new_remaining_qty rest in
      (remaining_lots, lot :: matched)
    else
      (* Partially consume this lot *)
      let remaining_lot, consumed_lot =
        _partially_consume_lot lot remaining_qty
      in
      (remaining_lot :: rest, [ consumed_lot ])

and _match_lots_rec (remaining_qty : float) (lots : position_lot list) :
    position_lot list * position_lot list =
  if _is_quantity_negligible remaining_qty then (lots, [])
  else
    match lots with
    | [] -> ([], [])
    | lot :: rest -> _match_single_lot remaining_qty lot rest

(* FIFO lot matching: consume oldest lots first when closing position.
   Assumes lots are already sorted by acquisition date (maintained as invariant). *)
let _match_fifo_lots (existing_lots : position_lot list)
    (trade_quantity : float) : position_lot list * position_lot list =
  _match_lots_rec trade_quantity existing_lots

let _make_lot trade_id trade_quantity effective_cost trade_timestamp :
    position_lot =
  {
    lot_id = trade_id;
    quantity = trade_quantity;
    cost_basis = Float.abs trade_quantity *. effective_cost;
    acquisition_date =
      Time_ns_unix.to_date trade_timestamp ~zone:Time_float.Zone.utc;
  }

let _set_position positions symbol position : status =
  Hashtbl.set positions ~key:symbol ~data:position;
  ok ()

let _remove_position positions symbol : status =
  Hashtbl.remove positions symbol;
  ok ()

let _create_new_position positions symbol trade_quantity effective_cost trade_id
    trade_timestamp accounting_method : status =
  let lot = _make_lot trade_id trade_quantity effective_cost trade_timestamp in
  let position = { symbol; lots = [ lot ]; accounting_method } in
  _set_position positions symbol position

let _add_lot_to_position positions symbol (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp : status =
  let new_lot =
    _make_lot trade_id trade_quantity effective_cost trade_timestamp
  in
  (* Maintain lots in sorted order by acquisition date (invariant) *)
  let updated_lots = _sort_lots_by_date (existing.lots @ [ new_lot ]) in
  let updated_position = { existing with lots = updated_lots } in
  _set_position positions symbol updated_position

let _close_or_reduce_fifo_position positions symbol
    (existing : portfolio_position) trade_quantity effective_cost trade_id
    trade_timestamp : status =
  let remaining_lots, _matched_lots =
    _match_fifo_lots existing.lots trade_quantity
  in
  let existing_qty = Calculations.position_quantity existing in
  let new_quantity = existing_qty +. trade_quantity in

  if _is_quantity_negligible new_quantity then _remove_position positions symbol
  else if List.is_empty remaining_lots then
    (* Direction changed - create new position with new_quantity *)
    _create_new_position positions symbol new_quantity effective_cost trade_id
      trade_timestamp existing.accounting_method
  else
    (* Position reduced - update with remaining lots *)
    let updated_position = { existing with lots = remaining_lots } in
    _set_position positions symbol updated_position

let _update_existing_position_fifo positions symbol
    (existing : portfolio_position) trade_quantity effective_cost trade_id
    trade_timestamp : status =
  let existing_qty = Calculations.position_quantity existing in
  let adding_to_position = _is_same_direction existing_qty trade_quantity in
  if adding_to_position then
    _add_lot_to_position positions symbol existing trade_quantity effective_cost
      trade_id trade_timestamp
  else
    _close_or_reduce_fifo_position positions symbol existing trade_quantity
      effective_cost trade_id trade_timestamp

let _update_existing_position_average_cost positions symbol
    (existing : portfolio_position) trade_quantity effective_cost trade_id
    trade_timestamp : status =
  let existing_qty = Calculations.position_quantity existing in
  let new_quantity = existing_qty +. trade_quantity in
  if _is_quantity_negligible new_quantity then _remove_position positions symbol
  else
    let new_avg_cost =
      _calculate_average_cost existing trade_quantity effective_cost
        new_quantity
    in
    _create_new_position positions symbol new_quantity new_avg_cost trade_id
      trade_timestamp existing.accounting_method

let _update_existing_position positions symbol (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp : status =
  match existing.accounting_method with
  | AverageCost ->
      _update_existing_position_average_cost positions symbol existing
        trade_quantity effective_cost trade_id trade_timestamp
  | FIFO ->
      _update_existing_position_fifo positions symbol existing trade_quantity
        effective_cost trade_id trade_timestamp

let _update_position_with_trade positions accounting_method
    (trade : Trading_base.Types.trade) : status =
  let symbol = trade.symbol in
  let trade_quantity =
    match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity
  in
  let effective_cost = _calculate_cost_basis_with_commission trade in

  match Hashtbl.find positions symbol with
  | None ->
      _create_new_position positions symbol trade_quantity effective_cost
        trade.id trade.timestamp accounting_method
  | Some existing ->
      _update_existing_position positions symbol existing trade_quantity
        effective_cost trade.id trade.timestamp

(* Helper functions for trade application *)
let _calculate_cash_change (trade : Trading_base.Types.trade) =
  match trade.side with
  | Buy -> -.((trade.quantity *. trade.price) +. trade.commission)
  | Sell -> (trade.quantity *. trade.price) -. trade.commission

let _is_closing_trade position_qty trade_qty : bool =
  not (_is_same_direction position_qty trade_qty)

(* Calculate P&L from matched lots (used for FIFO) *)
let _calculate_pnl_from_matched_lots (matched_lots : position_lot list)
    (trade : Trading_base.Types.trade) : float =
  let total_cost_basis =
    List.fold matched_lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.cost_basis)
  in
  (* Matched lots all have the same sign (opposite to trade direction),
     so we can sum quantities directly and take abs once. *)
  let total_qty_signed =
    List.fold matched_lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.quantity)
  in
  let total_qty = Float.abs total_qty_signed in
  if Float.(total_qty < negligible_quantity_epsilon) then 0.0
  else
    let matched_avg_cost = total_cost_basis /. total_qty in
    let pnl_before_commission =
      match trade.side with
      | Sell -> total_qty *. (trade.price -. matched_avg_cost)
      | Buy -> total_qty *. (matched_avg_cost -. trade.price)
    in
    pnl_before_commission -. trade.commission

(* Calculate P&L for average cost method *)
let _calculate_average_cost_pnl (trade : Trading_base.Types.trade)
    (existing_position : portfolio_position) : float =
  let existing_qty = Calculations.position_quantity existing_position in
  let close_qty =
    Float.min (Float.abs existing_qty) (Float.abs trade.quantity)
  in
  let existing_avg_cost = Calculations.avg_cost_of_position existing_position in
  let pnl_before_commission =
    match trade.side with
    | Sell -> close_qty *. (trade.price -. existing_avg_cost)
    | Buy -> close_qty *. (existing_avg_cost -. trade.price)
  in
  pnl_before_commission -. trade.commission

(* Calculate P&L for FIFO method *)
let _calculate_fifo_pnl (trade : Trading_base.Types.trade) (trade_qty : float)
    (existing_position : portfolio_position) : float =
  let _remaining_lots, matched_lots =
    _match_fifo_lots existing_position.lots trade_qty
  in
  _calculate_pnl_from_matched_lots matched_lots trade

let _calculate_realized_pnl (trade : Trading_base.Types.trade)
    (existing_position : portfolio_position) : float =
  let trade_qty =
    match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity
  in
  let existing_qty = Calculations.position_quantity existing_position in
  if _is_closing_trade existing_qty trade_qty then
    match existing_position.accounting_method with
    | AverageCost -> _calculate_average_cost_pnl trade existing_position
    | FIFO -> _calculate_fifo_pnl trade trade_qty existing_position
  else 0.0 (* Opening or adding to position *)

let _check_sufficient_cash portfolio cash_change =
  let new_cash = portfolio.current_cash +. cash_change in
  if Float.(new_cash < 0.0) then
    error_invalid_argument
      ("Insufficient cash for trade. Required: "
      ^ Float.to_string (-.cash_change)
      ^ ", Available: "
      ^ Float.to_string portfolio.current_cash)
  else Result.Ok new_cash

let apply_single_trade (portfolio : t) (trade : Trading_base.Types.trade) :
    t status_or =
  let cash_change = _calculate_cash_change trade in
  let%bind new_cash = _check_sufficient_cash portfolio cash_change in
  let new_positions = Hashtbl.copy portfolio.positions in
  let realized_pnl =
    match Hashtbl.find portfolio.positions trade.symbol with
    | None -> 0.0 (* New position - no realized P&L *)
    | Some existing_position -> _calculate_realized_pnl trade existing_position
  in
  let%bind () =
    _update_position_with_trade new_positions portfolio.accounting_method trade
  in
  let trade_with_pnl = { trade; realized_pnl } in
  return
    {
      portfolio with
      current_cash = new_cash;
      positions = new_positions;
      trade_history = portfolio.trade_history @ [ trade_with_pnl ];
    }

let apply_trades portfolio trades =
  List.fold_result trades ~init:portfolio ~f:apply_single_trade

(* Reconstruct portfolio from scratch for validation *)
let reconstruct_from_history initial_cash accounting_method trade_history =
  let trades = List.map trade_history ~f:(fun { trade; _ } -> trade) in
  let empty_portfolio = create ~accounting_method ~initial_cash () in
  apply_trades empty_portfolio trades

(* Helper functions for combinational validation *)
let _validate_lots_sorted (position : portfolio_position) : status =
  let rec check_sorted = function
    | [] | [ _ ] -> true
    | lot1 :: (lot2 :: _ as rest) ->
        Core.Date.(lot1.acquisition_date <= lot2.acquisition_date)
        && check_sorted rest
  in
  if check_sorted position.lots then ok ()
  else
    error_invalid_argument
      (Printf.sprintf "Lots not sorted by acquisition date for symbol %s"
         position.symbol)

let _validate_all_positions_lots_sorted positions : status =
  let position_validations =
    Hashtbl.to_alist positions
    |> List.map ~f:(fun (_symbol, position) -> _validate_lots_sorted position)
  in
  combine_status_list position_validations

let _validate_cash_balance portfolio reconstructed =
  if Float.equal portfolio.current_cash reconstructed.current_cash then ok ()
  else
    error_invalid_argument
      (Printf.sprintf "Cash balance mismatch: expected %.2f, found %.2f"
         reconstructed.current_cash portfolio.current_cash)

let _positions_to_sorted_list positions =
  Hashtbl.to_alist positions
  |> List.sort ~compare:(fun (s1, _) (s2, _) -> String.compare s1 s2)

let _validate_positions portfolio reconstructed =
  let position_pair_equal (s1, p1) (s2, p2) =
    String.equal s1 s2 && equal_portfolio_position p1 p2
  in
  let current_positions = _positions_to_sorted_list portfolio.positions in
  let reconstructed_positions =
    _positions_to_sorted_list reconstructed.positions
  in

  if List.equal position_pair_equal current_positions reconstructed_positions
  then ok ()
  else
    let format_positions positions =
      List.map positions ~f:(fun (symbol, pos) ->
          Printf.sprintf "%s: %s" symbol (show_portfolio_position pos))
      |> String.concat ~sep:"; "
    in
    error_invalid_argument
      (Printf.sprintf "Positions mismatch:\nExpected: [%s]\nFound: [%s]"
         (format_positions reconstructed_positions)
         (format_positions current_positions))

let validate portfolio =
  let%bind reconstructed =
    reconstruct_from_history portfolio.initial_cash portfolio.accounting_method
      portfolio.trade_history
  in
  (* Run all validations and collect errors *)
  let validations =
    [
      _validate_all_positions_lots_sorted portfolio.positions;
      _validate_cash_balance portfolio reconstructed;
      _validate_positions portfolio reconstructed;
    ]
  in
  combine_status_list validations
