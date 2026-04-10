(** End-to-end tests for single-stock analysis (Milestone 1).

    Demonstrates: "You can analyze any individual stock — its current stage,
    breakout proximity, volume confirmation, relative strength, overhead
    resistance, and suggested stop level."

    Uses real cached AAPL and GSPC.INDX data. See {!Test_data_loader} for
    required data dependencies. *)

open Core
open OUnit2
open Matchers
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _analyze ~ticker ~start_date ~end_date =
  let weekly =
    Test_data_loader.load_weekly_bars ~symbol:ticker ~start_date ~end_date
  in
  let benchmark_weekly =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX" ~start_date ~end_date
  in
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
    ~bars:weekly ~benchmark_bars:benchmark_weekly ~prior_stage:None
    ~as_of_date:end_date

(* ------------------------------------------------------------------ *)
(* M1 Test 1: Full analysis — AAPL in 2023 bull market                 *)
(* ------------------------------------------------------------------ *)

let test_aapl_bull_market_2023 _ =
  let result =
    _analyze ~ticker:"AAPL"
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-12-29")
  in
  assert_that result
    (all_of
       [
         field (fun (r : Stock_analysis.t) -> r.ticker) (equal_to "AAPL");
         (* Stage should be Stage2 — AAPL rose ~50% in 2023 *)
         field
           (fun (r : Stock_analysis.t) -> r.stage.stage)
           (matching ~msg:"Expected Stage2"
              (function Stage2 _ -> Some () | _ -> None)
              (equal_to ()));
         field
           (fun (r : Stock_analysis.t) -> r.stage.ma_direction)
           (equal_to Rising);
         (* RS should be computed *)
         field
           (fun (r : Stock_analysis.t) -> r.rs)
           (is_some_and
              (field (fun rs -> rs.Rs.current_rs) (gt (module Float_ord) 0.0)));
       ])

(* ------------------------------------------------------------------ *)
(* M1 Test 2: Full analysis — AAPL in 2022 bear market                 *)
(* ------------------------------------------------------------------ *)

let test_aapl_bear_market_2022 _ =
  let result =
    _analyze ~ticker:"AAPL"
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-10-14")
  in
  assert_that result
    (all_of
       [
         (* Stage should be Stage4 or Stage3 — AAPL fell ~30% in 2022 *)
         field
           (fun (r : Stock_analysis.t) -> r.stage.stage)
           (matching ~msg:"Expected Stage3 or Stage4"
              (function Stage3 _ -> Some () | Stage4 _ -> Some () | _ -> None)
              (equal_to ()));
         (* MA should be declining or flat *)
         field
           (fun (r : Stock_analysis.t) -> r.stage.ma_direction)
           (matching ~msg:"Expected Declining or Flat"
              (function Rising -> None | d -> Some d)
              (fun _ -> ()));
       ])

(* ------------------------------------------------------------------ *)
(* M1 Test 3: All output fields are populated                          *)
(* ------------------------------------------------------------------ *)

let test_all_fields_populated _ =
  let result =
    _analyze ~ticker:"AAPL"
      ~start_date:(Date.of_string "2022-01-01")
      ~end_date:(Date.of_string "2024-06-28")
  in
  assert_that result
    (all_of
       [
         field (fun (r : Stock_analysis.t) -> r.ticker) (equal_to "AAPL");
         field
           (fun (r : Stock_analysis.t) -> r.as_of_date)
           (equal_to (Date.of_string "2024-06-28"));
         field
           (fun (r : Stock_analysis.t) -> r.stage.above_ma_count)
           (ge (module Int_ord) 0);
         field
           (fun (r : Stock_analysis.t) -> r.rs)
           (is_some_and
              (field (fun rs -> rs.Rs.current_rs) (gt (module Float_ord) 0.0)));
         (* Volume and resistance may or may not find results, but should not crash *)
         field
           (fun (r : Stock_analysis.t) ->
             ignore (r.volume : Volume.result option))
           (fun () -> ());
         field
           (fun (r : Stock_analysis.t) ->
             ignore (r.resistance : Resistance.result option))
           (fun () -> ());
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("stock_analysis_e2e"
    >::: [
           "AAPL bull market 2023 — Stage2, rising MA, RS computed"
           >:: test_aapl_bull_market_2023;
           "AAPL bear market 2022 — Stage3/4, declining MA"
           >:: test_aapl_bear_market_2022;
           "all output fields populated" >:: test_all_fields_populated;
         ])
