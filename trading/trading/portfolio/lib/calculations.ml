open Core
open Types

let market_value position market_price = position.quantity *. market_price

let unrealized_pnl position market_price =
  let current_value = market_value position market_price in
  let cost_basis = position.quantity *. position.avg_cost in
  current_value -. cost_basis

let portfolio_value _symbols positions cash market_prices =
  let price_map = Map.of_alist_exn (module String) market_prices in
  let positions_value =
    List.fold positions ~init:0.0 ~f:(fun acc position ->
        match Map.find price_map position.symbol with
        | Some market_price -> acc +. market_value position market_price
        | None -> acc +. (position.quantity *. position.avg_cost)
        (* Fallback to cost basis *))
  in
  cash +. positions_value

let position_cost_basis position = position.quantity *. position.avg_cost

(* Commented out until we figure out trade type imports
let realized_pnl_from_trades trades =
  List.fold trades ~init:0.0 ~f:(fun acc trade ->
    match trade.side with
    | Sell -> acc +. (trade.quantity *. trade.price -. trade.commission)
    | Buy -> acc -. (trade.quantity *. trade.price +. trade.commission)
  )
*)
