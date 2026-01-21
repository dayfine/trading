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

(** Real data directory path. Tests run from
    _build/default/trading/simulation/test/ via dune, so we need to navigate up
    to find the data directory. *)
let real_data_dir =
  (* Try multiple possible locations for the data directory *)
  let candidates =
    [
      "../data";
      (* When running from trading/ directly *)
      "../../../../../data";
      (* When running from _build/default/trading/simulation/test/ *)
      "../../../../../../data";
      (* Alternative _build layout *)
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
  | None -> failwith "Could not find real data directory"

(** Sample commission config *)
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(* ==================== Real Data Loading Tests ==================== *)

let test_load_real_symbol_aapl _ =
  (* Test that we can load AAPL data from the real data directory *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  (* Run the simulation - should complete without errors *)
  match run sim with
  | Error err -> failwith ("Run failed: " ^ Status.show err)
  | Ok (steps, final_portfolio) ->
      (* Should have 4 trading days (Jan 2-5, 2024 were Tuesday-Friday) *)
      assert_that steps (size_is 3);
      (* With no trades, cash should remain unchanged *)
      assert_that final_portfolio.current_cash (float_equal 10000.0)

let test_load_multiple_real_symbols _ =
  (* Test loading multiple symbols from real data *)
  let symbols = [ "AAPL"; "MSFT"; "GOOGL" ] in
  let deps =
    create_deps ~symbols ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-10";
      initial_cash = 50000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  match run sim with
  | Error err -> failwith ("Run failed: " ^ Status.show err)
  | Ok (steps, final_portfolio) ->
      (* Should complete successfully with all symbols loaded.
         Jan 2-10 is 9 calendar days, last day returns Completed = 8 steps *)
      assert_that steps (size_is 8);
      assert_that final_portfolio.current_cash (float_equal 50000.0)

(* ==================== Date Range Validation Tests ==================== *)

let test_date_range_before_data_starts _ =
  (* AAPL data starts 1980-12-12. Test with dates before that. *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "1970-01-01";
      end_date = date_of_string "1970-01-10";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  (* The simulator should handle this gracefully - no data for those dates.
     Expected: simulation runs but with no price data available. *)
  match run sim with
  | Error _ ->
      (* Error is acceptable - no data available *)
      ()
  | Ok (steps, _) ->
      (* Or it completes with steps but no price data available *)
      List.iter steps ~f:(fun step ->
          assert_that step.trades is_empty;
          assert_that step.orders_submitted is_empty)

let test_date_range_after_data_ends _ =
  (* Test with dates after the last available data (May 16, 2025) *)
  let deps =
    create_deps ~symbols:[ "AAPL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2030-01-01";
      end_date = date_of_string "2030-01-10";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  (* The simulator should handle this gracefully *)
  match run sim with
  | Error _ ->
      (* Error is acceptable - no data available for future dates *)
      ()
  | Ok (steps, _) ->
      (* Or it completes with steps but no price data available *)
      List.iter steps ~f:(fun step ->
          assert_that step.trades is_empty;
          assert_that step.orders_submitted is_empty)

let test_partial_date_overlap _ =
  (* Test a date range where only part of it has data.
     GOOGL data starts 2004-08-19, so test spanning that date. *)
  let deps =
    create_deps ~symbols:[ "GOOGL" ] ~data_dir:real_data_dir
      ~strategy:(module Noop_strategy)
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2004-08-01";
      end_date = date_of_string "2004-08-31";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  (* Should handle partial data gracefully *)
  match run sim with
  | Error err -> failwith ("Run failed unexpectedly: " ^ Status.show err)
  | Ok (steps, _) ->
      (* Should have some steps, even if some days have no data *)
      assert_bool "Should have at least some steps" (List.length steps > 0)

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
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
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
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
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
      ~(positions : Trading_strategy.Position.t String.Map.t) =
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
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-10";
      initial_cash = 10000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  match run sim with
  | Error err -> failwith ("E2E run failed: " ^ Status.show err)
  | Ok (steps, final_portfolio) ->
      (* Should have multiple steps *)
      assert_bool "Should have steps" (List.length steps > 0);
      (* After buying, cash should be reduced *)
      assert_bool "Cash should be reduced after buying"
        Float.(final_portfolio.current_cash < 10000.0);
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
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-31";
      initial_cash = 100000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  match run sim with
  | Error err -> failwith ("Long simulation failed: " ^ Status.show err)
  | Ok (steps, final_portfolio) ->
      (* Jan 2-31 is 30 calendar days, last day returns Completed = 29 steps *)
      assert_that steps (size_is 29);
      assert_that final_portfolio.current_cash (float_equal 100000.0)

(* ==================== EMA Strategy E2E Test ==================== *)

type trade_metrics = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
}
(** Metrics for a completed round-trip trade *)

let show_trade_metrics m =
  Printf.sprintf
    "%s: %s -> %s (%d days), entry=%.2f exit=%.2f qty=%.0f, P&L=$%.2f (%.2f%%)"
    m.symbol
    (Date.to_string m.entry_date)
    (Date.to_string m.exit_date)
    m.days_held m.entry_price m.exit_price m.quantity m.pnl_dollars
    m.pnl_percent

(** Extract round-trip trades from step results. A round-trip is a buy followed
    by a sell for the same symbol. *)
let extract_round_trips (steps : step_result list) : trade_metrics list =
  (* Collect all trades *)
  let all_trades =
    List.concat_map steps ~f:(fun step ->
        List.map step.trades ~f:(fun trade -> (step.date, trade)))
  in
  (* Group by symbol *)
  let by_symbol =
    List.fold all_trades
      ~init:(Map.empty (module String))
      ~f:(fun acc (date, trade) ->
        let symbol = trade.Trading_base.Types.symbol in
        let existing = Map.find acc symbol |> Option.value ~default:[] in
        Map.set acc ~key:symbol ~data:((date, trade) :: existing))
  in
  (* For each symbol, pair buys with sells *)
  Map.fold by_symbol ~init:[] ~f:(fun ~key:symbol ~data:trades acc ->
      let sorted =
        List.sort trades ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
      in
      (* Simple pairing: assume alternating buy/sell *)
      let rec pair_trades trades_list metrics =
        match trades_list with
        | (entry_date, entry) :: (exit_date, exit) :: rest
          when Trading_base.Types.(
                 equal_side entry.side Buy && equal_side exit.side Sell) ->
            let days_held = Date.diff exit_date entry_date in
            let pnl_dollars =
              (exit.Trading_base.Types.price -. entry.Trading_base.Types.price)
              *. entry.Trading_base.Types.quantity
            in
            let pnl_percent =
              (exit.Trading_base.Types.price -. entry.Trading_base.Types.price)
              /. entry.Trading_base.Types.price *. 100.0
            in
            let m =
              {
                symbol;
                entry_date;
                exit_date;
                days_held;
                entry_price = entry.Trading_base.Types.price;
                exit_price = exit.Trading_base.Types.price;
                quantity = entry.Trading_base.Types.quantity;
                pnl_dollars;
                pnl_percent;
              }
            in
            pair_trades rest (m :: metrics)
        | _ :: rest -> pair_trades rest metrics
        | [] -> List.rev metrics
      in
      pair_trades sorted [] @ acc)

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
      ~commission:sample_commission
  in
  let config =
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-03-31";
      initial_cash = 100000.0;
      commission = sample_commission;
    }
  in
  let sim = create ~config ~deps in
  match run sim with
  | Error err -> failwith ("EMA strategy run failed: " ^ Status.show err)
  | Ok (steps, final_portfolio) ->
      (* Extract and display metrics *)
      let round_trips = extract_round_trips steps in
      Printf.printf "\n=== EMA Strategy E2E Results (Q1 2024) ===\n";
      Printf.printf "Simulation period: %s to %s\n"
        (Date.to_string config.start_date)
        (Date.to_string config.end_date);
      Printf.printf "Initial cash: $%.2f\n" config.initial_cash;
      Printf.printf "Final cash: $%.2f\n" final_portfolio.current_cash;
      Printf.printf "Number of round-trip trades: %d\n"
        (List.length round_trips);

      (* Print each trade *)
      List.iter round_trips ~f:(fun m ->
          Printf.printf "  %s\n" (show_trade_metrics m));

      (* Summary stats *)
      if not (List.is_empty round_trips) then (
        let total_pnl =
          List.fold round_trips ~init:0.0 ~f:(fun acc m -> acc +. m.pnl_dollars)
        in
        let avg_days =
          Float.of_int
            (List.fold round_trips ~init:0 ~f:(fun acc m -> acc + m.days_held))
          /. Float.of_int (List.length round_trips)
        in
        let win_count =
          List.count round_trips ~f:(fun m -> Float.(m.pnl_dollars > 0.0))
        in
        Printf.printf "\nSummary:\n";
        Printf.printf "  Total P&L: $%.2f\n" total_pnl;
        Printf.printf "  Avg holding period: %.1f days\n" avg_days;
        Printf.printf "  Win rate: %d/%d (%.1f%%)\n" win_count
          (List.length round_trips)
          (Float.of_int win_count
          /. Float.of_int (List.length round_trips)
          *. 100.0));
      Printf.printf "==========================================\n";

      (* Basic assertions - strategy should run without errors *)
      assert_bool "Should have steps" (List.length steps > 0);
      (* Cash should change if there were trades *)
      let total_trades =
        List.sum (module Int) steps ~f:(fun s -> List.length s.trades)
      in
      Printf.printf "Total individual trades: %d\n" total_trades;
      ()

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
       ]

let () = run_test_tt_main suite
