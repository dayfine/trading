open OUnit2
open Core
open Matchers
open Macro
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

let make_bar date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.01;
    low_price = adjusted_close *. 0.99;
    close_price = adjusted_close;
    adjusted_close;
    volume = 100_000;
  }

let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * 7))) p)

let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> weekly_bars

let flat_bars ~n price = List.init n ~f:(fun _ -> price) |> weekly_bars

(** Build [n] weekly A-D bars with [advancing] and [declining] counts per week.
    Matches the weekly-cadence contract of {!Macro.analyze} — each bar is dated
    7 days apart so they land in distinct ISO weeks. *)
let ad_bars ~n ~advancing ~declining =
  (* 2020-01-06 is a Monday. [i * 7] advances the anchor date by [i] whole
     weeks (7 calendar days per step): every bar lands on a Monday, weekends
     are crossed but no bar is placed on them — one emission per iteration,
     not seven. *)
  let base = Date.of_string "2020-01-06" in
  List.init n ~f:(fun i ->
      { date = Date.add_days base (i * 7); advancing; declining })

(* ------------------------------------------------------------------ *)
(* Bullish regime: strong rising index                                  *)
(* ------------------------------------------------------------------ *)

let test_bullish_regime_rising_index _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.trend (equal_to Bullish)

let test_confidence_between_0_and_1 _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.confidence (ge (module Float_ord) 0.0);
  assert_that result.confidence (le (module Float_ord) 1.0)

(* ------------------------------------------------------------------ *)
(* Bearish regime: declining index                                      *)
(* ------------------------------------------------------------------ *)

let test_bearish_regime_declining_index _ =
  let declining =
    List.init 40 ~f:(fun i -> 200.0 -. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let result =
    analyze ~config:cfg ~index_bars:declining ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.trend (equal_to Bearish)

(* ------------------------------------------------------------------ *)
(* Neutral: flat index                                                  *)
(* ------------------------------------------------------------------ *)

let test_neutral_flat_index _ =
  (* A flat index with no A-D or global data produces all-Neutral indicators.
     _compute_confidence returns 0.5 (fallback when all indicators are Neutral).
     0.5 is between bearish_threshold=0.35 and bullish_threshold=0.65 → Neutral. *)
  let index = flat_bars ~n:40 100.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.trend (equal_to Neutral);
  assert_that result.confidence (float_equal 0.5)

(* ------------------------------------------------------------------ *)
(* A-D line influence                                                   *)
(* ------------------------------------------------------------------ *)

let test_bullish_ad_line_boosts_confidence _ =
  let index = rising_bars ~n:40 100.0 150.0 in
  (* Advancing > declining → cumulative A-D rising → confirms index advance → Bullish *)
  let ad = ad_bars ~n:200 ~advancing:2000 ~declining:1000 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let ad_indicator =
    List.find_exn result.indicators ~f:(fun r -> String.(r.name = "A-D Line"))
  in
  assert_that ad_indicator.signal
    (equal_to (`Bullish : [ `Bullish | `Bearish | `Neutral ]))

(* ------------------------------------------------------------------ *)
(* A-D bearish divergence: index up, A-D down                          *)
(* ------------------------------------------------------------------ *)

let test_ad_bearish_divergence _ =
  (* Index rising but A-D cumulative declining → bearish divergence *)
  let index = rising_bars ~n:40 100.0 150.0 in
  let ad = ad_bars ~n:40 ~advancing:800 ~declining:1200 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let ad_indicator =
    List.find_exn result.indicators ~f:(fun r -> String.(r.name = "A-D Line"))
  in
  assert_that ad_indicator.signal
    (equal_to (`Bearish : [ `Bullish | `Bearish | `Neutral ]))

(* ------------------------------------------------------------------ *)
(* Momentum index signal                                               *)
(* ------------------------------------------------------------------ *)

let test_momentum_index_bullish _ =
  (* Advancing > declining → net positive → MA > 0 → Bullish *)
  let index = rising_bars ~n:40 100.0 150.0 in
  let ad = ad_bars ~n:40 ~advancing:1500 ~declining:1000 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let mom =
    List.find_exn result.indicators ~f:(fun r ->
        String.(r.name = "Momentum Index"))
  in
  assert_that mom.signal
    (equal_to (`Bullish : [ `Bullish | `Bearish | `Neutral ]))

let test_momentum_index_bearish _ =
  (* Declining > advancing → net negative → MA < 0 → Bearish *)
  let index = rising_bars ~n:40 100.0 150.0 in
  let ad = ad_bars ~n:40 ~advancing:500 ~declining:1500 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let mom =
    List.find_exn result.indicators ~f:(fun r ->
        String.(r.name = "Momentum Index"))
  in
  assert_that mom.signal
    (equal_to (`Bearish : [ `Bullish | `Bearish | `Neutral ]))

(* ------------------------------------------------------------------ *)
(* NH-NL proxy boundaries                                              *)
(* ------------------------------------------------------------------ *)

let test_nh_nl_bullish _ =
  (* Index gains > 2% over lookback window (13 bars) → NH-NL proxy bullish.
     20 bars: recent = bars[19], prior = bars[19-13] = bars[6].
     Prices rise 100 → 150, so bars[6]=~130, bars[19]=150 → ratio ~1.15 > 1.02. *)
  let index = rising_bars ~n:20 100.0 150.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let nh_nl =
    List.find_exn result.indicators ~f:(fun r -> String.(r.name = "NH-NL"))
  in
  assert_that nh_nl.signal
    (equal_to (`Bullish : [ `Bullish | `Bearish | `Neutral ]))

let test_nh_nl_bearish _ =
  (* Index drops > 2% over lookback → NH-NL proxy bearish. *)
  let index =
    List.init 20 ~f:(fun i -> 150.0 -. (Float.of_int i *. 2.5)) |> weekly_bars
  in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let nh_nl =
    List.find_exn result.indicators ~f:(fun r -> String.(r.name = "NH-NL"))
  in
  assert_that nh_nl.signal
    (equal_to (`Bearish : [ `Bullish | `Bearish | `Neutral ]))

(* ------------------------------------------------------------------ *)
(* Global market consensus                                             *)
(* ------------------------------------------------------------------ *)

let test_global_consensus_bullish _ =
  (* 3 global indices all in Stage2 (rising) → bullish_frac = 1.0 > 0.6 *)
  let rising = rising_bars ~n:40 100.0 200.0 in
  let global = [ ("DAX", rising); ("FTSE", rising); ("Nikkei", rising) ] in
  let result =
    analyze ~config:cfg ~index_bars:rising ~ad_bars:[] ~global_index_bars:global
      ~prior_stage:None ~prior:None
  in
  let global_ind =
    List.find_exn result.indicators ~f:(fun r ->
        String.(r.name = "Global Markets"))
  in
  assert_that global_ind.signal
    (equal_to (`Bullish : [ `Bullish | `Bearish | `Neutral ]))

let test_global_consensus_bearish _ =
  (* 3 global indices all declining (Stage4) → bearish_frac = 1.0 > 0.6 *)
  let declining =
    List.init 60 ~f:(fun i -> 200.0 -. Float.of_int i) |> weekly_bars
  in
  let global =
    [ ("DAX", declining); ("FTSE", declining); ("Nikkei", declining) ]
  in
  let result =
    analyze ~config:cfg ~index_bars:declining ~ad_bars:[]
      ~global_index_bars:global ~prior_stage:None ~prior:None
  in
  let global_ind =
    List.find_exn result.indicators ~f:(fun r ->
        String.(r.name = "Global Markets"))
  in
  assert_that global_ind.signal
    (equal_to (`Bearish : [ `Bullish | `Bearish | `Neutral ]))

(* ------------------------------------------------------------------ *)
(* Regime change detection                                              *)
(* ------------------------------------------------------------------ *)

let test_regime_changed_when_trend_flips _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let prior_bearish =
    analyze ~config:cfg ~index_bars:(flat_bars ~n:40 100.0) ~ad_bars:[]
      ~global_index_bars:[] ~prior_stage:None ~prior:None
  in
  (* Now analyze with rising index using prior bearish result *)
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:(Some prior_bearish)
  in
  (* If prior was Neutral/Bearish and current is Bullish, regime_changed=true *)
  if not (equal_market_trend result.trend prior_bearish.trend) then
    assert_bool "regime_changed should be true" result.regime_changed
  else
    assert_bool "regime_changed should be false (no change)"
      (not result.regime_changed)

let test_no_regime_change_same_trend _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let prior =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  (* Analyze again with same bars — should not change regime *)
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:(Some prior)
  in
  assert_bool "no regime change on same data" (not result.regime_changed)

(* ------------------------------------------------------------------ *)
(* Indicators structure                                                 *)
(* ------------------------------------------------------------------ *)

let test_indicators_list_not_empty _ =
  let index = rising_bars ~n:40 100.0 150.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_bool "should have indicators" (not (List.is_empty result.indicators))

let test_index_stage_indicator_present _ =
  let index = rising_bars ~n:40 100.0 150.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let has_index_stage =
    List.exists result.indicators ~f:(fun r -> String.(r.name = "Index Stage"))
  in
  assert_bool "Index Stage indicator present" has_index_stage

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let ad = ad_bars ~n:100 ~advancing:1500 ~declining:1000 in
  let r1 =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let r2 =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that r1.trend (equal_to (r2.trend : market_trend));
  assert_that r1.confidence (float_equal r2.confidence)

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                      *)
(* Builds the {!callbacks} record externally over the same bars the   *)
(* wrapper would compute internally, then asserts that the two entry   *)
(* points produce bit-identical [result] records. Each scenario hits   *)
(* a different regime: bullish (Stage2 + positive A-D divergence),     *)
(* bearish (Stage4 + negative A-D divergence), neutral (flat),         *)
(* insufficient bars, and partial global-index data.                   *)
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

(** Bit-identity matcher for one {!Macro.indicator_reading}. The closed-set
    [signal] variant, [name], [weight], and [detail] string are all checked. Any
    drift in float arithmetic that flips a signal or changes a printed detail
    (e.g. [Printf.sprintf "%.1f"] of the momentum MA) will surface here. *)
let indicator_reading_is_bit_identical (expected : indicator_reading) :
    indicator_reading matcher =
  all_of
    [
      field (fun (r : indicator_reading) -> r.name) (equal_to expected.name);
      field (fun (r : indicator_reading) -> r.signal) (equal_to expected.signal);
      field
        (fun (r : indicator_reading) -> r.weight)
        (equal_to (expected.weight : float));
      field (fun (r : indicator_reading) -> r.detail) (equal_to expected.detail);
    ]

(** Bit-identity matcher for {!Macro.result}. The composite trend / confidence /
    regime_changed / rationale plus the nested Stage result and
    indicator-by-indicator readings are all checked. *)
let result_is_bit_identical (expected : Macro.result) : Macro.result matcher =
  all_of
    [
      field
        (fun (r : Macro.result) -> r.index_stage)
        (stage_result_is_bit_identical expected.index_stage);
      field
        (fun (r : Macro.result) -> r.indicators)
        (elements_are
           (List.map expected.indicators ~f:indicator_reading_is_bit_identical));
      field
        (fun (r : Macro.result) -> r.trend)
        (equal_to (expected.trend : market_trend));
      field
        (fun (r : Macro.result) -> r.confidence)
        (equal_to (expected.confidence : float));
      field
        (fun (r : Macro.result) -> r.regime_changed)
        (equal_to expected.regime_changed);
      field
        (fun (r : Macro.result) -> r.rationale)
        (equal_to expected.rationale);
    ]

(** Run both [analyze] and [analyze_with_callbacks] over the same input and
    assert their results are bit-equal. The callback bundle is built externally
    via {!Macro.callbacks_from_bars} (the same constructor the wrapper uses
    internally, but we exercise it through the public API). *)
let assert_parity ~index_bars ?(ad_bars = []) ?(global_index_bars = [])
    ?(prior_stage = None) ?(prior = None) () =
  let callbacks =
    Macro.callbacks_from_bars ~config:cfg ~index_bars ~ad_bars
      ~global_index_bars
  in
  let from_bars =
    analyze ~config:cfg ~index_bars ~ad_bars ~global_index_bars ~prior_stage
      ~prior
  in
  let from_callbacks =
    analyze_with_callbacks ~config:cfg ~callbacks ~prior_stage ~prior
  in
  assert_that from_callbacks (result_is_bit_identical from_bars)

(** Bullish macro: rising primary index + positive A-D divergence (advancing >
    declining). Exercises the [Bullish] composite trend through the callback
    path. *)
let test_parity_bullish_stage2_positive_ad _ =
  let index = rising_bars ~n:60 100.0 200.0 in
  let ad = ad_bars ~n:200 ~advancing:2000 ~declining:1000 in
  assert_parity ~index_bars:index ~ad_bars:ad ()

(** Bearish macro: declining primary index + negative A-D divergence. Hits the
    [Bearish] composite trend. *)
let test_parity_bearish_stage4_negative_ad _ =
  let index =
    List.init 60 ~f:(fun i -> 200.0 -. (Float.of_int i *. 1.5)) |> weekly_bars
  in
  let ad = ad_bars ~n:60 ~advancing:800 ~declining:1500 in
  assert_parity ~index_bars:index ~ad_bars:ad ()

(** Neutral macro: flat index, no A-D, no global. The all-Neutral indicators
    branch yields confidence = 0.5 → Neutral trend. *)
let test_parity_neutral_flat_no_ad _ =
  let index = flat_bars ~n:40 100.0 in
  assert_parity ~index_bars:index ()

(** Insufficient bars: too-short index list (fewer than [stage_config.ma_period]
    bars and fewer than [nh_nl_min_bars]). Exercises the early-return /
    "Insufficient data" branches in the NH-NL signal and the Stage1 default. *)
let test_parity_insufficient_bars _ =
  let index = List.init 5 ~f:(Fn.const 100.0) |> weekly_bars in
  assert_parity ~index_bars:index ()

(** Partial global-index data: 3 global indices with mixed regimes (one rising,
    one declining, one flat). Exercises the per-index [Stage.classify] loop and
    the consensus aggregation through the callback path. *)
let test_parity_partial_global_indices _ =
  let index = rising_bars ~n:60 100.0 150.0 in
  let ad = ad_bars ~n:60 ~advancing:1500 ~declining:1000 in
  let rising = rising_bars ~n:60 100.0 180.0 in
  let declining =
    List.init 60 ~f:(fun i -> 200.0 -. Float.of_int i) |> weekly_bars
  in
  let flat = flat_bars ~n:60 100.0 in
  let global = [ ("DAX", rising); ("FTSE", declining); ("Nikkei", flat) ] in
  assert_parity ~index_bars:index ~ad_bars:ad ~global_index_bars:global ()

let suite =
  "macro_tests"
  >::: [
         "test_bullish_regime_rising_index" >:: test_bullish_regime_rising_index;
         "test_confidence_between_0_and_1" >:: test_confidence_between_0_and_1;
         "test_bearish_regime_declining_index"
         >:: test_bearish_regime_declining_index;
         "test_neutral_flat_index" >:: test_neutral_flat_index;
         "test_bullish_ad_line_boosts_confidence"
         >:: test_bullish_ad_line_boosts_confidence;
         "test_ad_bearish_divergence" >:: test_ad_bearish_divergence;
         "test_momentum_index_bullish" >:: test_momentum_index_bullish;
         "test_momentum_index_bearish" >:: test_momentum_index_bearish;
         "test_nh_nl_bullish" >:: test_nh_nl_bullish;
         "test_nh_nl_bearish" >:: test_nh_nl_bearish;
         "test_global_consensus_bullish" >:: test_global_consensus_bullish;
         "test_global_consensus_bearish" >:: test_global_consensus_bearish;
         "test_regime_changed_when_trend_flips"
         >:: test_regime_changed_when_trend_flips;
         "test_no_regime_change_same_trend" >:: test_no_regime_change_same_trend;
         "test_indicators_list_not_empty" >:: test_indicators_list_not_empty;
         "test_index_stage_indicator_present"
         >:: test_index_stage_indicator_present;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
         "test_parity_bullish_stage2_positive_ad"
         >:: test_parity_bullish_stage2_positive_ad;
         "test_parity_bearish_stage4_negative_ad"
         >:: test_parity_bearish_stage4_negative_ad;
         "test_parity_neutral_flat_no_ad" >:: test_parity_neutral_flat_no_ad;
         "test_parity_insufficient_bars" >:: test_parity_insufficient_bars;
         "test_parity_partial_global_indices"
         >:: test_parity_partial_global_indices;
       ]

let () = run_test_tt_main suite
