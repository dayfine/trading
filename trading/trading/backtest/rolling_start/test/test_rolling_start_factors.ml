open Core
open OUnit2
open Matchers
module F = Rolling_start.Rolling_start_factors

(* A [float matcher] asserting the value is [Float.nan] — the "factor
   unavailable" marker. Mirrors the local matcher in [test_dispersion_stats.ml]
   (the Matchers library has no built-in nan matcher). *)
let is_nan : float matcher =
  matching ~msg:"Expected nan"
    (fun x -> if Float.is_nan x then Some () else None)
    (equal_to ())

(* ----- macro_stage_of_value ----- *)

(* Each in-range stage code decodes to its integer stage; values are rounded
   defensively so a slightly-off cell (e.g. 2.0000001) still decodes. *)
let test_macro_stage_decodes_each_stage _ =
  assert_that
    (List.map [ 1.0; 2.0; 3.0; 4.0 ] ~f:F.macro_stage_of_value)
    (elements_are
       [
         equal_to (Some 1);
         equal_to (Some 2);
         equal_to (Some 3);
         equal_to (Some 4);
       ])

let test_macro_stage_nan_is_none _ =
  assert_that (F.macro_stage_of_value Float.nan) is_none

(* Out-of-range codes (0, 5, negative) are "not a stage" -> None, not silently
   clamped. *)
let test_macro_stage_out_of_range_is_none _ =
  assert_that
    (List.map [ 0.0; 5.0; -1.0 ] ~f:F.macro_stage_of_value)
    (elements_are [ is_none; is_none; is_none ])

(* ----- stage2_candidate_count ----- *)

(* Three of these five universe cells are Stage 2; one is nan (pre-IPO) and one
   is Stage 4 — neither counts. *)
let test_stage2_count_known_universe _ =
  assert_that
    (F.stage2_candidate_count [ 2.0; 1.0; 2.0; Float.nan; 2.0; 4.0 ])
    (equal_to 3)

let test_stage2_count_empty_is_zero _ =
  assert_that (F.stage2_candidate_count []) (equal_to 0)

let test_stage2_count_all_nan_is_zero _ =
  assert_that (F.stage2_candidate_count [ Float.nan; Float.nan ]) (equal_to 0)

(* ----- sector_rs_dispersion ----- *)

(* Per-sector means: Tech = mean(1.0, 3.0) = 2.0; Energy = mean(-1.0, -3.0) =
   -2.0; Health = 0.0. The three sector means are {2.0, 0.0, -2.0}; their IQR
   (p75 - p25, type-7: sorted [-2; 0; 2] -> p25 = -1, p75 = 1) is 2.0. *)
let test_sector_rs_dispersion_three_sectors _ =
  assert_that
    (F.sector_rs_dispersion
       [
         ("Tech", 1.0);
         ("Tech", 3.0);
         ("Energy", -1.0);
         ("Energy", -3.0);
         ("Health", 0.0);
       ])
    (float_equal 2.0)

(* nan RS cells are dropped before grouping, so an otherwise-Energy nan does not
   move the Energy mean. Two sectors {Tech mean 2.0, Energy mean -2.0}: IQR
   (type-7 over sorted [-2; 2] -> p25 = -1, p75 = 1) is 2.0. *)
let test_sector_rs_dispersion_drops_nan _ =
  assert_that
    (F.sector_rs_dispersion
       [ ("Tech", 1.0); ("Tech", 3.0); ("Energy", -2.0); ("Energy", Float.nan) ])
    (float_equal 2.0)

(* Fewer than two distinct sectors -> dispersion is undefined (nan), not 0.0. *)
let test_sector_rs_dispersion_single_sector_is_nan _ =
  assert_that (F.sector_rs_dispersion [ ("Tech", 1.0); ("Tech", 3.0) ]) is_nan

let test_sector_rs_dispersion_empty_is_nan _ =
  assert_that (F.sector_rs_dispersion []) is_nan

(* ----- empty ----- *)

let test_empty_is_all_unavailable _ =
  assert_that F.empty
    (all_of
       [
         field (fun f -> f.F.spy_stage_at_start) is_none;
         field (fun f -> f.F.macro_composite_at_start) is_nan;
         field (fun f -> f.F.stage2_candidate_count) is_none;
         field (fun f -> f.F.sector_rs_dispersion_at_start) is_nan;
       ])

let suite =
  "rolling_start_factors"
  >::: [
         "macro_stage_decodes_each_stage"
         >:: test_macro_stage_decodes_each_stage;
         "macro_stage_nan_is_none" >:: test_macro_stage_nan_is_none;
         "macro_stage_out_of_range_is_none"
         >:: test_macro_stage_out_of_range_is_none;
         "stage2_count_known_universe" >:: test_stage2_count_known_universe;
         "stage2_count_empty_is_zero" >:: test_stage2_count_empty_is_zero;
         "stage2_count_all_nan_is_zero" >:: test_stage2_count_all_nan_is_zero;
         "sector_rs_dispersion_three_sectors"
         >:: test_sector_rs_dispersion_three_sectors;
         "sector_rs_dispersion_drops_nan"
         >:: test_sector_rs_dispersion_drops_nan;
         "sector_rs_dispersion_single_sector_is_nan"
         >:: test_sector_rs_dispersion_single_sector_is_nan;
         "sector_rs_dispersion_empty_is_nan"
         >:: test_sector_rs_dispersion_empty_is_nan;
         "empty_is_all_unavailable" >:: test_empty_is_all_unavailable;
       ]

let () = run_test_tt_main suite
