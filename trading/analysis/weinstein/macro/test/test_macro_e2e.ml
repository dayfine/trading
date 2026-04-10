(** End-to-end tests for macro analysis (Milestone 2).

    Demonstrates: "You can see the current market regime
    (bullish/bearish/neutral) and which sectors are strong or weak."

    Uses real cached GSPC.INDX data. Sector analysis requires sector ETF data
    which is not yet cached — that part is deferred. *)

open Core
open OUnit2
open Matchers
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)

let _load_bars ~symbol ~start_date ~end_date =
  let data_dir = Fpath.to_string (Data_path.default_data_dir ()) in
  let simulation_date = end_date in
  let config : Historical_source.config = { data_dir; simulation_date } in
  let ds = Historical_source.make config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  let query : Data_source.bar_query =
    {
      symbol;
      period = Types.Cadence.Daily;
      start_date = Some start_date;
      end_date = Some end_date;
    }
  in
  match run_deferred (DS.get_bars ~query ()) with
  | Ok bars -> bars
  | Error e ->
      failwith (Printf.sprintf "load %s failed: %s" symbol (Status.show e))

let _to_weekly daily =
  Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily

let _analyze_macro ~start_date ~end_date =
  let daily = _load_bars ~symbol:"GSPC.INDX" ~start_date ~end_date in
  let weekly = _to_weekly daily in
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
  assert_that result.trend (equal_to Bearish);
  assert_that result.confidence (lt (module Float_ord) 0.5);
  assert_that result.rationale (fun rationale ->
      assert_that (List.length rationale) (gt (module Int_ord) 0))

(* ------------------------------------------------------------------ *)
(* M2 Test 2: 2023 bull market — bullish regime                        *)
(* ------------------------------------------------------------------ *)

let test_macro_2023_bull_market _ =
  let result =
    _analyze_macro
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2024-03-29")
  in
  assert_that result.trend (equal_to Bullish);
  assert_that result.confidence (gt (module Float_ord) 0.5);
  assert_that result.index_stage.ma_direction (equal_to Rising)

(* ------------------------------------------------------------------ *)
(* M2 Test 3: degrades gracefully with missing A-D breadth and global   *)
(* ------------------------------------------------------------------ *)

let test_macro_degrades_without_breadth _ =
  let daily =
    _load_bars ~symbol:"GSPC.INDX"
      ~start_date:(Date.of_string "2023-01-01")
      ~end_date:(Date.of_string "2024-03-29")
  in
  let weekly = _to_weekly daily in
  (* Call with empty ad_bars and global_index_bars — should not error *)
  let result =
    Macro.analyze ~config:Macro.default_config ~index_bars:weekly ~ad_bars:[]
      ~global_index_bars:[] ~prior_stage:None ~prior:None
  in
  (* Still returns a valid result with a trend *)
  (* Returns a valid trend (any of the three is fine) *)
  assert_that result.trend (fun actual ->
      assert_that
        (equal_market_trend actual Bullish
        || equal_market_trend actual Bearish
        || equal_market_trend actual Neutral)
        (equal_to true));
  (* Confidence is still between 0 and 1 *)
  assert_that result.confidence
    (all_of [ ge (module Float_ord) 0.0; le (module Float_ord) 1.0 ])

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
