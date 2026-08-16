(** Ladder-v4 scenario-spec validation (PR-6 of
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] §5).

    The v4 specs live under [experiments/], which the golden-parse sweep in
    {!Test_scenario} deliberately does {b not} collect — so without this file
    nothing would ever load them. Two hazards it closes:

    - {b The #1051 silent-no-op.} An overlay key that does not resolve to a real
      field on [Weinstein_strategy.config] used to be dropped silently,
      producing bit-identical metrics across an 81-cell sweep.
      {!Backtest.Overlay_validator.apply_overrides} now raises on unresolved
      paths — so round-tripping every committed v4 spec through it turns a
      typo'd axis flag into a test failure instead of an arm that quietly reruns
      the baseline. [test_typo_in_axis_flag_is_rejected] pins that the validator
      really is that mechanism.
    - {b A degenerate matrix.} Every axis is written explicitly in every spec
      (including its no-op value), so the per-axis {e cell counts} below pin the
      designed shape of the 24-cell ladder. A cell silently collapsing onto
      another moves a count and fails.

    It also pins the standing caveats each header is required to carry — most
    importantly the anchor-axis truncation: plan §5 lists
    [anchor in {4, 8, base-extent}] but no base-extent anchor exists on main, so
    v4 runs [{4, 8}] only and every header must say so. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Overlay_validator = Backtest.Overlay_validator
module Freshness = Weinstein_strategy.Entry_freshness
module Width = Weinstein_strategy.Stop_width_mode
module Floor = Weinstein_stops.Support_floor

let _scenarios_root_rel = "trading/test_data/backtest_scenarios"
let _v4_dir_rel = "experiments/ladder-v4-async-ticket-2026-08-10"

(* Under [dune runtest] the cwd is the test's _build dir; walk up to the repo
   root. Same shape as [Test_scenario._scenarios_root]. *)
let rec _walk_up dir tries_left =
  if tries_left = 0 then None
  else
    let candidate = Filename.concat dir _scenarios_root_rel in
    if try Stdlib.Sys.is_directory candidate with _ -> false then Some candidate
    else
      let parent = Filename.dirname dir in
      if String.equal parent dir then None else _walk_up parent (tries_left - 1)

let _v4_spec_files () =
  match _walk_up (Stdlib.Sys.getcwd ()) 10 with
  | None ->
      assert_failure
        (sprintf "scenario test-data dir not found from cwd=%s"
           (Stdlib.Sys.getcwd ()))
  | Some root ->
      let dir = Filename.concat root _v4_dir_rel in
      Stdlib.Sys.readdir dir |> Array.to_list
      |> List.filter ~f:(String.is_suffix ~suffix:".sexp")
      |> List.sort ~compare:String.compare
      |> List.map ~f:(Filename.concat dir)

(* The canonical base every scenario's overrides are deep-merged into. The
   universe / index arguments do not affect any v4 axis. *)
let _base_config () =
  Weinstein_strategy.default_config ~universe:[] ~index_symbol:"SPY"

(* Round-trip one spec: parse, then resolve its overlays against the real
   config record. Raises [Failure] (failing the test) on any unresolved key. *)
let _applied_config path =
  let scenario = Scenario.load path in
  Overlay_validator.apply_overrides (_base_config ()) scenario.config_overrides

let _all_applied_configs () = List.map (_v4_spec_files ()) ~f:_applied_config

(* --- Round-trip: every spec parses and every overlay key resolves --------- *)

let test_every_v4_spec_round_trips _ =
  (* [_applied_config] raises on an unresolved overlay key, so reaching the
     assertion at all is the round-trip guarantee; the count pins that the full
     24-cell ladder is present rather than a subset. *)
  assert_that (List.length (_all_applied_configs ())) (equal_to 24)

(* The validator's verdict on one overlay list, as a string: either the
   [Failure] message it raised, or a marker saying it accepted the overlay.
   Rendering both outcomes as a string keeps the assertion a single
   [contains_substring] and makes a silent acceptance name itself. *)
let _overlay_verdict overrides =
  match
    Or_error.try_with (fun () ->
        Overlay_validator.apply_overrides (_base_config ()) overrides)
  with
  | Ok _ -> "ACCEPTED (no failure raised)"
  | Error err -> Error.to_string_hum err

let test_typo_in_axis_flag_is_rejected _ =
  (* A misspelled axis flag must fail validation naming the offending path,
     rather than resolving to nothing and silently rerunning the baseline. *)
  let typo =
    [ Sexp.of_string "((entry_freshness_bassis Range_top_breakout))" ]
  in
  assert_that (_overlay_verdict typo)
    (contains_substring "entry_freshness_bassis")

(* --- Axis coverage: the designed 24-cell shape ---------------------------- *)

let test_anchor_axis_is_truncated_to_4_and_8 _ =
  let cfgs = _all_applied_configs () in
  (* Plan §5's [base-extent] anchor does not exist on main; v4 runs {4, 8}. *)
  assert_that
    ( List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
          c.entry_anchor_local_range_weeks = 4),
      List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
          c.entry_anchor_local_range_weeks = 8) )
    (equal_to (21, 3))

let test_freshness_axis_coverage _ =
  let cfgs = _all_applied_configs () in
  assert_that
    (List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
         Freshness.equal_basis c.entry_freshness_basis
           Freshness.Range_top_breakout))
    (equal_to 14)

(* Post-split (defect C, 2026-08-16) the old single [entry_order_ttl_weeks]
   is two fields, and the ladder specs were migrated behaviour-preservingly:
   [0] -> (false, 0), [N > 0] -> (true, N). The counts are unchanged, which is
   what makes the migration checkable. *)
let test_ttl_axis_coverage _ =
  let cfgs = _all_applied_configs () in
  let n ~rescreen ~weeks =
    List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
        Bool.equal c.enable_entry_ticket_rescreen rescreen
        && c.entry_order_max_rest_weeks = weeks)
  in
  assert_that
    ( n ~rescreen:false ~weeks:0,
      n ~rescreen:true ~weeks:4,
      n ~rescreen:true ~weeks:8 )
    (equal_to (13, 9, 2))

let test_stop_width_mode_axis_coverage _ =
  let cfgs = _all_applied_configs () in
  (* Size_down cells always carry the 0.50 diagnostic ceiling; Drop_over_max
     cells always leave it at the 0.0 no-op. *)
  assert_that
    ( List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
          Width.equal c.stop_width_mode Width.Size_down),
      List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
          Float.equal c.stop_width_size_down_max_pct 0.50) )
    (equal_to (3, 3))

let test_max_stop_distance_axis_coverage _ =
  let cfgs = _all_applied_configs () in
  let n pct =
    List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
        Float.equal c.stops_config.max_stop_distance_pct pct)
  in
  (* 0.35 / 0.50 are the plan §5 diagnostic-only cells. *)
  assert_that (n 0.15, n 0.25, n 0.35, n 0.50) (equal_to (18, 3, 2, 1))

let test_support_floor_scope_axis_coverage _ =
  let cfgs = _all_applied_configs () in
  assert_that
    (List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
         Floor.equal_anchor_scope c.stops_config.support_floor_anchor_scope
           Floor.Nearest))
    (equal_to 7)

let test_volume_confirm_axis_coverage _ =
  let cfgs = _all_applied_configs () in
  assert_that
    (List.count cfgs ~f:(fun (c : Weinstein_strategy.config) ->
         c.volume_confirm_at_fill))
    (equal_to 6)

(* --- Cell 00 is the reference cell: every v4 axis at its no-op ------------ *)

let test_cell_00_is_the_all_no_op_reference _ =
  let path =
    List.find_exn (_v4_spec_files ()) ~f:(fun p ->
        String.is_substring (Filename.basename p) ~substring:"-v4-00-")
  in
  let (c : Weinstein_strategy.config) = _applied_config path in
  assert_that
    ( c.entry_anchor_local_range_weeks,
      Freshness.show_basis c.entry_freshness_basis,
      (c.enable_entry_ticket_rescreen, c.entry_order_max_rest_weeks),
      Width.show c.stop_width_mode,
      Floor.show_anchor_scope c.stops_config.support_floor_anchor_scope,
      c.volume_confirm_at_fill )
    (equal_to
       ( 4,
         Freshness.show_basis Freshness.Ma_cross,
         (false, 0),
         Width.show Width.Drop_over_max,
         Floor.show_anchor_scope Floor.Window_extreme,
         false ))

let test_cell_00_keeps_the_book_width_gate _ =
  let path =
    List.find_exn (_v4_spec_files ()) ~f:(fun p ->
        String.is_substring (Filename.basename p) ~substring:"-v4-00-")
  in
  let (c : Weinstein_strategy.config) = _applied_config path in
  assert_that
    (c.stops_config.max_stop_distance_pct, c.stop_width_size_down_max_pct)
    (equal_to (0.15, 0.0))

(* --- Required header notes ------------------------------------------------ *)

(* Basenames of specs whose header is missing [marker], as a comma-joined
   string so a failure names the offending files. *)
let _specs_missing marker =
  _v4_spec_files ()
  |> List.filter ~f:(fun path ->
      not (String.is_substring (In_channel.read_all path) ~substring:marker))
  |> List.map ~f:Filename.basename
  |> String.concat ~sep:","

let _assert_every_header_carries marker =
  assert_that (_specs_missing marker) (equal_to "")

let test_every_header_carries_the_anchor_truncation_note _ =
  _assert_every_header_carries "ANCHOR-AXIS TRUNCATED"

let test_every_header_states_overhead_grading _ =
  _assert_every_header_carries "OVERHEAD GRADING:"

let test_every_header_states_the_preset_mix _ =
  _assert_every_header_carries "PRESET:"

let test_every_header_states_the_f5_report_divergence _ =
  _assert_every_header_carries "F5 REPORT DIVERGENCE:"

let test_every_header_states_the_ticket_age_audit_limit _ =
  _assert_every_header_carries "AUDIT LIMIT:"

let test_every_header_carries_comparators_and_provenance _ =
  _assert_every_header_carries "COMPARATORS";
  _assert_every_header_carries "PROVENANCE:"

let test_every_header_marks_the_spec_as_not_a_golden _ =
  _assert_every_header_carries "NOT a golden";
  _assert_every_header_carries "sentinel bands"

let suite =
  "ladder_v4_overlays"
  >::: [
         "every_v4_spec_round_trips" >:: test_every_v4_spec_round_trips;
         "typo_in_axis_flag_is_rejected" >:: test_typo_in_axis_flag_is_rejected;
         "anchor_axis_is_truncated_to_4_and_8"
         >:: test_anchor_axis_is_truncated_to_4_and_8;
         "freshness_axis_coverage" >:: test_freshness_axis_coverage;
         "ttl_axis_coverage" >:: test_ttl_axis_coverage;
         "stop_width_mode_axis_coverage" >:: test_stop_width_mode_axis_coverage;
         "max_stop_distance_axis_coverage"
         >:: test_max_stop_distance_axis_coverage;
         "support_floor_scope_axis_coverage"
         >:: test_support_floor_scope_axis_coverage;
         "volume_confirm_axis_coverage" >:: test_volume_confirm_axis_coverage;
         "cell_00_is_the_all_no_op_reference"
         >:: test_cell_00_is_the_all_no_op_reference;
         "cell_00_keeps_the_book_width_gate"
         >:: test_cell_00_keeps_the_book_width_gate;
         "every_header_carries_the_anchor_truncation_note"
         >:: test_every_header_carries_the_anchor_truncation_note;
         "every_header_states_overhead_grading"
         >:: test_every_header_states_overhead_grading;
         "every_header_states_the_preset_mix"
         >:: test_every_header_states_the_preset_mix;
         "every_header_states_the_f5_report_divergence"
         >:: test_every_header_states_the_f5_report_divergence;
         "every_header_states_the_ticket_age_audit_limit"
         >:: test_every_header_states_the_ticket_age_audit_limit;
         "every_header_carries_comparators_and_provenance"
         >:: test_every_header_carries_comparators_and_provenance;
         "every_header_marks_the_spec_as_not_a_golden"
         >:: test_every_header_marks_the_spec_as_not_a_golden;
       ]

let () = run_test_tt_main suite
