(** Experiment-flag discipline pins (R1 default-off, R2 axis reachability) for
    the stop-machine flags on [Weinstein_stops.config] added for issues #2982
    and #2974.

    R1: each flag's shipped default is the pre-flag behaviour. R2: each flag is
    a real field reachable through the {b real}
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path) under the
    nested [stops_config] key, so [((stops_config ((<flag> true))))] is a valid
    [Variant_matrix] cell rather than an unknown-key failure. *)

open OUnit2
open Core
open Matchers

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"

let _apply overlay =
  Backtest.Overlay_validator.apply_overrides (_default_config ())
    [ Sexp.of_string overlay ]

(* ---- stop_ma_same_basis (#2982) ---- *)

let test_stop_ma_same_basis_defaults_off _ =
  let c = _default_config () in
  assert_that c.stops_config.Weinstein_stops.stop_ma_same_basis
    (equal_to false)

let test_stop_ma_same_basis_resolves_via_overlay_validator _ =
  let c = _apply "((stops_config ((stop_ma_same_basis true))))" in
  assert_that c.stops_config.Weinstein_stops.stop_ma_same_basis
    (equal_to true)

(* ---- correction_must_follow_peak (#2974) ---- *)

let test_correction_must_follow_peak_defaults_off _ =
  let c = _default_config () in
  assert_that c.stops_config.Weinstein_stops.correction_must_follow_peak
    (equal_to false)

let test_correction_must_follow_peak_resolves_via_overlay_validator _ =
  let c = _apply "((stops_config ((correction_must_follow_peak true))))" in
  assert_that c.stops_config.Weinstein_stops.correction_must_follow_peak
    (equal_to true)

let suite =
  "stop_flag_overlays"
  >::: [
         "stop_ma_same_basis defaults off"
         >:: test_stop_ma_same_basis_defaults_off;
         "stop_ma_same_basis resolves via Overlay_validator"
         >:: test_stop_ma_same_basis_resolves_via_overlay_validator;
         "correction_must_follow_peak defaults off"
         >:: test_correction_must_follow_peak_defaults_off;
         "correction_must_follow_peak resolves via Overlay_validator"
         >:: test_correction_must_follow_peak_resolves_via_overlay_validator;
       ]

let () = run_test_tt_main suite
