open OUnit2
open Core
open Matchers
open Volume
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

let make_bar ?(price = 100.0) volume =
  {
    Daily_price.date = Date.of_string "2024-01-01";
    open_price = price;
    high_price = price;
    low_price = price;
    close_price = price;
    adjusted_close = price;
    volume;
    active_through = None;
  }

(** [n] baseline bars followed by one event bar. *)
let build_bars ~baseline_vol ~n ~event_vol =
  List.init n ~f:(fun _ -> make_bar baseline_vol) @ [ make_bar event_vol ]

(* ------------------------------------------------------------------ *)
(* analyze_breakout — confirmation classes                             *)
(* ------------------------------------------------------------------ *)

let test_strong_breakout _ =
  (* Baseline 1000/bar × 4; event = 2500 → ratio 2.5 → Strong *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and (fun r ->
         assert_that r.confirmation
           (equal_to (Strong 2.5 : volume_confirmation));
         assert_that r.event_volume (equal_to 2500);
         assert_that r.avg_volume (float_equal 1000.0)))

let test_adequate_breakout _ =
  (* event = 1700 → ratio 1.7, between adequate (1.5) and strong (2.0) *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1700 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and
       (field
          (fun r -> r.confirmation)
          (matching
             (function Adequate _ -> Some () | _ -> None)
             (equal_to ()))))

let test_weak_breakout _ =
  (* event = 1100 → ratio 1.1, below adequate threshold (1.5) *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1100 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and
       (field
          (fun r -> r.confirmation)
          (matching (function Weak _ -> Some () | _ -> None) (equal_to ()))))

(* ------------------------------------------------------------------ *)
(* analyze_breakout — boundary and edge cases                          *)
(* ------------------------------------------------------------------ *)

let test_exactly_2x_is_strong _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2000 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and (fun r ->
         assert_that r.confirmation
           (equal_to (Strong 2.0 : volume_confirmation))))

let test_insufficient_prior_bars_returns_none _ =
  (* Only 2 prior bars when lookback_bars=4 → None *)
  let bars = build_bars ~baseline_vol:1000 ~n:2 ~event_vol:3000 in
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:2) is_none

let test_out_of_range_event_idx _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:(-1)) is_none;
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:99) is_none

(* ------------------------------------------------------------------ *)
(* is_pullback_confirmed                                               *)
(* ------------------------------------------------------------------ *)

let test_pullback_confirmed_low_volume _ =
  (* Breakout 2000, pullback 400 → ratio 0.2 ≤ 0.25 → confirmed *)
  assert_bool "pullback confirmed"
    (is_pullback_confirmed ~config:cfg ~breakout_volume:2000
       ~pullback_volume:400)

let test_pullback_rejected_high_volume _ =
  (* Breakout 2000, pullback 600 → ratio 0.3 > 0.25 → not confirmed *)
  assert_bool "pullback not confirmed"
    (not
       (is_pullback_confirmed ~config:cfg ~breakout_volume:2000
          ~pullback_volume:600))

let test_pullback_zero_breakout_volume _ =
  assert_bool "zero breakout → false"
    (not
       (is_pullback_confirmed ~config:cfg ~breakout_volume:0
          ~pullback_volume:100))

(* ------------------------------------------------------------------ *)
(* average_volume                                                      *)
(* ------------------------------------------------------------------ *)

let test_average_volume_basic _ =
  let bars = [ make_bar 1000; make_bar 2000; make_bar 3000 ] in
  assert_that (average_volume ~bars ~n:3) (float_equal 2000.0)

let test_average_volume_takes_last_n _ =
  (* last 2 of [1000, 2000, 3000] → avg 2500 *)
  let bars = [ make_bar 1000; make_bar 2000; make_bar 3000 ] in
  assert_that (average_volume ~bars ~n:2) (float_equal 2500.0)

let test_average_volume_empty _ =
  assert_that (average_volume ~bars:[] ~n:3) (float_equal 0.0)

(* ------------------------------------------------------------------ *)
(* Parity: analyze_breakout (bar-list) vs analyze_breakout_with_callbacks *)
(*                                                                    *)
(* Builds a {!callbacks} record externally via the public               *)
(* {!callbacks_from_bars} and asserts that the two entry points produce *)
(* bit-identical results. Each scenario hits a different regime: strong *)
(* / adequate / weak confirmation, and the insufficient-history guard.  *)
(* ------------------------------------------------------------------ *)

(** Bit-identity matcher for {!result}. *)
let result_is_bit_identical (expected : result) : result matcher =
  all_of
    [
      field
        (fun (r : result) -> r.confirmation)
        (equal_to expected.confirmation);
      field
        (fun (r : result) -> r.event_volume)
        (equal_to (expected.event_volume : int));
      field
        (fun (r : result) -> r.avg_volume)
        (equal_to (expected.avg_volume : float));
      field
        (fun (r : result) -> r.volume_ratio)
        (equal_to (expected.volume_ratio : float));
    ]

(** Run both [analyze_breakout] and [analyze_breakout_with_callbacks] over the
    same input and assert the results are bit-equal. The callback bundle is
    built externally via the public {!callbacks_from_bars}. *)
let assert_parity ~bars ~event_idx () =
  let bar_result = analyze_breakout ~config:cfg ~bars ~event_idx in
  let callbacks = callbacks_from_bars ~bars in
  let event_offset = List.length bars - 1 - event_idx in
  let callback_result =
    analyze_breakout_with_callbacks ~config:cfg ~callbacks ~event_offset
  in
  match (bar_result, callback_result) with
  | None, None -> ()
  | Some r1, Some r2 -> assert_that r2 (result_is_bit_identical r1)
  | _ -> assert_failure "Volume parity: one path returned None"

let test_parity_strong_breakout _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  assert_parity ~bars ~event_idx:4 ()

let test_parity_adequate_breakout _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1700 in
  assert_parity ~bars ~event_idx:4 ()

let test_parity_weak_breakout _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1100 in
  assert_parity ~bars ~event_idx:4 ()

let test_parity_insufficient_history _ =
  let bars = build_bars ~baseline_vol:1000 ~n:2 ~event_vol:3000 in
  assert_parity ~bars ~event_idx:2 ()

let test_parity_event_at_max_index _ =
  (* Larger window — event at the last bar, 4 prior. *)
  let bars =
    List.init 6 ~f:(fun i ->
        if i = 5 then make_bar 5000 else make_bar (1000 + (i * 100)))
  in
  assert_parity ~bars ~event_idx:5 ()

(* NaN guard regression — see _result_of_volumes Float.is_finite guard. A
   NaN event volume from a bad CSV bar pre-guard would propagate through
   division to NaN ratio + crash at Int.of_float on the result's
   event_volume field. Post-guard: return None and the screener treats
   the bar as having no volume signal. *)
let test_nan_event_volume_returns_none _ =
  let prior_callback ~week_offset =
    if week_offset = 0 then Some Float.nan
    else if week_offset >= 1 && week_offset <= 4 then Some 1000.0
    else None
  in
  let callbacks = { get_volume = prior_callback } in
  let result =
    analyze_breakout_with_callbacks ~config:default_config ~callbacks
      ~event_offset:0
  in
  assert_that result is_none

(* ------------------------------------------------------------------ *)
(* confirms_breakout — the two §4.2 branches (F5)                       *)
(* ------------------------------------------------------------------ *)

(** Chronological bars (oldest first) from a volume list; the LAST entry is the
    event bar, so [event_offset = 0]. *)
let _confirms volumes =
  confirms_breakout ~config:cfg
    ~callbacks:(callbacks_from_bars ~bars:(List.map volumes ~f:make_bar))
    ~event_offset:0

(** Branch (a): the event bar alone is 3x the prior 4 weeks. *)
let test_confirms_via_spike_branch _ =
  assert_that
    (_confirms [ 1000; 1000; 1000; 1000; 3000 ])
    (is_some_and (equal_to true))

(** Branch (b): the event bar is only 1.36x its prior 4 weeks (branch (a)
    fails), but the 4-week build-up (1500/1400/1300/1200, mean 1350) is 2.7x the
    prior 4-week baseline (mean 500) and the event bar rises over the week
    before it. Book: "volume build-up over 3-4 weeks that is >= 2x average of
    prior several weeks, with at least some increase on breakout week". *)
let test_confirms_via_buildup_branch _ =
  assert_that
    (_confirms [ 500; 500; 500; 500; 1200; 1300; 1400; 1500 ])
    (is_some_and (equal_to true))

(** A build-up whose ratio qualifies but whose event bar FALLS is not a
    confirmation — the book requires some increase on the breakout week. *)
let test_buildup_without_increase_on_event_bar_does_not_confirm _ =
  assert_that
    (_confirms [ 500; 500; 500; 500; 1500; 1500; 1500; 1400 ])
    (is_some_and (equal_to false))

(** Neither branch: a flat tape with a below-average event bar. *)
let test_neither_branch_confirms _ =
  assert_that
    (_confirms [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 900 ])
    (is_some_and (equal_to false))

(** Enough history for branch (a) but not for branch (b) (which needs two
    [lookback_bars]-sized windows): the spike verdict still stands alone. *)
let test_spike_verdict_stands_without_buildup_history _ =
  assert_that
    (_confirms [ 1000; 1000; 1000; 1000; 900 ])
    (is_some_and (equal_to false))

(** Too little history for EITHER branch is [None] — "no verdict", which callers
    must not read as an unconfirmed breakout. *)
let test_insufficient_history_is_none _ =
  assert_that (_confirms [ 1000; 900 ]) is_none

(** A negative offset has no bar to judge. *)
let test_negative_offset_is_none _ =
  assert_that
    (confirms_breakout ~config:cfg
       ~callbacks:(callbacks_from_bars ~bars:[ make_bar 1000 ])
       ~event_offset:(-1))
    is_none

(* ------------------------------------------------------------------ *)
(* classify_breakout — the same verdict, with the branch + measurement  *)
(* ------------------------------------------------------------------ *)

let _classify volumes =
  classify_breakout ~config:cfg
    ~callbacks:(callbacks_from_bars ~bars:(List.map volumes ~f:make_bar))
    ~event_offset:0

(** Render a classification as a stable string so one [assert_that] can pin the
    constructor AND its measurement across several fixtures without exact-float
    record equality. *)
let _measure = function None -> "none" | Some v -> Printf.sprintf "%.3f" v

let _summary = function
  | None -> "no_verdict"
  | Some (Spike ratio) -> Printf.sprintf "spike:%.3f" ratio
  | Some (Buildup multiple) -> Printf.sprintf "buildup:%.3f" multiple
  | Some (Unconfirmed { spike_ratio; buildup_multiple }) ->
      Printf.sprintf "unconfirmed:%s/%s" (_measure spike_ratio)
        (_measure buildup_multiple)

(** All four cases the audit must tell apart, on the same fixtures the boolean
    tests use. Confirmations name their branch AND carry the deciding multiple
    (the spike bar is 3x its prior 4 weeks; the build-up window, mean 1350, is
    2.7x its baseline of 500). The two non-confirmations are different kinds:
    [Unconfirmed] is "measured and failed", [None] is "no verdict, nothing was
    measurable" — the cell the F5 runner holds on. *)
let test_classify_names_each_branch_and_the_no_verdict_case _ =
  assert_that
    (List.map
       ~f:(fun v -> _summary (_classify v))
       [
         [ 1000; 1000; 1000; 1000; 3000 ];
         [ 500; 500; 500; 500; 1200; 1300; 1400; 1500 ];
         [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 900 ];
         [ 1000; 900 ];
       ])
    (elements_are
       [
         equal_to "spike:3.000";
         equal_to "buildup:2.700";
         equal_to "unconfirmed:0.900/0.975";
         equal_to "no_verdict";
       ])

(** A build-up that clears the 2x multiple but FALLS on the event bar is
    [Unconfirmed] — and its 2.95x near-miss multiple is still recorded, so the
    audit can rank it against a flat tape rather than only counting it. *)
let test_classify_records_the_near_miss_buildup_multiple _ =
  assert_that
    (_summary (_classify [ 500; 500; 500; 500; 1500; 1500; 1500; 1400 ]))
    (equal_to "unconfirmed:1.120/2.950")

(** Only branch (a) had history: the branch that could not be evaluated records
    [None] rather than a fabricated zero. *)
let test_classify_carries_none_for_the_unevaluable_branch _ =
  assert_that
    (_summary (_classify [ 1000; 1000; 1000; 1000; 900 ]))
    (equal_to "unconfirmed:0.900/none")

(** [confirms_breakout] is defined as the projection of [classify_breakout], so
    the two can never disagree. Pinned across every shape above, including the
    negative offset. *)
let test_confirms_breakout_agrees_with_classify _ =
  let shapes =
    [
      [ 1000; 1000; 1000; 1000; 3000 ];
      [ 500; 500; 500; 500; 1200; 1300; 1400; 1500 ];
      [ 500; 500; 500; 500; 1500; 1500; 1500; 1400 ];
      [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 900 ];
      [ 1000; 1000; 1000; 1000; 900 ];
      [ 1000; 900 ];
    ]
  in
  let projected =
    List.map shapes ~f:(fun volumes ->
        Option.map (_classify volumes) ~f:(function
          | Spike _ | Buildup _ -> true
          | Unconfirmed _ -> false))
  in
  assert_that projected
    (elements_are (List.map shapes ~f:(fun v -> equal_to (_confirms v))))

let suite =
  "volume_tests"
  >::: [
         "test_classify_names_each_branch_and_the_no_verdict_case"
         >:: test_classify_names_each_branch_and_the_no_verdict_case;
         "test_classify_records_the_near_miss_buildup_multiple"
         >:: test_classify_records_the_near_miss_buildup_multiple;
         "test_classify_carries_none_for_the_unevaluable_branch"
         >:: test_classify_carries_none_for_the_unevaluable_branch;
         "test_confirms_breakout_agrees_with_classify"
         >:: test_confirms_breakout_agrees_with_classify;
         "test_confirms_via_spike_branch" >:: test_confirms_via_spike_branch;
         "test_confirms_via_buildup_branch" >:: test_confirms_via_buildup_branch;
         "test_buildup_without_increase_on_event_bar_does_not_confirm"
         >:: test_buildup_without_increase_on_event_bar_does_not_confirm;
         "test_neither_branch_confirms" >:: test_neither_branch_confirms;
         "test_spike_verdict_stands_without_buildup_history"
         >:: test_spike_verdict_stands_without_buildup_history;
         "test_confirms_insufficient_history_is_none"
         >:: test_insufficient_history_is_none;
         "test_confirms_negative_offset_is_none"
         >:: test_negative_offset_is_none;
         "test_strong_breakout" >:: test_strong_breakout;
         "test_adequate_breakout" >:: test_adequate_breakout;
         "test_weak_breakout" >:: test_weak_breakout;
         "test_exactly_2x_is_strong" >:: test_exactly_2x_is_strong;
         "test_insufficient_prior_bars_returns_none"
         >:: test_insufficient_prior_bars_returns_none;
         "test_out_of_range_event_idx" >:: test_out_of_range_event_idx;
         "test_pullback_confirmed_low_volume"
         >:: test_pullback_confirmed_low_volume;
         "test_pullback_rejected_high_volume"
         >:: test_pullback_rejected_high_volume;
         "test_pullback_zero_breakout_volume"
         >:: test_pullback_zero_breakout_volume;
         "test_average_volume_basic" >:: test_average_volume_basic;
         "test_average_volume_takes_last_n" >:: test_average_volume_takes_last_n;
         "test_average_volume_empty" >:: test_average_volume_empty;
         "test_parity_strong_breakout" >:: test_parity_strong_breakout;
         "test_parity_adequate_breakout" >:: test_parity_adequate_breakout;
         "test_parity_weak_breakout" >:: test_parity_weak_breakout;
         "test_parity_insufficient_history" >:: test_parity_insufficient_history;
         "test_parity_event_at_max_index" >:: test_parity_event_at_max_index;
         "test_nan_event_volume_returns_none"
         >:: test_nan_event_volume_returns_none;
       ]

let () = run_test_tt_main suite
