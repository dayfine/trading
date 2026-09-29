(** Experiment-flag discipline pins for #3015 [max_one_share_class_per_issuer]
    (R1 default-off, R2 axis reachability), plus the committed share-class map.

    R1: the shipped default is off and the map empty, so no run reads the file.
    R2: the flag resolves through the {b real}
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path), so
    [((flag max_one_share_class_per_issuer) (values (true false)))] is a valid
    [Variant_matrix] axis. The committed [share_classes.sexp] is what the runner
    loads when the flag is armed; it must parse and group the issue's anchor
    pair while leaving the spin-off pair IAC/MTCH (#2782) unmapped. *)

open OUnit2
open Core
open Matchers

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "GOOG" ] ~index_symbol:"GSPCX"

let _flag_after overlay =
  (Backtest.Overlay_validator.apply_overrides (_default_config ())
     [ Sexp.of_string overlay ])
    .max_one_share_class_per_issuer

let test_defaults_off_with_empty_map _ =
  let c = _default_config () in
  assert_that
    ( c.max_one_share_class_per_issuer,
      Weinstein_strategy.Share_class_map.is_empty c.share_class_groups )
    (equal_to (false, true))

let test_flag_axis_resolves_via_overlay_validator _ =
  assert_that
    [
      _flag_after "((max_one_share_class_per_issuer true))";
      _flag_after "((max_one_share_class_per_issuer false))";
    ]
    (elements_are [ equal_to true; equal_to false ])

(** The runner's resolution step on the committed map (via [TRADING_DATA_DIR],
    which tests point at [trading/test_data/]). *)
let test_committed_map_loads_for_armed_config _ =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  let armed =
    { (_default_config ()) with max_one_share_class_per_issuer = true }
  in
  let map =
    (Weinstein_strategy.resolve_share_class_map ~data_dir armed)
      .share_class_groups
  in
  let group_of = Weinstein_strategy.Share_class_map.group_of map in
  assert_that
    ( group_of "GOOG",
      group_of "GOOGL",
      group_of "BRK-B",
      group_of "IAC",
      group_of "MTCH" )
    (equal_to (Some "GOOG", Some "GOOG", Some "BRK-A", None, None))

let suite =
  "share_class_overlays"
  >::: [
         "defaults off with empty map" >:: test_defaults_off_with_empty_map;
         "flag axis resolves via Overlay_validator"
         >:: test_flag_axis_resolves_via_overlay_validator;
         "committed map loads for armed config"
         >:: test_committed_map_loads_for_armed_config;
       ]

let () = run_test_tt_main suite
