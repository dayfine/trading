(** F3 wide-stop admission policy. See [stop_width_mode.mli]. *)

open Core

type t = Drop_over_max | Size_down [@@deriving show, eq, sexp]
type policy = { mode : t; size_down_max_pct : float }

let default_policy = { mode = Drop_over_max; size_down_max_pct = 0.0 }

type outcome = Admit | Admit_sized_down | Drop

(* The distance above which [Size_down] still drops. A configured
   [size_down_max_pct > 0.0] is the swept sanity ceiling; [0.0] (the unset
   default) falls back to [max_stop_distance_pct], so an armed-but-unconfigured
   [Size_down] admits exactly the same population [Drop_over_max] does rather
   than admitting unbounded risk. *)
let _size_down_ceiling ~policy ~max_stop_distance_pct =
  if Float.( > ) policy.size_down_max_pct 0.0 then policy.size_down_max_pct
  else max_stop_distance_pct

let gate ~policy ~max_stop_distance_pct ~stop_distance_pct =
  let over_book_limit = Float.( > ) stop_distance_pct max_stop_distance_pct in
  match policy.mode with
  | Drop_over_max -> if over_book_limit then Drop else Admit
  | Size_down ->
      let ceiling = _size_down_ceiling ~policy ~max_stop_distance_pct in
      if Float.( > ) stop_distance_pct ceiling then Drop
      else if over_book_limit then Admit_sized_down
      else Admit
