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
       ]

let () = run_test_tt_main suite
