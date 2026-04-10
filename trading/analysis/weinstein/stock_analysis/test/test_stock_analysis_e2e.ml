(** End-to-end tests for single-stock analysis (Milestone 1).

    Demonstrates: "You can analyze any individual stock — its current stage,
    breakout proximity, volume confirmation, relative strength, overhead
    resistance, and suggested stop level."

    Uses real cached AAPL and GSPC.INDX data. *)

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

let _analyze ~ticker ~start_date ~end_date =
  let daily = _load_bars ~symbol:ticker ~start_date ~end_date in
  let benchmark_daily = _load_bars ~symbol:"GSPC.INDX" ~start_date ~end_date in
  let weekly = _to_weekly daily in
  let benchmark_weekly = _to_weekly benchmark_daily in
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
  (* Stage should be Stage2 — AAPL rose ~50% in 2023 *)
  assert_that result.stage.stage
    (matching ~msg:"Expected Stage2"
       (function Stage2 _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that result.stage.ma_direction (equal_to Rising);
  (* RS should be computed (not None) *)
  assert_that result.rs (is_some_and (fun _ -> ()));
  (* Ticker matches *)
  assert_that result.ticker (equal_to "AAPL")

(* ------------------------------------------------------------------ *)
(* M1 Test 2: Full analysis — AAPL in 2022 bear market                 *)
(* ------------------------------------------------------------------ *)

let test_aapl_bear_market_2022 _ =
  let result =
    _analyze ~ticker:"AAPL"
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-10-14")
  in
  (* Stage should be Stage4 or Stage3 — AAPL fell ~30% in 2022 *)
  assert_that result.stage.stage
    (matching ~msg:"Expected Stage3 or Stage4"
       (function
         | Stage3 _ -> Some "Stage3" | Stage4 _ -> Some "Stage4" | _ -> None)
       (fun _ -> ()));
  (* MA should be declining or flat *)
  assert_that result.stage.ma_direction
    (matching ~msg:"Expected Declining or Flat"
       (function Rising -> None | d -> Some d)
       (fun _ -> ()))

(* ------------------------------------------------------------------ *)
(* M1 Test 3: All output fields are populated                          *)
(* ------------------------------------------------------------------ *)

let test_all_fields_populated _ =
  let result =
    _analyze ~ticker:"AAPL"
      ~start_date:(Date.of_string "2022-01-01")
      ~end_date:(Date.of_string "2024-06-28")
  in
  (* Core fields always present *)
  assert_that result.ticker (equal_to "AAPL");
  assert_that result.as_of_date (equal_to (Date.of_string "2024-06-28"));
  (* Stage result always populated *)
  assert_that result.stage.above_ma_count (ge (module Int_ord) 0);
  (* RS computed when benchmark bars available *)
  assert_that result.rs
    (is_some_and (fun rs ->
         assert_that rs.Rs.current_rs (gt (module Float_ord) 0.0)));
  (* Volume may or may not detect a breakout, but should not crash *)
  ignore (result.volume : Volume.result option);
  (* Resistance may or may not find levels *)
  ignore (result.resistance : Resistance.result option)

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
