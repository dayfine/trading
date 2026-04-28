(* Regression tests for [Scenario_lib.Fixtures_root].

   The bug being pinned: a previous scenario_runner heuristic resolved the
   fixtures root via [Data_path.default_data_dir () |> Fpath.parent ^
   "trading/test_data/backtest_scenarios"]. With [TRADING_DATA_DIR] pointing
   at [trading/test_data] (the convention now used by the perf-tier workflows
   and by all in-repo tests), that produced a doubled-segment path
   [.../trading/trading/test_data/backtest_scenarios] which fails to resolve
   the universe sexp. See [dev/plans/perf-tier1-universe-path-2026-04-28.md]
   and the dev/status/backtest-perf.md next-step #4 entry. *)

open OUnit2
open Core
open Matchers
module Fixtures_root = Scenario_lib.Fixtures_root

(* Snapshot + restore [TRADING_DATA_DIR] around each test so cases don't
   leak env state to siblings or to the surrounding test runner. *)
let _with_trading_data_dir value f =
  let prev = Sys.getenv "TRADING_DATA_DIR" in
  Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:value;
  Exn.protect ~f ~finally:(fun () ->
      match prev with
      | Some v -> Core_unix.putenv ~key:"TRADING_DATA_DIR" ~data:v
      | None -> Core_unix.unsetenv "TRADING_DATA_DIR")

let test_explicit_override_is_returned_verbatim _ =
  assert_that
    (Fixtures_root.resolve ~fixtures_root:"/explicit/path" ())
    (equal_to "/explicit/path")

let test_explicit_override_wins_over_env _ =
  _with_trading_data_dir "/some/other/place" (fun () ->
      assert_that
        (Fixtures_root.resolve ~fixtures_root:"/explicit/path" ())
        (equal_to "/explicit/path"))

let test_fallback_uses_data_dir_plus_backtest_scenarios _ =
  _with_trading_data_dir "/ws/trading/test_data" (fun () ->
      assert_that (Fixtures_root.resolve ())
        (equal_to "/ws/trading/test_data/backtest_scenarios"))

(* Pin the actual bug: the legacy [Fpath.parent + "trading/test_data/..."]
   shape produced [/ws/trading/trading/test_data/backtest_scenarios] when
   TRADING_DATA_DIR=/ws/trading/test_data. The current [resolve] must NOT
   contain the doubled segment for that input. *)
let test_no_doubled_trading_segment _ =
  _with_trading_data_dir "/ws/trading/test_data" (fun () ->
      let resolved = Fixtures_root.resolve () in
      assert_that resolved
        (all_of
           [
             field
               (fun s -> String.is_substring s ~substring:"trading/trading")
               (equal_to false);
             field
               (String.is_substring ~substring:"backtest_scenarios")
               (equal_to true);
           ]))

let suite =
  "Fixtures_root"
  >::: [
         "explicit override is returned verbatim"
         >:: test_explicit_override_is_returned_verbatim;
         "explicit override wins over TRADING_DATA_DIR"
         >:: test_explicit_override_wins_over_env;
         "fallback uses data dir + backtest_scenarios"
         >:: test_fallback_uses_data_dir_plus_backtest_scenarios;
         "no doubled trading/trading segment in fallback"
         >:: test_no_doubled_trading_segment;
       ]

let () = run_test_tt_main suite
