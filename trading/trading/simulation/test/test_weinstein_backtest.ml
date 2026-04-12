(** Weinstein strategy historical backtesting integration tests.

    Runs [Simulator.run] with [Weinstein_strategy] over a multi-year window on 7
    real stocks + GSPC.INDX index, using committed test data fixtures at
    [test_data/].

    All test data is committed and deterministic — assertions pin exact trade
    counts, symbols, and portfolio values. If the strategy logic changes, these
    tests catch it. *)

open OUnit2
open Core
open Matchers
open Trading_simulation

(* ------------------------------------------------------------------ *)
(* Constants                                                            *)
(* ------------------------------------------------------------------ *)

let data_dir = Fpath.to_string (Data_path.default_data_dir ())
let universe = [ "AAPL"; "MSFT"; "JPM"; "JNJ"; "CVX"; "KO"; "HD" ]
let index_symbol = "GSPC.INDX"
let all_symbols = index_symbol :: universe
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
let initial_cash = 500_000.0

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
let _make_strategy () =
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in
  let ticker_sectors =
    Sector_map.load ~data_dir:(Data_path.default_data_dir ())
  in
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    { base_config with portfolio_config = conservative_portfolio_config }
  in
  Weinstein_strategy.make ~ad_bars ~ticker_sectors config

(** Create simulator deps and config, then run the simulation. *)
let _run_backtest ~start_date ~end_date =
  let strategy = _make_strategy () in
  let deps =
    Simulator.create_deps ~symbols:all_symbols ~data_dir:(Fpath.v data_dir)
      ~strategy ~commission:sample_commission ()
  in
  let sim_config =
    Simulator.
      {
        start_date;
        end_date;
        initial_cash;
        commission = sample_commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  let sim =
    match Simulator.create ~config:sim_config ~deps with
    | Ok s -> s
    | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
  in
  match Simulator.run sim with
  | Ok r -> r
  | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)

let _count_by_side steps side =
  List.concat_map steps ~f:(fun s -> s.Simulator.trades)
  |> List.count ~f:(fun t ->
      Trading_base.Types.equal_side t.Trading_base.Types.side side)

let _traded_symbols steps =
  List.concat_map steps ~f:(fun s -> s.Simulator.trades)
  |> List.map ~f:(fun t -> t.Trading_base.Types.symbol)
  |> List.dedup_and_sort ~compare:String.compare

let _min_portfolio_value steps =
  List.fold steps ~init:Float.max_value ~f:(fun acc s ->
      Float.min acc s.Simulator.portfolio_value)

(* ------------------------------------------------------------------ *)
(* 6-year full lifecycle: 2018–2023                                     *)
(* ------------------------------------------------------------------ *)

let test_six_year_full_lifecycle _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2018-01-02")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let n_buys = _count_by_side result.steps Trading_base.Types.Buy in
  let n_sells = _count_by_side result.steps Trading_base.Types.Sell in
  let final_value = (List.last_exn result.steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips result.steps in
  let summary = Metrics.compute_summary round_trips in
  (* Pinned: 2187 steps, 7 buys, 7 sells, all 7 symbols traded *)
  assert_that (List.length result.steps) (equal_to 2187);
  assert_that n_buys (equal_to 7);
  assert_that n_sells (equal_to 7);
  assert_that
    (_traded_symbols result.steps)
    (equal_to [ "AAPL"; "CVX"; "HD"; "JNJ"; "JPM"; "KO"; "MSFT" ]);
  (* 7 completed round-trips with 1 winner, 6 losers *)
  assert_that (List.length round_trips) (equal_to 7);
  assert_that summary
    (is_some_and
       (all_of
          [
            field (fun (s : Metrics.summary_stats) -> s.win_count) (equal_to 1);
            field (fun (s : Metrics.summary_stats) -> s.loss_count) (equal_to 6);
          ]));
  (* Final value ~$495k on $500k start — small loss from conservative sizing *)
  assert_that final_value
    (is_between (module Float_ord) ~low:490_000.0 ~high:500_000.0);
  (* Max drawdown under 10% *)
  let max_drawdown_pct =
    (initial_cash -. _min_portfolio_value result.steps) /. initial_cash
  in
  assert_that max_drawdown_pct (lt (module Float_ord) 0.10)

(* ------------------------------------------------------------------ *)
(* Entry/exit cycle around COVID crash: 2019–mid 2020                   *)
(* ------------------------------------------------------------------ *)

let test_entry_exit_cycle_around_covid _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2019-01-02")
      ~end_date:(Date.of_string "2020-06-30")
  in
  let n_buys = _count_by_side result.steps Trading_base.Types.Buy in
  let n_sells = _count_by_side result.steps Trading_base.Types.Sell in
  let final_value = (List.last_exn result.steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips result.steps in
  let summary = Metrics.compute_summary round_trips in
  (* Pinned: 545 steps, 4 buys/sells in AAPL HD JNJ KO *)
  assert_that (List.length result.steps) (equal_to 545);
  assert_that n_buys (equal_to 4);
  assert_that n_sells (equal_to 4);
  assert_that
    (_traded_symbols result.steps)
    (equal_to [ "AAPL"; "HD"; "JNJ"; "KO" ]);
  (* All 4 round-trips are losses — COVID crash stops out every position *)
  assert_that (List.length round_trips) (equal_to 4);
  assert_that summary
    (is_some_and
       (all_of
          [
            field (fun (s : Metrics.summary_stats) -> s.win_count) (equal_to 0);
            field (fun (s : Metrics.summary_stats) -> s.loss_count) (equal_to 4);
            field
              (fun (s : Metrics.summary_stats) -> s.total_pnl)
              (lt (module Float_ord) 0.0);
          ]));
  (* Final value ~$496k — losses are small due to conservative sizing *)
  assert_that final_value
    (is_between (module Float_ord) ~low:490_000.0 ~high:500_000.0);
  (* Max drawdown under 12% even through COVID *)
  let max_drawdown_pct =
    (initial_cash -. _min_portfolio_value result.steps) /. initial_cash
  in
  assert_that max_drawdown_pct (lt (module Float_ord) 0.12)

(* ------------------------------------------------------------------ *)
(* Portfolio value stays positive: 2020–2021                            *)
(* ------------------------------------------------------------------ *)

let test_portfolio_value_stays_positive _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2020-01-02")
      ~end_date:(Date.of_string "2021-12-31")
  in
  (* Pinned: 729 steps, 2 buys (HD, KO), no sells — positions held to end *)
  assert_that (List.length result.steps) (equal_to 729);
  assert_that (_count_by_side result.steps Trading_base.Types.Buy) (equal_to 2);
  assert_that (_count_by_side result.steps Trading_base.Types.Sell) (equal_to 0);
  (* Every step has positive portfolio value *)
  let min_value = _min_portfolio_value result.steps in
  assert_that min_value (gt (module Float_ord) 0.0);
  (* Max drawdown under 8% *)
  let max_drawdown_pct = (initial_cash -. min_value) /. initial_cash in
  assert_that max_drawdown_pct (lt (module Float_ord) 0.08);
  (* Final value above starting capital — recovery after COVID *)
  let final_value = (List.last_exn result.steps).portfolio_value in
  assert_that final_value (gt (module Float_ord) initial_cash)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "weinstein_backtest"
  >::: [
         "6-year full lifecycle" >:: test_six_year_full_lifecycle;
         "entry/exit cycle around COVID" >:: test_entry_exit_cycle_around_covid;
         "portfolio value stays positive"
         >:: test_portfolio_value_stays_positive;
       ]

let () = run_test_tt_main suite
