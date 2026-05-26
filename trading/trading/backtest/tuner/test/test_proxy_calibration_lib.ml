(** Unit tests for {!Tuner.Proxy_calibration_lib}. Synthetic float arrays;
    no walk-forward run, no sexp I/O. Pins the Spearman ρ formula at known
    expected values + edge cases. *)

open OUnit2
open Core
open Matchers
module PC = Tuner.Proxy_calibration_lib
module Wf = Walk_forward.Walk_forward_types

(* ----------------- Spearman ρ ------------------------------------------ *)

(** Identical inputs ⇒ ρ = 1.0 (perfect monotone match). *)
let test_spearman_identical _ =
  let xs = [| 1.0; 2.0; 3.0; 4.0; 5.0 |] in
  assert_that (PC.spearman_rho xs xs) (float_equal ~epsilon:1e-12 1.0)

(** Reverse inputs ⇒ ρ = -1.0 (perfect anti-monotone). *)
let test_spearman_reverse _ =
  let xs = [| 1.0; 2.0; 3.0; 4.0; 5.0 |] in
  let ys = [| 5.0; 4.0; 3.0; 2.0; 1.0 |] in
  assert_that (PC.spearman_rho xs ys) (float_equal ~epsilon:1e-12 (-1.0))

(** Hand-computed Spearman on a 5-element example.

    xs = [1; 2; 3; 4; 5]  -> ranks = [1; 2; 3; 4; 5]
    ys = [3; 1; 4; 2; 5]  -> ranks = [3; 1; 4; 2; 5]
    Differences d_i: [1-3; 2-1; 3-4; 4-2; 5-5] = [-2; 1; -1; 2; 0]
    Σd² = 4 + 1 + 1 + 4 + 0 = 10
    ρ_textbook = 1 - 6·Σd² / (n(n²-1)) = 1 - 60/(5·24) = 1 - 0.5 = 0.5 *)
let test_spearman_known_value _ =
  let xs = [| 1.0; 2.0; 3.0; 4.0; 5.0 |] in
  let ys = [| 3.0; 1.0; 4.0; 2.0; 5.0 |] in
  assert_that (PC.spearman_rho xs ys) (float_equal ~epsilon:1e-10 0.5)

(** Weak-correlation case. Hand computation:
    xs = [1; 2; 3; 4; 5]    ranks rx = [1; 2; 3; 4; 5]
    ys = [3; 1; 5; 2; 4]    ranks ry = [3; 1; 5; 2; 4]
    d_i = rx - ry = [-2; 1; -2; 2; 1]
    Σd² = 4 + 1 + 4 + 4 + 1 = 14
    ρ = 1 - 6·14 / (5·24) = 1 - 84/120 = 0.3 *)
let test_spearman_low_correlation _ =
  let xs = [| 1.0; 2.0; 3.0; 4.0; 5.0 |] in
  let ys = [| 3.0; 1.0; 5.0; 2.0; 4.0 |] in
  assert_that (PC.spearman_rho xs ys) (float_equal ~epsilon:1e-10 0.3)

(** Tie handling: equal values receive the average of their would-be ranks.

    xs = [1; 1; 2; 2; 3]
      Sorted: 1,1,2,2,3 → mid-ranks: avg(1,2)=1.5 for the two 1s, avg(3,4)=3.5
        for the two 2s, 5 for the 3. So ranks = [1.5; 1.5; 3.5; 3.5; 5].
    ys = [1; 2; 3; 4; 5]   ranks = [1; 2; 3; 4; 5]
    Pearson of those rank vectors = ? Compute by hand below.

    Σ(rx)  = 1.5+1.5+3.5+3.5+5 = 15 ; mean rx = 3
    Σ(ry)  = 1+2+3+4+5 = 15 ; mean ry = 3
    rx - mean rx: [-1.5; -1.5; 0.5; 0.5; 2]
    ry - mean ry: [-2; -1; 0; 1; 2]
    Cov num = (-1.5*-2) + (-1.5*-1) + (0.5*0) + (0.5*1) + (2*2) = 3 + 1.5 + 0 + 0.5 + 4 = 9
    sxx = 1.5²·2 + 0.5²·2 + 2² = 4.5 + 0.5 + 4 = 9 → wait: 2.25*2 = 4.5; 0.25*2 = 0.5; 4. Σ = 9
    syy = 4 + 1 + 0 + 1 + 4 = 10
    denom = sqrt(9*10) = sqrt(90) ≈ 9.4868
    ρ = 9 / 9.4868 ≈ 0.9487 *)
let test_spearman_ties _ =
  let xs = [| 1.0; 1.0; 2.0; 2.0; 3.0 |] in
  let ys = [| 1.0; 2.0; 3.0; 4.0; 5.0 |] in
  assert_that
    (PC.spearman_rho xs ys)
    (float_equal ~epsilon:1e-4 0.9487)

(** Length mismatch raises Invalid_argument. *)
let test_spearman_length_mismatch _ =
  let xs = [| 1.0; 2.0; 3.0 |] in
  let ys = [| 1.0; 2.0 |] in
  let f () =
    let _ = PC.spearman_rho xs ys in
    ()
  in
  assert_raises
    (Invalid_argument "spearman_rho: array length mismatch (3 vs 2)") f

(** Empty inputs ⇒ ρ = 0.0 (no signal). *)
let test_spearman_empty _ =
  assert_that (PC.spearman_rho [||] [||]) (float_equal ~epsilon:1e-12 0.0)

(** Single-point inputs ⇒ ρ = 0.0 (no rank variance). *)
let test_spearman_single _ =
  let xs = [| 7.0 |] in
  let ys = [| 9.0 |] in
  assert_that (PC.spearman_rho xs ys) (float_equal ~epsilon:1e-12 0.0)

(** All-equal inputs ⇒ ρ = 0.0 (denominator collapses; matches SciPy
    convention). *)
let test_spearman_zero_variance _ =
  let xs = [| 1.0; 1.0; 1.0; 1.0 |] in
  let ys = [| 2.0; 4.0; 6.0; 8.0 |] in
  assert_that (PC.spearman_rho xs ys) (float_equal ~epsilon:1e-12 0.0)

(* ----------------- matched_pairs --------------------------------------- *)

let _fold_actual ?(variant_label = "cell-E") ?(total_return_pct = Float.nan)
    ?(sharpe_ratio = Float.nan) ?(max_drawdown_pct = Float.nan)
    ?(calmar_ratio = Float.nan) ?(cagr_pct = Float.nan)
    ?(avg_holding_days = Float.nan) ~fold_name () : Wf.fold_actual =
  {
    fold_name;
    variant_label;
    total_return_pct;
    sharpe_ratio;
    max_drawdown_pct;
    calmar_ratio;
    cagr_pct;
    avg_holding_days;
  }

(** Cheap (6 folds) is a subset of expensive (26 folds); matched_pairs returns
    the intersection in cheap-order. *)
let test_matched_pairs_subset _ =
  let cheap =
    [
      _fold_actual ~fold_name:"fold-005" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"fold-010" ~sharpe_ratio:1.0 ();
      _fold_actual ~fold_name:"fold-020" ~sharpe_ratio:2.0 ();
    ]
  in
  let expensive =
    List.init 26 ~f:(fun i ->
        _fold_actual
          ~fold_name:(Printf.sprintf "fold-%03d" i)
          ~sharpe_ratio:(Float.of_int i *. 0.1)
          ())
  in
  let pairs =
    PC.matched_pairs ~cheap_actuals:cheap ~expensive_actuals:expensive
      ~metric:`Sharpe
  in
  assert_that pairs
    (elements_are
       [
         equal_to
           ({ PC.fold_name = "fold-005"; cheap = 0.5; expensive = 0.5 }
             : PC.fold_pair);
         equal_to
           ({ PC.fold_name = "fold-010"; cheap = 1.0; expensive = 1.0 }
             : PC.fold_pair);
         equal_to
           ({ PC.fold_name = "fold-020"; cheap = 2.0; expensive = 2.0 }
             : PC.fold_pair);
       ])

(** Disjoint inputs (no shared fold_name) return the empty list. *)
let test_matched_pairs_disjoint _ =
  let cheap =
    [
      _fold_actual ~fold_name:"alpha" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"beta" ~sharpe_ratio:1.0 ();
    ]
  in
  let expensive =
    [
      _fold_actual ~fold_name:"gamma" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"delta" ~sharpe_ratio:1.0 ();
    ]
  in
  let pairs =
    PC.matched_pairs ~cheap_actuals:cheap ~expensive_actuals:expensive
      ~metric:`Sharpe
  in
  assert_that pairs (size_is 0)

(** Metric dispatch: requesting `Total_return_pct projects the right field. *)
let test_matched_pairs_metric_dispatch _ =
  let cheap =
    [ _fold_actual ~fold_name:"f0" ~total_return_pct:10.0 ~sharpe_ratio:0.5 () ]
  in
  let expensive =
    [ _fold_actual ~fold_name:"f0" ~total_return_pct:20.0 ~sharpe_ratio:1.0 () ]
  in
  let pairs =
    PC.matched_pairs ~cheap_actuals:cheap ~expensive_actuals:expensive
      ~metric:`Total_return_pct
  in
  assert_that pairs
    (elements_are
       [
         equal_to
           ({ PC.fold_name = "f0"; cheap = 10.0; expensive = 20.0 }
             : PC.fold_pair);
       ])

(* ----------------- end-to-end calibration ------------------------------ *)

(** End-to-end on the T1.4 acceptance pattern. Cheap (6 folds) is a strict
    subset of expensive (26 folds), all Cell E, and the per-fold Sharpe values
    are PERFECTLY monotone — so ρ = 1.0 ≥ 0.7 ⇒ PASS. Demonstrates the full
    matched-pairs → spearman_rho → classify pipeline. *)
let test_end_to_end_pass _ =
  let n_expensive = 26 in
  let cheap_indices = [ 0; 5; 10; 15; 20; 25 ] in
  let expensive =
    List.init n_expensive ~f:(fun i ->
        _fold_actual
          ~fold_name:(Printf.sprintf "fold-%03d" i)
          ~sharpe_ratio:(Float.of_int i *. 0.1)
          ())
  in
  let cheap =
    List.map cheap_indices ~f:(fun i ->
        _fold_actual
          ~fold_name:(Printf.sprintf "fold-%03d" i)
          ~sharpe_ratio:(Float.of_int i *. 0.1)
          ())
  in
  let pairs =
    PC.matched_pairs ~cheap_actuals:cheap ~expensive_actuals:expensive
      ~metric:`Sharpe
  in
  let cheap_xs = List.map pairs ~f:(fun p -> p.cheap) |> Array.of_list in
  let exp_ys = List.map pairs ~f:(fun p -> p.expensive) |> Array.of_list in
  let rho = PC.spearman_rho cheap_xs exp_ys in
  let verdict = PC.classify ~threshold:PC.acceptance_threshold ~rho in
  assert_that rho (float_equal ~epsilon:1e-12 1.0);
  assert_that verdict (equal_to (PC.Pass : PC.verdict))

(** End-to-end FAIL case: cheap proxy is anti-correlated with expensive
    (perfect inverse) so ρ = -1.0 < 0.7 ⇒ FAIL. *)
let test_end_to_end_fail _ =
  let expensive =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:1.0 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:2.0 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:3.0 ();
      _fold_actual ~fold_name:"f3" ~sharpe_ratio:4.0 ();
    ]
  in
  let cheap =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:4.0 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:3.0 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:2.0 ();
      _fold_actual ~fold_name:"f3" ~sharpe_ratio:1.0 ();
    ]
  in
  let pairs =
    PC.matched_pairs ~cheap_actuals:cheap ~expensive_actuals:expensive
      ~metric:`Sharpe
  in
  let cheap_xs = List.map pairs ~f:(fun p -> p.cheap) |> Array.of_list in
  let exp_ys = List.map pairs ~f:(fun p -> p.expensive) |> Array.of_list in
  let rho = PC.spearman_rho cheap_xs exp_ys in
  let verdict = PC.classify ~threshold:PC.acceptance_threshold ~rho in
  assert_that rho (float_equal ~epsilon:1e-12 (-1.0));
  assert_that verdict (equal_to (PC.Fail : PC.verdict))

(* ----------------- classify -------------------------------------------- *)

(** Classify returns Pass when rho equals the threshold exactly. *)
let test_classify_boundary _ =
  assert_that
    (PC.classify ~threshold:0.7 ~rho:0.7)
    (equal_to (PC.Pass : PC.verdict))

(** Classify returns Fail just below the threshold. *)
let test_classify_below _ =
  assert_that
    (PC.classify ~threshold:0.7 ~rho:0.6999)
    (equal_to (PC.Fail : PC.verdict))

(** NaN rho classifies as Fail (defensive). *)
let test_classify_nan _ =
  assert_that
    (PC.classify ~threshold:0.7 ~rho:Float.nan)
    (equal_to (PC.Fail : PC.verdict))

(* ----------------- suite ----------------------------------------------- *)

let suite =
  "test_proxy_calibration_lib"
  >::: [
         "spearman_identical" >:: test_spearman_identical;
         "spearman_reverse" >:: test_spearman_reverse;
         "spearman_known_value" >:: test_spearman_known_value;
         "spearman_low_correlation" >:: test_spearman_low_correlation;
         "spearman_ties" >:: test_spearman_ties;
         "spearman_length_mismatch" >:: test_spearman_length_mismatch;
         "spearman_empty" >:: test_spearman_empty;
         "spearman_single" >:: test_spearman_single;
         "spearman_zero_variance" >:: test_spearman_zero_variance;
         "matched_pairs_subset" >:: test_matched_pairs_subset;
         "matched_pairs_disjoint" >:: test_matched_pairs_disjoint;
         "matched_pairs_metric_dispatch" >:: test_matched_pairs_metric_dispatch;
         "end_to_end_pass" >:: test_end_to_end_pass;
         "end_to_end_fail" >:: test_end_to_end_fail;
         "classify_boundary" >:: test_classify_boundary;
         "classify_below" >:: test_classify_below;
         "classify_nan" >:: test_classify_nan;
       ]

let () = run_test_tt_main suite
