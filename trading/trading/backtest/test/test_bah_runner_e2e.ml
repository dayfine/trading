(** End-to-end Buy-and-Hold-SPY benchmark through
    {!Backtest.Runner.run_backtest}.

    Loads the pinned [goldens-sp500/sp500-2019-2023-bah-spy.sexp] scenario and
    drives it through the full runner — the same path the postsubmit script
    [dev/scripts/golden_sp500_postsubmit.sh] takes. Asserts:

    - The runner picks the {!Backtest.Strategy_choice.Bah_benchmark} branch from
      the scenario's [strategy] field (#882) and constructs
      {!Trading_strategy.Bah_benchmark_strategy.make}, not Weinstein.
    - The single-symbol BAH path returns the pinned baseline from
      [sp500-2019-2023-bah-spy.sexp]: ~+91.31% total return, 0 closed
      round-trips, final equity ~$1,913,114.

    Skips gracefully when SPY's CSV is not present in [data/S/Y/SPY/]. The
    in-repo [test_data/] subset doesn't include SPY by default; the test runs
    locally with the full [data/] mount and inside the dev container at
    [/workspaces/trading-1/data]. Postsubmit GHA runs ship the SP500 dataset via
    [dev/scripts/prepare_ci_data.sh] so the same skip path won't fire there. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

(* The runner reads CSVs from [Data_path.default_data_dir]; SPY is at
   [<root>/S/Y/SPY/data.csv] under the standard layout. We probe the
   resolver up front and skip when SPY is missing — same pattern as
   [test_bah_benchmark_e2e]. *)
let _spy_data_present () =
  let data_dir = Data_path.default_data_dir () in
  let spy_path = Fpath.(data_dir / "S" / "Y" / "SPY" / "data.csv") in
  match Sys_unix.file_exists (Fpath.to_string spy_path) with
  | `Yes -> true
  | `No | `Unknown -> false

(** Walk cwd parents looking for the worktree-local fixtures root —
    [trading/test_data/backtest_scenarios] under the repo root. Necessary
    because the BAH scenario file pinned in #882 is part of the worktree's
    test_data, not the container-wide [/workspaces/trading-1/data] used by
    [Data_path.default_data_dir]. Mirrors the same walk-up trick
    [test_scenario.ml] uses. *)
let _worktree_fixtures_root () =
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

let _scenario_relpath = "goldens-sp500/sp500-2019-2023-bah-spy.sexp"

let _load_scenario_exn fixtures_root =
  Scenario.load (Filename.concat fixtures_root _scenario_relpath)

let _sector_map_override fixtures_root (s : Scenario.t) =
  let resolved = Filename.concat fixtures_root s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(** Pinned runner-actual final equity for BAH-SPY 2019-2023, verified 2026-05-06
    against the same code path the postsubmit script takes.

    See [sp500-2019-2023-bah-spy.sexp] §"Measurement" for the full breakdown —
    fill happens at next-day open ($248.23) and final MtM uses 2023-12-28's
    close ($476.69) since the simulator's [is_complete] check fires when
    [current_date >= end_date]. *)
let _expected_final_equity = 1_913_114.65

(** ±0.05% band around the expected equity. The number is fully deterministic
    against pinned SPY data — no parameter sensitivity, no stochasticity.
    Anything beyond 0.05% drift is a real regression in the runner's wiring
    (commission tier change, fill-pricing convention shift, end-date semantics
    drift). *)
let _equity_tolerance_pct = 0.05

let _resolve_fixtures_root () =
  match _worktree_fixtures_root () with
  | Some r -> r
  | None ->
      assert_failure
        (Printf.sprintf
           "scenario test-data dir not found from cwd=%s (expected \
            trading/test_data/backtest_scenarios under a parent)"
           (Stdlib.Sys.getcwd ()))

let test_bah_runner_e2e ctx =
  if not (_spy_data_present ()) then (
    skip_if true
      "SPY data unavailable (data/S/Y/SPY/data.csv missing — test_data subset \
       doesn't include SPY). Run locally with the full /data mount.";
    assert_failure "unreachable after skip_if");
  ignore ctx;
  let fixtures_root = _resolve_fixtures_root () in
  let s = _load_scenario_exn fixtures_root in
  let sector_map_override = _sector_map_override fixtures_root s in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ~strategy_choice:s.strategy ()
  in
  let final_equity = result.summary.final_portfolio_value in
  let low =
    _expected_final_equity *. (1.0 -. (_equity_tolerance_pct /. 100.0))
  in
  let high =
    _expected_final_equity *. (1.0 +. (_equity_tolerance_pct /. 100.0))
  in
  assert_that final_equity (is_between (module Float_ord) ~low ~high);
  (* BAH never sells — exactly zero closed round-trips by end of run.
     The position itself stays open and contributes the bulk of equity. *)
  assert_that (List.length result.round_trips) (equal_to 0)

(** Sanity: scenarios that omit the [strategy] field still parse and default to
    Weinstein. This is the back-compat invariant called out in #882 — every
    pre-#882 scenario must be unchanged. *)
let test_default_strategy_is_weinstein _ =
  let s =
    Scenario.t_of_sexp
      (Sexp.of_string
         {|
         ((name "no-strategy-field")
          (description "Test default strategy resolution")
          (period ((start_date 2023-01-02) (end_date 2023-12-31)))
          (config_overrides ())
          (expected
           ((total_return_pct ((min -20.0) (max 60.0)))
            (total_trades     ((min 0)     (max 60)))
            (win_rate         ((min 0.0)   (max 100.0)))
            (sharpe_ratio     ((min -2.0)  (max 5.0)))
            (max_drawdown_pct ((min 0.0)   (max 40.0)))
            (avg_holding_days ((min 0.0)   (max 100.0))))))
        |})
  in
  assert_that s.strategy
    (equal_to (Backtest.Strategy_choice.Weinstein : Backtest.Strategy_choice.t))

(** A scenario file that explicitly sets
    [(strategy (Bah_benchmark (symbol SPY)))] should round-trip through sexp
    serialization. *)
let test_bah_benchmark_strategy_roundtrips _ =
  let original =
    Scenario.t_of_sexp
      (Sexp.of_string
         {|
         ((name "bah-test")
          (description "Test BAH strategy field")
          (period ((start_date 2023-01-02) (end_date 2023-12-31)))
          (config_overrides ())
          (strategy (Bah_benchmark (symbol SPY)))
          (expected
           ((total_return_pct ((min -20.0) (max 60.0)))
            (total_trades     ((min 0)     (max 60)))
            (win_rate         ((min 0.0)   (max 100.0)))
            (sharpe_ratio     ((min -2.0)  (max 5.0)))
            (max_drawdown_pct ((min 0.0)   (max 40.0)))
            (avg_holding_days ((min 0.0)   (max 100.0))))))
        |})
  in
  let roundtripped = Scenario.t_of_sexp (Scenario.sexp_of_t original) in
  assert_that roundtripped.strategy
    (equal_to
       (Backtest.Strategy_choice.Bah_benchmark { symbol = "SPY" }
         : Backtest.Strategy_choice.t))

let suite =
  "Bah_runner_e2e"
  >::: [
         "BAH-SPY 2019-2023 through Backtest.Runner matches pinned baseline"
         >:: test_bah_runner_e2e;
         "scenarios without [strategy] field default to Weinstein (back-compat)"
         >:: test_default_strategy_is_weinstein;
         "Bah_benchmark variant round-trips through sexp"
         >:: test_bah_benchmark_strategy_roundtrips;
       ]

let () = run_test_tt_main suite
