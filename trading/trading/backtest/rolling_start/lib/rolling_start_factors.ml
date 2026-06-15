open Core

(* The four stage codes the snapshot [Stage] scalar encodes (1.0..4.0). A cell
   is decoded by rounding to the nearest integer and accepting only 1..4 — any
   nan or out-of-range value is "not classifiable" (None). *)
let _min_stage = 1
let _max_stage = 4

let macro_stage_of_value v =
  if Float.is_nan v then None
  else
    let rounded = Float.round_nearest v |> Int.of_float in
    Option.some_if (rounded >= _min_stage && rounded <= _max_stage) rounded

(* Stage 2 is the confirmed-breakout-eligible stage. *)
let _stage2 = 2

let stage2_candidate_count stage_values =
  List.count stage_values ~f:(fun v ->
      match macro_stage_of_value v with
      | Some stage -> stage = _stage2
      | None -> false)

(* The IQR of <2 distinct sectors is undefined — report nan rather than 0.0 so a
   degenerate single-sector universe is not read as "zero dispersion". *)
let _min_sectors_for_spread = 2

let _mean = function
  | [] -> Float.nan
  | xs -> List.sum (module Float) xs ~f:Fn.id /. Float.of_int (List.length xs)

let sector_rs_dispersion sector_rs =
  let defined =
    List.filter sector_rs ~f:(fun (_, rs) -> not (Float.is_nan rs))
  in
  let sector_means =
    Map.of_alist_multi (module String) defined |> Map.data |> List.map ~f:_mean
  in
  if List.length sector_means < _min_sectors_for_spread then Float.nan
  else Dispersion_stats.iqr sector_means

type factors = {
  spy_stage_at_start : int option;
  macro_composite_at_start : float;
  stage2_candidate_count : int option;
  sector_rs_dispersion_at_start : float;
}
[@@deriving sexp, equal]

let empty =
  {
    spy_stage_at_start = None;
    macro_composite_at_start = Float.nan;
    stage2_candidate_count = None;
    sector_rs_dispersion_at_start = Float.nan;
  }
