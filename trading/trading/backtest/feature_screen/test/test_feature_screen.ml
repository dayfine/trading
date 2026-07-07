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
         "logistic_separable" >:: test_logistic_separable;
         "one_hot_mapping" >:: test_one_hot_mapping;
         "era_split" >:: test_era_split;
       ]

let () = run_test_tt_main suite
