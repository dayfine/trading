(** F3 wide-stop admission policy. See [stop_width_mode.mli]. *)

open Core

type t = Drop_over_max | Size_down | Demote_over_max
[@@deriving show, eq, sexp]

type policy = { mode : t; size_down_max_pct : float }

let default_policy = { mode = Drop_over_max; size_down_max_pct = 0.0 }

type outcome = Admit | Admit_sized_down | Drop

(* The distance above which the two non-default modes still drop. A configured
   [size_down_max_pct > 0.0] is the swept sanity ceiling; [0.0] (the unset
   default) falls back to [max_stop_distance_pct], so an armed-but-unconfigured
   mode admits exactly the same population [Drop_over_max] does rather than
   admitting unbounded risk. Shared by [Size_down] and [Demote_over_max] — the
   field's name predates the second consumer; it is the ceiling for both. *)
let _ceiling ~policy ~max_stop_distance_pct =
  if Float.( > ) policy.size_down_max_pct 0.0 then policy.size_down_max_pct
  else max_stop_distance_pct

let over_book_limit ~max_stop_distance_pct ~stop_distance_pct =
  Float.( > ) stop_distance_pct max_stop_distance_pct

let gate ~policy ~max_stop_distance_pct ~stop_distance_pct =
  let over_limit = over_book_limit ~max_stop_distance_pct ~stop_distance_pct in
  let over_ceiling =
    Float.( > ) stop_distance_pct (_ceiling ~policy ~max_stop_distance_pct)
  in
  match policy.mode with
  | Drop_over_max -> if over_limit then Drop else Admit
  | Size_down ->
      if over_ceiling then Drop
      else if over_limit then Admit_sized_down
      else Admit
  | Demote_over_max -> if over_ceiling then Drop else Admit

let demotes ~policy =
  match policy.mode with
  | Demote_over_max -> true
  | Drop_over_max | Size_down -> false
