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
let base_date = Date.of_string "2020-01-06"

let make_bar i price volume =
  {
    Daily_price.date =
      Date.of_string (Date.to_string (Date.add_days base_date (i * 7)));
    open_price = price;
    high_price = price *. 1.02;
    low_price = price *. 0.98;
    close_price = price;
    adjusted_close = price;
    volume;
  }

(** Rising bars from [start] to [stop_], all at uniform volume 1000. *)
let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> make_bar i (start +. (Float.of_int i *. step)) 1000)

(** Rising bars with a volume spike at [spike_idx] (3000 vs 1000 elsewhere).
    With default [breakout_event_lookback=8] and [volume.lookback_bars=4],
    placing spike_idx at n-4 puts the spike inside the search window with 4
    baseline bars before it → ratio = 3.0 → Strong confirmation. *)
let rising_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start +. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      make_bar i p v)

(** Declining bars from [start] to [stop_]. *)
let declining_bars ~n start stop_ =
  let step = (start -. stop_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> make_bar i (start -. (Float.of_int i *. step)) 1000)

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

let test_insufficient_bars_yields_stage1 _ =
  let bars = List.init 5 ~f:(fun i -> make_bar i 50.0 1000) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  match result.stage.stage with
  | Stage1 _ -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Stage1 for insufficient data, got %s"
           (show_stage other))

(* ------------------------------------------------------------------ *)
(* Breakout candidate                                                   *)
(* ------------------------------------------------------------------ *)

let test_breakout_candidate_true_with_stage1_prior_and_strong_volume _ =
  (* spike_idx = n-4 = 31: inside 8-bar lookback, 4 baseline bars before it *)
  let bars = rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  assert_that (is_breakout_candidate result) (equal_to true)

let test_breakout_candidate_false_when_stage4 _ =
  (* A declining stock (Stage 4) is never a breakout candidate regardless of
     volume or RS. *)
  let bars = declining_bars ~n:60 100.0 30.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that (is_breakout_candidate result) (equal_to false)

let test_breakout_candidate_false_when_no_volume_confirmation _ =
  (* Uniform volume → ratio = 1.0 → Weak → not a candidate *)
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:bench
      ~prior_stage:prior ~as_of_date:as_of
  in
  assert_that (is_breakout_candidate result) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Breakdown candidate                                                  *)
(* ------------------------------------------------------------------ *)

let test_breakdown_candidate_true_with_stage3_prior _ =
  let bars = declining_bars ~n:60 100.0 30.0 in
  let prior = Some (Stage3 { weeks_topping = 8 }) in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:prior
      ~as_of_date:as_of
  in
  assert_that (is_breakdown_candidate result) (equal_to true)

let test_breakdown_candidate_false_for_stage2 _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that (is_breakdown_candidate result) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let bars = rising_bars ~n:35 50.0 100.0 in
  let bench = rising_bars ~n:35 80.0 110.0 in
  let run () =
    analyze ~config:cfg ~ticker:"AAPL" ~bars ~benchmark_bars:bench
      ~prior_stage:None ~as_of_date:as_of
  in
  let r1 = run () and r2 = run () in
  assert_that r1.stage.stage (equal_to (r2.stage.stage : stage));
  assert_that r1.breakout_price (equal_to (r2.breakout_price : float option));
  assert_that
    (Option.map r1.volume ~f:(fun v -> v.volume_ratio))
    (equal_to
       (Option.map r2.volume ~f:(fun v -> v.volume_ratio) : float option))

let suite =
  "stock_analysis_tests"
  >::: [
         "test_stage2_stock_classified_correctly"
         >:: test_stage2_stock_classified_correctly;
         "test_insufficient_bars_yields_stage1"
         >:: test_insufficient_bars_yields_stage1;
         "test_breakout_candidate_true_with_stage1_prior_and_strong_volume"
         >:: test_breakout_candidate_true_with_stage1_prior_and_strong_volume;
         "test_breakout_candidate_false_when_stage4"
         >:: test_breakout_candidate_false_when_stage4;
         "test_breakout_candidate_false_when_no_volume_confirmation"
         >:: test_breakout_candidate_false_when_no_volume_confirmation;
         "test_breakdown_candidate_true_with_stage3_prior"
         >:: test_breakdown_candidate_true_with_stage3_prior;
         "test_breakdown_candidate_false_for_stage2"
         >:: test_breakdown_candidate_false_for_stage2;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
       ]

let () = run_test_tt_main suite
