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
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Bar_panels = Data_panel.Bar_panels

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

(** Build the panel-backed bar reader for the universe + the requested date
    range. Stage 3 PR 3.2 deleted [Bar_history]; the strategy reads bars from
    [Bar_panels] now, so these integration tests must construct one before
    calling [Weinstein_strategy.make]. *)
let _build_calendar ~start ~end_ : Date.t array =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (Date.add_days d 1) acc'
  in
  Array.of_list (loop start [])

let _build_bar_panels ~start_date ~end_date =
  let calendar = _build_calendar ~start:start_date ~end_:end_date in
  let symbol_index =
    match Symbol_index.create ~universe:all_symbols with
    | Ok t -> t
    | Error err -> assert_failure ("Symbol_index.create: " ^ err.Status.message)
  in
  let ohlcv =
    match
      Ohlcv_panels.load_from_csv_calendar symbol_index
        ~data_dir:(Fpath.v data_dir) ~calendar
    with
    | Ok t -> t
    | Error err ->
        assert_failure
          ("Ohlcv_panels.load_from_csv_calendar: " ^ Status.show err)
  in
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> assert_failure ("Bar_panels.create: " ^ err.Status.message)

(** Build a Weinstein strategy configured for the 7-stock universe. The
    [bar_panels] handle threads the panel-backed bar reader into the strategy so
    its [Stage]/[RS]/[Stock_analysis]/[Stops_runner] reads have a populated
    source. *)
let _make_strategy ~bar_panels =
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in
  let ticker_sectors =
    Sector_map.load ~data_dir:(Data_path.default_data_dir ())
  in
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    { base_config with portfolio_config = conservative_portfolio_config }
  in
  Weinstein_strategy.make ~ad_bars ~ticker_sectors ~bar_panels config

(** Create simulator deps and config, then run the simulation. *)
let _run_backtest ~start_date ~end_date =
  let bar_panels = _build_bar_panels ~start_date ~end_date in
  let strategy = _make_strategy ~bar_panels in
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
  let symbols = _traded_symbols result.steps in
  let stats = Metrics.compute_summary round_trips in
  let max_drawdown_pct =
    (initial_cash -. _min_portfolio_value result.steps) /. initial_cash
  in
  (* Stage 3 PR 3.2 (post-rework): pin the deterministic post-3.2 values.
     With [Bar_history] deleted, panel-backed reads make bars visible
     up-front rather than via the pre-3.2 incremental cache. The trade
     counts shifted from the buggy pre-3.2 numbers (23/21 with 10W/11L)
     to the correct post-3.2 numbers captured below. The exact set of
     traded tickers, win/loss split, and a tight final-value band
     guarantee the strategy path is reproducible end-to-end.

     Short-side cascade-rules update (2026-04): n_buys/n_sells bumped
     from 36/33 → 39/36 after the support-below clean-space signal
     joined the short-side score. Three additional short trades in
     2018-2020 bear with no change to the round-trip count or
     traded-symbol set; final value drift well inside the ±$3K band. *)
  assert_that (List.length result.steps) (equal_to 2187);
  assert_that n_buys (equal_to 39);
  assert_that n_sells (equal_to 36);
  assert_that symbols
    (elements_are
       [
         equal_to "AAPL";
         equal_to "CVX";
         equal_to "HD";
         equal_to "JNJ";
         equal_to "JPM";
         equal_to "KO";
         equal_to "MSFT";
       ]);
  assert_that (List.length round_trips) (equal_to 33);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 16);
            field (fun s -> s.Metrics.loss_count) (equal_to 17);
          ]));
  (* Final value pinned within ±$3K of the captured post-3.2 value
     ($506,694.70). Tight band catches drift in the screener cascade or
     stop-loss path. *)
  assert_that final_value
    (is_between (module Float_ord) ~low:503_694.70 ~high:509_694.70);
  (* Max drawdown captured at 14.4778%; pin upper bound at captured + 1pp
     slack to catch regressions while tolerating tiny float drift. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.155)

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
  let symbols = _traded_symbols result.steps in
  let stats = Metrics.compute_summary round_trips in
  let max_drawdown_pct =
    (initial_cash -. _min_portfolio_value result.steps) /. initial_cash
  in
  (* Stage 3 PR 3.2 (post-rework): pinned post-3.2 deterministic values.
     Pre-3.2 was 6 buys / 6 sells; post-3.2 the cycle yields 11 buys / 10
     sells across {AAPL, HD, JNJ, KO} with 4W/6L and final ≈ $512,025. *)
  assert_that (List.length result.steps) (equal_to 545);
  assert_that n_buys (equal_to 11);
  assert_that n_sells (equal_to 10);
  assert_that symbols
    (elements_are
       [ equal_to "AAPL"; equal_to "HD"; equal_to "JNJ"; equal_to "KO" ]);
  assert_that (List.length round_trips) (equal_to 10);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 4);
            field (fun s -> s.Metrics.loss_count) (equal_to 6);
          ]));
  (* Final value pinned within ±$3K of the captured post-3.2 value
     ($512,025.01). *)
  assert_that final_value
    (is_between (module Float_ord) ~low:509_025.01 ~high:515_025.01);
  (* Max drawdown captured at 14.8438%; cap at captured + 1pp slack. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.16)

(* ------------------------------------------------------------------ *)
(* Portfolio value stays positive: 2020–2021                            *)
(* ------------------------------------------------------------------ *)

let test_portfolio_value_stays_positive _ =
  let result =
    _run_backtest
      ~start_date:(Date.of_string "2020-01-02")
      ~end_date:(Date.of_string "2021-12-31")
  in
  let n_buys = _count_by_side result.steps Trading_base.Types.Buy in
  let n_sells = _count_by_side result.steps Trading_base.Types.Sell in
  let min_value = _min_portfolio_value result.steps in
  let max_drawdown_pct = (initial_cash -. min_value) /. initial_cash in
  let final_value = (List.last_exn result.steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips result.steps in
  let symbols = _traded_symbols result.steps in
  let stats = Metrics.compute_summary round_trips in
  (* Stage 3 PR 3.2 (post-rework): pinned post-3.2 values. The 2020-2021
     window opens during the COVID crash, so every step has positive PV
     and the strategy completes 4 buys / 3 sells across {HD, KO} with
     1W/2L and final ≈ $505,302.82. *)
  assert_that (List.length result.steps) (equal_to 729);
  assert_that n_buys (equal_to 4);
  assert_that n_sells (equal_to 3);
  assert_that symbols (elements_are [ equal_to "HD"; equal_to "KO" ]);
  assert_that (List.length round_trips) (equal_to 3);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 1);
            field (fun s -> s.Metrics.loss_count) (equal_to 2);
          ]));
  assert_that min_value (gt (module Float_ord) 0.0);
  (* Max drawdown captured at 7.6625%; cap at captured + 1pp slack. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.087);
  (* Final value pinned within ±$3K of the captured post-3.2 value
     ($505,302.82). *)
  assert_that final_value
    (is_between (module Float_ord) ~low:502_302.82 ~high:508_302.82)

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
