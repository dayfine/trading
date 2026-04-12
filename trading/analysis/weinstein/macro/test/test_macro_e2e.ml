(** End-to-end tests for macro analysis (Milestone 2).

    Demonstrates: "You can see the current market regime
    (bullish/bearish/neutral) and which sectors are strong or weak."

    Uses real cached GSPC.INDX data. See {!Test_data_loader} for required data
    dependencies.

    {b Not tested yet} (data not available):
    - A-D breadth (ADL): EODHD does not carry [ADV.NYSE]/[DEC.NYSE]. Needs an
      alternative data source. Tracked in [dev/notes/data-gaps.md].
    - Sector analysis: requires sector ETF bars + [Instrument_info.sector]
      populated via EODHD fundamentals tier. Tracked in
      [dev/notes/data-gaps.md]. *)

open Core
open OUnit2
open Matchers
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let _analyze_macro ~start_date ~end_date =
  let weekly =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX" ~start_date ~end_date
  in
  Macro.analyze ~config:Macro.default_config ~index_bars:weekly ~ad_bars:[]
    ~global_index_bars:[] ~prior_stage:None ~prior:None

(* ------------------------------------------------------------------ *)
(* M2 Test 1: 2022 bear market — bearish regime                        *)
(* ------------------------------------------------------------------ *)

let test_macro_2022_bear_market _ =
  let result =
    _analyze_macro
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-10-14")
  in
  assert_that result
    (all_of
       [
         field (fun (r : Macro.result) -> r.trend) (equal_to Bearish);
         field
           (fun (r : Macro.result) -> r.confidence)
           (lt (module Float_ord) 0.5);
         field
           (fun (r : Macro.result) -> List.length r.rationale)
           (gt (module Int_ord) 0);
       ])

(* ------------------------------------------------------------------ *)
(* M2 Test 2: 2023 bull market — bullish regime                        *)
(* ------------------------------------------------------------------ *)

let test_macro_2023_bull_market _ =
  let result =
    _analyze_macro
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2024-03-29")
  in
  assert_that result
    (all_of
       [
         field (fun (r : Macro.result) -> r.trend) (equal_to Bullish);
         field
           (fun (r : Macro.result) -> r.confidence)
           (gt (module Float_ord) 0.5);
         field
           (fun (r : Macro.result) -> r.index_stage.ma_direction)
           (equal_to Rising);
       ])

(* ------------------------------------------------------------------ *)
(* M2 Test 3: degrades gracefully with missing A-D breadth and global   *)
(* ------------------------------------------------------------------ *)

let test_macro_degrades_without_breadth _ =
  let weekly =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX"
      ~start_date:(Date.of_string "2023-01-01")
      ~end_date:(Date.of_string "2024-03-29")
  in
  (* Call with empty ad_bars and global_index_bars — should not error *)
  let result =
    Macro.analyze ~config:Macro.default_config ~index_bars:weekly ~ad_bars:[]
      ~global_index_bars:[] ~prior_stage:None ~prior:None
  in
  assert_that result
    (all_of
       [
         (* trend is populated — type-checking ensures it's a valid variant *)
         field
           (fun (r : Macro.result) -> ignore (r.trend : market_trend))
           (fun () -> ());
         field
           (fun (r : Macro.result) -> r.confidence)
           (is_between (module Float_ord) ~low:0.0 ~high:1.0);
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("macro_e2e"
    >::: [
           "2022 bear market — bearish regime" >:: test_macro_2022_bear_market;
           "2023 bull market — bullish regime" >:: test_macro_2023_bull_market;
           "degrades gracefully without breadth data"
           >:: test_macro_degrades_without_breadth;
         ])
