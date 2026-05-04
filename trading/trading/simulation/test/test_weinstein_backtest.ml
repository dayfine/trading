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
module Bar_reader = Weinstein_strategy.Bar_reader

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

(** Build a [Bar_reader.t] from per-symbol CSVs in [data_dir] for the universe +
    requested date range. Phase F.3.a-4 (`?bar_panels` retirement): previously
    constructed a [Bar_panels.t] via {!Ohlcv_panels.load_from_csv_calendar} and
    threaded it through [Weinstein_strategy.make ~bar_panels]. After the
    optional [?bar_panels] parameter was removed, the integration test loads
    each symbol's bars from CSV directly via {!Csv.Csv_storage.get} and routes
    them through {!Bar_reader.of_in_memory_bars} — no panel allocation. *)
let _build_bar_reader ~start_date ~end_date =
  let symbol_bars =
    List.map all_symbols ~f:(fun symbol ->
        let storage =
          match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
          | Ok s -> s
          | Error err ->
              assert_failure ("Csv_storage.create: " ^ Status.show err)
        in
        match Csv.Csv_storage.get storage ~start_date ~end_date () with
        | Ok bars -> (symbol, bars)
        | Error err -> assert_failure ("Csv_storage.get: " ^ Status.show err))
  in
  Bar_reader.of_in_memory_bars symbol_bars

(** Build a Weinstein strategy configured for the 7-stock universe. The
    [bar_reader] handle threads the snapshot-backed bar reader into the strategy
    so its [Stage]/[RS]/[Stock_analysis]/[Stops_runner] reads have a populated
    source. *)
let _make_strategy ~bar_reader =
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in
  let ticker_sectors =
    Sector_map.load ~data_dir:(Data_path.default_data_dir ())
  in
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    { base_config with portfolio_config = conservative_portfolio_config }
  in
  Weinstein_strategy.make ~ad_bars ~ticker_sectors ~bar_reader config

(** Create simulator deps and config, then run the simulation. *)
let _run_backtest ~start_date ~end_date =
  let bar_reader = _build_bar_reader ~start_date ~end_date in
  let strategy = _make_strategy ~bar_reader in
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
     traded-symbol set; final value drift well inside the ±$3K band.

     G14 (2026-05-01) — Fix B (Position.t.entry_price = current close at
     order placement) plus split-boundary lookback truncation. Position
     sizing now correctly uses [effective_entry] (current close) rather
     than [cand.suggested_entry] (a buffered breakout level historically
     above current price).

     G15 step 3 (2026-05-01) — Pre-entry stop-width gate (15% cap) +
     sizing-uses-installed-stop. Sizing now keys off the support-floor-
     derived [installed_stop] instead of [cand.suggested_stop]. Wider
     structural stops → smaller risk_per_share → fewer shares → less
     cash consumed per entry, so more candidates fit the running cash
     budget. Net effect on this 6-year window:
     - 30 buys / 27 sells (up from 27 / 25 pre-G15-step-3) across the
       same 7-symbol set
     - 27 round-trips (5W/22L) — same risk profile, just more entries
     - max drawdown 54% (down from 95% pre-G15-step-3) reflects the
       smaller per-entry exposure capping the underlying short-side
       drawdown amplitude. *)
  assert_that (List.length result.steps) (equal_to 2187);
  assert_that n_buys (equal_to 30);
  assert_that n_sells (equal_to 27);
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
  assert_that (List.length round_trips) (equal_to 27);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 5);
            field (fun s -> s.Metrics.loss_count) (equal_to 22);
          ]));
  (* G15 step 3 (2026-05-01): final value $485,285.88; pin ±$3K. *)
  assert_that final_value
    (is_between (module Float_ord) ~low:482_285.88 ~high:488_285.88);
  (* G15 step 3 (2026-05-01): max drawdown 54.25%; pin loose at < 0.60. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.60)

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
     sells across {AAPL, HD, JNJ, KO} with 4W/6L and final ≈ $512,025.

     G14 (2026-05-01): realised-entry sizing reduces trade count to
     8 / 7 (same symbol set), 7 round-trips with 2W/5L.

     G15 step 3 (2026-05-01): same trade count + W/L (8/7, 2W/5L) on
     same symbol set; final value drops to $506,145 because sizing-
     uses-installed-stop trims per-entry size on the longs that worked,
     reducing compounding upside. Max drawdown 48.6% (down from 54.4%
     pre-G15-step-3) for the same reason. *)
  assert_that (List.length result.steps) (equal_to 545);
  assert_that n_buys (equal_to 8);
  assert_that n_sells (equal_to 7);
  assert_that symbols
    (elements_are
       [ equal_to "AAPL"; equal_to "HD"; equal_to "JNJ"; equal_to "KO" ]);
  assert_that (List.length round_trips) (equal_to 7);
  assert_that stats
    (is_some_and
       (all_of
          [
            field (fun s -> s.Metrics.win_count) (equal_to 2);
            field (fun s -> s.Metrics.loss_count) (equal_to 5);
          ]));
  (* G15 step 3 (2026-05-01): final value $506,145.21 ± $5K. *)
  assert_that final_value
    (is_between (module Float_ord) ~low:501_145.21 ~high:511_145.21);
  (* G15 step 3 (2026-05-01): max drawdown 48.59%; pin loose at < 0.52. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.52)

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
     1W/2L and final ≈ $505,302.82.

     G14 (2026-05-01): realised-entry sizing yields 3 / 2 trades on the
     same symbol set, 2 round-trips with 1W/1L.

     G15 step 3 (2026-05-01): smaller per-entry sizing admits one extra
     candidate that previously got cash-rejected → 4 / 3 trades, 3
     round-trips with 1W/2L on same {HD, KO} symbol set. Final
     $523,068; max drawdown 16.94% (up from 9.63% — the additional
     entry is a loser whose MTM swing dominates the new minimum PV).
     PV still stays positive throughout. *)
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
  (* G15 step 3 (2026-05-01): max drawdown 16.94%; cap at < 0.20. *)
  assert_that max_drawdown_pct (lt (module Float_ord) 0.20);
  (* G15 step 3: final value $523,067.89 ± $3K. *)
  assert_that final_value
    (is_between (module Float_ord) ~low:520_067.89 ~high:526_067.89)

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
