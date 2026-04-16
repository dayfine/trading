(** Tests for [Support_floor.find_recent_level].

    Scenarios cover peak/trough + counter-move identification, depth
    thresholding, lookback truncation, tie-breaking, and degenerate inputs
    (empty, single bar, monotonic series, flat prices).

    Long and short sides are covered symmetrically: long looks for a prior
    correction low (support floor); short looks for a prior counter-rally high
    (resistance ceiling). *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
module Support_floor = Weinstein_stops.Support_floor

(* ---- Test helpers ---- *)

(* Build a daily bar; defaults produce a non-gapping bar centred on [close]. *)
let make_bar ~date ~high ~low ~close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

(* ==================================================================== *)
(*                           Long-side tests                            *)
(* ==================================================================== *)

(* ---- Peak + pullback identification ---- *)

let test_long_happy_path _ =
  (* Clean peak + correction pattern:
       bar 1: low 100 high 102  (base)
       bar 2: low 108 high 110  (<- peak: high=110)
       bar 3: low  99 high 101  (correction: low=99)
       bar 4: low  98 high 103  (correction: low=98 — the overall correction low)
       bar 5: low 100 high 105  (recovery)
     Depth: (110 - 98) / 110 = 10.9% >= 8% -> Some 98.0 *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-03" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-04" ~high:103.0 ~low:98.0 ~close:102.0;
      make_bar ~date:"2024-01-05" ~high:105.0 ~low:100.0 ~close:104.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-05")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    (is_some_and (float_equal 98.0))

(* ---- Depth threshold ---- *)

let test_long_below_threshold_returns_none _ =
  (* Peak 110; lowest low after peak is 103. Depth 6.4% < 8% -> None. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-03" ~high:106.0 ~low:103.0 ~close:104.0;
      make_bar ~date:"2024-01-04" ~high:107.0 ~low:104.0 ~close:106.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-04")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_long_threshold_boundary _ =
  (* Exactly at threshold: peak 100, low 92. Depth 8.0% == 8% -> Some 92.0. *)
  let bars =
    [
      make_bar ~date:"2024-01-02" ~high:100.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-03" ~high:95.0 ~low:92.0 ~close:93.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-03")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    (is_some_and (float_equal 92.0))

(* ---- Peak at last bar: no pullback yet ---- *)

let test_long_peak_at_end_returns_none _ =
  (* Monotonically rising — the peak is the last bar, so there is no drawdown
     to measure. Expected: None. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:105.0 ~low:100.0 ~close:104.0;
      make_bar ~date:"2024-01-03" ~high:110.0 ~low:105.0 ~close:109.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-03")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

(* ---- Lookback truncation ---- *)

let test_long_truncates_to_lookback_window _ =
  (* Earlier correction (peak 200 / low 160) is outside the lookback window;
     the recent quiet zone has no pullback > 8%. With lookback_bars=3 we
     should only see bars 4..6 and get None. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:202.0 ~low:199.0 ~close:200.0;
      make_bar ~date:"2024-01-02" ~high:200.0 ~low:160.0 ~close:165.0;
      make_bar ~date:"2024-01-03" ~high:172.0 ~low:168.0 ~close:170.0;
      make_bar ~date:"2024-01-04" ~high:171.0 ~low:169.0 ~close:170.5;
      make_bar ~date:"2024-01-05" ~high:172.0 ~low:170.0 ~close:171.5;
      make_bar ~date:"2024-01-06" ~high:173.0 ~low:170.5 ~close:172.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-06")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:3)
    is_none

let test_long_lookback_brings_pullback_into_view _ =
  (* Peak bar on 01-01, correction low on 01-02. With lookback=2 we capture
     both bars and the correction qualifies. With lookback=1 only 01-02 is
     in the window, the peak is the last bar, so None. *)
  let bars =
    [
      make_bar ~date:"2023-12-20" ~high:80.0 ~low:78.0 ~close:79.0;
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:98.0 ~close:99.0;
      make_bar ~date:"2024-01-02" ~high:95.0 ~low:85.0 ~close:86.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-02")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:2)
    (is_some_and (float_equal 85.0));
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-02")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:1)
    is_none

(* ---- Equal-high tie-breaking: latest peak wins ---- *)

let test_long_tie_breaks_to_latest_peak _ =
  (* Two equal highs (100.0) on days 1 and 3. Later peak anchors the pullback,
     so only bars after day 3 count. Day 4 low=94 -> depth 6% < 8% -> None. If
     tie-break used the earlier peak we'd see day 2's low=85 and return Some. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:98.0 ~close:99.0;
      make_bar ~date:"2024-01-02" ~high:95.0 ~low:85.0 ~close:88.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:90.0 ~close:99.0;
      make_bar ~date:"2024-01-04" ~high:98.0 ~low:94.0 ~close:96.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-04")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

(* ---- as_of excludes future bars ---- *)

let test_long_respects_as_of _ =
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-02" ~high:103.0 ~low:98.0 ~close:100.0;
      make_bar ~date:"2024-01-03" ~high:115.0 ~low:105.0 ~close:114.0;
      make_bar ~date:"2024-01-04" ~high:118.0 ~low:90.0 ~close:92.0;
    ]
  in
  (* as_of = 01-02: only first two bars considered. Peak 110, low 98, depth
     10.9% -> Some 98.0. The post-01-02 drop is invisible. *)
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-02")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    (is_some_and (float_equal 98.0))

(* ---- Configurable depth threshold ---- *)

let test_long_custom_threshold _ =
  (* Peak 100, low 97. 3% depth. Strict 8% rejects; 2% accepts. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:99.0 ~low:97.0 ~close:98.0;
    ]
  in
  let as_of = Date.of_string "2024-01-02" in
  assert_that
    (Support_floor.find_recent_level ~bars ~as_of ~side:Long
       ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none;
  assert_that
    (Support_floor.find_recent_level ~bars ~as_of ~side:Long
       ~min_pullback_pct:0.02 ~lookback_bars:52)
    (is_some_and (float_equal 97.0))

(* ==================================================================== *)
(*                           Short-side tests                           *)
(* ==================================================================== *)

(* ---- Trough + rally identification ---- *)

let test_short_happy_path _ =
  (* Mirror of long happy path — a trough with a counter-rally afterwards:
       bar 1: low  99 high 100 (base near 100)
       bar 2: low  90 high  92 (<- trough: low=90)
       bar 3: low  98 high 100 (rally: high=100)
       bar 4: low  97 high 102 (rally: high=102 — overall rally peak)
       bar 5: low  95 high  99 (fade)
     Depth: (102 - 90) / 90 = 13.3% >= 8% -> Some 102.0 *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:92.0 ~low:90.0 ~close:91.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:98.0 ~close:99.0;
      make_bar ~date:"2024-01-04" ~high:102.0 ~low:97.0 ~close:98.0;
      make_bar ~date:"2024-01-05" ~high:99.0 ~low:95.0 ~close:96.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-05")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    (is_some_and (float_equal 102.0))

(* ---- Depth threshold ---- *)

let test_short_below_threshold_returns_none _ =
  (* Trough 90; highest high after trough is 95. Depth 5.6% < 8% -> None. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:92.0 ~low:90.0 ~close:91.0;
      make_bar ~date:"2024-01-03" ~high:94.0 ~low:92.0 ~close:93.0;
      make_bar ~date:"2024-01-04" ~high:95.0 ~low:93.0 ~close:94.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-04")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_short_threshold_boundary _ =
  (* Exactly at threshold: trough 100, rally high 108. Depth 8.0% == 8% ->
     Some 108.0. *)
  let bars =
    [
      make_bar ~date:"2024-01-02" ~high:101.0 ~low:100.0 ~close:100.5;
      make_bar ~date:"2024-01-03" ~high:108.0 ~low:105.0 ~close:107.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-03")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    (is_some_and (float_equal 108.0))

(* ---- Trough at last bar: no rally yet ---- *)

let test_short_trough_at_end_returns_none _ =
  (* Monotonically falling — the trough is the last bar, so there is no
     counter-rally to measure. Expected: None. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:110.0 ~low:109.0 ~close:109.5;
      make_bar ~date:"2024-01-02" ~high:108.0 ~low:105.0 ~close:106.0;
      make_bar ~date:"2024-01-03" ~high:105.0 ~low:100.0 ~close:101.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-03")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

(* ---- Equal-low tie-breaking: latest trough wins ---- *)

let test_short_tie_breaks_to_latest_trough _ =
  (* Two equal lows (90.0) on days 1 and 3. Later trough anchors the rally,
     so only bars after day 3 count. Day 4 high=95 -> depth 5.6% < 8% -> None.
     If tie-break used the earlier trough we'd see day 2's high=105 and
     return Some 105.0. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:92.0 ~low:90.0 ~close:91.0;
      make_bar ~date:"2024-01-02" ~high:105.0 ~low:95.0 ~close:100.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:90.0 ~close:92.0;
      make_bar ~date:"2024-01-04" ~high:95.0 ~low:92.0 ~close:94.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-04")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

(* ---- Lookback truncation ---- *)

let test_short_truncates_to_lookback_window _ =
  (* Earlier rally (trough 100 / high 130) is outside the lookback window;
     the recent quiet zone has no rally > 8%. With lookback_bars=3 we should
     only see bars 4..6 and get None. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2024-01-02" ~high:130.0 ~low:100.0 ~close:129.0;
      make_bar ~date:"2024-01-03" ~high:129.0 ~low:125.0 ~close:127.0;
      make_bar ~date:"2024-01-04" ~high:128.0 ~low:126.0 ~close:127.0;
      make_bar ~date:"2024-01-05" ~high:127.5 ~low:126.0 ~close:126.5;
      make_bar ~date:"2024-01-06" ~high:127.0 ~low:125.5 ~close:126.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-06")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:3)
    is_none

(* ==================================================================== *)
(*                          Degenerate inputs                           *)
(* ==================================================================== *)

let test_empty_bars_returns_none_long _ =
  assert_that
    (Support_floor.find_recent_level ~bars:[]
       ~as_of:(Date.of_string "2024-01-05")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_empty_bars_returns_none_short _ =
  assert_that
    (Support_floor.find_recent_level ~bars:[]
       ~as_of:(Date.of_string "2024-01-05")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_single_bar_returns_none_long _ =
  (* Single bar: anchor is also the last bar; no counter-move. *)
  let bars =
    [ make_bar ~date:"2024-01-01" ~high:100.0 ~low:90.0 ~close:95.0 ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-01")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_single_bar_returns_none_short _ =
  let bars =
    [ make_bar ~date:"2024-01-01" ~high:100.0 ~low:90.0 ~close:95.0 ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-01")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_flat_prices_returns_none_long _ =
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:100.0 ~close:100.0;
      make_bar ~date:"2024-01-02" ~high:100.0 ~low:100.0 ~close:100.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:100.0 ~close:100.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-03")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_flat_prices_returns_none_short _ =
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:100.0 ~close:100.0;
      make_bar ~date:"2024-01-02" ~high:100.0 ~low:100.0 ~close:100.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:100.0 ~close:100.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-03")
       ~side:Short ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_as_of_before_all_bars_returns_none _ =
  let bars =
    [
      make_bar ~date:"2024-02-01" ~high:100.0 ~low:90.0 ~close:95.0;
      make_bar ~date:"2024-02-02" ~high:102.0 ~low:88.0 ~close:90.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-01")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:52)
    is_none

let test_zero_lookback_returns_none _ =
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-02" ~high:103.0 ~low:98.0 ~close:100.0;
    ]
  in
  assert_that
    (Support_floor.find_recent_level ~bars
       ~as_of:(Date.of_string "2024-01-02")
       ~side:Long ~min_pullback_pct:0.08 ~lookback_bars:0)
    is_none

let suite =
  "support_floor"
  >::: [
         (* Long side *)
         "long_happy_path" >:: test_long_happy_path;
         "long_below_threshold" >:: test_long_below_threshold_returns_none;
         "long_threshold_boundary" >:: test_long_threshold_boundary;
         "long_peak_at_end" >:: test_long_peak_at_end_returns_none;
         "long_truncates_to_lookback" >:: test_long_truncates_to_lookback_window;
         "long_lookback_brings_pullback_into_view"
         >:: test_long_lookback_brings_pullback_into_view;
         "long_tie_breaks_to_latest_peak"
         >:: test_long_tie_breaks_to_latest_peak;
         "long_respects_as_of" >:: test_long_respects_as_of;
         "long_custom_threshold" >:: test_long_custom_threshold;
         (* Short side *)
         "short_happy_path" >:: test_short_happy_path;
         "short_below_threshold" >:: test_short_below_threshold_returns_none;
         "short_threshold_boundary" >:: test_short_threshold_boundary;
         "short_trough_at_end" >:: test_short_trough_at_end_returns_none;
         "short_tie_breaks_to_latest_trough"
         >:: test_short_tie_breaks_to_latest_trough;
         "short_truncates_to_lookback"
         >:: test_short_truncates_to_lookback_window;
         (* Degenerate inputs *)
         "empty_bars_long" >:: test_empty_bars_returns_none_long;
         "empty_bars_short" >:: test_empty_bars_returns_none_short;
         "single_bar_long" >:: test_single_bar_returns_none_long;
         "single_bar_short" >:: test_single_bar_returns_none_short;
         "flat_prices_long" >:: test_flat_prices_returns_none_long;
         "flat_prices_short" >:: test_flat_prices_returns_none_short;
         "as_of_before_bars" >:: test_as_of_before_all_bars_returns_none;
         "zero_lookback" >:: test_zero_lookback_returns_none;
       ]

let () = run_test_tt_main suite
