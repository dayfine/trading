open OUnit2
open Core
open Matchers
open Continuation

(* ------------------------------------------------------------------ *)
(* Synthetic-callback builder                                          *)
(*                                                                      *)
(* The detector reads [get_ma], [get_close], [get_high], [get_low] at  *)
(* weekly offsets. Tests build an explicit array per metric so each    *)
(* precondition can be flipped independently. Offset 0 = most recent   *)
(* bar; offsets grow back in time. Missing offsets return [None].      *)
(* ------------------------------------------------------------------ *)

let _make_get arr ~week_offset =
  let n = Array.length arr in
  if week_offset < 0 || week_offset >= n then None else Some arr.(week_offset)

let make_callbacks ~ma ~close ~high ~low : callbacks =
  {
    get_ma = _make_get (Array.of_list ma);
    get_close = _make_get (Array.of_list close);
    get_high = _make_get (Array.of_list high);
    get_low = _make_get (Array.of_list low);
  }

let cfg = default_config

(* ------------------------------------------------------------------ *)
(* Precondition (a): MA slope ≥ ma_slope_min                            *)
(* ------------------------------------------------------------------ *)

(** MA values trace a clearly-rising series: offset 0 = 100.0, offset 4 = 95.0 →
    slope ≈ 5.3%. Default [ma_slope_min] is 1%. Precondition (a) fires. MA stays
    around 95-100 across the relevant window so the pullback-band bar sits at
    offset 5 (close 95 / ma 95 = 1.0) — outside the [consolidation_weeks = 4]
    window (offsets 1..4). *)
let _rising_ma = [ 100.0; 99.0; 98.0; 97.0; 96.0; 95.0; 95.0; 95.0; 95.0; 95.0 ]

(** MA values flat: slope = 0%. Fails precondition (a) regardless of the other
    gates. *)
let _flat_ma =
  [ 100.0; 100.0; 100.0; 100.0; 100.0; 100.0; 100.0; 100.0; 100.0; 100.0 ]

(** Close series: bar 0 = 130 (new breakout above 125 consolidation high); bars
    1-4 inside consolidation [120, 125] (ratio ≈ 1.20+, outside pullback band);
    bar 5 in pullback band (close 95 / ma 95 = 1.0); bars 6-9 earlier. *)
let _close_with_pullback =
  [ 130.0; 124.0; 123.0; 121.0; 120.0; 95.0; 92.0; 89.0; 86.0; 83.0 ]

let _high_with_consolidation =
  [ 131.0; 125.0; 124.0; 122.0; 121.0; 96.0; 93.0; 90.0; 87.0; 84.0 ]

let _low_with_pullback =
  [ 129.0; 121.0; 120.0; 118.0; 117.0; 90.0; 88.0; 85.0; 82.0; 79.0 ]

(** Happy-path cfg: default [consolidation_weeks = 4] (scans offsets 1..4).
    Highs in window: 125, 124, 122, 121 → max = 125. Lows: 121, 120, 118, 117 →
    min = 117. Closes: 124, 123, 121, 120 → sum = 488, avg = 122. Range = (125 -
    117) / 122 ≈ 0.066 < default 10% — consolidation gate OK. Pullback scan
    (offsets 1..8 by default): offset 5 has close 95 / ma 95 = 1.0 ∈
    [0.95, 1.05]. Earlier offsets (1..4) have ratios 1.20+, outside.
    pullback_low = low at offset 5 = 90.0. Breakout check: close[0] = 130 >
    consolidation_high = 125 → passes. *)
let _happy_cfg = cfg

let test_happy_path_all_preconditions_satisfied _ =
  let callbacks =
    make_callbacks ~ma:_rising_ma ~close:_close_with_pullback
      ~high:_high_with_consolidation ~low:_low_with_pullback
  in
  let result = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  assert_that result
    (all_of
       [
         field (fun (r : result) -> r.is_continuation) (equal_to true);
         field
           (fun (r : result) -> r.pullback_low)
           (is_some_and (float_equal 90.0));
         field
           (fun (r : result) -> r.consolidation_high)
           (is_some_and (float_equal 125.0));
       ])

(** MA flat → precondition (a) fails; [is_continuation = false] even though
    (b)-(d) would otherwise fire. *)
let test_flat_ma_blocks_continuation _ =
  let callbacks =
    make_callbacks ~ma:_flat_ma ~close:_close_with_pullback
      ~high:_high_with_consolidation ~low:_low_with_pullback
  in
  let result = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  assert_that result.is_continuation (equal_to false)

(* ------------------------------------------------------------------ *)
(* Precondition (b): pullback to MA inside [pullback_band]              *)
(* ------------------------------------------------------------------ *)

(** Closes that never touch the MA — all far above (ratio > 1.05). No pullback
    bar found. Precondition (b) fails. Closes 130..123 against MA 100..95 →
    ratios 1.30..1.29, all outside [0.95, 1.05]. *)
let test_no_pullback_blocks_continuation _ =
  let close =
    [ 130.0; 125.0; 128.0; 127.0; 126.0; 125.0; 124.0; 123.0; 122.0; 121.0 ]
  in
  let high =
    [ 132.0; 126.0; 129.0; 128.0; 127.0; 126.0; 125.0; 124.0; 123.0; 122.0 ]
  in
  let low =
    [ 128.0; 123.0; 126.0; 125.0; 124.0; 123.0; 122.0; 121.0; 120.0; 119.0 ]
  in
  let callbacks = make_callbacks ~ma:_rising_ma ~close ~high ~low in
  let result = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  assert_that result
    (all_of
       [
         field (fun (r : result) -> r.is_continuation) (equal_to false);
         field (fun (r : result) -> r.pullback_low) is_none;
       ])

(* ------------------------------------------------------------------ *)
(* Precondition (c): consolidation range tight enough                    *)
(* ------------------------------------------------------------------ *)

(** Same setup as the happy path but the consolidation window is wide (range >
    10%). Precondition (c) fails → no consolidation_high. The single spiked high
    (250) at offset 2 blows up the range. *)
let test_wide_consolidation_blocks_continuation _ =
  let high =
    [ 131.0; 125.0; 250.0; 122.0; 121.0; 96.0; 93.0; 90.0; 87.0; 84.0 ]
  in
  let callbacks =
    make_callbacks ~ma:_rising_ma ~close:_close_with_pullback ~high
      ~low:_low_with_pullback
  in
  let result = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  assert_that result
    (all_of
       [
         field (fun (r : result) -> r.is_continuation) (equal_to false);
         field (fun (r : result) -> r.consolidation_high) is_none;
       ])

(* ------------------------------------------------------------------ *)
(* Precondition (d): current close > consolidation_high                  *)
(* ------------------------------------------------------------------ *)

(** Consolidation high is 125 but the current close is only 123 — no new
    breakout. Precondition (d) fails. consolidation_high is still surfaced (the
    consolidation gate fired); only is_continuation is false. *)
let test_no_new_breakout_blocks_continuation _ =
  let close =
    [ 123.0; 124.0; 123.0; 121.0; 120.0; 95.0; 92.0; 89.0; 86.0; 83.0 ]
  in
  let callbacks =
    make_callbacks ~ma:_rising_ma ~close ~high:_high_with_consolidation
      ~low:_low_with_pullback
  in
  let result = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  assert_that result
    (all_of
       [
         field (fun (r : result) -> r.is_continuation) (equal_to false);
         field
           (fun (r : result) -> r.consolidation_high)
           (is_some_and (float_equal 125.0));
       ])

(* ------------------------------------------------------------------ *)
(* Lookback truncation                                                  *)
(* ------------------------------------------------------------------ *)

(** When [pullback_lookback_weeks] is 3, the scan covers offsets 1-3 only. The
    pullback bar at offset 5 (close 95 / ma 95 = 1.0) sits past the window.
    Closes 124, 123, 121 against MA 99, 98, 97 → ratios 1.25+, outside band.
    Precondition (b) fails. *)
let test_pullback_outside_lookback_window _ =
  let tighter_cfg = { _happy_cfg with pullback_lookback_weeks = 3 } in
  let callbacks =
    make_callbacks ~ma:_rising_ma ~close:_close_with_pullback
      ~high:_high_with_consolidation ~low:_low_with_pullback
  in
  let result = analyze_with_callbacks ~config:tighter_cfg ~callbacks in
  assert_that result
    (all_of
       [
         field (fun (r : result) -> r.is_continuation) (equal_to false);
         field (fun (r : result) -> r.pullback_low) is_none;
       ])

(* ------------------------------------------------------------------ *)
(* Empty callback bundle                                                *)
(* ------------------------------------------------------------------ *)

(** Every callback returns [None]. Detector returns [is_continuation = false]
    without crashing. *)
let test_empty_callbacks_no_continuation _ =
  let callbacks = make_callbacks ~ma:[] ~close:[] ~high:[] ~low:[] in
  let result = analyze_with_callbacks ~config:cfg ~callbacks in
  assert_that result
    (all_of
       [
         field (fun (r : result) -> r.is_continuation) (equal_to false);
         field (fun (r : result) -> r.pullback_low) is_none;
         field (fun (r : result) -> r.consolidation_high) is_none;
         field (fun (r : result) -> r.ma_slope_observed) (float_equal 0.0);
       ])

(* ------------------------------------------------------------------ *)
(* Purity                                                              *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let callbacks =
    make_callbacks ~ma:_rising_ma ~close:_close_with_pullback
      ~high:_high_with_consolidation ~low:_low_with_pullback
  in
  let r1 = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  let r2 = analyze_with_callbacks ~config:_happy_cfg ~callbacks in
  assert_that r1.is_continuation (equal_to r2.is_continuation)

let suite =
  "continuation_tests"
  >::: [
         "happy path: all preconditions satisfied"
         >:: test_happy_path_all_preconditions_satisfied;
         "flat MA blocks continuation" >:: test_flat_ma_blocks_continuation;
         "no pullback to MA blocks continuation"
         >:: test_no_pullback_blocks_continuation;
         "wide consolidation blocks continuation"
         >:: test_wide_consolidation_blocks_continuation;
         "no new breakout above consolidation blocks continuation"
         >:: test_no_new_breakout_blocks_continuation;
         "pullback outside lookback window"
         >:: test_pullback_outside_lookback_window;
         "empty callbacks no continuation"
         >:: test_empty_callbacks_no_continuation;
         "pure: same inputs produce same result" >:: test_pure_same_inputs;
       ]

let () = run_test_tt_main suite
