open Core

type t = { cash : float; positions : Position.t String.Map.t }

(* Mark-to-market contribution of a single position to portfolio value.

   [Position.t.state.Holding.quantity] is unsigned (always positive); the
   long/short direction lives in [pos.side]. Long holdings contribute their
   market value as an asset; short holdings contribute the negative of their
   current market value, since the position is a liability — shares owed back
   at the current price. Cash already reflects the proceeds credited at short
   entry, so subtracting the current liability is what makes
   [portfolio_value] track P&L correctly on shorts. *)
let _signed_quantity ~side quantity =
  match (side : Position.position_side) with
  | Long -> quantity
  | Short -> -.quantity

let _holding_market_value (pos : Position.t) ~get_price =
  match pos.state with
  | Holding { quantity; _ } ->
      Option.value_map (get_price pos.symbol) ~default:0.0
        ~f:(fun (bar : Types.Daily_price.t) ->
          _signed_quantity ~side:pos.side quantity *. bar.close_price)
  | _ -> 0.0

let portfolio_value { cash; positions } ~get_price =
  Map.fold positions ~init:cash ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _holding_market_value pos ~get_price)
