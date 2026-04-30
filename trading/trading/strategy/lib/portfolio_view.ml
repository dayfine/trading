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
let _holding_market_value (pos : Position.t) ~get_price =
  match pos.state with
  | Holding { quantity; _ } -> (
      match get_price pos.symbol with
      | Some (bar : Types.Daily_price.t) ->
          let signed_qty =
            match pos.side with Long -> quantity | Short -> -.quantity
          in
          signed_qty *. bar.close_price
      | None -> 0.0)
  | _ -> 0.0

let portfolio_value { cash; positions } ~get_price =
  Map.fold positions ~init:cash ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _holding_market_value pos ~get_price)
