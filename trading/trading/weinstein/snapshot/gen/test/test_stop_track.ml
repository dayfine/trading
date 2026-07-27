(** Tests for {!Stop_track} — the persisted trailing-stop state of one holding.

    The through-line is the never-lower rule (weinstein-book-reference.md §5.2 /
    §5.4): {!Stop_track.ratchet} is the single place it is enforced, so every
    test here is about what it will and will not do to a stop level. *)

open Core
open OUnit2
open Matchers
module Stop_track = Weinstein_snapshot_gen.Stop_track

let _date d = Date.of_string d
let _updated = _date "2026-07-24"

let _initial ~level : Stop_track.t =
  {
    state = Initial { stop_level = level; reference_level = level +. 5.0 };
    updated = _updated;
    raises = 0;
  }

(* A Trailing track carries five fields besides the stop level; the ratchet must
   preserve every one of them. *)
let _trailing ~level : Stop_track.t =
  {
    state =
      Trailing
        {
          stop_level = level;
          last_correction_extreme = 175.0;
          last_trend_extreme = 195.0;
          ma_at_last_adjustment = 170.0;
          correction_count = 2;
          correction_observed_since_reset = true;
        };
    updated = _updated;
    raises = 3;
  }

let _tightened ~level : Stop_track.t =
  {
    state =
      Tightened
        {
          stop_level = level;
          last_correction_extreme = 180.0;
          reason = "flat MA";
        };
    updated = _updated;
    raises = 1;
  }

let test_level_reads_each_state_arm _ =
  assert_that
    (List.map
       [
         _initial ~level:100.0; _trailing ~level:110.0; _tightened ~level:120.0;
       ]
       ~f:Stop_track.level)
    (elements_are [ float_equal 100.0; float_equal 110.0; float_equal 120.0 ])

let test_state_name_covers_each_arm _ =
  assert_that
    (List.map
       [ _initial ~level:1.0; _trailing ~level:1.0; _tightened ~level:1.0 ]
       ~f:(fun t -> Stop_track.state_name t.Stop_track.state))
    (elements_are
       [ equal_to "Initial"; equal_to "Trailing"; equal_to "Tightened" ])

(* The report needs the ratchet history, not just the level. *)
let test_label_carries_state_raises_and_date _ =
  assert_that
    (Stop_track.label (_trailing ~level:172.5))
    (equal_to "Trailing (3 raises, through 2026-07-24)")

(* --- the never-lower rule ------------------------------------------------ *)

let test_ratchet_raises_the_level _ =
  assert_that
    (Stop_track.ratchet (_initial ~level:168.0) ~to_:175.0)
    (is_some_and (field Stop_track.level (float_equal 175.0)))

(* A lower target is refused outright — this is the invariant the whole item
   exists to enforce. *)
let test_ratchet_refuses_a_lower_level _ =
  assert_that (Stop_track.ratchet (_initial ~level:168.0) ~to_:160.0) is_none

(* Equality is idempotent, not an error: re-applying the stop in force is a
   no-op a caller should be able to repeat. *)
let test_ratchet_accepts_the_same_level _ =
  assert_that
    (Stop_track.ratchet (_initial ~level:168.0) ~to_:168.0)
    (is_some_and (equal_to (_initial ~level:168.0)))

(* Raising a Trailing track keeps its arm and all of its correction
   bookkeeping — a raise moves the stop, it does not restart the machine. *)
let test_ratchet_preserves_trailing_bookkeeping _ =
  assert_that
    (Stop_track.ratchet (_trailing ~level:168.0) ~to_:175.0)
    (is_some_and (equal_to (_trailing ~level:175.0)))

let test_ratchet_preserves_tightened_bookkeeping _ =
  assert_that
    (Stop_track.ratchet (_tightened ~level:168.0) ~to_:175.0)
    (is_some_and (equal_to (_tightened ~level:175.0)))

let test_ratchet_preserves_initial_reference_level _ =
  assert_that
    (Stop_track.ratchet (_initial ~level:168.0) ~to_:175.0)
    (is_some_and
       (field
          (fun (t : Stop_track.t) ->
            match t.state with
            | Initial { reference_level; _ } -> reference_level
            | Trailing _ | Tightened _ -> Float.nan)
          (float_equal 173.0)))

(* A raise is a stop movement, not a correction cycle: it must not inflate the
   ratchet history the report describes. *)
let test_ratchet_does_not_bump_raises _ =
  assert_that
    (Stop_track.ratchet (_trailing ~level:168.0) ~to_:175.0)
    (is_some_and (field (fun (t : Stop_track.t) -> t.raises) (equal_to 3)))

let suite =
  "stop_track"
  >::: [
         "level_reads_each_state_arm" >:: test_level_reads_each_state_arm;
         "state_name_covers_each_arm" >:: test_state_name_covers_each_arm;
         "label_carries_state_raises_and_date"
         >:: test_label_carries_state_raises_and_date;
         "ratchet_raises_the_level" >:: test_ratchet_raises_the_level;
         "ratchet_refuses_a_lower_level" >:: test_ratchet_refuses_a_lower_level;
         "ratchet_accepts_the_same_level"
         >:: test_ratchet_accepts_the_same_level;
         "ratchet_preserves_trailing_bookkeeping"
         >:: test_ratchet_preserves_trailing_bookkeeping;
         "ratchet_preserves_tightened_bookkeeping"
         >:: test_ratchet_preserves_tightened_bookkeeping;
         "ratchet_preserves_initial_reference_level"
         >:: test_ratchet_preserves_initial_reference_level;
         "ratchet_does_not_bump_raises" >:: test_ratchet_does_not_bump_raises;
       ]

let () = run_test_tt_main suite
