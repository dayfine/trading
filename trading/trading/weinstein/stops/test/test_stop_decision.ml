(** Issue #2977 — {!Weinstein_stops.Stop_decision} names the decision the
    trailing-stop state machine made on each update.

    Every tape below is driven through the real {!Weinstein_stops.update}; the
    record is built from the [(before, after, event, bar, ma)] that call
    returned, exactly as the strategy's stops runner does. So these tests pin
    the classifier against the state machine, not against a re-implementation
    of it. Long side, Stage 2 with a rising MA throughout, so tightening never
    fires and every step is a trailing-cycle decision. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers
module D = Stop_decision

let stage2 = Stage2 { weeks_advancing = 4; late = false }
let start = Date.of_string "2024-01-05"
let ma_value = 95.0

(* Only the long side's fields matter: the trigger and the correction extreme
   read [low_price], the recovery test reads [close_price]. *)
let bar ~day ~low ~close =
  Types.Daily_price.
    {
      date = Date.add_days start day;
      open_price = close;
      high_price = close;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

let initial ~stop = Initial { stop_level = stop; reference_level = stop }

(* Replay [(low, close)] bars from [state], returning one decision per update. *)
let decisions ?(config = default_config) ~state tape =
  List.foldi tape ~init:(state, []) ~f:(fun day (before, acc) (low, close) ->
      let bar = bar ~day ~low ~close in
      let after, event =
        update ~config ~side:Long ~state:before ~current_bar:bar ~ma_value
          ~ma_direction:Rising ~stage:stage2
      in
      let d =
        D.make ~config ~side:Long ~position_id:"AAA-wein-1"
          { D.before; after; event; bar; ma_value }
      in
      (after, d :: acc))
  |> snd |> List.rev

let reasons ds = List.map ds ~f:(fun (d : D.t) -> d.reason)

(* Seed at 99/100, run to a 115 close, pull back to a 104 low (-9.6% from the
   115 peak, >= the 8% [min_correction_pct]) without recovering, then close at
   120 — back through the 115 peak. The completed cycle's candidate is
   [min (99, ma 95) *. 0.99 = 94.05], nudged below the 94.0 round number to
   93.875. *)
let correction_then_recovery =
  [ (99.0, 100.0); (105.0, 115.0); (104.0, 106.0); (110.0, 120.0) ]

(* Creeps 100 -> 104 without ever pulling back: the depth from the running peak
   to the 99 seed low never reaches 8%. *)
let steady_advance =
  [ (99.0, 100.0); (100.0, 101.0); (101.0, 102.0); (102.0, 103.0); (103.0, 104.0) ]

let test_correction_and_recovery_raises_once _ =
  assert_that
    (reasons (decisions ~state:(initial ~stop:90.0) correction_then_recovery))
    (elements_are
       [
         equal_to D.Seeded_trailing;
         equal_to D.No_correction_yet;
         equal_to D.Correction_not_recovered;
         equal_to D.Raised;
       ])

let test_raised_record_carries_the_cycle_inputs _ =
  assert_that
    (List.last (decisions ~state:(initial ~stop:90.0) correction_then_recovery))
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.date) (equal_to (Date.add_days start 3));
            field (fun (d : D.t) -> d.position_id) (equal_to "AAA-wein-1");
            field (fun (d : D.t) -> d.state_before) (equal_to D.Trailing);
            field (fun (d : D.t) -> d.state_after) (equal_to D.Trailing);
            field (fun (d : D.t) -> d.stop_before) (float_equal 90.0);
            field (fun (d : D.t) -> d.stop_after) (float_equal 93.875);
            field (fun (d : D.t) -> d.correction_count) (equal_to 1);
            field
              (fun (d : D.t) -> d.last_trend_extreme)
              (is_some_and (float_equal 115.0));
            field
              (fun (d : D.t) -> d.last_correction_extreme)
              (is_some_and (float_equal 99.0));
            field (fun (d : D.t) -> d.ma_value) (float_equal ma_value);
          ]))

let test_steady_advance_holds_with_no_correction _ =
  assert_that
    (decisions ~state:(initial ~stop:90.0) steady_advance)
    (elements_are
       (field (fun (d : D.t) -> d.reason) (equal_to D.Seeded_trailing)
       :: List.init 4 ~f:(fun _ ->
              all_of
                [
                  field (fun (d : D.t) -> d.reason) (equal_to D.No_correction_yet);
                  field (fun (d : D.t) -> d.stop_after) (float_equal 90.0);
                ])))

(* Same tape, but the resting stop (97) already sits above the 93.875 candidate:
   the cycle completes and the never-lower rule keeps the stop. Pinned under
   both [reset_anchor_on_stalled_cycle] values — the bookkeeping differs, the
   decision tag does not. *)
let _stalled_tail ~reset =
  let config =
    { default_config with reset_anchor_on_stalled_cycle = reset }
  in
  List.last (decisions ~config ~state:(initial ~stop:97.0) correction_then_recovery)

let test_stalled_cycle_with_anchor_reset _ =
  assert_that (_stalled_tail ~reset:true)
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.reason) (equal_to D.Cycle_stalled);
            field (fun (d : D.t) -> d.stop_after) (float_equal 97.0);
            field (fun (d : D.t) -> d.correction_count) (equal_to 1);
          ]))

let test_stalled_cycle_with_frozen_anchor _ =
  assert_that (_stalled_tail ~reset:false)
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.reason) (equal_to D.Cycle_stalled);
            field (fun (d : D.t) -> d.stop_after) (float_equal 97.0);
            field (fun (d : D.t) -> d.correction_count) (equal_to 0);
          ]))

let test_is_hold_splits_holds_from_decisions _ =
  assert_that
    (List.map
       [
         D.No_correction_yet;
         D.Correction_not_recovered;
         D.Anchor_not_fresh;
         D.Tightened_hold;
         D.Raised;
         D.Cycle_stalled;
         D.Seeded_trailing;
         D.Stop_hit;
       ]
       ~f:D.is_hold)
    (equal_to [ true; true; true; true; false; false; false; false ])

let test_sexp_round_trip _ =
  let d : D.t =
    {
      D.date = Date.of_string "2024-03-15";
      position_id = "AAA-wein-1";
      state_before = D.Trailing;
      state_after = D.Trailing;
      stop_before = 90.0;
      stop_after = 93.875;
      correction_count = 1;
      last_trend_extreme = Some 115.0;
      last_correction_extreme = None;
      ma_value = 95.0;
      reason = D.Raised;
    }
  in
  assert_that (D.t_of_sexp (D.sexp_of_t d)) (equal_to d)

let suite =
  "Stop_decision"
  >::: [
         "correction + recovery raises once"
         >:: test_correction_and_recovery_raises_once;
         "raised record carries the cycle inputs"
         >:: test_raised_record_carries_the_cycle_inputs;
         "steady advance holds with no correction"
         >:: test_steady_advance_holds_with_no_correction;
         "stalled cycle with anchor reset"
         >:: test_stalled_cycle_with_anchor_reset;
         "stalled cycle with frozen anchor"
         >:: test_stalled_cycle_with_frozen_anchor;
         "is_hold splits holds from decisions"
         >:: test_is_hold_splits_holds_from_decisions;
         "sexp round trip" >:: test_sexp_round_trip;
       ]

let () = run_test_tt_main suite
