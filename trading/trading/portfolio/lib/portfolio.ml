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

let get_cash portfolio = portfolio.current_cash
let get_initial_cash portfolio = portfolio.initial_cash
let get_trade_history portfolio = portfolio.trade_history

let get_total_realized_pnl portfolio =
  Calculations.realized_pnl_from_trades portfolio.trade_history

let get_position portfolio symbol = Hashtbl.find portfolio.positions symbol

(* Helper functions for position updates *)

(* Calculate effective cost per share including commission for opening/adding trades *)
let _calculate_cost_basis_with_commission (trade : Trading_base.Types.trade) =
  let open Trading_base.Types in
  let commission_per_share = trade.commission /. trade.quantity in
  match trade.side with
  | Buy -> trade.price +. commission_per_share
  | Sell -> trade.price -. commission_per_share

let _calculate_average_cost (existing : portfolio_position) (trade_quantity : float)
    (effective_cost : float) (new_quantity : float) : float =
  let same_direction = Float.(existing.quantity *. new_quantity > 0.0) in
  let adding_to_position = Float.(existing.quantity *. trade_quantity > 0.0) in
  let existing_avg_cost = Calculations.avg_cost_of_position existing in

  if same_direction && adding_to_position then
    (* Adding to existing position in same direction - weighted average *)
    ((existing_avg_cost *. existing.quantity)
    +. (effective_cost *. trade_quantity))
    /. new_quantity
  else if not same_direction then
    (* Direction changed - use new effective cost as basis *)
    effective_cost
  else
    (* Reducing position in same direction - keep existing average cost *)
    existing_avg_cost

(* FIFO lot matching: consume oldest lots first when closing position *)
let _match_fifo_lots (existing_lots : position_lot list) (trade_quantity : float)
    : (position_lot list * position_lot list) =
  (* Sort lots by acquisition_date (oldest first) *)
  let sorted_lots =
    List.sort existing_lots ~compare:(fun (lot1 : position_lot) (lot2 : position_lot) ->
        Core.Date.compare lot1.acquisition_date lot2.acquisition_date)
  in

  (* Match lots *)
  let rec match_lots (remaining_qty : float) (lots_to_match : position_lot list)
      : (position_lot list * position_lot list) =
    if Float.(abs remaining_qty < 1e-9) then
      (* All matched - return all remaining lots *)
      (lots_to_match, [])
    else
      match lots_to_match with
      | [] -> ([], [])  (* No more lots to match *)
      | lot :: rest ->
          let same_direction = Float.(lot.quantity *. remaining_qty > 0.0) in
          if same_direction then
            (* Lot is in same direction as trade - keep it *)
            let (remaining_lots, matched) = match_lots remaining_qty rest in
            (lot :: remaining_lots, matched)
          else
            (* Lot is in opposite direction - match against it *)
            let lot_qty_abs = Float.abs lot.quantity in
            if Float.(lot_qty_abs <= abs remaining_qty) then
              (* Fully consume this lot *)
              let new_remaining_qty =
                remaining_qty +. lot.quantity  (* Add because opposite signs *)
              in
              let (remaining_lots, matched) = match_lots new_remaining_qty rest in
              (remaining_lots, lot :: matched)
            else
              (* Partially consume this lot *)
              (* remaining_qty and lot.quantity have opposite signs *)
              let remaining_lot_qty = lot.quantity +. remaining_qty in
              let remaining_lot_cost =
                (lot.cost_basis /. lot_qty_abs) *. (Float.abs remaining_lot_qty)
              in
              let updated_lot = { lot with quantity = remaining_lot_qty; cost_basis = remaining_lot_cost } in
              (updated_lot :: rest, [ lot ])  (* Return original lot as matched for P&L calculation *)
  in
  match_lots trade_quantity sorted_lots

let _create_new_position positions symbol trade_quantity effective_cost trade_id
    trade_timestamp accounting_method =
  let total_cost_basis = Float.abs trade_quantity *. effective_cost in
  let lot =
    {
      lot_id = trade_id;
      quantity = trade_quantity;
      cost_basis = total_cost_basis;
      acquisition_date = Time_ns_unix.to_date trade_timestamp ~zone:Time_float.Zone.utc;
    }
  in
  let position =
    { symbol; quantity = trade_quantity; lots = [ lot ]; accounting_method }
  in
  Hashtbl.set positions ~key:symbol ~data:position;
  Result.Ok ()

let _update_existing_position_fifo positions symbol (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp : unit status_or =
  let adding_to_position = Float.(existing.quantity *. trade_quantity > 0.0) in

  if adding_to_position then
    (* Adding to position - create new lot *)
    let new_lot =
      {
        lot_id = trade_id;
        quantity = trade_quantity;
        cost_basis = Float.abs trade_quantity *. effective_cost;
        acquisition_date = Time_ns_unix.to_date trade_timestamp ~zone:Time_float.Zone.utc;
      }
    in
    let new_quantity = existing.quantity +. trade_quantity in
    let updated_position =
      {
        existing with
        quantity = new_quantity;
        lots = existing.lots @ [ new_lot ];
      }
    in
    Hashtbl.set positions ~key:symbol ~data:updated_position;
    Result.Ok ()
  else
    (* Closing/reducing position - match against oldest lots *)
    let (remaining_lots, _matched_lots) = _match_fifo_lots existing.lots trade_quantity in
    let new_quantity = existing.quantity +. trade_quantity in

    if Float.(abs new_quantity < 1e-9) then (
      (* Position fully closed *)
      Hashtbl.remove positions symbol;
      Result.Ok ())
    else if List.is_empty remaining_lots then (
      (* Direction changed - create new position *)
      _create_new_position positions symbol new_quantity effective_cost trade_id
        trade_timestamp existing.accounting_method)
    else (
      (* Position reduced - update with remaining lots *)
      let updated_position =
        {
          existing with
          quantity = new_quantity;
          lots = remaining_lots;
        }
      in
      Hashtbl.set positions ~key:symbol ~data:updated_position;
      Result.Ok ())

let _update_existing_position_average_cost positions symbol (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp : unit status_or =
  let new_quantity = existing.quantity +. trade_quantity in
  if Float.(abs new_quantity < 1e-9) then (
    (* Position closed *)
    Hashtbl.remove positions symbol;
    Result.Ok ())
  else
    (* Calculate new average cost and use _create_new_position to rebuild *)
    let new_avg_cost =
      _calculate_average_cost existing trade_quantity effective_cost
        new_quantity
    in
    _create_new_position positions symbol new_quantity new_avg_cost trade_id
      trade_timestamp existing.accounting_method

let _update_existing_position positions symbol (existing : portfolio_position)
    trade_quantity effective_cost trade_id trade_timestamp : unit status_or =
  match existing.accounting_method with
  | AverageCost ->
      _update_existing_position_average_cost positions symbol existing
        trade_quantity effective_cost trade_id trade_timestamp
  | FIFO ->
      _update_existing_position_fifo positions symbol existing trade_quantity
        effective_cost trade_id trade_timestamp

let _update_position_with_trade positions accounting_method
    (trade : Trading_base.Types.trade) : unit status_or =
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

let _calculate_realized_pnl (trade : Trading_base.Types.trade) existing_position
    =
  let trade_qty =
    match trade.side with Buy -> trade.quantity | Sell -> -.trade.quantity
  in

  (* Only realize P&L when closing or reducing position *)
  if Float.(existing_position.quantity *. trade_qty < 0.0) then
    (* Closing position (opposite direction trade) *)
    let close_qty =
      Float.min (Float.abs existing_position.quantity) (Float.abs trade_qty)
    in
    let existing_avg_cost = Calculations.avg_cost_of_position existing_position in
    let pnl_before_commission =
      match trade.side with
      | Sell -> close_qty *. (trade.price -. existing_avg_cost)
      | Buy -> close_qty *. (existing_avg_cost -. trade.price)
    in
    pnl_before_commission -. trade.commission
  else
    (* Opening or adding to position - no realized P&L *)
    0.0

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

let list_positions portfolio =
  Hashtbl.fold portfolio.positions ~init:[]
    ~f:(fun ~key:_symbol ~data:position acc -> position :: acc)

(* Reconstruct portfolio from scratch for validation *)
let reconstruct_from_history initial_cash accounting_method trade_history =
  let trades = List.map trade_history ~f:(fun { trade; _ } -> trade) in
  let empty_portfolio = create ~accounting_method ~initial_cash () in
  apply_trades empty_portfolio trades

(* Helper functions for combinational validation *)
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
      _validate_cash_balance portfolio reconstructed;
      _validate_positions portfolio reconstructed;
    ]
  in
  combine_status_list validations
