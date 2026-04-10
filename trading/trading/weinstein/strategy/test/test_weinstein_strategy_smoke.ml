(** End-to-end smoke test: Simulator.run with Weinstein_strategy.

    Writes synthetic bar data to a temp directory using [Synthetic_source], then
    runs the full simulator pipeline with [Weinstein_strategy.make].

    {1 Slice 2 infrastructure (now implemented)}

    - Bar accumulation: per-symbol daily bar buffer in the [make] closure,
      converted to weekly via [Time_period.Conversion.daily_to_weekly]. History
      starts at 2022-01-01 (100+ weekly bars of warmup).
    - Portfolio value: derived via [Portfolio_view.portfolio_value] from the
      [Portfolio_view.t] passed to [on_market_close]. Used for position sizing.
    - MA direction: computed from [Stage.classify] on the bar buffer (not
      hardcoded [Flat]).
    - Simulation date: uses current bar's date (not [Date.today]).

    {1 Trade assertion status}

    The screener cascade (macro gate, is_breakout_candidate, sector filter,
    grade floor) does not produce buy candidates with a pure [Trending] pattern
    because [is_breakout_candidate] requires either a Stage 1 → 2 transition or
    very early Stage 2 (weeks_advancing <= 4). A long-running trend exceeds this
    threshold. Trade assertions require a [Breakout] pattern with carefully
    timed parameters — deferred to Slice 3 (screener-aware test data).

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
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "weinstein_strategy_smoke"
  >::: [
         "smoke test completes without error" >:: test_weinstein_strategy_smoke;
         "simulation respects date range" >:: test_weinstein_date_range;
         "weekly cadence exercises Friday-gated strategy path"
         >:: test_weinstein_weekly_cadence;
       ]

let () = run_test_tt_main suite
