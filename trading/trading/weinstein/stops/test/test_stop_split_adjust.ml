(** Tests for [Stop_split_adjust.scale].

    Pin the contract that every absolute price field of a {!stop_state} divides
    by the split [factor], for each of the three state variants (Initial /
    Trailing / Tightened) and across both forward (factor > 1) and reverse
    (factor < 1) splits. Non-price fields ([correction_count], [reason]) pass
    through unchanged. *)

open OUnit2
open Matchers
open Weinstein_stops
module Stop_split_adjust = Weinstein_stops.Stop_split_adjust

(* ---- Initial state ---- *)

let test_initial_forward_4_to_1 _ =
  (* Pre-split entry at $440 stop / $448 reference. After a 4:1 forward
     split (factor 4.0) both fields divide by 4. *)
  let state = Initial { stop_level = 440.0; reference_level = 448.0 } in
  assert_that
    (Stop_split_adjust.scale ~factor:4.0 state)
    (equal_to (Initial { stop_level = 110.0; reference_level = 112.0 }))

let test_initial_reverse_1_to_5 _ =
  (* Reverse 1:5 split (factor 0.2) — share count multiplies by 0.2,
     prices multiply by 5. $20 stop becomes $100. *)
  let state = Initial { stop_level = 20.0; reference_level = 22.0 } in
  assert_that
    (Stop_split_adjust.scale ~factor:0.2 state)
    (equal_to (Initial { stop_level = 100.0; reference_level = 110.0 }))

(* ---- Trailing state ---- *)

let test_trailing_forward_4_to_1 _ =
  (* Every absolute price field divides by 4; non-price fields
     ([correction_count], [correction_observed_since_reset]) must NOT scale. *)
  let state =
    Trailing
      {
        stop_level = 440.0;
        last_correction_extreme = 460.0;
        last_trend_extreme = 520.0;
        ma_at_last_adjustment = 480.0;
        correction_count = 3;
        correction_observed_since_reset = true;
      }
  in
  assert_that
    (Stop_split_adjust.scale ~factor:4.0 state)
    (equal_to
       (Trailing
          {
            stop_level = 110.0;
            last_correction_extreme = 115.0;
            last_trend_extreme = 130.0;
            ma_at_last_adjustment = 120.0;
            correction_count = 3;
            correction_observed_since_reset = true;
          }))

(* ---- Tightened state ---- *)

let test_tightened_forward_4_to_1 _ =
  (* [reason] is a string and must pass through unchanged. *)
  let state =
    Tightened
      {
        stop_level = 440.0;
        last_correction_extreme = 460.0;
        reason = "Stage 3 detected";
      }
  in
  assert_that
    (Stop_split_adjust.scale ~factor:4.0 state)
    (equal_to
       (Tightened
          {
            stop_level = 110.0;
            last_correction_extreme = 115.0;
            reason = "Stage 3 detected";
          }))

(* ---- Identity case ---- *)

let test_factor_one_is_identity _ =
  (* factor=1.0 represents a degenerate "no split" — every price field
     stays where it was. Useful for callers that may pass a detected-but-
     trivial factor without an extra branch. *)
  let state =
    Trailing
      {
        stop_level = 100.0;
        last_correction_extreme = 110.0;
        last_trend_extreme = 130.0;
        ma_at_last_adjustment = 120.0;
        correction_count = 1;
        correction_observed_since_reset = false;
      }
  in
  assert_that (Stop_split_adjust.scale ~factor:1.0 state) (equal_to state)

(* ---- Validation ---- *)

let test_zero_factor_raises _ =
  let state = Initial { stop_level = 100.0; reference_level = 105.0 } in
  assert_raises
    (Invalid_argument
       "Stop_split_adjust.scale: factor must be > 0.0, got 0.000000") (fun () ->
      Stop_split_adjust.scale ~factor:0.0 state)

let test_negative_factor_raises _ =
  let state = Initial { stop_level = 100.0; reference_level = 105.0 } in
  assert_raises
    (Invalid_argument
       "Stop_split_adjust.scale: factor must be > 0.0, got -1.000000")
    (fun () -> Stop_split_adjust.scale ~factor:(-1.0) state)

(* ---- Suite ---- *)

let () =
  run_test_tt_main
    ("stop_split_adjust"
    >::: [
           "Initial state — forward 4:1 split divides every price by 4"
           >:: test_initial_forward_4_to_1;
           "Initial state — reverse 1:5 split (factor 0.2) divides by 0.2 (= \
            ×5)" >:: test_initial_reverse_1_to_5;
           "Trailing state — every price divides; correction_count unchanged"
           >:: test_trailing_forward_4_to_1;
           "Tightened state — every price divides; reason unchanged"
           >:: test_tightened_forward_4_to_1;
           "factor=1.0 is the identity transform"
           >:: test_factor_one_is_identity;
           "factor=0.0 raises Invalid_argument" >:: test_zero_factor_raises;
           "negative factor raises Invalid_argument"
           >:: test_negative_factor_raises;
         ])
