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

(* When [get_price] returns None for a held symbol (e.g. M&A delist, dataset
   gap, weekend/holiday before the adapter forward-fill kicks in), fall back to
   [entry_price] — zero unrealized P&L. Returning 0.0 here used to silently
   collapse market value to bare cash, which corrupted [portfolio_value] and
   anything derived from it (sizing, [Peak_tracker], NAV series). The
   simulator's own NAV path has an analogous cache+avg-cost chain (see
   simulator.ml [_resolve_price]); this fallback is the defense-in-depth at the
   strategy-facing seam. *)
let _holding_market_value (pos : Position.t) ~get_price =
  match pos.state with
  | Holding { quantity; entry_price; _ } ->
      let price =
        match get_price pos.symbol with
        | Some (bar : Types.Daily_price.t) -> bar.close_price
        | None -> entry_price
      in
      _signed_quantity ~side:pos.side quantity *. price
  | _ -> 0.0

let portfolio_value { cash; positions } ~get_price =
  Map.fold positions ~init:cash ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _holding_market_value pos ~get_price)
