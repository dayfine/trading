open Core
open Base

(** Portfolio and position management *)

(** Portfolio state *)
type t = {
  positions: position list;
  cash: money;
  total_value: money;
} [@@deriving show, eq]

(** Create a new portfolio *)
let create initial_cash = {
  positions = [];
  cash = initial_cash;
  total_value = initial_cash;
}

(** Add a position to the portfolio *)
let add_position portfolio symbol quantity price =
  let new_position = { symbol; quantity; avg_price = price } in

  (* Check if position already exists *)
  let existing_pos = List.find portfolio.positions ~f:(fun pos -> pos.symbol = symbol) in

  let updated_positions = match existing_pos with
    | None -> new_position :: portfolio.positions
    | Some existing ->
      let total_quantity = existing.quantity + quantity in
      let total_cost = (Float.of_int existing.quantity *. existing.avg_price) +.
                      (Float.of_int quantity *. price) in
      let new_avg_price = total_cost /. Float.of_int total_quantity in
      let updated_pos = { symbol; quantity = total_quantity; avg_price = new_avg_price } in
      List.map portfolio.positions ~f:(fun pos ->
        if pos.symbol = symbol then updated_pos else pos
      )
  in

  { portfolio with positions = updated_positions }

(** Remove a position from the portfolio *)
let remove_position portfolio symbol quantity =
  let existing_pos = List.find portfolio.positions ~f:(fun pos -> pos.symbol = symbol) in

  match existing_pos with
  | None -> portfolio
  | Some pos ->
    let remaining_quantity = pos.quantity - quantity in
    if remaining_quantity <= 0 then
      (* Remove position entirely *)
      let updated_positions = List.filter portfolio.positions ~f:(fun p -> p.symbol <> symbol) in
      { portfolio with positions = updated_positions }
    else
      (* Update position with remaining quantity *)
      let updated_pos = { pos with quantity = remaining_quantity } in
      let updated_positions = List.map portfolio.positions ~f:(fun p ->
        if p.symbol = symbol then updated_pos else p
      ) in
      { portfolio with positions = updated_positions }

(** Get position for a symbol *)
let get_position portfolio symbol =
  List.find portfolio.positions ~f:(fun pos -> pos.symbol = symbol)

(** Get all positions *)
let get_positions portfolio = portfolio.positions

(** Calculate position value *)
let calculate_position_value position current_price =
  Float.of_int position.quantity *. current_price

(** Calculate unrealized P&L for a position *)
let calculate_unrealized_pnl position current_price =
  let current_value = calculate_position_value position current_price in
  let cost_basis = Float.of_int position.quantity *. position.avg_price in
  current_value -. cost_basis

(** Update portfolio value based on current prices *)
let update_portfolio_value portfolio price_map =
  let position_values = List.map portfolio.positions ~f:(fun pos ->
    match Map.find price_map pos.symbol with
    | Some price -> calculate_position_value pos price
    | None -> 0.0
  ) in
  let total_position_value = List.fold position_values ~init:0.0 ~f:(+.) in
  let total_value = total_position_value +. portfolio.cash.amount in
  { portfolio with total_value = { portfolio.total_value with amount = total_value } }

(** Get portfolio summary *)
let get_summary portfolio =
  let num_positions = List.length portfolio.positions in
  let total_positions = List.fold portfolio.positions ~init:0 ~f:(fun acc pos -> acc + pos.quantity) in
  {
    num_positions;
    total_positions;
    cash = portfolio.cash;
    total_value = portfolio.total_value;
  }
