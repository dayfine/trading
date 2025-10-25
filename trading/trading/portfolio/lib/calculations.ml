open Core
open Status
open Types

(* Compute total quantity from all lots *)
let position_quantity (position : portfolio_position) : float =
  List.fold position.lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.quantity)

(* Helper to compute average cost from lots *)
let avg_cost_of_position (position : portfolio_position) : float =
  let qty = position_quantity position in
  if Float.(abs qty < 1e-9) then 0.0
  else
    let total_cost_basis =
      List.fold position.lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.cost_basis)
    in
    total_cost_basis /. Float.abs qty

let market_value position market_price =
  position_quantity position *. market_price

let unrealized_pnl position market_price =
  let current_value = market_value position market_price in
  let cost_basis = position_quantity position *. avg_cost_of_position position in
  current_value -. cost_basis

let portfolio_value positions cash_value market_prices =
  let price_map = Map.of_alist_exn (module String) market_prices in
  let missing_prices =
    List.filter_map positions ~f:(fun position ->
        match Map.find price_map position.symbol with
        | Some _ -> None
        | None -> Some position.symbol)
  in

  if not (List.is_empty missing_prices) then
    error_invalid_argument
      (Printf.sprintf "Missing market prices for symbols: %s"
         (String.concat ~sep:", " missing_prices))
  else
    let positions_value =
      List.fold positions ~init:0.0 ~f:(fun acc position ->
          let market_price = Map.find_exn price_map position.symbol in
          acc +. market_value position market_price)
    in
    Result.Ok (cash_value +. positions_value)

let position_cost_basis position =
  position_quantity position *. avg_cost_of_position position

let realized_pnl_from_trades trade_history =
  List.fold trade_history ~init:0.0 ~f:(fun acc { realized_pnl; _ } ->
      acc +. realized_pnl)
