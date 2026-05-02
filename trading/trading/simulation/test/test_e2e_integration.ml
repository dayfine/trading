(** End-to-end integration tests using real CSV market data.

    These tests verify the complete simulator pipeline works correctly with real
    market data loaded from the data directory. This tests:
    - Price cache lazy loading from actual CSV files
    - Date range validation and error handling
    - Multi-symbol simulation
    - Strategy execution with real historical prices *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

(** Data directory path. Tests run from _build/default/trading/simulation/test/
    via dune, so we need to navigate up to find the data directory.

    Tries real data first (../data), then falls back to test_data/ which
    contains a minimal sample dataset for reproducible testing. *)
let real_data_dir =
  let candidates =
    [
      (* Real data locations *)
      "../data";
      "../../../../../data";
      "../../../../../../data";
      (* Sample test data locations (fallback for reproducible builds) *)
      "../test_data";
      "../../../../../test_data";
      "../../../../../../test_data";
    ]
  in
  let data_dir_opt =
    List.find_map candidates ~f:(fun path ->
        let fpath = Fpath.v path in
        let aapl_path = Fpath.(fpath / "A" / "L" / "AAPL" / "data.csv") in
        match Sys_unix.file_exists (Fpath.to_string aapl_path) with
        | `Yes -> Some fpath
        | `No | `Unknown -> None)
  in
  match data_dir_opt with
  | Some path -> path
  | None ->
      failwith
        "Could not find data directory. Either provide real data in ../data or \
         use test_data/ sample dataset."

(** Sample commission config *)
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Helper to run simulation and extract results, failing on error *)
let run_sim_exn sim =
  match run sim with
  | Error err -> failwith ("Simulation failed: " ^ Status.show err)
  | Ok result ->
      let final_portfolio = (List.last_exn result.steps).portfolio in
      (result.steps, final_portfolio)

(* ==================== Real Data Loading Tests ==================== *)

let test_load_real_symbol_aapl _ =
  (* Test that we can load AAPL data from the real data directory *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, final_portfolio = run_sim_exn sim in
  (* Should have 3 steps (Jan 2-4), Jan 5 returns Completed *)
  assert_that steps (size_is 3);
  (* With no trades, cash should remain unchanged *)
  assert_that final_portfolio.current_cash (float_equal config.initial_cash)

let test_load_multiple_real_symbols _ =
  (* Test loading multiple symbols from real data *)
  let symbols = [ "AAPL"; "MSFT"; "GOOGL" ] in
  let deps =
    create_deps ~symbols ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-10";
      initial_cash = 50000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, final_portfolio = run_sim_exn sim in
  (* Should complete successfully with all symbols loaded.
     Jan 2-10 is 9 calendar days, last day returns Completed = 8 steps *)
  assert_that steps (size_is 8);
  assert_that final_portfolio.current_cash (float_equal config.initial_cash)

(* ==================== Date Range Validation Tests ==================== *)

let test_date_range_before_data_starts _ =
  (* AAPL data starts 1980-12-12. Test with dates before that. *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "1970-01-01";
      end_date = date_of_string "1970-01-10";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  (* The simulator should handle this gracefully - no data for those dates.
     Expected: simulation runs but with no price data available. *)
  match run sim with
  | Error _ ->
      (* Error is acceptable - no data available *)
      ()
  | Ok result ->
      (* Or it completes with steps but no price data available *)
      List.iter result.steps ~f:(fun step ->
          assert_that step.trades is_empty;
          assert_that step.orders_submitted is_empty)

let test_date_range_after_data_ends _ =
  (* Test with dates after the last available data (May 16, 2025) *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2030-01-01";
      end_date = date_of_string "2030-01-10";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  (* The simulator should handle this gracefully *)
  match run sim with
  | Error _ ->
      (* Error is acceptable - no data available for future dates *)
      ()
  | Ok result ->
      (* Or it completes with steps but no price data available *)
      List.iter result.steps ~f:(fun step ->
          assert_that step.trades is_empty;
          assert_that step.orders_submitted is_empty)

let test_partial_date_overlap _ =
  (* Test a date range where only part of it has data.
     GOOGL data starts 2004-08-19, so test spanning that date. *)
  let deps =
    create_deps ~symbols:[ "GOOGL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2004-08-01";
      end_date = date_of_string "2004-08-31";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, _ = run_sim_exn sim in
  (* Should have some steps, even if some days have no data *)
  assert_that steps (not_ is_empty)

(* ==================== Missing Symbol Tests ==================== *)

let test_missing_symbol_graceful_handling _ =
  (* Test with a symbol that doesn't exist in the data directory.
     The simulator should return an error indicating the data file was not found,
     rather than throwing an exception. *)
  let deps =
    create_deps
      ~symbols:[ "NONEXISTENT_SYMBOL_XYZ" ]
      ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  match run sim with
  | Error err ->
      (* Should get an error about missing data file *)
      let err_msg = Status.show err in
      assert_bool
        (Printf.sprintf "Error should indicate data not found: %s" err_msg)
        (String.is_substring err_msg ~substring:"not found"
        || String.is_substring err_msg ~substring:"NotFound")
  | Ok _ ->
      (* Success is acceptable if the symbol is simply skipped *)
      ()

let test_mixed_valid_and_invalid_symbols _ =
  (* Test with a mix of valid and invalid symbols.
     The simulator fails on first access to invalid symbol since it tries
     to load price data for all configured symbols. *)
  let deps =
    create_deps
      ~symbols:[ "AAPL"; "INVALID_SYMBOL" ]
      ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  match run sim with
  | Error err ->
      (* Error is expected - invalid symbol can't be loaded *)
      let err_msg = Status.show err in
      assert_bool
        (Printf.sprintf "Error should indicate data not found: %s" err_msg)
        (String.is_substring err_msg ~substring:"not found"
        || String.is_substring err_msg ~substring:"NotFound")
  | Ok _ ->
      (* Success is also acceptable if only valid symbols were used *)
      ()

(* ==================== Buy and Hold Strategy E2E Test ==================== *)

(** Buy and hold strategy for e2e testing - buys on first day *)
module Buy_first_day_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "BuyFirstDay"
  let entered = ref false
  let reset () = entered := false

  (* Check if a position exists for a given symbol.
     The positions map is keyed by position_id, so we need to iterate. *)
  let _has_position_for_symbol positions symbol =
    Map.exists positions ~f:(fun pos ->
        String.equal pos.Trading_strategy.Position.symbol symbol)

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    let positions = portfolio.positions in
    let open Trading_strategy.Position in
    (* Only enter once, and only if no position exists for AAPL *)
    if !entered || _has_position_for_symbol positions "AAPL" then
      Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else
      match get_price "AAPL" with
      | Some price ->
          entered := true;
          Ok
            {
              Trading_strategy.Strategy_interface.transitions =
                [
                  {
                    position_id = "AAPL-E2E-1";
                    date = price.Types.Daily_price.date;
                    kind =
                      CreateEntering
                        {
                          symbol = "AAPL";
                          side = Long;
                          target_quantity = 10.0;
                          entry_price = price.close_price;
                          reasoning =
                            ManualDecision { description = "E2E test entry" };
                        };
                  };
                ];
            }
      | None -> Ok { Trading_strategy.Strategy_interface.transitions = [] }
end

let test_buy_and_hold_e2e _ =
  Buy_first_day_strategy.reset ();
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Buy_first_day_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-10";
      initial_cash = 10000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, final_portfolio = run_sim_exn sim in
  (* Should have multiple steps *)
  assert_that steps (not_ is_empty);
  (* After buying, cash should be reduced *)
  assert_that final_portfolio.current_cash
    (lt (module Float_ord) config.initial_cash);
  (* Should have a position in AAPL *)
  let aapl_position =
    Trading_portfolio.Portfolio.get_position final_portfolio "AAPL"
  in
  assert_that aapl_position
    (is_some_and (fun (pos : Trading_portfolio.Types.portfolio_position) ->
         assert_that pos.symbol (equal_to "AAPL")))

(* ==================== Longer Simulation Test ==================== *)

let test_longer_simulation_period _ =
  (* Test a longer simulation period (1 month) with real data *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-31";
      initial_cash = 100000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, final_portfolio = run_sim_exn sim in
  (* Jan 2-31 is 30 calendar days, last day returns Completed = 29 steps *)
  assert_that steps (size_is 29);
  assert_that final_portfolio.current_cash (float_equal config.initial_cash)

(* ==================== EMA Strategy E2E Test ==================== *)

let test_ema_strategy_e2e _ =
  (* Run EMA crossover strategy on AAPL for Q1 2024 *)
  let ema_config =
    {
      Trading_strategy.Ema_strategy.symbols = [ "AAPL" ];
      ema_period = 10;
      stop_loss_percent = 0.05;
      take_profit_percent = 0.10;
      position_size = 100.0;
    }
  in
  let strategy = Trading_strategy.Ema_strategy.make ema_config in
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir ~strategy
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-03-31";
      initial_cash = 100000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, final_portfolio = run_sim_exn sim in
  (* Extract and display metrics using the Metrics module *)
  let round_trips = Trading_simulation.Metrics.extract_round_trips steps in
  Printf.printf "\n=== EMA Strategy E2E Results (Q1 2024) ===\n";
  Printf.printf "Simulation period: %s to %s\n"
    (Date.to_string config.start_date)
    (Date.to_string config.end_date);
  Printf.printf "Initial cash: $%.2f\n" config.initial_cash;
  Printf.printf "Final cash: $%.2f\n" final_portfolio.current_cash;
  Printf.printf "Number of round-trip trades: %d\n" (List.length round_trips);

  (* Print each trade *)
  List.iter round_trips ~f:(fun m ->
      Printf.printf "  %s\n" (Trading_simulation.Metrics.show_trade_metrics m));

  (* Summary stats *)
  (match Trading_simulation.Metrics.compute_summary round_trips with
  | Some summary ->
      Printf.printf "\nSummary:\n";
      Printf.printf "  %s\n" (Trading_simulation.Metrics.show_summary summary)
  | None -> ());
  Printf.printf "==========================================\n";

  (* Basic assertions - strategy should run without errors *)
  assert_that steps (not_ is_empty);
  let total_trades =
    List.sum (module Int) steps ~f:(fun s -> List.length s.trades)
  in
  Printf.printf "Total individual trades: %d\n" total_trades

(* ==================== Benchmark Plumbing Integration Tests ==================== *)

(** Integration test for the antifragility benchmark plumbing
    (M5.2d follow-up).

    Verifies that wiring [~benchmark_symbol] through
    [Simulator.create_deps] populates [step_result.benchmark_return] on every
    trading day for which the benchmark has both a current and a prior bar.
    The benchmark symbol is independent from the universe — [symbols] holds
    only ["AAPL"] but the benchmark series is sourced from [GSPC.INDX]. *)
let test_benchmark_symbol_populates_step_result _ =
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission ~benchmark_symbol:"GSPC.INDX" ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-31";
      initial_cash = 100000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let steps, _ = run_sim_exn sim in
  (* Every trading day past the first one should carry a benchmark return; the
     first trading day has no prior bar inside the configured window so it can
     be [None]. We assert at least 15 of the ~21 trading days have a value to
     keep the test resilient to weekend/holiday spread. *)
  let with_bench =
    List.count steps ~f:(fun s -> Option.is_some s.benchmark_return)
  in
  assert_that with_bench (gt (module Int_ord) 15)

(** Integration test: when [~benchmark_symbol] is wired and the antifragility
    computer is included in the metric suite, the metrics produced by
    [BucketAsymmetry] reflect the strategy/benchmark co-movement (non-zero,
    finite). Uses [Buy_first_day_strategy] so portfolio_value moves with
    AAPL — correlated with GSPC.INDX, so the OLS quadratic fit and the
    bucket means are well-defined. *)
let test_antifragility_metrics_non_zero_with_benchmark _ =
  Buy_first_day_strategy.reset ();
  let metric_suite =
    Trading_simulation.Metric_computers.default_metric_suite ()
  in
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Buy_first_day_strategy)
      ~commission:sample_commission ~metric_suite
      ~benchmark_symbol:"GSPC.INDX" ()
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-03-31";
      initial_cash = 100000.0;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let result =
    match run sim with
    | Ok r -> r
    | Error err -> failwith ("Sim failed: " ^ Status.show err)
  in
  (* BucketAsymmetry compares Q1+Q5 vs Q2+Q3+Q4 means; with AAPL co-moving
     with the S&P 500 the bucket means are non-trivial and the ratio is
     bounded away from 0. The exact value depends on the period; we assert
     a strict positive lower bound (0.01) so a future regression to the
     [None]-short-circuit path (which would emit 0.0) is caught. *)
  let bucket_asym =
    Map.find_exn result.metrics
      Trading_simulation_types.Metric_types.BucketAsymmetry
  in
  assert_that (Float.abs bucket_asym) (gt (module Float_ord) 0.01)

(* ==================== Test Suite ==================== *)

let suite =
  "E2E Integration Tests"
  >::: [
         (* Real data loading tests *)
         "load real symbol AAPL" >:: test_load_real_symbol_aapl;
         "load multiple real symbols" >:: test_load_multiple_real_symbols;
         (* Date range validation tests *)
         "date range before data starts" >:: test_date_range_before_data_starts;
         "date range after data ends" >:: test_date_range_after_data_ends;
         "partial date overlap" >:: test_partial_date_overlap;
         (* Missing symbol tests *)
         "missing symbol graceful handling"
         >:: test_missing_symbol_graceful_handling;
         "mixed valid and invalid symbols"
         >:: test_mixed_valid_and_invalid_symbols;
         (* Strategy E2E tests *)
         "buy and hold e2e" >:: test_buy_and_hold_e2e;
         "ema strategy e2e" >:: test_ema_strategy_e2e;
         (* Longer simulation *)
         "longer simulation period" >:: test_longer_simulation_period;
         (* Benchmark plumbing (M5.2d follow-up) *)
         "benchmark symbol populates step_result"
         >:: test_benchmark_symbol_populates_step_result;
         "antifragility metrics emit with benchmark"
         >:: test_antifragility_metrics_non_zero_with_benchmark;
       ]

let () = run_test_tt_main suite
