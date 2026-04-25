(** Parity tests for {!Weinstein_stops.compute_initial_stop_with_floor} and its
    indicator-callback shape {!compute_initial_stop_with_floor_with_callbacks}.

    Each test exercises both entry points over the same input and asserts the
    resulting [stop_state] is bit-identical via structural [equal_to]. The
    callback bundle is constructed externally via the public
    [Weinstein_stops.callbacks_from_bars] (the same path the bar-list wrapper
    uses internally), so any drift between the two would surface as an
    inequality. *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
open Weinstein_stops

(* ---- Test helpers ---- *)

let cfg = default_config
let fallback_buffer = 1.02

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

(* Call the bar-list path and the callback path on identical inputs and assert
   the resulting [stop_state] is bit-identical. *)
let assert_parity ~side ~entry_price ~bars ~as_of =
  let from_bars =
    compute_initial_stop_with_floor ~config:cfg ~side ~entry_price ~bars ~as_of
      ~fallback_buffer
  in
  let callbacks = callbacks_from_bars ~config:cfg ~bars ~as_of in
  let from_callbacks =
    compute_initial_stop_with_floor_with_callbacks ~config:cfg ~side
      ~entry_price ~callbacks ~fallback_buffer
  in
  assert_that from_callbacks (equal_to (from_bars : stop_state))

(* ---- Long: clear support floor present ---- *)

let test_long_with_support_floor _ =
  (* Clean peak (high=110) on 01-02 + correction low (low=98) on 01-04 →
     depth 10.9% > 8% → reference_level=98.0. Both entry points must agree
     on the resulting Initial state. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2024-01-02" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2024-01-03" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-04" ~high:103.0 ~low:98.0 ~close:102.0;
      make_bar ~date:"2024-01-05" ~high:109.0 ~low:105.0 ~close:108.0;
    ]
  in
  assert_parity ~side:Long ~entry_price:109.0 ~bars
    ~as_of:(Date.of_string "2024-01-05")

(* ---- Long: no qualifying floor → fallback path ---- *)

let test_long_no_floor_falls_back _ =
  (* Flat series — no qualifying pullback. Both paths must hit the
     fallback_buffer branch and produce the same Initial state. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-02" ~high:102.0 ~low:99.5 ~close:100.5;
      make_bar ~date:"2024-01-03" ~high:102.0 ~low:100.0 ~close:101.0;
    ]
  in
  assert_parity ~side:Long ~entry_price:100.0 ~bars
    ~as_of:(Date.of_string "2024-01-03")

(* ---- Short: clear resistance ceiling present ---- *)

let test_short_with_resistance_ceiling _ =
  (* Mirror of long-with-floor: trough (low=90) on 01-02 + rally high
     (high=102) on 01-04 → depth 13.3% > 8% → reference_level=102.0. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:92.0 ~low:90.0 ~close:91.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:98.0 ~close:99.0;
      make_bar ~date:"2024-01-04" ~high:102.0 ~low:97.0 ~close:98.0;
      make_bar ~date:"2024-01-05" ~high:99.0 ~low:95.0 ~close:96.0;
    ]
  in
  assert_parity ~side:Short ~entry_price:91.0 ~bars
    ~as_of:(Date.of_string "2024-01-05")

(* ---- Short: no qualifying rally → fallback path ---- *)

let test_short_no_ceiling_falls_back _ =
  (* Same flat series — short side falls back to entry_price /. fallback. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2024-01-02" ~high:102.0 ~low:99.5 ~close:100.5;
      make_bar ~date:"2024-01-03" ~high:102.0 ~low:100.0 ~close:101.0;
    ]
  in
  assert_parity ~side:Short ~entry_price:100.0 ~bars
    ~as_of:(Date.of_string "2024-01-03")

(* ---- Anchor at most-recent bar: no post-anchor counter-move ---- *)

let test_long_anchor_at_end_no_counter_move _ =
  (* Monotonically rising — peak is the last bar. _counter_extreme_in_range
     is empty, primitive returns None, both paths fall back. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:99.0 ~close:99.5;
      make_bar ~date:"2024-01-02" ~high:105.0 ~low:100.0 ~close:104.0;
      make_bar ~date:"2024-01-03" ~high:110.0 ~low:105.0 ~close:109.0;
    ]
  in
  assert_parity ~side:Long ~entry_price:109.0 ~bars
    ~as_of:(Date.of_string "2024-01-03")

(* ---- Equal-extreme tie-break: latest date wins ---- *)

let test_long_tie_break_latest_peak _ =
  (* Two equal highs (100.0) on 01-01 and 01-03. The bar-list path tie-breaks
     to the latest date (01-03) using [>=] in chronological order; the
     callback path takes the smallest tying [day_offset] (= newest date) using
     a strict [>]. Both must agree on the resulting [stop_state].

     Inputs derived from [test_support_floor.test_long_tie_breaks_to_latest_peak]:
     anchor on 01-03 → post-anchor low=94 on 01-04 → depth 6% < 8% → fallback.
     Both paths must therefore land on the same fallback Initial state. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:100.0 ~low:98.0 ~close:99.0;
      make_bar ~date:"2024-01-02" ~high:95.0 ~low:85.0 ~close:88.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:90.0 ~close:99.0;
      make_bar ~date:"2024-01-04" ~high:98.0 ~low:94.0 ~close:96.0;
    ]
  in
  assert_parity ~side:Long ~entry_price:99.0 ~bars
    ~as_of:(Date.of_string "2024-01-04")

let test_short_tie_break_latest_trough _ =
  (* Mirror tie-break for short side: two equal lows (90.0) on 01-01 and 01-03;
     latest-trough rule anchors on 01-03; post-anchor high=95 on 01-04 → depth
     5.6% < 8% → fallback in both paths. *)
  let bars =
    [
      make_bar ~date:"2024-01-01" ~high:92.0 ~low:90.0 ~close:91.0;
      make_bar ~date:"2024-01-02" ~high:105.0 ~low:95.0 ~close:100.0;
      make_bar ~date:"2024-01-03" ~high:100.0 ~low:90.0 ~close:92.0;
      make_bar ~date:"2024-01-04" ~high:95.0 ~low:92.0 ~close:94.0;
    ]
  in
  assert_parity ~side:Short ~entry_price:92.0 ~bars
    ~as_of:(Date.of_string "2024-01-04")

(* ---- Lookback truncation (config-driven window cap) ---- *)

let test_long_lookback_truncates_old_correction _ =
  (* The 01-02 correction (peak=200/low=160) is outside the
     [config.support_floor_lookback_bars] window when the override is small.
     With [lookback_bars=3], only the recent quiet zone is in view; both paths
     should fall back identically.

     This exercises the [callbacks_from_bars] truncation path: the bundle
     materialises only the trailing 3 days, and the callback algorithm has no
     way of seeing the older correction. *)
  let cfg_short_lookback = { cfg with support_floor_lookback_bars = 3 } in
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
  let from_bars =
    compute_initial_stop_with_floor ~config:cfg_short_lookback ~side:Long
      ~entry_price:172.0 ~bars
      ~as_of:(Date.of_string "2024-01-06")
      ~fallback_buffer
  in
  let callbacks =
    callbacks_from_bars ~config:cfg_short_lookback ~bars
      ~as_of:(Date.of_string "2024-01-06")
  in
  let from_callbacks =
    compute_initial_stop_with_floor_with_callbacks ~config:cfg_short_lookback
      ~side:Long ~entry_price:172.0 ~callbacks ~fallback_buffer
  in
  assert_that from_callbacks (equal_to (from_bars : stop_state))

(* ---- Empty bar history ---- *)

let test_long_empty_bars _ =
  (* No bars at all — primitive returns None, fallback path is exercised on
     both sides of the parity. *)
  assert_parity ~side:Long ~entry_price:100.0 ~bars:[]
    ~as_of:(Date.of_string "2024-01-05")

let test_short_empty_bars _ =
  assert_parity ~side:Short ~entry_price:100.0 ~bars:[]
    ~as_of:(Date.of_string "2024-01-05")

let suite =
  "weinstein_stops_callbacks_parity"
  >::: [
         "long_with_support_floor" >:: test_long_with_support_floor;
         "long_no_floor_falls_back" >:: test_long_no_floor_falls_back;
         "short_with_resistance_ceiling" >:: test_short_with_resistance_ceiling;
         "short_no_ceiling_falls_back" >:: test_short_no_ceiling_falls_back;
         "long_anchor_at_end_no_counter_move"
         >:: test_long_anchor_at_end_no_counter_move;
         "long_tie_break_latest_peak" >:: test_long_tie_break_latest_peak;
         "short_tie_break_latest_trough" >:: test_short_tie_break_latest_trough;
         "long_lookback_truncates_old_correction"
         >:: test_long_lookback_truncates_old_correction;
         "long_empty_bars" >:: test_long_empty_bars;
         "short_empty_bars" >:: test_short_empty_bars;
       ]

let () = run_test_tt_main suite
