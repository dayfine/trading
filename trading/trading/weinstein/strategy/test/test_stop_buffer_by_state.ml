(** {!Weinstein_strategy.Stop_buffer_by_state} — the per-macro-state fallback
    initial-stop width map.

    Plan: [dev/plans/stop-width-by-macro-state-2026-09-06.md]. The walk-level
    integration (a real entry's installed stop moving with the state) is pinned
    separately in [test_stop_width_by_macro_state.ml]; this file pins the
    resolver, the R1 no-op default, the sexp shape the [Overlay_validator]
    override path depends on, and the documented breadth-direction interaction.
*)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* The scalar [config.initial_stop_buffer] a caller passes as [~fallback]. 1.0
   is the shipped default: the reference sits at the entry price, so the stop
   lands [min_correction_pct /. 2] = 4% away (book §5.3's band floor). *)
let _scalar = 1.0

(* The first candidate map's wide slot, from the 2026-09-05 width surface:
   0.9167 puts the fallback stop ~12% under entry. A value, not a default —
   nothing in this PR arms it. *)
let _wide = 0.9167

(* A second armed value, distinct from [_wide], so a per-state test can tell
   "read the right slot" apart from "read some armed slot". *)
let _mid = 0.95

let _all_states : Weinstein_types.breadth_state list =
  [
    Bullish_breadth; Neutral_breadth; Deteriorating; Recovering; Bearish_breadth;
  ]

let _buffers_for map =
  List.map _all_states ~f:(fun state ->
      Stop_buffer_by_state.buffer_for map ~fallback:_scalar ~state)

(** R1, the whole point of the default: with {!Stop_buffer_by_state.default}
    every one of the five states resolves to the caller's scalar, so an entry
    walk that consults the map installs exactly the stop it installed before
    this module existed. Asserted over all five states rather than a sample — a
    single missed slot would be a silent width change in one regime only. *)
let test_default_map_resolves_to_the_fallback_for_every_state _ =
  assert_that
    (_buffers_for Stop_buffer_by_state.default)
    (elements_are
       [
         float_equal _scalar;
         float_equal _scalar;
         float_equal _scalar;
         float_equal _scalar;
         float_equal _scalar;
       ])

(** {!Stop_buffer_by_state.is_no_op} agrees with the observable behaviour above:
    [true] for the default, [false] once any single slot is armed. Pinned on the
    [deteriorating] slot specifically because that is the one the 27-year
    breadth study motivates arming first. *)
let test_is_no_op_tracks_whether_any_slot_is_armed _ =
  assert_that
    [
      Stop_buffer_by_state.is_no_op Stop_buffer_by_state.default;
      Stop_buffer_by_state.is_no_op
        { Stop_buffer_by_state.default with deteriorating = _wide };
    ]
    (elements_are [ equal_to true; equal_to false ])

(** A fully-populated map selects {b per state}, and each state reads its own
    slot. The five values are pairwise distinguishable (two armed values plus
    the scalar, arranged so no two adjacent states share one) so a resolver that
    transposed two constructors would fail here rather than pass by symmetry. *)
let test_a_populated_map_selects_each_state_s_own_width _ =
  let map =
    {
      Stop_buffer_by_state.bullish = _wide;
      neutral = _mid;
      deteriorating = _scalar;
      recovering = _wide;
      bearish = _mid;
    }
  in
  assert_that (_buffers_for map)
    (elements_are
       [
         float_equal _wide;
         float_equal _mid;
         float_equal _scalar;
         float_equal _wide;
         float_equal _mid;
       ])

(** A {b partially} populated map leaves the unset states on the scalar — the
    property that makes a one-slot override
    ([initial_stop_buffer_by_macro_state.deteriorating=1.0]) mean "widen this
    regime", not "reset the other four to zero". This is the concrete failure
    the plan's shape-(b) rejection is about. *)
let test_unset_slots_fall_back_to_the_scalar _ =
  let map =
    {
      Stop_buffer_by_state.default with
      deteriorating = _mid;
      recovering = _wide;
    }
  in
  assert_that (_buffers_for map)
    (elements_are
       [
         float_equal _scalar;
         float_equal _scalar;
         float_equal _mid;
         float_equal _wide;
         float_equal _scalar;
       ])

(** The sentinel is "non-positive", not "exactly [unset]" — a negative typo in a
    sweep spec falls back to the scalar rather than inverting the stop to the
    wrong side of the entry price. Documented in the [.mli]; pinned here because
    the guard's shape ([<= unset] vs [= unset]) is invisible from the outside
    otherwise. *)
let test_a_negative_slot_is_treated_as_unset _ =
  assert_that
    (Stop_buffer_by_state.buffer_for
       { Stop_buffer_by_state.default with bearish = -1.0 }
       ~fallback:_scalar ~state:Bearish_breadth)
    (float_equal _scalar)

(** The documented breadth-direction interaction (plan §"Interaction worth
    documenting"): with [macro_config.breadth_direction] off — the default —
    [Macro.result.breadth_state] is exactly
    [Weinstein_types.breadth_state_of_market_trend trend], so the only states
    reachable are the projections of the three-state trend. A map that arms
    {b only} [deteriorating] and [recovering] therefore fires for none of them.

    Built through the real projection function rather than by listing the three
    constructors, so a change to what the three-state read projects onto moves
    this test with it. *)
let test_deteriorating_and_recovering_are_inert_with_the_breadth_read_off _ =
  let map =
    {
      Stop_buffer_by_state.default with
      deteriorating = _wide;
      recovering = _wide;
    }
  in
  assert_that
    ([ Weinstein_types.Bullish; Neutral; Bearish ]
    |> List.map ~f:(fun trend ->
        Stop_buffer_by_state.buffer_for map ~fallback:_scalar
          ~state:(Weinstein_types.breadth_state_of_market_trend trend)))
    (elements_are
       [ float_equal _scalar; float_equal _scalar; float_equal _scalar ])

(** The overlay-shape contract the [.mli] argues for: the default map serialises
    {b all five keys}, never [()]. [Overlay_validator] deep-merges an overlay
    against the base config's own sexp and rejects any key the base does not
    present, so a default that collapsed to an empty list would make
    [initial_stop_buffer_by_macro_state.deteriorating=1.0] raise instead of
    apply. Asserted on the emitted key names, which is the property the
    validator actually reads. *)
let test_the_default_serialises_all_five_keys _ =
  let keys =
    match Stop_buffer_by_state.sexp_of_t Stop_buffer_by_state.default with
    | Sexp.List fields ->
        List.filter_map fields ~f:(function
          | Sexp.List [ Sexp.Atom k; _ ] -> Some k
          | _ -> None)
    | Sexp.Atom _ -> []
  in
  assert_that keys
    (elements_are
       [
         equal_to "bullish";
         equal_to "neutral";
         equal_to "deteriorating";
         equal_to "recovering";
         equal_to "bearish";
       ])

(** The [[@sexp.default unset]] half of R1, pinned against a {b literal} legacy
    shape rather than one derived by stripping the current serialisation: the
    empty record [()] — and a one-key record, the shape a dot-path override
    produces — both parse, landing [unset] in every omitted slot. A spec written
    before this field existed, and a sweep overlay naming a single state, are
    exactly these two shapes. *)
let test_partial_and_empty_sexps_parse_with_unset_slots _ =
  assert_that
    [
      Stop_buffer_by_state.t_of_sexp (Sexp.of_string "()");
      Stop_buffer_by_state.t_of_sexp (Sexp.of_string "((deteriorating 0.9167))");
    ]
    (elements_are
       [
         equal_to (Stop_buffer_by_state.default : Stop_buffer_by_state.t);
         equal_to
           ({ Stop_buffer_by_state.default with deteriorating = _wide }
             : Stop_buffer_by_state.t);
       ])

(** Round-trip: an armed map survives [sexp_of_t] / [t_of_sexp] unchanged, which
    is what lets a scenario spec carry a full five-slot map. *)
let test_an_armed_map_round_trips_through_sexp _ =
  let map =
    { Stop_buffer_by_state.default with bullish = _wide; recovering = _wide }
  in
  assert_that
    (Stop_buffer_by_state.t_of_sexp (Stop_buffer_by_state.sexp_of_t map))
    (equal_to (map : Stop_buffer_by_state.t))

let suite =
  "stop_buffer_by_state"
  >::: [
         "the default map resolves to the fallback for every state"
         >:: test_default_map_resolves_to_the_fallback_for_every_state;
         "is_no_op tracks whether any slot is armed"
         >:: test_is_no_op_tracks_whether_any_slot_is_armed;
         "a populated map selects each state's own width"
         >:: test_a_populated_map_selects_each_state_s_own_width;
         "unset slots fall back to the scalar"
         >:: test_unset_slots_fall_back_to_the_scalar;
         "a negative slot is treated as unset"
         >:: test_a_negative_slot_is_treated_as_unset;
         "deteriorating/recovering are inert with the breadth read off"
         >:: test_deteriorating_and_recovering_are_inert_with_the_breadth_read_off;
         "the default serialises all five keys"
         >:: test_the_default_serialises_all_five_keys;
         "partial and empty sexps parse with unset slots"
         >:: test_partial_and_empty_sexps_parse_with_unset_slots;
         "an armed map round-trips through sexp"
         >:: test_an_armed_map_round_trips_through_sexp;
       ]

let () = run_test_tt_main suite
