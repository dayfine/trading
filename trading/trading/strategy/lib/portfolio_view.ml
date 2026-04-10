open Core

type t = { cash : float; positions : Position.t String.Map.t }

let _holding_market_value (pos : Position.t) ~get_price =
  match pos.state with
  | Holding { quantity; _ } -> (
      match get_price pos.symbol with
      | Some (bar : Types.Daily_price.t) -> quantity *. bar.close_price
      | None -> 0.0)
  | _ -> 0.0

let portfolio_value { cash; positions } ~get_price =
  Map.fold positions ~init:cash ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _holding_market_value pos ~get_price)
