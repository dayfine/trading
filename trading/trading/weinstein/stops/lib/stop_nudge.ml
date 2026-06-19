open Core
open Trading_base.Types

(* Nearest half-dollar (or whole dollar) to [price] — the round-number reference
   stops are nudged away from. *)
let _nearest_half price =
  let floor_half = Float.round_down (price /. 0.5) *. 0.5 in
  let ceil_half = floor_half +. 0.5 in
  if
    Float.( < )
      (Float.abs (price -. ceil_half))
      (Float.abs (price -. floor_half))
  then ceil_half
  else floor_half

let nudge_round_number ~nudge ~side price =
  let candidate = _nearest_half price in
  if Float.( <= ) (Float.abs (price -. candidate)) nudge then
    match side with
    | Long when Float.( >= ) price candidate -> candidate -. nudge
    | Short when Float.( <= ) price candidate -> candidate +. nudge
    | _ -> price
  else price
