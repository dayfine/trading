open Core
open Types

type t = { symbol : string; date : Date.t; factor : float }
[@@deriving show, eq, sexp]

(* Multiply a single lot's quantity by [factor]. The lot's [cost_basis] is
   a TOTAL (not per-share) and stays constant across a split — total dollars
   committed to the position do not change. The implied per-share cost
   ([cost_basis /. abs quantity]) therefore divides by [factor], matching
   broker reality. [acquisition_date] and [lot_id] are unchanged. *)
let _scale_lot (factor : float) (lot : position_lot) : position_lot =
  { lot with quantity = lot.quantity *. factor }

let apply_to_position (event : t) (position : portfolio_position) :
    portfolio_position =
  { position with lots = List.map position.lots ~f:(_scale_lot event.factor) }

let _replace_position ~symbol ~updated (p : portfolio_position) =
  if String.equal p.symbol symbol then updated else p

let apply_to_portfolio (event : t) (portfolio : Portfolio.t) : Portfolio.t =
  match Portfolio.get_position portfolio event.symbol with
  | None -> portfolio
  | Some existing ->
      let updated = apply_to_position event existing in
      let new_positions =
        List.map portfolio.positions
          ~f:(_replace_position ~symbol:event.symbol ~updated)
      in
      { portfolio with positions = new_positions }
