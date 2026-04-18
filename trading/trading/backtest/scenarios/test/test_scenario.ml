open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario

(* Minimum sexp that makes Scenario.t_of_sexp succeed. *)
let _base_expected_fields =
  {|
    (total_return_pct ((min -20.0) (max 60.0)))
    (total_trades     ((min 0)     (max 60)))
    (win_rate         ((min 0.0)   (max 100.0)))
    (sharpe_ratio     ((min -2.0)  (max 5.0)))
    (max_drawdown_pct ((min 0.0)   (max 40.0)))
    (avg_holding_days ((min 0.0)   (max 100.0)))
  |}

let _make_sexp ~extra_expected_fields =
  sprintf
    {|
  ((name "test-scenario")
   (description "Unit-test fixture")
   (period ((start_date 2023-01-02) (end_date 2023-12-31)))
   (config_overrides ())
   (expected
    (%s %s)))
  |}
    _base_expected_fields extra_expected_fields

let test_unrealized_pnl_field_absent _ =
  let s =
    Scenario.t_of_sexp (Sexp.of_string (_make_sexp ~extra_expected_fields:""))
  in
  assert_that s.expected.unrealized_pnl is_none

let test_unrealized_pnl_field_present _ =
  let s =
    Scenario.t_of_sexp
      (Sexp.of_string
         (_make_sexp
            ~extra_expected_fields:
              "(unrealized_pnl ((min 1000.0) (max 50000.0)))"))
  in
  assert_that s.expected.unrealized_pnl
    (is_some_and
       (all_of
          [
            field (fun (r : Scenario.range) -> r.min_f) (float_equal 1000.0);
            field (fun (r : Scenario.range) -> r.max_f) (float_equal 50000.0);
          ]))

let test_unrealized_pnl_roundtrip _ =
  let original =
    Scenario.t_of_sexp
      (Sexp.of_string
         (_make_sexp
            ~extra_expected_fields:
              "(unrealized_pnl ((min -5000.0) (max 5000.0)))"))
  in
  (* sexp_of + of_sexp round-trip preserves the pinned range. *)
  let roundtripped = Scenario.t_of_sexp (Scenario.sexp_of_t original) in
  assert_that roundtripped.expected.unrealized_pnl
    (is_some_and
       (all_of
          [
            field (fun (r : Scenario.range) -> r.min_f) (float_equal (-5000.0));
            field (fun (r : Scenario.range) -> r.max_f) (float_equal 5000.0);
          ]))

(* Sanity check: every real scenario file under [trading/test_data/backtest_scenarios]
   must parse. The new [unrealized_pnl] field is optional, so scenarios both with
   and without it must be accepted. *)
let _scenarios_root () =
  (* Under [dune runtest], cwd is
     [_build/default/trading/backtest/scenarios/test]; the test data lives at
     [trading/test_data/backtest_scenarios] relative to the repo root.
     Walk up the cwd until we find it. *)
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate =
        Filename.concat dir "trading/test_data/backtest_scenarios"
      in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let test_all_scenario_files_parse _ =
  match _scenarios_root () with
  | None ->
      (* Test data directory not discoverable from the test cwd. This
         normally means the test is being run from an unusual cwd; fail
         loudly so we notice rather than silently skipping. *)
      assert_failure
        (sprintf
           "scenario test-data dir not found from cwd=%s (tried ./trading and \
            ../../ walk-ups)"
           (Stdlib.Sys.getcwd ()))
  | Some root ->
      let collect dir =
        Stdlib.Sys.readdir dir |> Array.to_list
        |> List.filter ~f:(fun f -> String.is_suffix f ~suffix:".sexp")
        |> List.map ~f:(fun f -> Filename.concat dir f)
      in
      let files =
        collect (Filename.concat root "goldens-small")
        @ collect (Filename.concat root "goldens-broad")
        @ collect (Filename.concat root "smoke")
      in
      (* Sanity: at least the three smokes + three goldens-small + some
         goldens-broad should be there. *)
      assert_bool
        (sprintf "expected >=6 scenario files, found %d in %s"
           (List.length files) root)
        (List.length files >= 6);
      (* At least one scenario should have a pinned [unrealized_pnl] range
         excluding zero — this is the regression guard for PR #393. *)
      let with_nonzero_pin =
        List.filter_map files ~f:(fun path ->
            let s = Scenario.load path in
            match s.expected.unrealized_pnl with
            | Some r when Float.(r.min_f > 0.0) -> Some s.name
            | _ -> None)
      in
      assert_bool "expected >=1 scenario pinning unrealized_pnl with min > 0"
        (not (List.is_empty with_nonzero_pin))

(* Regression guard: a range like [min=1000, max=50000] catches a regression
   back to [UnrealizedPnl = 0], which is exactly the bug PR #393 fixed. *)
let test_non_zero_range_rejects_zero _ =
  let r = { Scenario.min_f = 1000.0; max_f = 50000.0 } in
  assert_that (Scenario.in_range r 0.0) (equal_to false);
  assert_that (Scenario.in_range r 12345.0) (equal_to true)

let test_near_zero_range_accepts_zero _ =
  (* Scenarios that liquidate everything by end should have UnrealizedPnl ≈ 0;
     a symmetric near-zero window accepts that case while still rejecting
     large regressions. *)
  let r = { Scenario.min_f = -100.0; max_f = 100.0 } in
  assert_that (Scenario.in_range r 0.0) (equal_to true);
  assert_that (Scenario.in_range r 5000.0) (equal_to false)

(* A scenario sexp that omits [universe_path] should receive the default,
   preserving backward compatibility with pre-migration scenario files. *)
let test_universe_path_absent_uses_default _ =
  let s =
    Scenario.t_of_sexp (Sexp.of_string (_make_sexp ~extra_expected_fields:""))
  in
  assert_that s.universe_path (equal_to Scenario.default_universe_path)

let _make_sexp_with_universe ~universe_path =
  sprintf
    {|
  ((name "test-scenario")
   (description "Unit-test fixture")
   (period ((start_date 2023-01-02) (end_date 2023-12-31)))
   (universe_path %S)
   (config_overrides ())
   (expected
    (%s)))
  |}
    universe_path _base_expected_fields

let test_universe_path_present _ =
  let s =
    Scenario.t_of_sexp
      (Sexp.of_string
         (_make_sexp_with_universe ~universe_path:"universes/broad.sexp"))
  in
  assert_that s.universe_path (equal_to "universes/broad.sexp")

let test_universe_path_roundtrip _ =
  let original =
    Scenario.t_of_sexp
      (Sexp.of_string
         (_make_sexp_with_universe ~universe_path:"universes/custom.sexp"))
  in
  let roundtripped = Scenario.t_of_sexp (Scenario.sexp_of_t original) in
  assert_that roundtripped.universe_path (equal_to "universes/custom.sexp")

let suite =
  "Scenario"
  >::: [
         "unrealized_pnl absent => None" >:: test_unrealized_pnl_field_absent;
         "unrealized_pnl present => Some range"
         >:: test_unrealized_pnl_field_present;
         "unrealized_pnl sexp round-trips" >:: test_unrealized_pnl_roundtrip;
         "non-zero range rejects zero" >:: test_non_zero_range_rejects_zero;
         "near-zero range accepts zero" >:: test_near_zero_range_accepts_zero;
         "universe_path absent => default"
         >:: test_universe_path_absent_uses_default;
         "universe_path present => round-trips" >:: test_universe_path_present;
         "universe_path sexp round-trips" >:: test_universe_path_roundtrip;
         "all scenario files parse" >:: test_all_scenario_files_parse;
       ]

let () = run_test_tt_main suite
