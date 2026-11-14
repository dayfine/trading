(** Experiment-flag discipline pins for the stale-entry cap
    [entry_cap_local_range_weeks] (H2′, #3594): R1 default-off and R2 axis
    reachability.

    R1: the shipped default is [0] (no cap), and a config sexp without the field
    parses to [0], so every existing spec replays unchanged. R2: the field
    resolves through the {b real} [Overlay_validator.apply_overrides] (the sweep
    / WF-CV path), so [((flag entry_cap_local_range_weeks) (values (0 4)))] is a
    valid [Variant_matrix] axis. *)

open OUnit2
open Core
open Matchers

let _field = "entry_cap_local_range_weeks"

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"

let _weeks_after overlay =
  (Backtest.Overlay_validator.apply_overrides (_default_config ())
     [ Sexp.of_string overlay ])
    .entry_cap_local_range_weeks

let test_defaults_to_zero _ =
  assert_that (_default_config ()).entry_cap_local_range_weeks (equal_to 0)

let test_axis_resolves_via_overlay_validator _ =
  assert_that
    [
      _weeks_after "((entry_cap_local_range_weeks 4))";
      _weeks_after "((entry_cap_local_range_weeks 0))";
    ]
    (elements_are [ equal_to 4; equal_to 0 ])

(* A config sexp written before the field existed parses to the no-op. *)
let test_absent_field_parses_as_zero _ =
  let sexp =
    match Weinstein_strategy.sexp_of_config (_default_config ()) with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom name :: _) -> not (String.equal name _field)
            | _ -> true))
    | atom -> atom
  in
  assert_that
    (Weinstein_strategy.config_of_sexp sexp).entry_cap_local_range_weeks
    (equal_to 0)

let suite =
  "entry_cap_overlays"
  >::: [
         "defaults to 0" >:: test_defaults_to_zero;
         "axis resolves via Overlay_validator"
         >:: test_axis_resolves_via_overlay_validator;
         "absent field parses as 0" >:: test_absent_field_parses_as_zero;
       ]

let () = run_test_tt_main suite
