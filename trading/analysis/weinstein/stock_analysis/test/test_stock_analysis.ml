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

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                      *)
(* Builds the {!callbacks} record externally over the same arrays the  *)
(* wrapper would compute internally, then asserts that the two entry   *)
(* points produce bit-identical [t] records. Each scenario hits a      *)
(* different regime: pre-breakout, confirmed breakout (high vs low     *)
(* volume), Stage1/2/3/4 input, insufficient bars.                     *)
(* ------------------------------------------------------------------ *)

(** Bit-identity matcher for {!Stage.result}. Float fields use [equal_to]
    (Poly.equal — structural equality) so any drift fails. *)
let stage_result_is_bit_identical (expected : Stage.result) :
    Stage.result matcher =
  all_of
    [
      field (fun (r : Stage.result) -> r.stage) (equal_to expected.stage);
      field
        (fun (r : Stage.result) -> r.ma_value)
        (equal_to (expected.ma_value : float));
      field
        (fun (r : Stage.result) -> r.ma_direction)
        (equal_to expected.ma_direction);
      field
        (fun (r : Stage.result) -> r.ma_slope_pct)
        (equal_to (expected.ma_slope_pct : float));
      field
        (fun (r : Stage.result) -> r.transition)
        (equal_to expected.transition);
      field
        (fun (r : Stage.result) -> r.above_ma_count)
        (equal_to expected.above_ma_count);
    ]

(** Bit-identity matcher for {!Volume.result}. *)
let volume_result_is_bit_identical (expected : Volume.result) :
    Volume.result matcher =
  all_of
    [
      field
        (fun (r : Volume.result) -> r.confirmation)
        (equal_to expected.confirmation);
      field
        (fun (r : Volume.result) -> r.event_volume)
        (equal_to (expected.event_volume : int));
      field
        (fun (r : Volume.result) -> r.avg_volume)
        (equal_to (expected.avg_volume : float));
      field
        (fun (r : Volume.result) -> r.volume_ratio)
        (equal_to (expected.volume_ratio : float));
    ]

(** Bit-identity matcher for {!Stock_analysis.t}. The Resistance result is
    compared structurally (via [Poly.equal]) since the [resistance_zone] list
    has no derived equality but its float and int fields support polymorphic
    equality. Same for the {!Rs.result} record. *)
let result_is_bit_identical (expected : Stock_analysis.t) :
    Stock_analysis.t matcher =
  all_of
    [
      field (fun (r : Stock_analysis.t) -> r.ticker) (equal_to expected.ticker);
      field
        (fun (r : Stock_analysis.t) -> r.stage)
        (stage_result_is_bit_identical expected.stage);
      field
        (fun (r : Stock_analysis.t) -> r.rs)
        (equal_to (expected.rs : Rs.result option));
      field
        (fun (r : Stock_analysis.t) -> r.volume)
        (match expected.volume with
        | None -> is_none
        | Some v -> is_some_and (volume_result_is_bit_identical v));
      field
        (fun (r : Stock_analysis.t) -> r.resistance)
        (equal_to (expected.resistance : Resistance.result option));
      field
        (fun (r : Stock_analysis.t) -> r.breakout_price)
        (equal_to (expected.breakout_price : float option));
      field
        (fun (r : Stock_analysis.t) -> r.prior_stage)
        (equal_to expected.prior_stage);
      field
        (fun (r : Stock_analysis.t) -> r.as_of_date)
        (equal_to expected.as_of_date);
    ]

(** Run both [analyze] and [analyze_with_callbacks] over the same input and
    assert their results are bit-equal. The callback bundle is built externally
    via {!Stock_analysis.callbacks_from_bars} (the same constructor the wrapper
    uses internally, but we exercise it through the public API). *)
let assert_parity ~bars ~benchmark_bars ?(prior_stage = None) () =
  let callbacks =
    Stock_analysis.callbacks_from_bars ~config:cfg ~bars ~benchmark_bars
  in
  let from_bars =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars ~prior_stage
      ~as_of_date:as_of
  in
  let from_callbacks =
    analyze_with_callbacks ~config:cfg ~ticker:"X" ~callbacks ~prior_stage
      ~as_of_date:as_of
  in
  assert_that from_callbacks (result_is_bit_identical from_bars)

(** Pre-breakout: declining stock, no signals fire. Hits Stage4 input. *)
let test_parity_pre_breakout_stage4 _ =
  let bars = declining_bars ~n:80 100.0 50.0 in
  let bench = rising_bars ~n:80 80.0 110.0 in
  assert_parity ~bars ~benchmark_bars:bench ()

(** Confirmed breakout with high volume: Stage1 prior + spike. Hits the
    Strong-volume branch. *)
let test_parity_confirmed_breakout_high_volume _ =
  let bars = rising_bars_with_spike ~n:60 50.0 150.0 ~spike_idx:56 in
  let bench = rising_bars ~n:60 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Confirmed breakout but low volume: uniform volume produces ratio=1.0 → Weak.
    Hits the breakout-no-confirmation branch. *)
let test_parity_confirmed_breakout_low_volume _ =
  let bars = rising_bars ~n:60 50.0 150.0 in
  let bench = rising_bars ~n:60 80.0 110.0 in
  let prior = Some (Stage1 { weeks_in_base = 12 }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Stage2 input regime: pure rising series, no prior. *)
let test_parity_stage2_rising _ =
  let bars = rising_bars ~n:80 50.0 200.0 in
  let bench = rising_bars ~n:80 80.0 110.0 in
  assert_parity ~bars ~benchmark_bars:bench ()

(** Stage3 input regime: rising then flat with prior Stage2. *)
let test_parity_stage3_flat_after_advance _ =
  let rising = List.init 30 ~f:(fun i -> 50.0 +. (Float.of_int i *. 2.0)) in
  let flat = List.init 70 ~f:(fun _ -> 110.0) in
  let bars = List.mapi (rising @ flat) ~f:(fun i p -> make_bar i p 1000) in
  let bench = rising_bars ~n:100 80.0 110.0 in
  let prior = Some (Stage2 { weeks_advancing = 10; late = false }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Stage1 input regime: declining then flat with prior Stage4. *)
let test_parity_stage1_flat_after_decline _ =
  let declining = List.init 30 ~f:(fun i -> 200.0 -. (Float.of_int i *. 2.0)) in
  let flat = List.init 70 ~f:(fun _ -> 140.0) in
  let bars = List.mapi (declining @ flat) ~f:(fun i p -> make_bar i p 1000) in
  let bench = rising_bars ~n:100 80.0 110.0 in
  let prior = Some (Stage4 { weeks_declining = 10 }) in
  assert_parity ~bars ~benchmark_bars:bench ~prior_stage:prior ()

(** Insufficient bars: too few for Stage / RS / breakout-price scan. *)
let test_parity_insufficient_bars _ =
  let bars = List.init 5 ~f:(fun i -> make_bar i 50.0 1000) in
  assert_parity ~bars ~benchmark_bars:[] ()

(** Edge of the breakout-price scan: bars exactly equal to base_lookback +
    base_end_offset. The wrapper's scan covers indices [n - base_lookback] to
    [n - base_end_offset] (exclusive). *)
let test_parity_exact_base_window _ =
  (* default_config: base_lookback=52, base_end_offset=8 → need ≥ 8 bars, and
     a base window with at least one bar requires n > 8. n = 60 puts
     base_start = 8, base_end = 52, scanning 44 bars. *)
  let bars = rising_bars ~n:60 50.0 150.0 in
  let bench = rising_bars ~n:60 80.0 110.0 in
  assert_parity ~bars ~benchmark_bars:bench ()

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
         "test_parity_pre_breakout_stage4" >:: test_parity_pre_breakout_stage4;
         "test_parity_confirmed_breakout_high_volume"
         >:: test_parity_confirmed_breakout_high_volume;
         "test_parity_confirmed_breakout_low_volume"
         >:: test_parity_confirmed_breakout_low_volume;
         "test_parity_stage2_rising" >:: test_parity_stage2_rising;
         "test_parity_stage3_flat_after_advance"
         >:: test_parity_stage3_flat_after_advance;
         "test_parity_stage1_flat_after_decline"
         >:: test_parity_stage1_flat_after_decline;
         "test_parity_insufficient_bars" >:: test_parity_insufficient_bars;
         "test_parity_exact_base_window" >:: test_parity_exact_base_window;
       ]

let () = run_test_tt_main suite
