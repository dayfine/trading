(** End-to-end smoke test: Simulator.run with Weinstein_strategy.

    Writes synthetic bar data to a temp directory using [Synthetic_source], then
    runs the full simulator pipeline with [Weinstein_strategy.make].

    {1 Infrastructure}

    - Bar accumulation: per-symbol daily bar buffer in the [make] closure,
      converted to weekly via [Time_period.Conversion.daily_to_weekly].
    - Portfolio value: derived via [Portfolio_view.portfolio_value] from the
      [Portfolio_view.t] passed to [on_market_close]. Used for position sizing.
    - MA direction: computed from [Stage.classify] on the bar buffer.
    - Simulation date: uses current bar's date (not [Date.today]).
    - Prior stage accumulation: per-symbol stage history in the [make] closure,
      enabling Stage1→Stage2 transition detection in the screener cascade.

    {1 Test coverage}

    Smoke tests cover: basic pipeline completion ([Trending] pattern), date
    range handling, weekly cadence gating, and full screener→order→trade flow
    ([Breakout] pattern with high volume and long warmup).

    TODO: remove the tmpdir round-trip once Price_cache accepts an injected
    DATA_SOURCE (follow-up to #218/#219). *)

open OUnit2
open Core
open Matchers

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)
let date_of_string s = Date.of_string s
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Generate bars for every symbol in [syn_config] and write them to [data_dir]
    as CSV files. Replaces the manual [make_bars] + [write_csv] pattern — bar
    shapes come from [Synthetic_source] patterns instead. *)
let write_synthetic_bars data_dir (syn_config : Synthetic_source.config) =
  let ds = Synthetic_source.make syn_config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  List.iter syn_config.symbols ~f:(fun (symbol, _) ->
      let query : Data_source.bar_query =
        {
          symbol;
          period = Types.Cadence.Daily;
          start_date = Some syn_config.start_date;
          end_date = None;
        }
      in
      let bars =
        match run_deferred (DS.get_bars ~query ()) with
        | Ok b -> b
        | Error e -> OUnit2.assert_failure ("get_bars failed: " ^ Status.show e)
      in
      match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
      | Error e -> OUnit2.assert_failure ("csv create: " ^ Status.show e)
      | Ok storage -> (
          match Csv.Csv_storage.save storage ~override:true bars with
          | Error e -> OUnit2.assert_failure ("csv save: " ^ Status.show e)
          | Ok () -> ()))

(* ------------------------------------------------------------------ *)
(* Smoke test: simulator completes without error                        *)
(* ------------------------------------------------------------------ *)

let test_weinstein_strategy_smoke _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_smoke" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      (* History from 2022-01-01 gives ~100 weekly bars before the sim
         start — enough for 30-week MA + stage classification warmup. *)
      let hist_start = date_of_string "2022-01-01" in
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = hist_start;
            symbols =
              [
                ( "AAPL",
                  Trending
                    {
                      start_price = 180.0;
                      weekly_gain_pct = 0.01;
                      volume = 50_000_000;
                    } );
                ( "GSPCX",
                  Trending
                    {
                      start_price = 4500.0;
                      weekly_gain_pct = 0.005;
                      volume = 1_000_000_000;
                    } );
              ];
          };
      let start_date = date_of_string "2024-01-02" in
      let end_date = date_of_string "2024-01-19" in
      let strategy =
        Weinstein_strategy.make
          (Weinstein_strategy.default_config ~universe:[ "AAPL" ]
             ~index_symbol:"GSPCX")
      in
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ "AAPL"; "GSPCX" ]
          ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission
          ()
      in
      let config =
        Trading_simulation.Simulator.
          {
            start_date;
            end_date;
            initial_cash = 100_000.0;
            commission = sample_commission;
            strategy_cadence = Types.Cadence.Daily;
          }
      in
      let sim =
        match Trading_simulation.Simulator.create ~config ~deps with
        | Ok s -> s
        | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
      in
      let result =
        match Trading_simulation.Simulator.run sim with
        | Ok r -> r
        | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)
      in
      assert_that result.steps (not_ is_empty);
      let final_portfolio = (List.last_exn result.steps).portfolio in
      assert_that final_portfolio.Trading_portfolio.Portfolio.current_cash
        (gt (module Float_ord) 0.0);
      (* Verify portfolio value is computed (not just cash — includes positions'
         market value). Bar accumulation + portfolio_value wiring make this
         nonzero even when no trades occur. *)
      let final_value = (List.last_exn result.steps).portfolio_value in
      assert_that final_value (gt (module Float_ord) 0.0))

(* ------------------------------------------------------------------ *)
(* Smoke test: simulation respects date range                          *)
(* ------------------------------------------------------------------ *)

let test_weinstein_date_range _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_range" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = date_of_string "2023-12-27";
            symbols =
              [
                ( "AAPL",
                  Basing
                    { base_price = 100.0; noise_pct = 0.01; volume = 1_000_000 }
                );
                ( "GSPCX",
                  Basing
                    {
                      base_price = 4500.0;
                      noise_pct = 0.005;
                      volume = 100_000_000;
                    } );
              ];
          };
      let start_date = date_of_string "2024-01-02" in
      let end_date = date_of_string "2024-01-05" in
      let strategy =
        Weinstein_strategy.make
          (Weinstein_strategy.default_config ~universe:[ "AAPL" ]
             ~index_symbol:"GSPCX")
      in
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ "AAPL"; "GSPCX" ]
          ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission
          ()
      in
      let config =
        Trading_simulation.Simulator.
          {
            start_date;
            end_date;
            initial_cash = 100_000.0;
            commission = sample_commission;
            strategy_cadence = Types.Cadence.Daily;
          }
      in
      let sim =
        match Trading_simulation.Simulator.create ~config ~deps with
        | Ok s -> s
        | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
      in
      let result =
        match Trading_simulation.Simulator.run sim with
        | Ok r -> r
        | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)
      in
      (* Jan 2-4 = 3 steps (Jan 5 = end_date, returns Completed) *)
      assert_that result.steps (size_is 3))

(* ------------------------------------------------------------------ *)
(* Smoke test: weekly cadence exercises Friday-gated strategy path      *)
(* ------------------------------------------------------------------ *)

let test_weinstein_weekly_cadence _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_weekly" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      (* Jan 2 – Jan 19 spans two Fridays (Jan 5 and Jan 12); Jan 19 is
         end_date so returns Completed without a step. Weekly cadence means
         the strategy is called only on those Fridays; all other trading days
         still produce steps with only pending-order processing. *)
      let hist_start = date_of_string "2022-01-01" in
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = hist_start;
            symbols =
              [
                ( "AAPL",
                  Trending
                    {
                      start_price = 180.0;
                      weekly_gain_pct = 0.01;
                      volume = 50_000_000;
                    } );
                ( "GSPCX",
                  Trending
                    {
                      start_price = 4500.0;
                      weekly_gain_pct = 0.005;
                      volume = 1_000_000_000;
                    } );
              ];
          };
      let start_date = date_of_string "2024-01-02" in
      let end_date = date_of_string "2024-01-19" in
      let strategy =
        Weinstein_strategy.make
          (Weinstein_strategy.default_config ~universe:[ "AAPL" ]
             ~index_symbol:"GSPCX")
      in
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ "AAPL"; "GSPCX" ]
          ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission
          ()
      in
      let config =
        Trading_simulation.Simulator.
          {
            start_date;
            end_date;
            initial_cash = 100_000.0;
            commission = sample_commission;
            strategy_cadence = Types.Cadence.Weekly;
          }
      in
      let sim =
        match Trading_simulation.Simulator.create ~config ~deps with
        | Ok s -> s
        | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
      in
      let result =
        match Trading_simulation.Simulator.run sim with
        | Ok r -> r
        | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)
      in
      assert_that result.steps (not_ is_empty);
      let final_portfolio = (List.last_exn result.steps).portfolio in
      assert_that final_portfolio.Trading_portfolio.Portfolio.current_cash
        (gt (module Float_ord) 0.0))

(* ------------------------------------------------------------------ *)
(* Slice 3: breakout pattern produces trades via screener cascade        *)
(* ------------------------------------------------------------------ *)

(** Smoke test using a [Breakout] synthetic pattern that passes the full
    screener cascade. The basing phase produces 95 weeks of Stage 1 data; the
    breakout with 2.5x volume starts the transition to Stage 2. With
    [prior_stage] accumulation, the screener detects the Stage1 -> Stage2
    transition and emits a [CreateEntering] transition.

    Asserts:
    - At least one step produced non-empty transitions
    - Final portfolio has an open position in AAPL
    - Portfolio value is positive *)
let test_weinstein_breakout_trade _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_breakout" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      let hist_start = date_of_string "2022-01-01" in
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = hist_start;
            symbols =
              [
                ( "AAPL",
                  Breakout
                    {
                      base_price = 150.0;
                      base_weeks = 40;
                      weekly_gain_pct = 0.02;
                      breakout_volume_mult = 8.0;
                      base_volume = 50_000_000;
                    } );
                ( "GSPCX",
                  Trending
                    {
                      start_price = 4500.0;
                      weekly_gain_pct = 0.005;
                      volume = 1_000_000_000;
                    } );
              ];
          };
      (* Sim starts from data start so the strategy accumulates enough
         bars for the 30-week MA. The breakout at week 40 means ~10 weeks
         of Stage 2 bars follow, and the screener fires on the first
         Friday after the breakout. *)
      let start_date = date_of_string "2022-01-03" in
      let end_date = date_of_string "2023-01-06" in
      let strategy =
        Weinstein_strategy.make
          (Weinstein_strategy.default_config ~universe:[ "AAPL" ]
             ~index_symbol:"GSPCX")
      in
      let deps =
        Trading_simulation.Simulator.create_deps ~symbols:[ "AAPL"; "GSPCX" ]
          ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission
          ()
      in
      let config =
        Trading_simulation.Simulator.
          {
            start_date;
            end_date;
            initial_cash = 100_000.0;
            commission = sample_commission;
            strategy_cadence = Types.Cadence.Daily;
          }
      in
      let sim =
        match Trading_simulation.Simulator.create ~config ~deps with
        | Ok s -> s
        | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
      in
      let result =
        match Trading_simulation.Simulator.run sim with
        | Ok r -> r
        | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)
      in
      assert_that result.steps (not_ is_empty);
      (* The run produces exactly four AAPL buys on successive Fridays. The
         breakout at week ~40 triggers a Stage1->Stage2 transition, and the
         screener's [weeks_advancing <= 4] fallback keeps AAPL a candidate for
         four more weeks. Quantities come from fixed-risk position sizing
         against rising prices, so they tick up by 1 share each week. A
         Trending GSPCX index never transitions, so GSPCX never trades. *)
      let all_trades =
        List.concat_map result.steps ~f:(fun step -> step.trades)
      in
      let is_aapl_buy ~qty ~price =
        all_of
          [
            field (fun t -> t.Trading_base.Types.symbol) (equal_to "AAPL");
            field
              (fun t -> t.Trading_base.Types.side)
              (equal_to Trading_base.Types.Buy);
            field
              (fun t -> t.Trading_base.Types.quantity)
              (float_equal ~epsilon:0.5 qty);
            field
              (fun t -> t.Trading_base.Types.price)
              (float_equal ~epsilon:0.1 price);
          ]
      in
      assert_that all_trades
        (elements_are
           [
             is_aapl_buy ~qty:80.0 ~price:162.45;
             is_aapl_buy ~qty:80.0 ~price:166.38;
             is_aapl_buy ~qty:81.0 ~price:170.42;
             is_aapl_buy ~qty:82.0 ~price:174.55;
           ]);
      (* Started with $100k, four buys at ~$162-$175 → long AAPL position in
         a rising breakout. Final value lands near $126k (positions held
         through continued 2%/wk trend for the remainder of the year). *)
      let final_value = (List.last_exn result.steps).portfolio_value in
      assert_that final_value
        (is_between (module Float_ord) ~low:125_000.0 ~high:128_000.0))

(* ------------------------------------------------------------------ *)
(* Strategy wiring: ad_bars + sector ETFs + global indices              *)
(* ------------------------------------------------------------------ *)

(** Smoke test that the strategy accepts and exercises the new macro-input
    wiring (NYSE breadth ad_bars, sector ETFs, global indices) without
    regressing the breakout trade flow. Uses [Basing] patterns for the ETFs and
    globals — they accumulate bars but do not trigger any new signals of their
    own, so the breakout outcome matches [test_weinstein_breakout_trade].

    Asserts:
    - Pipeline runs to completion without error
    - At least one AAPL buy was executed (sector wiring did not block screen)
    - Final portfolio value is positive *)
let test_weinstein_strategy_wiring_smoke _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_wiring" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      let hist_start = date_of_string "2022-01-01" in
      let basing price =
        Synthetic_source.Basing
          { base_price = price; noise_pct = 0.01; volume = 20_000_000 }
      in
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = hist_start;
            symbols =
              [
                ( "AAPL",
                  Breakout
                    {
                      base_price = 150.0;
                      base_weeks = 40;
                      weekly_gain_pct = 0.02;
                      breakout_volume_mult = 8.0;
                      base_volume = 50_000_000;
                    } );
                ( "GSPCX",
                  Trending
                    {
                      start_price = 4500.0;
                      weekly_gain_pct = 0.005;
                      volume = 1_000_000_000;
                    } );
                (* Sector ETF proxies: two synthetic tickers that the
                   strategy will accumulate + classify via Sector.analyze. *)
                ("XLK_SYN", basing 160.0);
                ("XLF_SYN", basing 35.0);
                (* Global index proxy *)
                ("DAX_SYN", basing 15000.0);
              ];
          };
      let start_date = date_of_string "2022-01-03" in
      let end_date = date_of_string "2023-01-06" in
      let base_config =
        Weinstein_strategy.default_config ~universe:[ "AAPL" ]
          ~index_symbol:"GSPCX"
      in
      let config =
        {
          base_config with
          sector_etfs = [ ("XLK_SYN", "Technology"); ("XLF_SYN", "Financials") ];
          global_index_symbols = [ ("DAX_SYN", "DAX") ];
        }
      in
      (* Synthetic ad_bars — enough rows to cover macro's [ad_min_bars] gate. *)
      let ad_bars =
        List.init 60 ~f:(fun i ->
            {
              Macro.date = Date.add_days hist_start i;
              advancing = 1500 + i;
              declining = 1400 - i;
            })
      in
      let strategy = Weinstein_strategy.make ~ad_bars config in
      let deps =
        Trading_simulation.Simulator.create_deps
          ~symbols:[ "AAPL"; "GSPCX"; "XLK_SYN"; "XLF_SYN"; "DAX_SYN" ]
          ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission
          ()
      in
      let sim_config =
        Trading_simulation.Simulator.
          {
            start_date;
            end_date;
            initial_cash = 100_000.0;
            commission = sample_commission;
            strategy_cadence = Types.Cadence.Daily;
          }
      in
      let sim =
        match Trading_simulation.Simulator.create ~config:sim_config ~deps with
        | Ok s -> s
        | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
      in
      let result =
        match Trading_simulation.Simulator.run sim with
        | Ok r -> r
        | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)
      in
      assert_that result.steps (not_ is_empty);
      let all_trades =
        List.concat_map result.steps ~f:(fun step -> step.trades)
      in
      let aapl_buys =
        List.filter all_trades ~f:(fun t ->
            String.equal t.Trading_base.Types.symbol "AAPL"
            && Trading_base.Types.equal_side t.side Buy)
      in
      assert_that (List.length aapl_buys) (gt (module Int_ord) 0);
      let final_value = (List.last_exn result.steps).portfolio_value in
      assert_that final_value (gt (module Float_ord) 0.0))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "weinstein_strategy_smoke"
  >::: [
         "smoke test completes without error" >:: test_weinstein_strategy_smoke;
         "simulation respects date range" >:: test_weinstein_date_range;
         "weekly cadence exercises Friday-gated strategy path"
         >:: test_weinstein_weekly_cadence;
         "breakout pattern produces trades via screener"
         >:: test_weinstein_breakout_trade;
         "strategy wiring accepts ad_bars + sector ETFs + globals"
         >:: test_weinstein_strategy_wiring_smoke;
       ]

let () = run_test_tt_main suite
