(** M5 historical backtesting integration test.

    Runs [Simulator.run] with [Weinstein_strategy] over a multi-year window on 7
    real stocks + GSPC.INDX index, using committed test data fixtures at
    [test_data/].

    Verifies: 1. The simulation runs to completion without error over ~1500
    trading days 2. Entries are generated (buy orders during bullish periods) 3.
    Exits fire (trailing stops produce sell trades) 4. P&L is tracked (final
    portfolio value computed and reasonable) 5. Full cycle: entry -> trailing
    stop management -> exit observed

    Uses conservative position sizing (0.3% risk per trade) to avoid cash
    exhaustion when multiple symbols enter simultaneously. *)

open OUnit2
open Core
open Matchers

(* ------------------------------------------------------------------ *)
(* Test data resolution                                                 *)
(* ------------------------------------------------------------------ *)

(** Resolve the test_data directory. Checks [TRADING_DATA_DIR] env var first,
    then walks up from the current directory looking for [test_data/]. *)
let resolve_test_data_dir () =
  match Sys.getenv "TRADING_DATA_DIR" with
  | Some d when String.length d > 0 -> d
  | _ -> (
      (* Walk up from cwd looking for test_data/ (handles both source and
         _build/ contexts). Also try absolute Docker container path. *)
      let rec walk dir depth =
        if depth > 8 then None
        else
          let candidate = Filename.concat dir "test_data" in
          match Sys_unix.is_directory candidate with
          | `Yes -> Some candidate
          | _ -> walk (Filename.concat dir Filename.parent_dir_name) (depth + 1)
      in
      match walk (Sys_unix.getcwd ()) 0 with
      | Some d -> d
      | None ->
          OUnit2.assert_failure
            "Cannot find test_data/ directory. Set TRADING_DATA_DIR or run \
             from the trading/ directory.")

(* ------------------------------------------------------------------ *)
(* Constants                                                            *)
(* ------------------------------------------------------------------ *)

let universe = [ "AAPL"; "MSFT"; "JPM"; "JNJ"; "CVX"; "KO"; "HD" ]
let index_symbol = "GSPC.INDX"
let all_symbols = index_symbol :: universe
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(* Conservative position sizing: 0.3% risk per trade keeps each position
   small enough to avoid cash exhaustion when multiple stocks enter. *)
let conservative_portfolio_config =
  {
    Portfolio_risk.default_config with
    risk_per_trade_pct = 0.003;
    max_positions = 10;
  }

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(** Build a Weinstein strategy configured for the 7-stock universe. *)
let make_backtest_strategy ~data_dir =
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    { base_config with portfolio_config = conservative_portfolio_config }
  in
  Weinstein_strategy.make ~ad_bars config

(** Create simulator deps and config, then run the simulation. *)
let run_backtest ~data_dir ~start_date ~end_date =
  let strategy = make_backtest_strategy ~data_dir in
  let deps =
    Trading_simulation.Simulator.create_deps ~symbols:all_symbols
      ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission ()
  in
  let sim_config =
    Trading_simulation.Simulator.
      {
        start_date;
        end_date;
        initial_cash = 500_000.0;
        commission = sample_commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  let sim =
    match Trading_simulation.Simulator.create ~config:sim_config ~deps with
    | Ok s -> s
    | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
  in
  match Trading_simulation.Simulator.run sim with
  | Ok r -> r
  | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)

(** Count trades by side across all steps. *)
let count_trades_by_side steps side =
  List.concat_map steps ~f:(fun step ->
      step.Trading_simulation.Simulator.trades)
  |> List.count ~f:(fun t ->
      Trading_base.Types.equal_side t.Trading_base.Types.side side)

(** Collect all unique symbols that were traded. *)
let traded_symbols steps =
  List.concat_map steps ~f:(fun step ->
      step.Trading_simulation.Simulator.trades)
  |> List.map ~f:(fun t -> t.Trading_base.Types.symbol)
  |> List.dedup_and_sort ~compare:String.compare

(* ------------------------------------------------------------------ *)
(* M5 backtest: 6-year historical run                                   *)
(* ------------------------------------------------------------------ *)

let test_m5_historical_backtest _ =
  let data_dir = resolve_test_data_dir () in
  let result =
    run_backtest ~data_dir
      ~start_date:(Date.of_string "2018-01-02")
      ~end_date:(Date.of_string "2023-12-29")
  in
  (* 1. Simulation runs to completion -- many steps over 6 years *)
  let n_steps = List.length result.steps in
  assert_that n_steps (gt (module Int_ord) 1000);
  (* 2. Entries generated -- at least some buy trades *)
  let n_buys = count_trades_by_side result.steps Trading_base.Types.Buy in
  assert_that n_buys (gt (module Int_ord) 0);
  (* 3. Exits fire -- sell trades from trailing stops *)
  let n_sells = count_trades_by_side result.steps Trading_base.Types.Sell in
  assert_that n_sells (gt (module Int_ord) 0);
  (* 4. Multiple symbols traded -- not just one lucky pick *)
  let syms = traded_symbols result.steps in
  assert_that (List.length syms) (gt (module Int_ord) 1);
  (* 5. Final portfolio value is positive and reasonable *)
  let final_step = List.last_exn result.steps in
  let final_value = final_step.portfolio_value in
  assert_that final_value (gt (module Float_ord) 0.0);
  (* Started at $500k, after 6 years should be between $100k and $2M. *)
  assert_that final_value
    (is_between (module Float_ord) ~low:100_000.0 ~high:2_000_000.0);
  (* 6. Full cycle observed: buys AND sells happened *)
  assert_that (n_buys + n_sells) (gt (module Int_ord) 2)

(* ------------------------------------------------------------------ *)
(* M5 backtest: verify entry/exit cycle                                 *)
(* ------------------------------------------------------------------ *)

let test_m5_entry_exit_cycle _ =
  let data_dir = resolve_test_data_dir () in
  let result =
    run_backtest ~data_dir
      ~start_date:(Date.of_string "2019-01-02")
      ~end_date:(Date.of_string "2020-06-30")
  in
  assert_that result.steps (not_ is_empty);
  let final_value = (List.last_exn result.steps).portfolio_value in
  assert_that final_value (gt (module Float_ord) 0.0);
  (* Over 2019-2020 the strategy should enter positions in the bull run
     and exit some during the COVID crash. *)
  let all_trades = List.concat_map result.steps ~f:(fun step -> step.trades) in
  assert_that all_trades (not_ is_empty)

(* ------------------------------------------------------------------ *)
(* M5 backtest: portfolio value tracks through time                     *)
(* ------------------------------------------------------------------ *)

let test_m5_portfolio_value_continuity _ =
  let data_dir = resolve_test_data_dir () in
  let result =
    run_backtest ~data_dir
      ~start_date:(Date.of_string "2020-01-02")
      ~end_date:(Date.of_string "2021-12-31")
  in
  (* Every step should have positive portfolio value *)
  List.iter result.steps ~f:(fun step ->
      assert_that step.portfolio_value (gt (module Float_ord) 0.0));
  (* ~500 trading days in 2 years *)
  let n_values = List.length result.steps in
  assert_that n_values (gt (module Int_ord) 400)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "m5_backtest"
  >::: [
         "6-year historical backtest" >:: test_m5_historical_backtest;
         "entry/exit cycle around COVID" >:: test_m5_entry_exit_cycle;
         "portfolio value continuity" >:: test_m5_portfolio_value_continuity;
       ]

let () = run_test_tt_main suite
