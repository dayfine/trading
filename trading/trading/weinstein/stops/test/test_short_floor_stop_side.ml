(** Regression guard for issue #3039: a short entry whose initial stop comes
    from the structural-floor path must install its stop {b above} the entry.

    {b The report.} Committed artefacts under
    [dev/warmup-fix-runs/after-fix1-stop-log/] show short entries with
    [stop_floor_kind Support_floor] whose [installed_stop] sits below
    [suggested_entry] (e.g. ABBV-wein-206: entry 93.44, installed 81.04). Those
    artefacts were produced by code_version [ea2eb3a] (2026-05), before the G14
    price-basis fix: the same run's [trades.csv] fills that ABBV short at 74.65
    — [74.65 /. 93.44 = 0.799], a dividend-adjustment factor — so the installed
    stop 81.04 was above the adjusted-basis {i fill} and only "below entry"
    against the raw-basis [suggested_entry]. The mismatch was between price
    bases, not in the short-side floor geometry.

    {b What this file pins, on current main.} The module exercised is
    {!Weinstein_stops.Floor_stop} (re-exported through {!Weinstein_stops}):
    [compute_initial_stop_with_floor_with_callbacks] →
    [Support_floor.find_recent_level_with_callbacks ~side:Short] (the
    counter-rally {i high} after the window's trough) → [compute_initial_stop]
    (reference +4%). On an ABBV-shaped rally-then-breakdown tape the installed
    short stop is above the entry under every anchor mode × scope combination;
    the [Buffer_fallback] short and the [Support_floor] long are pinned
    unchanged alongside it, so a one-sided "fix" cannot slip through. *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
open Weinstein_stops
module Support_floor = Weinstein_stops.Support_floor

let config = default_config
let as_of = "2020-04-03"

(* Shipped [initial_stop_buffer] (strategy layer default, mirrored — the stops
   library sits below the strategy layer). *)
let fallback_buffer = 1.0

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

(* ABBV-wein-206 shape (2020 H1): slide from ~100 into a March crash trough at
   62, a counter-rally to 96.5, then the Stage-4 breakdown bar on [as_of]. The
   short is entered at 93.44 — the audit's [suggested_entry] — just under the
   breakdown bar's close.

   Wick scan (window extreme): anchor = min low 62.0 (03-23); rally high after
   it = 96.5 (03-31); depth (96.5 - 62) / 62 = 55.6% >= 8% -> reference 96.5.
   Close scan: anchor = min close 64.0; rally close after it = 95.0. *)
let short_entry = 93.44

let short_tape =
  [
    make_bar ~date:"2020-03-02" ~high:101.0 ~low:97.0 ~close:99.0;
    make_bar ~date:"2020-03-09" ~high:92.0 ~low:84.0 ~close:86.0;
    make_bar ~date:"2020-03-23" ~high:70.0 ~low:62.0 ~close:64.0;
    make_bar ~date:"2020-03-26" ~high:86.0 ~low:74.0 ~close:84.0;
    make_bar ~date:"2020-03-31" ~high:96.5 ~low:89.0 ~close:95.0;
    make_bar ~date:as_of ~high:95.2 ~low:93.1 ~close:93.6;
  ]

let callbacks_of bars =
  callbacks_from_bars ~config ~bars ~as_of:(Date.of_string as_of)

let stop_level_with ~config ~side ~entry_price ~bars =
  get_stop_level
    (compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
       ~callbacks:(callbacks_of bars) ~fallback_buffer)

(* The level [compute_initial_stop] places off a known reference — the expected
   value is rebuilt through the same primitive so the pin is about WHICH
   reference the floor path picked, not about the haircut arithmetic. *)
let stop_from_reference ~side reference_level =
  get_stop_level (compute_initial_stop ~config ~side ~reference_level)

(* The reported defect, reproduced as a test: on current main the short's
   structural stop is the rally high 96.5 plus the 4% haircut — above the
   93.44 entry, and flagged as a structural (Support_floor) placement. *)
let test_short_support_floor_stop_above_entry _ =
  assert_that
    ( floor_is_structural_with_callbacks ~config ~side:Short
        ~callbacks:(callbacks_of short_tape),
      stop_level_with ~config ~side:Short ~entry_price:short_entry
        ~bars:short_tape )
    (all_of
       [
         field fst (equal_to true);
         field snd (float_equal (stop_from_reference ~side:Short 96.5));
         field snd (gt (module Float_ord) short_entry);
       ])

(* Every anchor mode x scope arm the config can select lands the short stop on
   the correct side. Wick arms anchor on the rally HIGH (96.5); Close arms on
   the rally CLOSE (95.0) — both above the entry, never the trough low. *)
let test_short_support_floor_above_entry_every_anchor_arm _ =
  let arm mode scope =
    let config =
      {
        config with
        support_floor_anchor_mode = mode;
        support_floor_anchor_scope = scope;
      }
    in
    stop_level_with ~config ~side:Short ~entry_price:short_entry
      ~bars:short_tape
  in
  let above_entry reference =
    all_of
      [
        float_equal (stop_from_reference ~side:Short reference);
        gt (module Float_ord) short_entry;
      ]
  in
  assert_that
    [
      arm Support_floor.Wick Support_floor.Window_extreme;
      arm Support_floor.Wick Support_floor.Nearest;
      arm Support_floor.Close Support_floor.Window_extreme;
      arm Support_floor.Close Support_floor.Nearest;
    ]
    (elements_are
       [
         above_entry 96.5; above_entry 96.5; above_entry 95.0; above_entry 95.0;
       ])

(* Buffer_fallback short, unchanged: a monotonic decline has no counter-rally
   after its trough (the trough is today), so no floor qualifies and the stop is
   the fixed-buffer fallback entry * 1.04 = 97.1776. *)
let test_short_buffer_fallback_unchanged _ =
  let decline =
    [
      make_bar ~date:"2020-03-02" ~high:101.0 ~low:99.0 ~close:100.0;
      make_bar ~date:"2020-03-16" ~high:99.0 ~low:96.0 ~close:97.0;
      make_bar ~date:as_of ~high:96.0 ~low:93.0 ~close:93.6;
    ]
  in
  assert_that
    ( floor_is_structural_with_callbacks ~config ~side:Short
        ~callbacks:(callbacks_of decline),
      stop_level_with ~config ~side:Short ~entry_price:short_entry ~bars:decline
    )
    (all_of
       [
         field fst (equal_to false);
         field snd (float_equal (short_entry *. 1.04));
         field snd (gt (module Float_ord) short_entry);
       ])

(* Support_floor long, unchanged: the mirror tape (peak 110, pullback low 98,
   recovery to a 104 entry) anchors on the correction LOW and installs the stop
   below the entry. *)
let test_long_support_floor_unchanged _ =
  let long_entry = 104.0 in
  let rally =
    [
      make_bar ~date:"2020-03-02" ~high:102.0 ~low:100.0 ~close:101.0;
      make_bar ~date:"2020-03-09" ~high:110.0 ~low:108.0 ~close:109.0;
      make_bar ~date:"2020-03-23" ~high:101.0 ~low:98.0 ~close:100.0;
      make_bar ~date:as_of ~high:105.0 ~low:100.0 ~close:104.0;
    ]
  in
  assert_that
    ( floor_is_structural_with_callbacks ~config ~side:Long
        ~callbacks:(callbacks_of rally),
      stop_level_with ~config ~side:Long ~entry_price:long_entry ~bars:rally )
    (all_of
       [
         field fst (equal_to true);
         field snd (float_equal (stop_from_reference ~side:Long 98.0));
         field snd (lt (module Float_ord) long_entry);
       ])

let suite =
  "short_floor_stop_side"
  >::: [
         "short Support_floor stop above entry (#3039)"
         >:: test_short_support_floor_stop_above_entry;
         "short Support_floor above entry on every anchor arm"
         >:: test_short_support_floor_above_entry_every_anchor_arm;
         "short Buffer_fallback unchanged"
         >:: test_short_buffer_fallback_unchanged;
         "long Support_floor unchanged" >:: test_long_support_floor_unchanged;
       ]

let () = run_test_tt_main suite
