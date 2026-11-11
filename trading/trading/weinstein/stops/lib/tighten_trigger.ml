open Core

type t =
  | Stage3_or_4
  | Ma_flat_in_stage2
  | Ma_falling_in_stage2
  | Stage1_or_2
  | Ma_rising_in_stage4
  | Ma_flat_in_stage4
[@@deriving show, eq, sexp]

let all =
  [
    Stage3_or_4;
    Ma_flat_in_stage2;
    Ma_falling_in_stage2;
    Stage1_or_2;
    Ma_rising_in_stage4;
    Ma_flat_in_stage4;
  ]

(* These strings predate the typed trigger and are what every tightened stop
   has recorded; changing one would change serialized stop state. *)
let to_reason = function
  | Stage3_or_4 -> "Stage 3/4 detected"
  | Ma_flat_in_stage2 -> "30-week MA flattening"
  | Ma_falling_in_stage2 -> "30-week MA falling in Stage 2"
  | Stage1_or_2 -> "Stage 1/2 detected"
  | Ma_rising_in_stage4 -> "30-week MA rising in Stage 4"
  | Ma_flat_in_stage4 -> "30-week MA flattening in Stage 4"

let of_reason reason =
  List.find all ~f:(fun trigger -> String.equal (to_reason trigger) reason)
