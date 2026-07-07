open Core
open OUnit2
open Matchers
module FS = Backtest_feature_screen
module CR = FS.Csv_rows
module FM = FS.Feature_matrix
module Reg = FS.Regression

(* ---------------------------------------------------------------- *)
(* Row builder                                                        *)
(* ---------------------------------------------------------------- *)

let mk_row ?(date = "2020-01-03") ?(return_pct = 0.05) ?(cascade_score = 70)
    ?(passes_macro = true) ?rs_value ?rs_trend ?volume_ratio ?weeks_advancing
    ?stage2_late ?resistance_quality () : CR.row =
  {
    signal_date = Date.of_string date;
    return_pct;
    cascade_score;
    passes_macro;
    rs_value;
    rs_trend;
    volume_ratio;
    weeks_advancing;
    stage2_late;
    resistance_quality;
  }

(* ---------------------------------------------------------------- *)
(* CSV parsing                                                        *)
(* ---------------------------------------------------------------- *)

let valid_row =
  "2020-01-03,AAA,LONG,10.0000,2020-02-07,Stop_hit,0.050000,35,5000.00,500.000000,250.00,70,true,,,1.800000,4,false,Clean"

let test_parse_valid _ =
  assert_that
    (Result.ok (CR.parse_rows [ CR.expected_header; valid_row ]))
    (is_some_and
       (elements_are
          [
            all_of
              [
                field (fun (r : CR.row) -> r.return_pct) (float_equal 0.05);
                field (fun (r : CR.row) -> r.cascade_score) (equal_to 70);
                field (fun (r : CR.row) -> r.passes_macro) (equal_to true);
                field (fun (r : CR.row) -> r.rs_value) is_none;
                field (fun (r : CR.row) -> r.rs_trend) is_none;
                field
                  (fun (r : CR.row) -> r.volume_ratio)
                  (is_some_and (float_equal 1.8));
                field
                  (fun (r : CR.row) -> r.weeks_advancing)
                  (is_some_and (equal_to 4));
                field
                  (fun (r : CR.row) -> r.stage2_late)
                  (is_some_and (equal_to false));
                field
                  (fun (r : CR.row) -> r.resistance_quality)
                  (is_some_and (equal_to "Clean"));
              ];
          ]))

let test_parse_bad_header _ =
  assert_that (Result.ok (CR.parse_rows [ "wrong,header"; valid_row ])) is_none

let test_parse_bad_column_count _ =
  assert_that
    (Result.ok (CR.parse_rows [ CR.expected_header; "a,b,c" ]))
    is_none

(* ---------------------------------------------------------------- *)
(* OLS coefficient recovery (noise-free)                             *)
(* ---------------------------------------------------------------- *)

let test_ols_recovers_known _ =
  (* y = 2*x1 - 1*x2, intercept 0, exact. *)
  let pts = [ (1., 0.); (0., 1.); (1., 1.); (2., 1.); (1., 2.); (3., 2.) ] in
  let x = Array.of_list_map pts ~f:(fun (a, b) -> [| 1.0; a; b |]) in
  let y = Array.of_list_map pts ~f:(fun (a, b) -> (2.0 *. a) -. b) in
  assert_that
    (Result.ok (Reg.ols ~x ~y ~names:[ "intercept"; "x1"; "x2" ]))
    (is_some_and
       (all_of
          [
            field
              (fun (r : Reg.ols_result) -> r.r2)
              (float_equal ~epsilon:1e-9 1.0);
            field
              (fun (r : Reg.ols_result) -> r.terms)
              (elements_are
                 [
                   field (fun t -> t.Reg.coef) (float_equal ~epsilon:1e-6 0.0);
                   field (fun t -> t.Reg.coef) (float_equal ~epsilon:1e-6 2.0);
                   field
                     (fun t -> t.Reg.coef)
                     (float_equal ~epsilon:1e-6 (-1.0));
                 ]);
          ]))

(* ---------------------------------------------------------------- *)
(* OLS HC1-robust standard errors (heteroscedastic residuals)        *)
(* ---------------------------------------------------------------- *)

(* Hand-computed golden pinning the White HC1-robust SE path (the noise-free
   test above leaves residuals = 0, so the sandwich is never exercised there).
   Design: intercept + one centred predictor, so [X'X] is diagonal and the
   sandwich collapses to a per-coefficient scalar we can compute by hand.
     x column = [1; -1; 2; -2; 3; -3]   (Σx = 0, Σx² = 28),  n = 6, p = 2
   True model y = 1 + 2·x + e with residuals e = [-3; -3; 1; 1; 2; 2], chosen
   to satisfy the OLS normal equations (Σe = 0, Σ x·e = 0) so the fit recovers
   β = (1, 2) exactly with exactly those (heteroscedastic) residuals:
     y = [0; -4; 6; -2; 9; -3]
   HC1: var(β_j) = n/(n-p) · [ bread · (Σ_i e_i² x_i x_iᵀ) · bread ]_jj, with
   the small-sample factor n/(n-p) = 6/4 = 1.5 and diagonal bread =
   diag(1/6, 1/28):
     meat[0,0] = Σ e²   = 9+9+1+1+4+4 = 28
     meat[1,1] = Σ e²·x² = 9+9+4+4+36+36 = 98
     var(intercept) = 1.5 · (1/6)²  · 28 = 7/6    → se = √(7/6)  = 1.0801234497
     var(slope)     = 1.5 · (1/28)² · 98 = 0.1875 → se = √0.1875 = 0.4330127019
   t-stats = coef/se: intercept 1/√(7/6) = 0.9258200998,
                      slope     2/√0.1875 = 4.6188021535
   r² = 1 - Σe²/Σ(y-ȳ)² = 1 - 28/140 = 0.8 *)
let test_ols_hc1_robust_se _ =
  let xs = [ 1.; -1.; 2.; -2.; 3.; -3. ] in
  let ys = [ 0.; -4.; 6.; -2.; 9.; -3. ] in
  let x = Array.of_list_map xs ~f:(fun v -> [| 1.0; v |]) in
  let y = Array.of_list ys in
  assert_that
    (Result.ok (Reg.ols ~x ~y ~names:[ "intercept"; "slope" ]))
    (is_some_and
       (all_of
          [
            field
              (fun (r : Reg.ols_result) -> r.r2)
              (float_equal ~epsilon:1e-9 0.8);
            field
              (fun (r : Reg.ols_result) -> r.terms)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun t -> t.Reg.coef)
                         (float_equal ~epsilon:1e-9 1.0);
                       field
                         (fun t -> t.Reg.se)
                         (float_equal ~epsilon:1e-6 1.0801234497);
                       field
                         (fun t -> t.Reg.stat)
                         (float_equal ~epsilon:1e-6 0.9258200998);
                     ];
                   all_of
                     [
                       field
                         (fun t -> t.Reg.coef)
                         (float_equal ~epsilon:1e-9 2.0);
                       field
                         (fun t -> t.Reg.se)
                         (float_equal ~epsilon:1e-6 0.4330127019);
                       field
                         (fun t -> t.Reg.stat)
                         (float_equal ~epsilon:1e-6 4.6188021535);
                     ];
                 ]);
          ]))

(* ---------------------------------------------------------------- *)
(* Singular-matrix Error paths                                        *)
(* ---------------------------------------------------------------- *)

let test_solve_singular _ =
  (* Row 2 = 2·row 1: rank-deficient, no unique solution. *)
  let a = [| [| 1.0; 2.0 |]; [| 2.0; 4.0 |] |] in
  let b = [| 1.0; 2.0 |] in
  assert_that
    (Result.error (Reg.solve a b))
    (is_some_and (equal_to "singular matrix"))

let test_ols_singular_column _ =
  (* Duplicated predictor column ⇒ X'X is singular ⇒ solve's Error propagates. *)
  let x =
    [|
      [| 1.0; 1.0; 1.0 |];
      [| 1.0; 2.0; 2.0 |];
      [| 1.0; 3.0; 3.0 |];
      [| 1.0; 4.0; 4.0 |];
    |]
  in
  let y = [| 1.0; 2.0; 3.0; 4.0 |] in
  assert_that
    (Result.error (Reg.ols ~x ~y ~names:[ "intercept"; "x1"; "x1_dup" ]))
    (is_some_and (equal_to "singular matrix"))

(* ---------------------------------------------------------------- *)
(* Logistic sign + AUC on separable data                             *)
(* ---------------------------------------------------------------- *)

let test_logistic_separable _ =
  let xs = [ 1.; 1.5; 2.; 2.5; 3.; 3.5; 4.; 4.5 ] in
  let x = Array.of_list_map xs ~f:(fun v -> [| 1.0; v |]) in
  let y =
    Array.of_list_map xs ~f:(fun v -> if Float.( >= ) v 3.0 then 1.0 else 0.0)
  in
  assert_that
    (Result.ok (Reg.logistic ~x ~y ~names:[ "intercept"; "x1" ]))
    (is_some_and
       (all_of
          [
            field (fun (r : Reg.logit_result) -> r.auc) (float_equal 1.0);
            field
              (fun (r : Reg.logit_result) -> r.terms)
              (elements_are
                 [ __; field (fun t -> t.Reg.coef) (gt (module Float_ord) 0.0) ]);
          ]))

(* ---------------------------------------------------------------- *)
(* One-hot encoding (drop-first reference)                           *)
(* ---------------------------------------------------------------- *)

let test_one_hot_mapping _ =
  (* Observed levels (canonical order): Bullish_crossover (reference),
     Positive_rising, Positive_flat. Unobserved levels get no column. *)
  let rows =
    [
      mk_row ~rs_trend:"Bullish_crossover" ();
      mk_row ~rs_trend:"Positive_rising" ();
      mk_row ~rs_trend:"Positive_flat" ();
    ]
  in
  assert_that
    (Result.ok (FM.build ~features:[ FM.Rs_trend ] ~rows))
    (is_some_and
       (field
          (fun ((d : FM.design), _) -> d)
          (all_of
             [
               field
                 (fun (d : FM.design) -> d.column_names)
                 (elements_are
                    [
                      equal_to "intercept";
                      equal_to "rs_trend=Positive_rising";
                      equal_to "rs_trend=Positive_flat";
                    ]);
               (* Reference row (Bullish_crossover): all dummies 0. *)
               field
                 (fun (d : FM.design) -> Array.to_list d.x.(0))
                 (elements_are (List.map [ 1.0; 0.0; 0.0 ] ~f:float_equal));
               (* Positive_rising row: first dummy set. *)
               field
                 (fun (d : FM.design) -> Array.to_list d.x.(1))
                 (elements_are (List.map [ 1.0; 1.0; 0.0 ] ~f:float_equal));
               (* Positive_flat row: second dummy set. *)
               field
                 (fun (d : FM.design) -> Array.to_list d.x.(2))
                 (elements_are (List.map [ 1.0; 0.0; 1.0 ] ~f:float_equal));
             ])))

(* ---------------------------------------------------------------- *)
(* Era split                                                          *)
(* ---------------------------------------------------------------- *)

let test_era_split _ =
  let rows =
    List.map
      [
        "2005-06-03";
        "2012-06-01";
        "2020-06-05";
        "2008-12-05";
        "2009-01-02";
        "2018-03-02";
      ] ~f:(fun d -> mk_row ~date:d ())
  in
  assert_that (FM.eras rows)
    (elements_are
       [
         all_of
           [
             field fst (equal_to "2000-2008");
             field (fun (_, l) -> List.length l) (equal_to 2);
           ];
         all_of
           [
             field fst (equal_to "2009-2017");
             field (fun (_, l) -> List.length l) (equal_to 2);
           ];
         all_of
           [
             field fst (equal_to "2018-2026");
             field (fun (_, l) -> List.length l) (equal_to 2);
           ];
       ])

let suite =
  "feature_screen"
  >::: [
         "parse_valid" >:: test_parse_valid;
         "parse_bad_header" >:: test_parse_bad_header;
         "parse_bad_column_count" >:: test_parse_bad_column_count;
         "ols_recovers_known" >:: test_ols_recovers_known;
         "ols_hc1_robust_se" >:: test_ols_hc1_robust_se;
         "solve_singular" >:: test_solve_singular;
         "ols_singular_column" >:: test_ols_singular_column;
         "logistic_separable" >:: test_logistic_separable;
         "one_hot_mapping" >:: test_one_hot_mapping;
         "era_split" >:: test_era_split;
       ]

let () = run_test_tt_main suite
