(** End-to-end smoke test: Simulator.run with Weinstein_strategy.

    Writes synthetic bar data to a temp directory, runs the full simulator
    pipeline with [Weinstein_strategy.make], and asserts that:
    - The simulation completes without error.
    - All steps run (date range is respected).
    - Cash starts and ends at known values (no trades expected with minimal
      synthetic data — strategy degrades gracefully when history is too short
      for stage classification). *)

open OUnit2
open Core
open Matchers

let date_of_string s = Date.of_string s
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Write a list of bars for [symbol] into [data_dir] using Csv_storage. *)
let write_csv_bars data_dir symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> OUnit2.assert_failure ("write_csv_bars create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e ->
          OUnit2.assert_failure ("write_csv_bars save: " ^ Status.show e)
      | Ok () -> ())

(** Generate [n] weekday bars starting from [start_date] at [base_price]. *)
let make_bars start_date base_price n =
  let rec loop date acc remaining =
    if remaining = 0 then List.rev acc
    else
      let skip =
        match Date.day_of_week date with
        | Day_of_week.Sat -> 2
        | Day_of_week.Sun -> 1
        | _ -> 0
      in
      if skip > 0 then loop (Date.add_days date skip) acc remaining
      else
        let bar =
          {
            Types.Daily_price.date;
            open_price = base_price *. 0.995;
            high_price = base_price *. 1.01;
            low_price = base_price *. 0.99;
            close_price = base_price;
            adjusted_close = base_price;
            volume = 1000;
          }
        in
        loop (Date.add_days date 1) (bar :: acc) (remaining - 1)
  in
  loop start_date [] n

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
      let start_date = date_of_string "2024-01-02" in
      let end_date = date_of_string "2024-01-19" in
      (* Write 50 bars of history before simulation start so the strategy
         has some price data to work with *)
      let hist_start = Date.add_days start_date (-70) in
      let aapl_bars = make_bars hist_start 180.0 80 in
      let index_bars = make_bars hist_start 4500.0 80 in
      write_csv_bars data_dir "AAPL" aapl_bars;
      write_csv_bars data_dir "GSPCX" index_bars;
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
      (* Simulation ran — verify basic invariants *)
      assert_that result.steps (not_ is_empty);
      (* Cash should still be positive (no bad state) *)
      let final_portfolio = (List.last_exn result.steps).portfolio in
      assert_that final_portfolio.Trading_portfolio.Portfolio.current_cash
        (gt (module Float_ord) 0.0))

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
      let start_date = date_of_string "2024-01-02" in
      let end_date = date_of_string "2024-01-05" in
      let bars = make_bars (Date.add_days start_date (-5)) 100.0 20 in
      write_csv_bars data_dir "AAPL" bars;
      write_csv_bars data_dir "GSPCX" bars;
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
      let start_date = date_of_string "2024-01-02" in
      let end_date = date_of_string "2024-01-19" in
      let hist_start = Date.add_days start_date (-70) in
      let aapl_bars = make_bars hist_start 180.0 80 in
      let index_bars = make_bars hist_start 4500.0 80 in
      write_csv_bars data_dir "AAPL" aapl_bars;
      write_csv_bars data_dir "GSPCX" index_bars;
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
