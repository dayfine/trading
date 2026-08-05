(** Tests for [Support_floor.find_recent_level] and the
    [compute_initial_stop_with_floor] wrapper.

    Primitive scenarios cover peak/trough + counter-move identification, depth
    thresholding, lookback truncation, tie-breaking, and degenerate inputs
    (empty, single bar, monotonic series, flat prices). Long and short sides are
    covered symmetrically.

    Wrapper scenarios verify the [None] fallback path matches the pre-primitive
    fixed-buffer proxy and the [Some] path uses the identified level as the stop
    reference. *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
open Weinstein_stops
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
    active_through = None;
  }

(* Build a bar with a distinct [adjusted_close] — used by the split-safe
   fixtures, where the per-bar factor [adjusted_close /. close] differs from
   1.0 (a split / dividend inside the window). *)
let make_bar_adj ~date ~high ~low ~close ~adjusted_close =
  { (make_bar ~date ~high ~low ~close) with adjusted_close }

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

(* ==================================================================== *)
(*            compute_initial_stop_with_floor wrapper tests             *)
(* ==================================================================== *)

let cfg = default_config

(* Matches the proxy the strategy used before this primitive existed. *)
let fallback_buffer = 1.02

(* ---- None path: wrapper === pre-primitive direct call ---- *)

let test_wrapper_empty_bars_matches_proxy _ =
  (* No bars at all: primitive returns None, wrapper uses
     entry_price *. fallback_buffer as reference_level. Compare against a
     direct compute_initial_stop call with that same reference. *)
  let entry_price = 100.0 in
  let direct =
    compute_initial_stop ~config:cfg ~side:Long
      ~reference_level:(entry_price *. fallback_buffer)
  in
  let wrapped =
    compute_initial_stop_with_floor ~config:cfg ~side:Long ~entry_price ~bars:[]
      ~as_of:(Date.of_string "2024-01-05")
      ~fallback_buffer
  in
  assert_that wrapped (equal_to (direct : stop_state))

let test_wrapper_no_qualifying_pullback_matches_proxy _ =
  (* Bars present but no qualifying pullback (flat series): fallback path. *)
  let entry_price = 100.0 in
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-02" ~high:102.0 ~low:99.5 ~close:100.5;
      make_bar ~date:"2024-01-03" ~high:102.0 ~low:100.0 ~close:101.0;
    ]
  in
  let direct =
    compute_initial_stop ~config:cfg ~side:Long
      ~reference_level:(entry_price *. fallback_buffer)
  in
  let wrapped =
    compute_initial_stop_with_floor ~config:cfg ~side:Long ~entry_price ~bars
      ~as_of:(Date.of_string "2024-01-03")
      ~fallback_buffer
  in
  assert_that wrapped (equal_to (direct : stop_state))

let test_wrapper_short_no_qualifying_rally_falls_back _ =
  (* Short side: bars present but no qualifying counter-rally. Falls back
     to entry_price /. fallback_buffer (stop placed above entry). *)
  let entry_price = 100.0 in
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-02" ~high:102.0 ~low:99.5 ~close:100.5;
      make_bar ~date:"2024-01-03" ~high:102.0 ~low:100.0 ~close:101.0;
    ]
  in
  let direct =
    compute_initial_stop ~config:cfg ~side:Short
      ~reference_level:(entry_price /. fallback_buffer)
  in
  let wrapped =
    compute_initial_stop_with_floor ~config:cfg ~side:Short ~entry_price ~bars
      ~as_of:(Date.of_string "2024-01-03")
      ~fallback_buffer
  in
  assert_that wrapped (equal_to (direct : stop_state))

(* ---- Some path: wrapper uses the support level as reference ---- *)

let test_wrapper_long_uses_support_floor_when_available _ =
  (* Clear peak + correction in recent bars — primitive returns Some 98.0.
     Wrapper should build an Initial state with reference_level=98.0 (the
     identified correction low), not entry_price*fallback_buffer. *)
  let entry_price = 109.0 in
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-03" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-04" ~high:103.0 ~low:98.0 ~close:102.0;
      make_bar ~date:"2024-01-05" ~high:109.0 ~low:105.0 ~close:108.0;
    ]
  in
  let wrapped =
    compute_initial_stop_with_floor ~config:cfg ~side:Long ~entry_price ~bars
      ~as_of:(Date.of_string "2024-01-05")
      ~fallback_buffer
  in
  assert_that wrapped
    (matching ~msg:"Expected Initial state with support-floor reference"
       (function
         | Initial { reference_level; _ } -> Some reference_level | _ -> None)
       (float_equal 98.0))

let test_wrapper_short_uses_resistance_ceiling_when_available _ =
  (* Mirror of the long support-floor test — short side picks up a rally
     high of 102.0 from a recent trough. Wrapper should build an Initial
     state with reference_level=102.0 (not entry_price/fallback_buffer). *)
  let entry_price = 91.0 in
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:92.0 ~low:90.0 ~close:91.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:98.0 ~close:99.0;
      make_bar ~date:"2024-01-04" ~high:102.0 ~low:97.0 ~close:98.0;
      make_bar ~date:"2024-01-05" ~high:95.0 ~low:92.0 ~close:93.0;
    ]
  in
  let wrapped =
    compute_initial_stop_with_floor ~config:cfg ~side:Short ~entry_price ~bars
      ~as_of:(Date.of_string "2024-01-05")
      ~fallback_buffer
  in
  assert_that wrapped
    (matching ~msg:"Expected Initial state with resistance-ceiling reference"
       (function
         | Initial { reference_level; _ } -> Some reference_level | _ -> None)
       (float_equal 102.0))

let test_wrapper_support_floor_vs_proxy_differs _ =
  (* Regression: same entry + same bars, compare support-floor path to the
     naive proxy path. They MUST produce different stops, else the primitive
     is inert. *)
  let entry_price = 109.0 in
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-03" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-04" ~high:103.0 ~low:98.0 ~close:102.0;
      make_bar ~date:"2024-01-05" ~high:109.0 ~low:105.0 ~close:108.0;
    ]
  in
  let proxy =
    compute_initial_stop ~config:cfg ~side:Long
      ~reference_level:(entry_price *. fallback_buffer)
  in
  let wrapped =
    compute_initial_stop_with_floor ~config:cfg ~side:Long ~entry_price ~bars
      ~as_of:(Date.of_string "2024-01-05")
      ~fallback_buffer
  in
  assert_that (equal_stop_state proxy wrapped) (equal_to false)

(* ==================================================================== *)
(*            anchor_mode: Wick (default) vs Close                       *)
(* ==================================================================== *)

(* CLMB-shaped long fixture: bar 3 has a deep intraday wick (low 90) that
   undercuts every surrounding close, while the closes hold a shallower
   correction.
     peak  (bar 2): high 110, close 109
     wick  (bar 3): low  90,  close 100  <- capitulation wick
   Wick mode  → correction low = intraday low 90  (depth (110-90)/110 = 18%).
   Close mode → correction low = lowest close 100 (depth (109-100)/109 = 8.3%),
                anchoring on the highest close 109; the wick is ignored. *)
let clmb_long_bars =
  [
    make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
    make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
    make_bar ~date:"2024-01-03" ~high:101.0 ~low:90.0 ~close:100.0;
    make_bar ~date:"2024-01-04" ~high:102.0 ~low:99.0 ~close:100.0;
    make_bar ~date:"2024-01-05" ~high:109.0 ~low:105.0 ~close:108.0;
  ]

let clmb_long_callbacks =
  Support_floor.callbacks_from_bars ~bars:clmb_long_bars
    ~as_of:(Date.of_string "2024-01-05")
    ~lookback_bars:90

(* Mirror short fixture: bar 3 has an intraday spike (high 110) above every
   surrounding close.
     trough (bar 2): low 90, close 91
     spike  (bar 3): high 110, close 100  <- counter-rally spike
   Wick mode  → rally high = intraday high 110 (depth (110-90)/90 = 22%).
   Close mode → rally high = highest close 100 (depth (100-91)/91 = 9.9%),
                anchoring on the lowest close 91; the spike is ignored. *)
let spike_short_bars =
  [
    make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
    make_bar ~date:"2024-01-02" ~high:92.0 ~low:90.0 ~close:91.0;
    make_bar ~date:"2024-01-03" ~high:110.0 ~low:97.0 ~close:100.0;
    make_bar ~date:"2024-01-04" ~high:101.0 ~low:98.0 ~close:99.0;
    make_bar ~date:"2024-01-05" ~high:95.0 ~low:92.0 ~close:93.0;
  ]

let spike_short_callbacks =
  Support_floor.callbacks_from_bars ~bars:spike_short_bars
    ~as_of:(Date.of_string "2024-01-05")
    ~lookback_bars:90

let test_anchor_default_is_wick_long _ =
  (* Omitting [~anchor_mode] reads the intraday wick — bit-identical to the
     historical behaviour (default = Wick). *)
  assert_that
    (Support_floor.find_recent_level_with_callbacks
       ~callbacks:clmb_long_callbacks ~side:Long ~min_pullback_pct:0.08 ())
    (is_some_and (float_equal 90.0))

let test_anchor_wick_long_explicit _ =
  assert_that
    (Support_floor.find_recent_level_with_callbacks
       ~anchor_mode:Support_floor.Wick ~callbacks:clmb_long_callbacks ~side:Long
       ~min_pullback_pct:0.08 ())
    (is_some_and (float_equal 90.0))

let test_anchor_close_long_ignores_wick _ =
  assert_that
    (Support_floor.find_recent_level_with_callbacks
       ~anchor_mode:Support_floor.Close ~callbacks:clmb_long_callbacks
       ~side:Long ~min_pullback_pct:0.08 ())
    (is_some_and (float_equal 100.0))

let test_anchor_default_is_wick_short _ =
  assert_that
    (Support_floor.find_recent_level_with_callbacks
       ~callbacks:spike_short_callbacks ~side:Short ~min_pullback_pct:0.08 ())
    (is_some_and (float_equal 110.0))

let test_anchor_close_short_ignores_spike _ =
  assert_that
    (Support_floor.find_recent_level_with_callbacks
       ~anchor_mode:Support_floor.Close ~callbacks:spike_short_callbacks
       ~side:Short ~min_pullback_pct:0.08 ())
    (is_some_and (float_equal 100.0))

(* ---- Config field: default, round-trip, omitted-defaults-to-Wick ---- *)

let test_config_default_anchor_mode_is_wick _ =
  assert_that default_config.support_floor_anchor_mode
    (equal_to (Support_floor.Wick : Support_floor.anchor_mode))

let test_config_close_sexp_roundtrips _ =
  let c =
    { default_config with support_floor_anchor_mode = Support_floor.Close }
  in
  assert_that (config_of_sexp (sexp_of_config c)) (equal_to (c : config))

let test_config_sexp_omits_field_defaults_wick _ =
  (* A serialized config that predates this field (no
     [support_floor_anchor_mode] key) must parse back to the [Wick] default —
     the backward-compat guarantee behind R1. *)
  let stripped =
    match sexp_of_config default_config with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "support_floor_anchor_mode" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that (config_of_sexp stripped) (equal_to (default_config : config))

(* ==================================================================== *)
(*            split_safe_floors: raw vs adjusted-basis bars              *)
(* ==================================================================== *)

let cfg_split = { cfg with split_safe_floors = true }

(* Long 4:1 forward split between bar 4 and bar 5. Bars 1-4 are pre-split
   (raw ~4x the current price, [adjusted_close] = raw / 4 → factor 0.25); bar 5
   is post-split (factor 1.0). On the {b adjusted} basis the series is a clean
   peak (110) + correction (low 98); on the {b raw} basis the pre-split high
   (440) is a phantom peak and the post-split low (104) is picked up as the
   "correction low" of a bogus 76% drawdown — a garbage floor at 104 that sits
   right at the current ~104 entry. *)
let split_long_bars =
  [
    make_bar_adj ~date:"2024-01-01" ~high:408.0 ~low:400.0 ~close:404.0
      ~adjusted_close:101.0;
    make_bar_adj ~date:"2024-01-02" ~high:440.0 ~low:432.0 ~close:436.0
      ~adjusted_close:109.0;
    make_bar_adj ~date:"2024-01-03" ~high:404.0 ~low:396.0 ~close:400.0
      ~adjusted_close:100.0;
    make_bar_adj ~date:"2024-01-04" ~high:412.0 ~low:392.0 ~close:408.0
      ~adjusted_close:102.0;
    make_bar_adj ~date:"2024-01-05" ~high:105.0 ~low:104.0 ~close:104.0
      ~adjusted_close:104.0;
  ]

let split_long_entry = 104.0
let split_as_of = Date.of_string "2024-01-05"

let _initial_reference matcher =
  matching ~msg:"Expected Initial state"
    (function
      | Initial { reference_level; _ } -> Some reference_level | _ -> None)
    matcher

let test_split_safe_long_uses_adjusted_floor _ =
  (* split_safe on: floor lands where the adjusted chart says (98.0). *)
  assert_that
    (compute_initial_stop_with_floor ~config:cfg_split ~side:Long
       ~entry_price:split_long_entry ~bars:split_long_bars ~as_of:split_as_of
       ~fallback_buffer)
    (_initial_reference (float_equal 98.0))

let test_split_safe_long_off_uses_raw_floor _ =
  (* Default-off (bit-identical to pre-flag behaviour): the raw pre-split high
     anchors and the post-split low 104 becomes the phantom floor. *)
  assert_that
    (compute_initial_stop_with_floor ~config:cfg ~side:Long
       ~entry_price:split_long_entry ~bars:split_long_bars ~as_of:split_as_of
       ~fallback_buffer)
    (_initial_reference (float_equal 104.0))

(* Short mirror: same 4:1 split between bar 4 and bar 5. On the adjusted basis a
   clean trough (low 90) + counter-rally (high 102); on the raw basis the
   post-split low 92 is the lowest bar and it is the LAST bar, so there is no
   counter-rally after the trough at all — the raw path finds no ceiling and
   falls back to the buffer. *)
let split_short_bars =
  [
    make_bar_adj ~date:"2024-01-01" ~high:400.0 ~low:396.0 ~close:398.0
      ~adjusted_close:99.5;
    make_bar_adj ~date:"2024-01-02" ~high:368.0 ~low:360.0 ~close:364.0
      ~adjusted_close:91.0;
    make_bar_adj ~date:"2024-01-03" ~high:400.0 ~low:392.0 ~close:396.0
      ~adjusted_close:99.0;
    make_bar_adj ~date:"2024-01-04" ~high:408.0 ~low:388.0 ~close:392.0
      ~adjusted_close:98.0;
    make_bar_adj ~date:"2024-01-05" ~high:95.0 ~low:92.0 ~close:93.0
      ~adjusted_close:93.0;
  ]

let split_short_entry = 93.0

let test_split_safe_short_uses_adjusted_ceiling _ =
  assert_that
    (compute_initial_stop_with_floor ~config:cfg_split ~side:Short
       ~entry_price:split_short_entry ~bars:split_short_bars ~as_of:split_as_of
       ~fallback_buffer)
    (_initial_reference (float_equal 102.0))

(* Corrupt-close guard: bar 3 (the correction-low bar) carries a [close_price]
   of 0.0 and bar 4 a [close_price] of NaN. Either would make the factor
   meaningless ([102 /. 0.0 = +inf]; [104 /. nan = nan]), poisoning the scanned
   highs/lows and dropping the real floor. Both are rejected by
   [_usable_price] — the zero by the [> 0.0] test and the NaN by the same test
   (IEEE: [nan > 0.0] is [false]), which is why no separate [is_nan] branch is
   needed. The window is then not adjustable at all, so the scan runs raw and
   the finite structural floor (98.0) still lands. *)
let corrupt_close_bars =
  [
    make_bar_adj ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0
      ~adjusted_close:101.0;
    make_bar_adj ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0
      ~adjusted_close:109.0;
    make_bar_adj ~date:"2024-01-03" ~high:103.0 ~low:98.0 ~close:0.0
      ~adjusted_close:102.0;
    make_bar_adj ~date:"2024-01-04" ~high:105.0 ~low:100.0 ~close:Float.nan
      ~adjusted_close:104.0;
  ]

let test_split_safe_corrupt_close_guarded _ =
  assert_that
    (compute_initial_stop_with_floor ~config:cfg_split ~side:Long
       ~entry_price:104.0 ~bars:corrupt_close_bars ~as_of:split_as_of
       ~fallback_buffer)
    (_initial_reference (float_equal 98.0))

(* ---- B1: the close is replaced by the ADJUSTED close, not merely scaled ---- *)

(* Under [Close] anchor the scan reads [get_close] for both the anchoring peak
   and the correction extreme, so the close's basis is load-bearing — this is
   the only configuration in which the close-replacement half of the rescale is
   observable at all.

   On the adjusted basis the closes are 101 / 109 / 100 / 102 / 104: peak 109,
   post-peak low 100, depth (109-100)/109 = 8.3% >= 8% -> reference 100.0.
   Leave [get_close] on the raw closes (404 / 436 / 400 / 408 / 104) and the
   scan anchors on 436 and returns the phantom 104.0 instead — adjusted
   highs/lows measured against raw closes, the exact mixed-basis pathology this
   flag exists to remove. [(Close x split_safe_floors=true)] is an expressible
   [Variant_matrix] cell (both are config fields), so this is a reachable
   configuration, not a hypothetical. *)
let test_split_safe_close_anchor_uses_adjusted_closes _ =
  assert_that
    (compute_initial_stop_with_floor
       ~config:
         { cfg_split with support_floor_anchor_mode = Support_floor.Close }
       ~side:Long ~entry_price:split_long_entry ~bars:split_long_bars
       ~as_of:split_as_of ~fallback_buffer)
    (_initial_reference (float_equal 100.0))

(* ---- B2: an unusable adjusted close degrades the WHOLE window to raw ---- *)

(* The contract: [split_safe_floors] either measures on a fully-adjusted window
   or does exactly what the flag-off path does. It never produces a third
   answer. Both fixtures below therefore assert structural equality of the whole
   [stop_state] against the same bars scanned with the flag off — a stronger and
   more durable claim than any particular float. *)

(* [split_long_bars] with the adjusted close blanked on the correction-low bar
   (2024-01-04, whose adjusted low 98 IS the structural floor).

   Degrading only this bar to raw was measured at reference 104.0 — the phantom
   — because its un-rescaled high 412 out-tops every adjusted high and becomes
   the anchor. Propagating the NaN instead was measured at 99.0: a silently
   wrong floor still reported [stop_is_structural = true]. Whole-window fallback
   is the only one of the three that yields a value the caller can reason
   about. *)
let nan_adj_at_low_bars =
  List.map split_long_bars ~f:(fun (b : Types.Daily_price.t) ->
      if Date.equal b.date (Date.of_string "2024-01-04") then
        { b with adjusted_close = Float.nan }
      else b)

(* Every adjusted close blanked — the "legacy warehouse" shape. A snapshot whose
   schema predates [Adjusted_close] makes the field read fail, and
   [Snapshot_bar_views._read_history_or_empty] maps that to [], so every
   adjusted cell reads NaN. Because the field read fails for the whole symbol
   rather than per date, all-or-nothing is also the granularity at which the
   real data source actually fails.

   Under NaN-propagation this collapsed EVERY scan to the buffer fallback
   (measured: reference 106.08 = entry x fallback_buffer), which in a
   walk-forward surface over [((stops_config ((split_safe_floors true))))] would
   read as a real, meaningful negative result. Inertness that is identical to
   baseline is instead visible as "on == off in every row" — the same signature
   that exposed this PR's original panel-path defect. *)
let all_nan_adj_bars =
  List.map split_long_bars ~f:(fun (b : Types.Daily_price.t) ->
      { b with adjusted_close = Float.nan })

(* The discriminating fixture for whole-window vs per-bar fallback: the adjusted
   close is blanked on the {b post-split} bar (2024-01-05), whose true factor
   happens to be 1.0.

   Per-bar fallback substitutes 1.0 for that bar and rescales the other four, so
   it reconstructs the fully-adjusted window by luck and returns 98.0.
   Whole-window fallback returns the flag-off answer, 104.0. The two coincide on
   [nan_adj_at_low_bars], which is why this second fixture exists.

   Per-bar is a gamble on the unknowable: it is right exactly when the missing
   factor was ~1.0 and lands on the phantom anchor when it was not (measured:
   104.0 on [nan_adj_at_low_bars] via that bar's un-rescaled raw high 412
   out-topping every adjusted high). A stop mechanism cannot tell those apart
   from the data — the cell is missing precisely because the factor is unknown —
   so it takes the conservative branch rather than the lucky one. *)
let nan_adj_at_last_bar_bars =
  List.map split_long_bars ~f:(fun (b : Types.Daily_price.t) ->
      if Date.equal b.date (Date.of_string "2024-01-05") then
        { b with adjusted_close = Float.nan }
      else b)

let _flag_off_long bars =
  compute_initial_stop_with_floor ~config:cfg ~side:Long
    ~entry_price:split_long_entry ~bars ~as_of:split_as_of ~fallback_buffer

let _flag_on_long bars =
  compute_initial_stop_with_floor ~config:cfg_split ~side:Long
    ~entry_price:split_long_entry ~bars ~as_of:split_as_of ~fallback_buffer

let test_split_safe_nan_adjusted_close_degrades_to_raw_window _ =
  assert_that
    (_flag_on_long nan_adj_at_low_bars)
    (equal_to (_flag_off_long nan_adj_at_low_bars : stop_state))

(* Pins whole-window (not per-bar) fallback: per-bar would return 98.0 here. *)
let test_split_safe_nan_adjusted_falls_back_whole_window_not_per_bar _ =
  assert_that
    (_flag_on_long nan_adj_at_last_bar_bars)
    (all_of
       [
         equal_to (_flag_off_long nan_adj_at_last_bar_bars : stop_state);
         _initial_reference (float_equal 104.0);
       ])

let test_split_safe_all_nan_adjusted_is_inert _ =
  assert_that
    (_flag_on_long all_nan_adj_bars)
    (equal_to (_flag_off_long all_nan_adj_bars : stop_state))

(* The inert case must also not claim a structural floor it did not measure:
   the classifier follows the same window fallback as the level. *)
let test_split_safe_all_nan_adjusted_structural_flag_matches_flag_off _ =
  assert_that
    (floor_is_structural ~config:cfg_split ~side:Long ~bars:all_nan_adj_bars
       ~as_of:split_as_of)
    (equal_to
       (floor_is_structural ~config:cfg ~side:Long ~bars:all_nan_adj_bars
          ~as_of:split_as_of))

(* ==================================================================== *)
(*            floor_is_structural: flag agrees with the level            *)
(* ==================================================================== *)

(* Wick qualifies (deep intraday low 90) but the CLOSES hold a shallow (<8%)
   correction, so [Close] mode finds no structural floor. This is exactly the
   #2167 divergence: keying [stop_is_structural] off the Wick-only bar-list
   [find_recent_level] reports [true] while a [Close]-anchored stop level uses
   the fallback buffer. [floor_is_structural] threads [anchor_mode], so the flag
   now agrees with the level. *)
let wick_only_bars =
  [
    make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
    make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
    make_bar ~date:"2024-01-03" ~high:101.0 ~low:90.0 ~close:105.0;
    make_bar ~date:"2024-01-04" ~high:108.0 ~low:104.0 ~close:106.0;
    make_bar ~date:"2024-01-05" ~high:109.0 ~low:105.0 ~close:108.0;
  ]

let test_floor_is_structural_wick_true _ =
  assert_that
    (floor_is_structural ~config:cfg ~side:Long ~bars:wick_only_bars
       ~as_of:split_as_of)
    (equal_to true)

let test_floor_is_structural_close_mode_false _ =
  (* Fails on the old Wick-only classifier, which would return [true] here. *)
  assert_that
    (floor_is_structural
       ~config:{ cfg with support_floor_anchor_mode = Support_floor.Close }
       ~side:Long ~bars:wick_only_bars ~as_of:split_as_of)
    (equal_to false)

let test_floor_is_structural_close_level_uses_fallback _ =
  (* The [Close]-mode level agrees with the [false] flag: it is the buffer
     fallback, not a structural floor. *)
  assert_that
    (compute_initial_stop_with_floor
       ~config:{ cfg with support_floor_anchor_mode = Support_floor.Close }
       ~side:Long ~entry_price:108.0 ~bars:wick_only_bars ~as_of:split_as_of
       ~fallback_buffer)
    (_initial_reference (float_equal (108.0 *. fallback_buffer)))

let test_floor_is_structural_split_safe_off_short_false _ =
  (* Raw basis: no counter-rally after the (last-bar) trough → non-structural. *)
  assert_that
    (floor_is_structural ~config:cfg ~side:Short ~bars:split_short_bars
       ~as_of:split_as_of)
    (equal_to false)

let test_floor_is_structural_split_safe_on_short_true _ =
  (* Adjusted basis: a real trough + counter-rally → structural. Confirms
     [split_safe_floors] threads through [floor_is_structural]. *)
  assert_that
    (floor_is_structural ~config:cfg_split ~side:Short ~bars:split_short_bars
       ~as_of:split_as_of)
    (equal_to true)

(* ---- Config field: default, round-trip, omitted-defaults-to-false ---- *)

let test_config_default_split_safe_is_false _ =
  assert_that default_config.split_safe_floors (equal_to false)

let test_config_split_safe_sexp_roundtrips _ =
  let c = { default_config with split_safe_floors = true } in
  assert_that (config_of_sexp (sexp_of_config c)) (equal_to (c : config))

let test_config_sexp_omits_split_safe_defaults_false _ =
  (* A serialized config predating this field (no [split_safe_floors] key) must
     parse back to the [false] default — the R1 backward-compat guarantee. *)
  let stripped =
    match sexp_of_config default_config with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "split_safe_floors" :: _) -> false
            | _ -> true))
    | other -> other
  in
  assert_that (config_of_sexp stripped) (equal_to (default_config : config))

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
         (* Wrapper: None path matches pre-primitive proxy *)
         "wrapper_empty_bars_matches_proxy"
         >:: test_wrapper_empty_bars_matches_proxy;
         "wrapper_no_qualifying_pullback_matches_proxy"
         >:: test_wrapper_no_qualifying_pullback_matches_proxy;
         "wrapper_short_no_qualifying_rally_falls_back"
         >:: test_wrapper_short_no_qualifying_rally_falls_back;
         (* Wrapper: Some path uses identified level *)
         "wrapper_long_uses_support_floor_when_available"
         >:: test_wrapper_long_uses_support_floor_when_available;
         "wrapper_short_uses_resistance_ceiling_when_available"
         >:: test_wrapper_short_uses_resistance_ceiling_when_available;
         "wrapper_support_floor_vs_proxy_differs"
         >:: test_wrapper_support_floor_vs_proxy_differs;
         (* anchor_mode: Wick (default) vs Close *)
         "anchor_default_is_wick_long" >:: test_anchor_default_is_wick_long;
         "anchor_wick_long_explicit" >:: test_anchor_wick_long_explicit;
         "anchor_close_long_ignores_wick"
         >:: test_anchor_close_long_ignores_wick;
         "anchor_default_is_wick_short" >:: test_anchor_default_is_wick_short;
         "anchor_close_short_ignores_spike"
         >:: test_anchor_close_short_ignores_spike;
         (* config field: default / round-trip / back-compat *)
         "config_default_anchor_mode_is_wick"
         >:: test_config_default_anchor_mode_is_wick;
         "config_close_sexp_roundtrips" >:: test_config_close_sexp_roundtrips;
         "config_sexp_omits_field_defaults_wick"
         >:: test_config_sexp_omits_field_defaults_wick;
         (* split_safe_floors: raw vs adjusted-basis bars *)
         "split_safe_long_uses_adjusted_floor"
         >:: test_split_safe_long_uses_adjusted_floor;
         "split_safe_long_off_uses_raw_floor"
         >:: test_split_safe_long_off_uses_raw_floor;
         "split_safe_short_uses_adjusted_ceiling"
         >:: test_split_safe_short_uses_adjusted_ceiling;
         "split_safe_corrupt_close_guarded"
         >:: test_split_safe_corrupt_close_guarded;
         "split_safe_close_anchor_uses_adjusted_closes"
         >:: test_split_safe_close_anchor_uses_adjusted_closes;
         "split_safe_nan_adjusted_close_degrades_to_raw_window"
         >:: test_split_safe_nan_adjusted_close_degrades_to_raw_window;
         "split_safe_nan_adjusted_falls_back_whole_window_not_per_bar"
         >:: test_split_safe_nan_adjusted_falls_back_whole_window_not_per_bar;
         "split_safe_all_nan_adjusted_is_inert"
         >:: test_split_safe_all_nan_adjusted_is_inert;
         "split_safe_all_nan_adjusted_structural_flag_matches_flag_off"
         >:: test_split_safe_all_nan_adjusted_structural_flag_matches_flag_off;
         (* floor_is_structural: flag agrees with level *)
         "floor_is_structural_wick_true" >:: test_floor_is_structural_wick_true;
         "floor_is_structural_close_mode_false"
         >:: test_floor_is_structural_close_mode_false;
         "floor_is_structural_close_level_uses_fallback"
         >:: test_floor_is_structural_close_level_uses_fallback;
         "floor_is_structural_split_safe_off_short_false"
         >:: test_floor_is_structural_split_safe_off_short_false;
         "floor_is_structural_split_safe_on_short_true"
         >:: test_floor_is_structural_split_safe_on_short_true;
         (* config field: split_safe default / round-trip / back-compat *)
         "config_default_split_safe_is_false"
         >:: test_config_default_split_safe_is_false;
         "config_split_safe_sexp_roundtrips"
         >:: test_config_split_safe_sexp_roundtrips;
         "config_sexp_omits_split_safe_defaults_false"
         >:: test_config_sexp_omits_split_safe_defaults_false;
       ]

let () = run_test_tt_main suite
