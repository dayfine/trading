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

(* ------------------------------------------------------------------ *)
(* G14 split-boundary truncation                                        *)
(*                                                                      *)
(* The breakout-price / breakdown-price scans must stop at the most     *)
(* recent split between consecutive bars in the prior-base window —     *)
(* otherwise pre-split raw highs (in a different price space) leak into *)
(* post-split breakout levels. See [_scan_max_high_callback] in         *)
(* [stock_analysis.ml] and [dev/notes/g14-deep-dive-2026-05-01.md].     *)
(* ------------------------------------------------------------------ *)

(** Build a synthetic series of [n_total] bars where the first [n_pre] bars sit
    in pre-split raw price space (high=[pre_high], close=[pre_close],
    adjusted_close=[pre_adj]) and the remaining bars sit in post-split raw price
    space (high=[post_high], close=[post_close], adjusted_close=[post_adj]). The
    split is between bar [n_pre - 1] and bar [n_pre]: factor jumps from
    [pre_adj /. pre_close] to [post_adj /. post_close] across that boundary.

    Uses weekly cadence (date stride 7) so the bars look like weekly buckets to
    [Stock_analysis.analyze]. *)
let _split_synth ~n_total ~n_pre ~pre_high ~pre_close ~pre_adj ~post_high
    ~post_close ~post_adj : Daily_price.t list =
  List.init n_total ~f:(fun i ->
      let high, close, adj =
        if i < n_pre then (pre_high, pre_close, pre_adj)
        else (post_high, post_close, post_adj)
      in
      {
        Daily_price.date = Date.add_days base_date (i * 7);
        open_price = close;
        high_price = high;
        low_price = close *. 0.99;
        close_price = close;
        adjusted_close = adj;
        volume = 1000;
      })

(** With a 4:1 split between weeks 15 and 16 (pre: factor 0.25, post: factor
    1.0), the prior-base scan must stop at the split boundary — pre-split raw
    highs ($200) leaking into the breakout level would be in a different price
    space than the current post-split fill ($50). The truncated max falls within
    the post-split bars only (a small range around $52). *)
let test_breakout_truncates_at_split_boundary _ =
  (* n_pre = 16, n_total = 30. With base_end_offset = 8 the scan walks
     offsets [8, 52) → bars [21..0]; the split lives between bars 15 and 16
     (= offsets 13 and 14 from the newest-at-29). The truncation guard fires
     at offset 14, so the scan covers bars [16..21] only (post-split). *)
  let bars =
    _split_synth ~n_total:30 ~n_pre:16 ~pre_high:200.0 ~pre_close:400.0
      ~pre_adj:100.0 ~post_high:50.0 ~post_close:48.0 ~post_adj:48.0
  in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  (* breakout_price comes from the post-split window only — never the
     pre-split $200. Pin a tight upper bound to catch any leakage. *)
  assert_that result.breakout_price (is_some_and (lt (module Float_ord) 100.0))

(** Mirror of the breakout truncation: when post-split lows ($48) and pre- split
    lows ($396) live in different price spaces, [_scan_min_low_callback] must
    truncate at the split boundary so the breakdown level reflects the current
    price space. The pre-split low at $396 is artificially high (it sits in the
    pre-split raw space), so without truncation it would not affect the min —
    but the symmetric test validates the truncation guard fires on the short
    side too. We verify breakdown_price is below 100 (in the post-split price
    space). *)
let test_breakdown_truncates_at_split_boundary _ =
  let bars =
    _split_synth ~n_total:30 ~n_pre:16 ~pre_high:200.0 ~pre_close:400.0
      ~pre_adj:100.0 ~post_high:50.0 ~post_close:48.0 ~post_adj:48.0
  in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  assert_that result.breakdown_price (is_some_and (lt (module Float_ord) 100.0))

(** Sanity: when there is no split (every bar's adjusted_close = close_price),
    the truncation guard never fires and the scan covers the full prior-base
    window. The classic rising_bars fixture exercises this. *)
let test_no_split_no_truncation _ =
  let bars = rising_bars ~n:60 50.0 150.0 in
  let result =
    analyze ~config:cfg ~ticker:"X" ~bars ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:as_of
  in
  (* base window covers bars [8, 52) → indices [60-52..60-8) = [8..52) of the
     rising series. Highs in this slice peak near the most-recent bar in the
     window (~$133) — well above the all-bars min of ~$50. Pin the lower
     bound to confirm truncation didn't fire spuriously. *)
  assert_that result.breakout_price (is_some_and (gt (module Float_ord) 100.0))

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
         "G14: breakout truncates at split boundary"
         >:: test_breakout_truncates_at_split_boundary;
         "G14: breakdown truncates at split boundary"
         >:: test_breakdown_truncates_at_split_boundary;
         "G14: no split, no truncation" >:: test_no_split_no_truncation;
       ]

let () = run_test_tt_main suite
