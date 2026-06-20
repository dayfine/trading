(** Tests for [Vol_scaled_stop.effective_min_stop_distance_pct].

    Covers the default-off no-op (mult = 0.0 returns the base floor unchanged),
    the active high-volatility widen (a large ATR pushes the floor above the
    fixed base), the active low-volatility keep-floor case (a small ATR leaves
    the base floor in place via [Float.max]), and the degenerate fallbacks
    (insufficient bars, non-positive entry price) which never narrow below the
    base. *)

open OUnit2
open Core
open Matchers
module Vol_scaled_stop = Weinstein_stops.Vol_scaled_stop

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

(* A low-volatility series: each bar spans ~$1 (ATR ≈ 1.0 on a ~$100 name →
   atr_pct ≈ 0.01). *)
let low_vol_bars =
  List.init 20 ~f:(fun i ->
      let day = i + 1 in
      let date = Printf.sprintf "2024-02-%02d" day in
      let mid = 100.0 +. Float.of_int i in
      make_bar ~date ~high:(mid +. 0.5) ~low:(mid -. 0.5) ~close:mid)

(* A high-volatility series: each bar spans ~$15 on a ~$100 name → atr_pct ≈
   0.15, well above the 8% base floor. *)
let high_vol_bars =
  List.init 20 ~f:(fun i ->
      let day = i + 1 in
      let date = Printf.sprintf "2024-02-%02d" day in
      let mid = 100.0 +. Float.of_int i in
      make_bar ~date ~high:(mid +. 7.5) ~low:(mid -. 7.5) ~close:mid)

let config_with_mult mult =
  { Weinstein_stops.default_config with vol_scaled_stop_atr_mult = mult }

let base = 0.08

(* ---- Default-off no-op ---- *)

let test_default_off_returns_base _ =
  (* mult = 0.0 → exact passthrough of the base floor, even on a wildly volatile
     name. Guarantees bit-identical golden replay. *)
  assert_that
    (Vol_scaled_stop.effective_min_stop_distance_pct
       ~config:(config_with_mult 0.0) ~base_min_distance_pct:base
       ~entry_price:119.0 ~bars:high_vol_bars)
    (float_equal base)

(* ---- Active knob, high-volatility name widens the floor ---- *)

let test_high_vol_widens_floor _ =
  (* mult = 1.0, atr_pct ≈ 0.15 (> base 0.08) → floor widens to ≈ 0.15. The last
     close is 119.0; ATR over 15-wide bars is 15.0 → atr_pct = 15/119 ≈ 0.126. *)
  let result =
    Vol_scaled_stop.effective_min_stop_distance_pct
      ~config:(config_with_mult 1.0) ~base_min_distance_pct:base
      ~entry_price:119.0 ~bars:high_vol_bars
  in
  assert_that result
    (all_of
       [ gt (module Float_ord) base; float_equal ~epsilon:1e-9 (15.0 /. 119.0) ])

let test_high_vol_mult_scales _ =
  (* mult = 2.0 doubles the ATR contribution → ≈ 2 * 15/119. *)
  assert_that
    (Vol_scaled_stop.effective_min_stop_distance_pct
       ~config:(config_with_mult 2.0) ~base_min_distance_pct:base
       ~entry_price:119.0 ~bars:high_vol_bars)
    (float_equal ~epsilon:1e-9 (2.0 *. 15.0 /. 119.0))

(* ---- Active knob, low-volatility name keeps the base floor ---- *)

let test_low_vol_keeps_base_floor _ =
  (* mult = 1.0, atr_pct ≈ 1/119 ≈ 0.0084 (< base 0.08) → Float.max keeps base.
     The mechanism only ever widens; it never narrows below the fixed floor. *)
  assert_that
    (Vol_scaled_stop.effective_min_stop_distance_pct
       ~config:(config_with_mult 1.0) ~base_min_distance_pct:base
       ~entry_price:119.0 ~bars:low_vol_bars)
    (float_equal base)

(* ---- Degenerate fallbacks never narrow below base ---- *)

let test_insufficient_bars_falls_back_to_base _ =
  (* Fewer than period + 1 bars → Atr.atr returns None → base floor. *)
  assert_that
    (Vol_scaled_stop.effective_min_stop_distance_pct
       ~config:(config_with_mult 1.0) ~base_min_distance_pct:base
       ~entry_price:119.0
       ~bars:[ make_bar ~date:"2024-02-01" ~high:110.0 ~low:90.0 ~close:100.0 ])
    (float_equal base)

let test_non_positive_entry_falls_back_to_base _ =
  assert_that
    (Vol_scaled_stop.effective_min_stop_distance_pct
       ~config:(config_with_mult 1.0) ~base_min_distance_pct:base
       ~entry_price:0.0 ~bars:high_vol_bars)
    (float_equal base)

let suite =
  "Vol_scaled_stop"
  >::: [
         "default off (mult = 0.0) returns base unchanged"
         >:: test_default_off_returns_base;
         "high-vol name widens the floor above base"
         >:: test_high_vol_widens_floor;
         "mult scales the ATR contribution" >:: test_high_vol_mult_scales;
         "low-vol name keeps the base floor (max never narrows)"
         >:: test_low_vol_keeps_base_floor;
         "insufficient bars falls back to base"
         >:: test_insufficient_bars_falls_back_to_base;
         "non-positive entry price falls back to base"
         >:: test_non_positive_entry_falls_back_to_base;
       ]

let () = run_test_tt_main suite
