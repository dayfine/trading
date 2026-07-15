(** Tests for {!Trade_audit_report.Trade_score} — the composite per-trade
    quality score surfaced in the interactive audit report. *)

open Core
open OUnit2
open Matchers
module Ratings = Trade_audit_report.Trade_audit_ratings
module Trade_score = Trade_audit_report.Trade_score

let _rating ?(r_multiple = 1.0) ?(mfe_pct = 0.10) ?(mae_pct = -0.02)
    ?(weinstein_score = 1.0) ?(outcome = Ratings.Win) () : Ratings.rating =
  {
    symbol = "AAPL";
    entry_date = Date.of_string "2020-01-03";
    r_multiple;
    mfe_pct;
    mae_pct;
    hold_time_anomaly = Ratings.Normal;
    outcome;
    weinstein_score;
  }

(* A near-perfect trade: kept all of a large excursion (capture 1), high R
   (risk_reward ~ 0.75 at 6R), never sank (pain 1), all rules pass. *)
let test_strong_winner_grades_high _ =
  let rating = _rating ~r_multiple:6.0 ~mfe_pct:0.30 ~mae_pct:0.0 () in
  let q = Trade_score.compute ~rating ~pnl_percent:30.0 () in
  assert_that q
    (all_of
       [
         field (fun (q : Trade_score.t) -> q.capture) (float_equal 1.0);
         field (fun (q : Trade_score.t) -> q.pain) (float_equal 1.0);
         field (fun (q : Trade_score.t) -> q.score) (ge (module Float_ord) 85.0);
         field (fun (q : Trade_score.t) -> q.grade) (equal_to "A+");
       ])

(* A full-stop loss: no capture, no risk_reward credit at -1R, pain floored at
   0 (MAE consumed the whole risk budget), rules pass; the conformance weight
   alone bounds the composite. *)
let test_full_stop_loss_grades_low _ =
  let rating =
    _rating ~r_multiple:(-1.0) ~mfe_pct:0.0 ~mae_pct:(-0.09)
      ~outcome:Ratings.Loss ()
  in
  let q = Trade_score.compute ~rating ~pnl_percent:(-9.0) () in
  assert_that q
    (all_of
       [
         field (fun (q : Trade_score.t) -> q.capture) (float_equal 0.0);
         field (fun (q : Trade_score.t) -> q.risk_reward) (float_equal 0.0);
         field (fun (q : Trade_score.t) -> q.pain) (float_equal 0.0);
         field (fun (q : Trade_score.t) -> q.score) (le (module Float_ord) 30.0);
       ])

(* NaN conformance (no applicable rules) re-weights onto the remaining
   components rather than zeroing or poisoning the composite. *)
let test_nan_conformance_reweights _ =
  let rating =
    _rating ~r_multiple:6.0 ~mfe_pct:0.30 ~mae_pct:0.0
      ~weinstein_score:Float.nan ()
  in
  let q = Trade_score.compute ~rating ~pnl_percent:30.0 () in
  assert_that q
    (all_of
       [
         field
           (fun (q : Trade_score.t) -> Float.is_nan q.conformance)
           (equal_to true);
         field
           (fun (q : Trade_score.t) -> Float.is_finite q.score)
           (equal_to true);
         field (fun (q : Trade_score.t) -> q.score) (ge (module Float_ord) 85.0);
       ])

(* A 2R winner earns exactly half the risk_reward component (r_scale = 2). *)
let test_r_scale_midpoint _ =
  let rating = _rating ~r_multiple:2.0 () in
  let q = Trade_score.compute ~rating ~pnl_percent:10.0 () in
  assert_that q.risk_reward (float_equal 0.5)

let test_grade_cuts _ =
  assert_that
    (List.map
       [ 90.0; 70.0; 55.0; 40.0; 25.0; 10.0 ]
       ~f:Trade_score.grade_of_score)
    (equal_to [ "A+"; "A"; "B"; "C"; "D"; "F" ])

let suite =
  "trade_score"
  >::: [
         "strong winner grades high" >:: test_strong_winner_grades_high;
         "full stop loss grades low" >:: test_full_stop_loss_grades_low;
         "nan conformance reweights" >:: test_nan_conformance_reweights;
         "2R winner is the risk_reward midpoint" >:: test_r_scale_midpoint;
         "grade cuts" >:: test_grade_cuts;
       ]

let () = run_test_tt_main suite
