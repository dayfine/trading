(** See [feature_matrix.mli] for the API contract. *)

open Core

type feature =
  | Cascade_score
  | Rs_value
  | Volume_ratio
  | Weeks_advancing
  | Passes_macro
  | Stage2_late
  | Rs_trend
  | Resistance_quality
[@@deriving sexp_of, eq]

type kind = Continuous | Boolean | Categorical of string list

type design = {
  x : float array array;
  y : float array;
  win : float array;
  column_names : string list;
  n_complete : int;
}

type coverage = { feature : string; present : int; total : int }

(* Reference-first category orders — element 0 is the dropped reference level.
   Mirror the [Weinstein_types] sexp atoms exactly. *)
let _rs_trend_categories =
  [
    "Bullish_crossover";
    "Positive_rising";
    "Positive_flat";
    "Negative_improving";
    "Negative_declining";
    "Bearish_crossover";
  ]

let _resistance_categories =
  [
    "Virgin_territory";
    "Clean";
    "Moderate_resistance";
    "Heavy_resistance";
    "Insufficient_history";
  ]

let all_features =
  [
    Cascade_score;
    Rs_value;
    Volume_ratio;
    Weeks_advancing;
    Passes_macro;
    Stage2_late;
    Rs_trend;
    Resistance_quality;
  ]

let feature_name = function
  | Cascade_score -> "cascade_score"
  | Rs_value -> "rs_value"
  | Volume_ratio -> "volume_ratio"
  | Weeks_advancing -> "weeks_advancing"
  | Passes_macro -> "passes_macro"
  | Stage2_late -> "stage2_late"
  | Rs_trend -> "rs_trend"
  | Resistance_quality -> "resistance_quality"

let feature_of_string s =
  List.find all_features ~f:(fun f ->
      String.equal (feature_name f) (String.lowercase (String.strip s)))

let feature_kind = function
  | Cascade_score | Rs_value | Volume_ratio | Weeks_advancing -> Continuous
  | Passes_macro | Stage2_late -> Boolean
  | Rs_trend -> Categorical _rs_trend_categories
  | Resistance_quality -> Categorical _resistance_categories

(* Numeric extraction for Continuous/Boolean features; [None] for categoricals. *)
let _numeric_value feature (r : Csv_rows.row) : float option =
  let of_bool b = if b then 1.0 else 0.0 in
  match feature with
  | Cascade_score -> Some (Float.of_int r.cascade_score)
  | Passes_macro -> Some (of_bool r.passes_macro)
  | Rs_value -> r.rs_value
  | Volume_ratio -> r.volume_ratio
  | Weeks_advancing -> Option.map r.weeks_advancing ~f:Float.of_int
  | Stage2_late -> Option.map r.stage2_late ~f:of_bool
  | Rs_trend | Resistance_quality -> None

let _categorical_value feature (r : Csv_rows.row) : string option =
  match feature with
  | Rs_trend -> r.rs_trend
  | Resistance_quality -> r.resistance_quality
  | _ -> None

let _present feature r =
  match feature_kind feature with
  | Categorical _ -> Option.is_some (_categorical_value feature r)
  | Continuous | Boolean -> Option.is_some (_numeric_value feature r)

(* ---------------------------------------------------------------- *)
(* Column assembly                                                    *)
(* ---------------------------------------------------------------- *)

(* Below this a column is treated as constant; z-scoring would divide by ~0. *)
let _std_floor = 1e-12
let _mean a = Array.fold a ~init:0.0 ~f:( +. ) /. Float.of_int (Array.length a)

let _std a ~mean =
  let n = Float.of_int (Array.length a) in
  let ss =
    Array.fold a ~init:0.0 ~f:(fun acc v -> acc +. ((v -. mean) ** 2.0))
  in
  Float.sqrt (ss /. n)

(* A named column of per-row float values over the complete-case rows. *)
let _continuous_column feature rows =
  let raw =
    Array.of_list_map rows ~f:(fun r ->
        Option.value_exn (_numeric_value feature r))
  in
  let mean = _mean raw in
  let std = _std raw ~mean in
  let denom = if Float.( < ) std _std_floor then 1.0 else std in
  (feature_name feature, Array.map raw ~f:(fun v -> (v -. mean) /. denom))

let _boolean_column feature rows =
  ( feature_name feature,
    Array.of_list_map rows ~f:(fun r ->
        Option.value_exn (_numeric_value feature r)) )

let _row_has_category feature rows cat =
  List.exists rows ~f:(fun r ->
      match _categorical_value feature r with
      | Some c -> String.equal c cat
      | None -> false)

(* Build the 0/1 dummy column for a single category over [rows]. *)
let _dummy_column feature rows cat =
  let name = Printf.sprintf "%s=%s" (feature_name feature) cat in
  let hit r =
    match _categorical_value feature r with
    | Some c when String.equal c cat -> 1.0
    | _ -> 0.0
  in
  (name, Array.of_list_map rows ~f:hit)

(* One dummy per OBSERVED non-reference category. The reference is the first
   category (in canonical order) that actually appears in [rows]; emitting
   dummies only for observed levels avoids all-zero columns (which would make
   the design rank-deficient) and keeps the reference-row dummies all-zero so no
   dummy set sums to the intercept. *)
let _categorical_columns feature ~categories rows =
  match List.filter categories ~f:(_row_has_category feature rows) with
  | [] | [ _ ] -> []
  | _reference :: non_reference ->
      List.map non_reference ~f:(_dummy_column feature rows)

let _feature_columns feature rows =
  match feature_kind feature with
  | Continuous -> [ _continuous_column feature rows ]
  | Boolean -> [ _boolean_column feature rows ]
  | Categorical categories -> _categorical_columns feature ~categories rows

let _assemble ~features ~complete : design =
  let n = List.length complete in
  let intercept = ("intercept", Array.create ~len:n 1.0) in
  let columns =
    intercept
    :: List.concat_map features ~f:(fun f -> _feature_columns f complete)
  in
  let column_names = List.map columns ~f:fst in
  let cols = List.map columns ~f:snd |> Array.of_list in
  let p = Array.length cols in
  let x = Array.init n ~f:(fun i -> Array.init p ~f:(fun j -> cols.(j).(i))) in
  let y = Array.of_list_map complete ~f:(fun r -> r.return_pct) in
  let win = Array.map y ~f:(fun v -> if Float.( > ) v 0.0 then 1.0 else 0.0) in
  { x; y; win; column_names; n_complete = n }

let build ~features ~rows =
  let total = List.length rows in
  let coverage =
    List.map features ~f:(fun f ->
        {
          feature = feature_name f;
          present = List.count rows ~f:(_present f);
          total;
        })
  in
  let complete =
    List.filter rows ~f:(fun r ->
        List.for_all features ~f:(fun f -> _present f r))
  in
  if List.is_empty complete then Error "feature_matrix: no complete-case rows"
  else Ok (_assemble ~features ~complete, coverage)

(* ---------------------------------------------------------------- *)
(* Era split                                                          *)
(* ---------------------------------------------------------------- *)

(* Each era binding is a single [let _ = ...] line so the year boundaries stay
   named constants (the formatter cannot split them onto flagged lines). *)
let _era_2000s = ("2000-2008", 2000, 2008)
let _era_2010s = ("2009-2017", 2009, 2017)
let _era_2020s = ("2018-2026", 2018, 2026)
let era_bounds = [ _era_2000s; _era_2010s; _era_2020s ]
let _year (r : Csv_rows.row) = Date.year r.signal_date

let _members_in rows ~lo ~hi =
  List.filter rows ~f:(fun r -> lo <= _year r && _year r <= hi)

let eras rows =
  List.map era_bounds ~f:(fun (label, lo, hi) ->
      (label, _members_in rows ~lo ~hi))
