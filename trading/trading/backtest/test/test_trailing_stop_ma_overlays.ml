(** Experiment-flag discipline pins for #3038 [trailing_stop_ma_period] (arm
    T2): R1 default-off and R2 axis reachability.

    R1: the shipped default is [None] (trail on the stage MA), and a config sexp
    without the field parses to [None], so every existing spec replays
    unchanged. R2: the field resolves through the {b real}
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path), so
    [((flag trailing_stop_ma_period) (values (() (10))))] is a valid
    [Variant_matrix] axis. *)

open OUnit2
open Core
open Matchers

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"

let _period_after overlay =
  (Backtest.Overlay_validator.apply_overrides (_default_config ())
     [ Sexp.of_string overlay ])
    .trailing_stop_ma_period

let test_defaults_to_none _ =
  assert_that (_default_config ()).trailing_stop_ma_period is_none

let test_axis_resolves_via_overlay_validator _ =
  assert_that
    [
      _period_after "((trailing_stop_ma_period (10)))";
      _period_after "((trailing_stop_ma_period ()))";
    ]
    (elements_are [ is_some_and (equal_to 10); is_none ])

let test_armed_config_round_trips _ =
  let armed = { (_default_config ()) with trailing_stop_ma_period = Some 10 } in
  assert_that
    (Weinstein_strategy.config_of_sexp
       (Weinstein_strategy.sexp_of_config armed))
      .trailing_stop_ma_period
    (is_some_and (equal_to 10))

(* A config sexp written before the field existed parses to the no-op. *)
let test_absent_field_parses_as_none _ =
  let sexp =
    match Weinstein_strategy.sexp_of_config (_default_config ()) with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom "trailing_stop_ma_period" :: _) -> false
            | _ -> true))
    | atom -> atom
  in
  assert_that (Weinstein_strategy.config_of_sexp sexp).trailing_stop_ma_period
    is_none

let suite =
  "trailing_stop_ma_overlays"
  >::: [
         "defaults to None" >:: test_defaults_to_none;
         "axis resolves via Overlay_validator"
         >:: test_axis_resolves_via_overlay_validator;
         "armed config round-trips through sexp"
         >:: test_armed_config_round_trips;
         "absent field parses as None" >:: test_absent_field_parses_as_none;
       ]

let () = run_test_tt_main suite
