(** Unit tests for {!Stale_entry_cap} (H2′, #3594): [E′ = min(E, T)], applied
    only to a long's base-level anchors, and the identity when the cap is off.
*)

open OUnit2
open Core
open Matchers

let _ticket ?(range_top = None) ?(breakout_price = None) cap_top =
  Stale_entry_cap.ticket_anchor ~range_top ~cap_top ~breakout_price

(** Cap off: the replace anchor passes through untouched, armed or not —
    bit-identical to the pre-cap analysis. *)
let test_off_passes_replace_anchor_through _ =
  assert_that
    [
      _ticket ~breakout_price:(Some 120.0) None;
      _ticket ~range_top:(Some 90.0) ~breakout_price:(Some 120.0) None;
    ]
    (elements_are [ is_none; is_some_and (float_equal 90.0) ])

(** E above T: a graded top of [120] over a current range topping at [100] is
    capped to [100]. *)
let test_graded_top_above_range_is_capped _ =
  assert_that
    (_ticket ~breakout_price:(Some 120.0) (Some 100.0))
    (is_some_and (float_equal 100.0))

(** E at or below T: no ticket anchor, so the screener keeps the graded top. *)
let test_graded_top_at_or_below_range_is_unchanged _ =
  assert_that
    [
      _ticket ~breakout_price:(Some 100.0) (Some 100.0);
      _ticket ~breakout_price:(Some 90.0) (Some 100.0);
    ]
    (elements_are [ is_none; is_none ])

(** No breakout price (the MA-fallback arm): the cap never applies. *)
let test_no_breakout_price_is_never_capped _ =
  assert_that (_ticket (Some 100.0)) is_none

(** Replace anchor armed: the ticket is [min(range_top, T)] — lowered when the
    replace anchor sits above [T], unchanged when at or below it. *)
let test_replace_anchor_is_capped_from_above_only _ =
  assert_that
    [
      _ticket ~range_top:(Some 110.0) (Some 100.0);
      _ticket ~range_top:(Some 90.0) (Some 100.0);
    ]
    (elements_are
       [ is_some_and (float_equal 100.0); is_some_and (float_equal 90.0) ])

(** [anchors] reads both windows from the same walk: the replace anchor over its
    own window, and the ticket capped by the shorter cap window. Highs by offset
    (0 = newest): [101; 102; 150; 103; 104]. *)
let test_anchors_scan_both_windows _ =
  let highs = [| 101.0; 102.0; 150.0; 103.0; 104.0 |] in
  let get_high ~week_offset =
    if week_offset < Array.length highs then Some highs.(week_offset) else None
  in
  let get_split_factor ~week_offset:_ = None in
  assert_that
    (Stale_entry_cap.anchors ~get_high ~get_split_factor ~replace_weeks:5
       ~cap_weeks:2 ~breakout_price:(Some 200.0))
    (pair (is_some_and (float_equal 150.0)) (is_some_and (float_equal 102.0)))

(** Both weeks at [0]: no scan, no anchor — the default analysis. *)
let test_anchors_off_scans_nothing _ =
  let get_high ~week_offset:_ = Some 100.0 in
  let get_split_factor ~week_offset:_ = None in
  assert_that
    (Stale_entry_cap.anchors ~get_high ~get_split_factor ~replace_weeks:0
       ~cap_weeks:0 ~breakout_price:(Some 200.0))
    (pair is_none is_none)

let suite =
  "stale_entry_cap"
  >::: [
         "off passes the replace anchor through"
         >:: test_off_passes_replace_anchor_through;
         "graded top above the range is capped"
         >:: test_graded_top_above_range_is_capped;
         "graded top at or below the range is unchanged"
         >:: test_graded_top_at_or_below_range_is_unchanged;
         "no breakout price is never capped"
         >:: test_no_breakout_price_is_never_capped;
         "replace anchor is capped from above only"
         >:: test_replace_anchor_is_capped_from_above_only;
         "anchors scan both windows" >:: test_anchors_scan_both_windows;
         "anchors off scans nothing" >:: test_anchors_off_scans_nothing;
       ]

let () = run_test_tt_main suite
