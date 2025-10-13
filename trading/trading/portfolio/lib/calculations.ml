open Core
open Status
open Types

let market_value position market_price = position.quantity *. market_price

let unrealized_pnl position market_price =
  let current_value = market_value position market_price in
  let cost_basis = position.quantity *. position.avg_cost in
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

let position_cost_basis position = position.quantity *. position.avg_cost

let realized_pnl_from_trades trade_history =
  List.fold trade_history ~init:0.0 ~f:(fun acc { realized_pnl; _ } ->
      acc +. realized_pnl)
