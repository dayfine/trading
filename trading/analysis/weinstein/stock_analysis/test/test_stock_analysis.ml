open OUnit2
open Core
open Matchers
open Stock_analysis
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let as_of = Date.of_string "2024-01-01"

let make_bar date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.02;
    low_price = adjusted_close *. 0.98;
    close_price = adjusted_close;
    adjusted_close;
    volume = 1000;
  }

let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * 7))) p)

let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> weekly_bars

(* ------------------------------------------------------------------ *)
(* Basic functionality                                                  *)
(* ------------------------------------------------------------------ *)

let test_analyze_returns_ticker _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 100.0 200.0 in
  let result =
    analyze ~config:cfg ~ticker:"AAPL" ~bars ~benchmark_bars:bench
      ~prior_stage:None ~as_of_date:as_of
  in
  assert_that result.ticker (equal_to "AAPL")

let test_analyze_sets_as_of_date _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that result.as_of_date (equal_to as_of)

let test_analyze_preserves_prior_stage _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let prior = Some (Stage1 { weeks_in_base = 5 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:prior
      ~as_of_date:as_of
  in
  assert_that result.prior_stage (equal_to (prior : stage option))

(* ------------------------------------------------------------------ *)
(* Stage propagation                                                    *)
(* ------------------------------------------------------------------ *)

let test_stage2_stock_classified_correctly _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  match result.stage.stage with
  | Stage2 _ -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Stage2, got %s" (show_stage other))

(* ------------------------------------------------------------------ *)
(* Breakout candidate detection                                         *)
(* ------------------------------------------------------------------ *)

let test_breakout_candidate_stage2_transition _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  (* A Stage2 transition with adequate volume should be a breakout candidate *)
  (* The is_breakout_candidate function checks stage + volume + RS *)
  let _ = is_breakout_candidate result in
  () (* Just verify it doesn't raise *)

let test_breakdown_candidate_stage4_transition _ =
  let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 85.0) in
  let decline2 = List.init 20 ~f:(fun i -> 85.0 -. Float.of_int i) in
  let bars = declining @ flat @ decline2 |> weekly_bars in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:prior
      ~as_of_date:as_of
  in
  let _ = is_breakdown_candidate result in
  ()

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let r1 =
    analyze ~config:cfg ~ticker:"AAPL" ~bars ~benchmark_bars:bench
      ~prior_stage:None ~as_of_date:as_of
  in
  let r2 =
    analyze ~config:cfg ~ticker:"AAPL" ~bars ~benchmark_bars:bench
      ~prior_stage:None ~as_of_date:as_of
  in
  assert_that r1.stage.stage (equal_to (r2.stage.stage : stage));
  assert_that r1.breakout_price (equal_to (r2.breakout_price : float option))

(* ------------------------------------------------------------------ *)
(* Empty bars edge case                                                 *)
(* ------------------------------------------------------------------ *)

let test_insufficient_bars_graceful _ =
  let bars = List.init 5 ~f:(fun _ -> 50.0) |> weekly_bars in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  (* Should not raise — Stage1 with zero ma_value *)
  match result.stage.stage with
  | Stage1 _ -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Stage1 for insufficient data, got %s"
           (show_stage other))

let suite =
  "stock_analysis_tests"
  >::: [
         "test_analyze_returns_ticker" >:: test_analyze_returns_ticker;
         "test_analyze_sets_as_of_date" >:: test_analyze_sets_as_of_date;
         "test_analyze_preserves_prior_stage"
         >:: test_analyze_preserves_prior_stage;
         "test_stage2_stock_classified_correctly"
         >:: test_stage2_stock_classified_correctly;
         "test_breakout_candidate_stage2_transition"
         >:: test_breakout_candidate_stage2_transition;
         "test_breakdown_candidate_stage4_transition"
         >:: test_breakdown_candidate_stage4_transition;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
         "test_insufficient_bars_graceful" >:: test_insufficient_bars_graceful;
       ]

let () = run_test_tt_main suite
