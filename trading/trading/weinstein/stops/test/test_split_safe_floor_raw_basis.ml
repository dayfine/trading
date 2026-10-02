(** Regression guard for issue #3043: under [split_safe_floors = true] the
    support-floor scan reads split/dividend-ADJUSTED prices while the entry is a
    RAW price. The found level must be restated on the raw basis — relative to
    the as-of bar, [level_raw = level_adj /. f(as_of)] — before
    [compute_initial_stop] combines it with the entry.

    {b The defect.} On #3042's ABBV-shaped short tape with a constant 0.8
    adjustment factor, the adjusted rally high is [96.5 *. 0.8 = 77.2], and the
    short stop landed at [77.2 *. 1.04 = 80.29] against a 93.44 entry — the
    wrong side for a short. Longs carried the same mismatch, hidden: an adjusted
    floor sits further below a raw entry and still reads as "below entry".

    {b What this file pins.} With a non-unit factor and the flag on: the short
    [Support_floor] stop is above the entry and equals the raw-basis stop; the
    long stop is below the entry and equals the raw-basis floor's stop (also
    across a split whose as-of factor is not 1); and with the flag off the
    adjusted closes are ignored and the stop is exactly today's raw answer. *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
open Weinstein_stops

let as_of = "2020-04-03"
let fallback_buffer = 1.0
let flag_on = { default_config with split_safe_floors = true }
let flag_off = { default_config with split_safe_floors = false }

(* A bar whose adjusted close is [factor *. close] — i.e. per-bar factor
   [f = adjusted_close /. close_price = factor]. *)
let make_bar ?(factor = 0.8) ~date ~high ~low ~close () =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close *. factor;
    volume = 1_000_000;
    active_through = None;
  }

(* #3042's ABBV-wein-206 tape (raw prices unchanged), every bar at factor 0.8.
   Raw wick scan: trough low 62.0, counter-rally high 96.5 -> reference 96.5. *)
let short_entry = 93.44

let short_tape =
  [
    make_bar ~date:"2020-03-02" ~high:101.0 ~low:97.0 ~close:99.0 ();
    make_bar ~date:"2020-03-09" ~high:92.0 ~low:84.0 ~close:86.0 ();
    make_bar ~date:"2020-03-23" ~high:70.0 ~low:62.0 ~close:64.0 ();
    make_bar ~date:"2020-03-26" ~high:86.0 ~low:74.0 ~close:84.0 ();
    make_bar ~date:"2020-03-31" ~high:96.5 ~low:89.0 ~close:95.0 ();
    make_bar ~date:as_of ~high:95.2 ~low:93.1 ~close:93.6 ();
  ]

(* Mirror long tape at factor 0.8: peak 110, pullback low 98, entry 104. *)
let long_entry = 104.0

let long_tape =
  [
    make_bar ~date:"2020-03-02" ~high:102.0 ~low:100.0 ~close:101.0 ();
    make_bar ~date:"2020-03-09" ~high:110.0 ~low:108.0 ~close:109.0 ();
    make_bar ~date:"2020-03-23" ~high:101.0 ~low:98.0 ~close:100.0 ();
    make_bar ~date:as_of ~high:105.0 ~low:100.0 ~close:104.0 ();
  ]

let callbacks_of bars =
  callbacks_from_bars ~config:flag_on ~bars ~as_of:(Date.of_string as_of)

let stop_with ~config ~side ~entry_price bars =
  get_stop_level
    (compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
       ~callbacks:(callbacks_of bars) ~fallback_buffer)

(* The stop [compute_initial_stop] installs off a raw-basis reference — rebuilt
   through the same primitive so the pin is about WHICH reference (and on which
   basis) the floor path fed it, not about the haircut arithmetic. *)
let stop_from_reference ~side reference_level =
  get_stop_level
    (compute_initial_stop ~config:default_config ~side ~reference_level)

(* The reported defect: flag on, constant 0.8 factor. The scan ran on the
   adjusted basis (telemetry [Adjusted], structural) and the stop is the
   RAW-basis rally high 96.5 + 4% — above the 93.44 entry, not 80.29. *)
let test_short_support_floor_above_entry_split_safe _ =
  let callbacks = callbacks_of short_tape in
  assert_that
    ( split_safe_basis_of_callbacks ~config:flag_on ~callbacks,
      floor_is_structural_with_callbacks ~config:flag_on ~side:Short ~callbacks,
      stop_with ~config:flag_on ~side:Short ~entry_price:short_entry short_tape
    )
    (all_of
       [
         field (fun (b, _, _) -> b) (equal_to Adjusted);
         field (fun (_, s, _) -> s) (equal_to true);
         field
           (fun (_, _, l) -> l)
           (float_equal (stop_from_reference ~side:Short 96.5));
         field (fun (_, _, l) -> l) (gt (module Float_ord) short_entry);
       ])

(* Long side, flag on, constant 0.8 factor: the adjusted low 78.4 is restated
   as the raw floor 98.0, so the stop is the raw-floor stop, below the entry. *)
let test_long_support_floor_raw_basis_split_safe _ =
  let callbacks = callbacks_of long_tape in
  assert_that
    ( split_safe_basis_of_callbacks ~config:flag_on ~callbacks,
      stop_with ~config:flag_on ~side:Long ~entry_price:long_entry long_tape )
    (all_of
       [
         field fst (equal_to Adjusted);
         field snd (float_equal (stop_from_reference ~side:Long 98.0));
         field snd (lt (module Float_ord) long_entry);
       ])

(* A 2:1 split inside the window AND a non-unit as-of factor: pre-split bars
   trade at 2x (factor 0.4), post-split bars at factor 0.8. Adjusted: peak
   [220 *. 0.4 = 88.0], low [98 *. 0.8 = 78.4] (depth 10.9% >= 8%). Restated
   relative to the as-of bar: [78.4 /. 0.8 = 98.0] — the raw floor in today's
   share units, not the adjusted 78.4. *)
let test_long_split_in_window_restated_to_as_of _ =
  let bars =
    [
      make_bar ~factor:0.4 ~date:"2020-03-02" ~high:204.0 ~low:200.0
        ~close:202.0 ();
      make_bar ~factor:0.4 ~date:"2020-03-09" ~high:220.0 ~low:216.0
        ~close:218.0 ();
      make_bar ~date:"2020-03-23" ~high:101.0 ~low:98.0 ~close:100.0 ();
      make_bar ~date:as_of ~high:105.0 ~low:100.0 ~close:104.0 ();
    ]
  in
  assert_that
    (stop_with ~config:flag_on ~side:Long ~entry_price:long_entry bars)
    (all_of
       [
         float_equal (stop_from_reference ~side:Long 98.0);
         lt (module Float_ord) long_entry;
       ])

(* Flag off: the adjusted closes are never read, so the stops are exactly
   (bit-for-bit, [equal_to] on floats) the raw-reference stops — today's
   default-path answer. *)
let test_flag_off_bit_identical _ =
  assert_that
    ( split_safe_basis_of_callbacks ~config:flag_off
        ~callbacks:(callbacks_of short_tape),
      stop_with ~config:flag_off ~side:Short ~entry_price:short_entry short_tape,
      stop_with ~config:flag_off ~side:Long ~entry_price:long_entry long_tape )
    (all_of
       [
         field (fun (b, _, _) -> b) (equal_to Flag_off);
         field
           (fun (_, s, _) -> s)
           (equal_to (stop_from_reference ~side:Short 96.5));
         field
           (fun (_, _, l) -> l)
           (equal_to (stop_from_reference ~side:Long 98.0));
       ])

let suite =
  "split_safe_floor_raw_basis"
  >::: [
         "split-safe short Support_floor stop above entry (#3043)"
         >:: test_short_support_floor_above_entry_split_safe;
         "split-safe long Support_floor stop on raw basis"
         >:: test_long_support_floor_raw_basis_split_safe;
         "split-safe long split in window restated to as-of"
         >:: test_long_split_in_window_restated_to_as_of;
         "split_safe_floors off bit-identical" >:: test_flag_off_bit_identical;
       ]

let () = run_test_tt_main suite
