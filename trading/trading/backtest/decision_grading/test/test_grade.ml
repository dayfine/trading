open OUnit2
open Matchers
module G = Decision_grading.Grade
module PE = Decision_grading.Post_exit

(* A Post_exit.horizon_result with only the fields the grader reads spelled out;
   the excursion fields are irrelevant to grade_exit and fixed to 0.0. *)
let result ~horizon_weeks ~continuation_pct =
  {
    PE.horizon_weeks;
    continuation_pct;
    post_exit_max_favorable_pct = 0.0;
    post_exit_max_adverse_pct = 0.0;
  }

(* Grade on the default config (premature/good thresholds 0.10, horizon 13w). *)
let config = G.default_config

(* Continuation well above +threshold at the grade horizon -> gave up a winner. *)
let test_premature _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:[ result ~horizon_weeks:13 ~continuation_pct:0.25 ])
    (equal_to G.Premature)

(* Continuation well below -threshold -> dodged a drop. *)
let test_good_exit _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:[ result ~horizon_weeks:13 ~continuation_pct:(-0.25) ])
    (equal_to G.Good_exit)

(* Continuation inside the band -> neither. *)
let test_neutral_in_band _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:[ result ~horizon_weeks:13 ~continuation_pct:0.03 ])
    (equal_to G.Neutral)

(* Exactly at +premature_threshold -> Premature (boundary is decisive). *)
let test_premature_boundary _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:[ result ~horizon_weeks:13 ~continuation_pct:0.10 ])
    (equal_to G.Premature)

(* Exactly at -good_exit_threshold -> Good_exit (boundary is decisive). *)
let test_good_exit_boundary _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:[ result ~horizon_weeks:13 ~continuation_pct:(-0.10) ])
    (equal_to G.Good_exit)

(* Just inside each boundary -> Neutral. *)
let test_just_inside_boundaries _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:[ result ~horizon_weeks:13 ~continuation_pct:0.099 ])
    (equal_to G.Neutral)

(* The configured horizon is absent from the list -> Neutral, even when other
   horizons would grade Premature. *)
let test_missing_horizon_neutral _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:
         [
           result ~horizon_weeks:4 ~continuation_pct:0.30;
           result ~horizon_weeks:26 ~continuation_pct:0.40;
         ])
    (equal_to G.Neutral)

(* Empty list -> Neutral. *)
let test_empty_neutral _ =
  assert_that (G.grade_exit ~config ~post_exit:[]) (equal_to G.Neutral)

(* A multi-horizon list grades on the CONFIGURED horizon (13w, continuation
   -0.20 = Good_exit), not the 4w (+0.30 = would be Premature) or 26w. *)
let test_multi_horizon_picks_configured _ =
  assert_that
    (G.grade_exit ~config
       ~post_exit:
         [
           result ~horizon_weeks:4 ~continuation_pct:0.30;
           result ~horizon_weeks:13 ~continuation_pct:(-0.20);
           result ~horizon_weeks:26 ~continuation_pct:0.05;
         ])
    (equal_to G.Good_exit)

(* A non-default config: grade on the 4w horizon with a tighter +0.05
   premature threshold -> the 4w +0.30 result is Premature. *)
let test_custom_config_horizon _ =
  let custom =
    {
      G.premature_threshold_pct = 0.05;
      good_exit_threshold_pct = 0.05;
      grade_horizon_weeks = 4;
    }
  in
  assert_that
    (G.grade_exit ~config:custom
       ~post_exit:
         [
           result ~horizon_weeks:4 ~continuation_pct:0.30;
           result ~horizon_weeks:13 ~continuation_pct:(-0.20);
         ])
    (equal_to G.Premature)

(* Capture ratio, normal case: realized +10% against a +20% peak = 0.5 captured. *)
let test_capture_ratio_normal _ =
  assert_that
    (G.entry_capture_ratio ~realized_pnl_pct:0.10 ~max_favorable_pct:0.20)
    (is_some_and (float_equal 0.5))

(* Realized loss despite an in-trade peak -> negative ratio (gave it all back
   and then some). *)
let test_capture_ratio_negative _ =
  assert_that
    (G.entry_capture_ratio ~realized_pnl_pct:(-0.05) ~max_favorable_pct:0.20)
    (is_some_and (float_equal (-0.25)))

(* Captured the entire peak -> 1.0. *)
let test_capture_ratio_full _ =
  assert_that
    (G.entry_capture_ratio ~realized_pnl_pct:0.20 ~max_favorable_pct:0.20)
    (is_some_and (float_equal 1.0))

(* No in-trade gain (mfe = 0) -> undefined -> None. *)
let test_capture_ratio_mfe_zero_none _ =
  assert_that
    (G.entry_capture_ratio ~realized_pnl_pct:0.10 ~max_favorable_pct:0.0)
    is_none

(* Negative mfe (should not occur, but guarded) -> None. *)
let test_capture_ratio_mfe_negative_none _ =
  assert_that
    (G.entry_capture_ratio ~realized_pnl_pct:0.10 ~max_favorable_pct:(-0.05))
    is_none

let suite =
  "grade"
  >::: [
         "premature" >:: test_premature;
         "good_exit" >:: test_good_exit;
         "neutral_in_band" >:: test_neutral_in_band;
         "premature_boundary" >:: test_premature_boundary;
         "good_exit_boundary" >:: test_good_exit_boundary;
         "just_inside_boundaries" >:: test_just_inside_boundaries;
         "missing_horizon_neutral" >:: test_missing_horizon_neutral;
         "empty_neutral" >:: test_empty_neutral;
         "multi_horizon_picks_configured"
         >:: test_multi_horizon_picks_configured;
         "custom_config_horizon" >:: test_custom_config_horizon;
         "capture_ratio_normal" >:: test_capture_ratio_normal;
         "capture_ratio_negative" >:: test_capture_ratio_negative;
         "capture_ratio_full" >:: test_capture_ratio_full;
         "capture_ratio_mfe_zero_none" >:: test_capture_ratio_mfe_zero_none;
         "capture_ratio_mfe_negative_none"
         >:: test_capture_ratio_mfe_negative_none;
       ]

let () = run_test_tt_main suite
