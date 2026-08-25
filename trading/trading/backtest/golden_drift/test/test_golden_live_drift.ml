(** Unit + corpus tests for the golden-vs-live config drift check (#2403).

    The unit cases run against fixture specs written to a temp dir, so they pin
    the rule itself and stay stable as the committed goldens and the live
    overrides both evolve. The last test is the actual linter gate: every
    committed golden under the postsubmit directories must declare its drift. *)

open OUnit2
open Core
open Matchers
module Drift = Golden_live_drift_lib.Golden_live_drift

(* Minimum expected block that makes Scenario.t_of_sexp succeed. *)
let _expected_block =
  {|
    (total_return_pct ((min -20.0) (max 60.0)))
    (total_trades     ((min 0)     (max 60)))
    (win_rate         ((min 0.0)   (max 100.0)))
    (sharpe_ratio     ((min -2.0)  (max 5.0)))
    (max_drawdown_pct ((min 0.0)   (max 40.0)))
    (avg_holding_days ((min 0.0)   (max 100.0)))
  |}

let _spec_sexp ?(strategy = "") ?(overrides = "") ?(deviates = "") () =
  sprintf
    {|
  ((name "drift-fixture")
   (description "Unit-test fixture for the golden/live drift check")
   (period ((start_date 2023-01-02) (end_date 2023-12-31)))
   %s
   (config_overrides (%s))
   %s
   (expected (%s)))
  |}
    strategy overrides deviates _expected_block

(* Write one fixture spec plus a live-overrides file into a fresh temp dir and
   return (spec_path, live_config). The live arming is deliberately tiny so the
   expected deviation set is exactly enumerable. *)
let _fixture ?strategy ?overrides ?deviates ~live_overrides () =
  let dir = Filename_unix.temp_dir "golden_drift_test" "" in
  let spec_path = Filename.concat dir "fixture.sexp" in
  let live_path = Filename.concat dir "live-overrides.sexp" in
  Out_channel.write_all spec_path
    ~data:(_spec_sexp ?strategy ?overrides ?deviates ());
  Out_channel.write_all live_path ~data:live_overrides;
  (spec_path, Drift.live_config ~overrides_path:live_path)

let _finding_labels (report : Drift.spec_report) =
  List.map report.findings ~f:(function
    | Drift.Undeclared_deviation d -> "undeclared:" ^ d.field
    | Drift.Stale_declaration f -> "stale:" ^ f)

(* Live arms one report-side knob; the golden leaves it at its default. *)
let _live_arms_extension_cap = "((entry_extension_max_pct 15.0))"

let test_undeclared_deviation_is_reported _ =
  let spec_path, live = _fixture ~live_overrides:_live_arms_extension_cap () in
  assert_that
    (_finding_labels (Drift.check_spec ~live spec_path))
    (elements_are [ equal_to "undeclared:entry_extension_max_pct" ])

let test_declared_deviation_is_clean _ =
  let spec_path, live =
    _fixture
      ~deviates:
        {|(deviates_from_live
            ((entry_extension_max_pct "live arms 15.0; corpus runs the default")))|}
      ~live_overrides:_live_arms_extension_cap ()
  in
  assert_that (_finding_labels (Drift.check_spec ~live spec_path)) is_empty

(* A declaration naming a field that matches live is a note that outlived its
   drift; it must fail rather than linger. *)
let test_stale_declaration_is_reported _ =
  let spec_path, live =
    _fixture ~overrides:"((entry_extension_max_pct 15.0))"
      ~deviates:
        {|(deviates_from_live ((entry_extension_max_pct "no longer true")))|}
      ~live_overrides:_live_arms_extension_cap ()
  in
  assert_that
    (_finding_labels (Drift.check_spec ~live spec_path))
    (elements_are [ equal_to "stale:entry_extension_max_pct" ])

(* A non-Weinstein scenario has no full Weinstein config to compare against. *)
let test_bah_scenario_is_skipped _ =
  let spec_path, live =
    _fixture ~strategy:"(strategy (Bah_benchmark (symbol SPY)))"
      ~live_overrides:_live_arms_extension_cap ()
  in
  assert_that
    (Drift.check_spec ~live spec_path)
    (all_of
       [
         field
           (fun (r : Drift.spec_report) -> r.skipped_reason)
           (is_some_and (contains_substring "Bah_benchmark"));
         field (fun (r : Drift.spec_report) -> r.findings) is_empty;
       ])

(* A nested config record must name the differing leaf, not dump the whole
   sub-record — otherwise the message is unreadable and the declaration
   author cannot tell which knob moved. *)
let test_nested_deviation_names_the_differing_leaf _ =
  let golden =
    Backtest.Overlay_validator.apply_overrides
      (Weinstein_strategy.default_config ~universe:[] ~index_symbol:"SPY")
      [ Sexp.of_string "((portfolio_config ((min_cash_pct 0.30))))" ]
  in
  let live =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:"SPY"
  in
  assert_that
    (Drift.diff_configs ~golden ~live)
    (elements_are
       [
         all_of
           [
             field
               (fun (d : Drift.deviation) -> d.field)
               (equal_to "portfolio_config");
             field
               (fun (d : Drift.deviation) -> d.golden)
               (equal_to "((min_cash_pct 0.3))");
           ];
       ])

(* --- The gate: every committed postsubmit golden declares its drift ------- *)

let _repo_relative_dirs =
  [
    "trading/test_data/backtest_scenarios/goldens-sp500";
    "trading/test_data/backtest_scenarios/goldens-sp500-historical";
    "trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios";
  ]

let _live_overrides_rel = "dev/weekly-picks/live-config-overrides.sexp"

(* Under [dune runtest] the cwd is the test's _build dir; walk up to the repo
   root. Same shape as [Test_ladder_v4_overlays._walk_up]. *)
let rec _walk_up dir tries_left =
  if tries_left = 0 then None
  else if
    try Stdlib.Sys.file_exists (Filename.concat dir _live_overrides_rel)
    with _ -> false
  then Some dir
  else
    let parent = Filename.dirname dir in
    if String.equal parent dir then None else _walk_up parent (tries_left - 1)

let _repo_root () =
  match _walk_up (Stdlib.Sys.getcwd ()) 10 with
  | Some root -> root
  | None ->
      assert_failure
        (sprintf "repo root not found from cwd=%s" (Stdlib.Sys.getcwd ()))

let test_committed_goldens_declare_every_deviation _ =
  let root = _repo_root () in
  let live =
    Drift.live_config ~overrides_path:(Filename.concat root _live_overrides_rel)
  in
  let reports =
    Drift.check_dirs ~live
      (List.map _repo_relative_dirs ~f:(Filename.concat root))
  in
  (* Render the full report on failure — the message IS the linter output. *)
  assert_that (Drift.render_report reports) (contains_substring "OK: ")

let suite =
  "golden_live_drift"
  >::: [
         "undeclared_deviation_is_reported"
         >:: test_undeclared_deviation_is_reported;
         "declared_deviation_is_clean" >:: test_declared_deviation_is_clean;
         "stale_declaration_is_reported" >:: test_stale_declaration_is_reported;
         "bah_scenario_is_skipped" >:: test_bah_scenario_is_skipped;
         "nested_deviation_names_the_differing_leaf"
         >:: test_nested_deviation_names_the_differing_leaf;
         "committed_goldens_declare_every_deviation"
         >:: test_committed_goldens_declare_every_deviation;
       ]

let () = run_test_tt_main suite
