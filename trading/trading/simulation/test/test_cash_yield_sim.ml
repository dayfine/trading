(** Simulator wiring for the cash yield (#3137 part 1): the default (no accrual)
    leaves cash and the metric set untouched; an armed accrual credits interest
    every calendar day from its start date (never before it) and reports
    [CashInterestTotal]; a rate series starting after the accrual start fails
    the run instead of earning a silent zero. *)

open OUnit2
open Core
open Matchers
open Trading_simulation.Simulator
open Test_helpers
module Cash_yield = Trading_simulation_cash_yield.Cash_yield
module Metric_types = Trading_simulation_types.Metric_types
module Strategy_interface = Trading_strategy.Strategy_interface

let _date = Date.of_string
let _initial_cash = 100_000.0

let _bar d : Types.Daily_price.t =
  {
    date = _date d;
    open_price = 50.0;
    high_price = 50.0;
    low_price = 50.0;
    close_price = 50.0;
    adjusted_close = 50.0;
    volume = 1_000_000;
    active_through = None;
  }

let _bars =
  List.map
    [ "2024-01-02"; "2024-01-03"; "2024-01-04"; "2024-01-05"; "2024-01-08" ]
    ~f:_bar

(* Holds cash only: no transitions, so cash moves by interest alone. *)
let _idle_strategy : (module Strategy_interface.STRATEGY) =
  let module S : Strategy_interface.STRATEGY = struct
    let name = "Idle"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Ok { Strategy_interface.transitions = [] }
  end in
  (module S)

(* Steps run 2024-01-01 .. 2024-01-09 (end date exclusive): 9 calendar days. *)
let _config =
  {
    Trading_simulation_types.Simulator_types.start_date = _date "2024-01-01";
    end_date = _date "2024-01-10";
    initial_cash = _initial_cash;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _run ~test_name ?cash_yield () =
  let result = ref None in
  with_test_data test_name [ ("AAPL", _bars) ] ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir ~strategy:_idle_strategy
          ~commission:_config.commission ?cash_yield ()
      in
      result := Some (run (create_exn ~config:_config ~deps)));
  Option.value_exn !result

(* 3.6 %/yr, no fee: exactly 1 bp per calendar day under ACT/360. *)
let _one_bp_a_day = Cash_yield.constant ~rate_pct:3.6 ~fee_bp:0.0

let test_default_accrues_nothing _ =
  assert_that
    (_run ~test_name:"cash_yield_default" ())
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (r : run_result) -> r.final_portfolio.current_cash)
              (float_equal _initial_cash);
            field
              (fun (r : run_result) ->
                Map.mem r.metrics Metric_types.CashInterestTotal)
              (equal_to false);
          ]))

(* Armed from 01-03: days 01-03 .. 01-09 accrue (7 days, weekend included);
   01-01 and 01-02 are the "warmup" and earn nothing. *)
let test_armed_accrues_from_start_date _ =
  let acc = Cash_yield.Accrual.create _one_bp_a_day ~start_date:(_date "2024-01-03") in
  let interest = _initial_cash *. ((1.0001 ** 7.0) -. 1.0) in
  assert_that
    (_run ~test_name:"cash_yield_armed" ~cash_yield:acc ())
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (r : run_result) -> r.final_portfolio.current_cash)
              (float_equal ~epsilon:1e-6 (_initial_cash +. interest));
            field
              (fun (r : run_result) -> r.metrics)
              (contains_entry Metric_types.CashInterestTotal
                 (float_equal ~epsilon:1e-6 interest));
          ]))

let test_series_starting_late_fails_the_run _ =
  let late =
    Option.value_exn
      (Result.ok
         (Cash_yield.of_series [ (_date "2024-01-05", 4.0) ] ~fee_bp:0.0))
  in
  let acc = Cash_yield.Accrual.create late ~start_date:(_date "2024-01-03") in
  assert_that
    (_run ~test_name:"cash_yield_late_series" ~cash_yield:acc ())
    (is_error_with Status.Invalid_argument)

let suite =
  "cash_yield_sim"
  >::: [
         "default accrues nothing" >:: test_default_accrues_nothing;
         "armed accrues from start date" >:: test_armed_accrues_from_start_date;
         "series starting late fails the run"
         >:: test_series_starting_late_fails_the_run;
       ]

let () = run_test_tt_main suite
