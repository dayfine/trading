(** Pinned tests for {!Trade_aggregates_computer} (M5.2b).

    Each test builds a small, hand-pinned fixture of round-trip trades, runs the
    computer, and asserts every metric against a value computed by hand. *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types

let _date s = Date.of_string s

let _make_trade ~id ~symbol ~side ~quantity ~price =
  {
    Trading_base.Types.id;
    order_id = id ^ "-order";
    symbol;
    side;
    quantity;
    price;
    commission = 0.0;
    timestamp = Time_ns_unix.now ();
  }

let _step_with_trades ~date ~trades : Simulator_types.step_result =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 ()
  in
  {
    date;
    portfolio;
    portfolio_value = 10_000.0;
    trades;
    orders_submitted = [];
    splits_applied = [];
  }

let _config =
  {
    Simulator_types.start_date = _date "2024-01-01";
    end_date = _date "2024-12-31";
    initial_cash = 10_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _run ?(initial_cash = 10_000.0) steps =
  let computer =
    Trading_simulation.Trade_aggregates_computer.computer ~initial_cash ()
  in
  computer.run ~config:_config ~steps

(* ----- Empty input ----- *)

let test_empty_steps_yields_zero_metrics _ =
  let metrics = _run [] in
  assert_that metrics
    (map_includes
       [
         (NumTrades, float_equal 0.0);
         (LossRate, float_equal 0.0);
         (AvgWinDollar, float_equal 0.0);
         (LargestWinDollar, float_equal 0.0);
         (LargestLossDollar, float_equal 0.0);
         (Expectancy, float_equal 0.0);
         (WinLossRatio, float_equal 0.0);
         (MaxConsecutiveWins, float_equal 0.0);
         (MaxConsecutiveLosses, float_equal 0.0);
       ])

(* ----- Mixed wins / losses ----- *)

(** Three round-trips, hand-pinned numbers:

    Trip 1: AAPL Buy@100 q=10 → Sell@120 q=10. PnL = +200, pct = +20%. Notional
    = 1000. Days held = 5. Trip 2: MSFT Buy@50 q=20 → Sell@40 q=20. PnL = -200,
    pct = -20%. Notional = 1000. Days held = 10. Trip 3: GOOG Buy@200 q=5 →
    Sell@260 q=5. PnL = +300, pct = +30%. Notional = 1000. Days held = 7.

    Wins = 2 (trips 1 + 3), losses = 1 (trip 2). win_rate = 2/3 × 100 = 66.6...
    loss_rate = 1/3 × 100 = 33.3... avg_win_dollar = (200 + 300) / 2 = 250
    avg_win_pct = (20 + 30) / 2 = 25 avg_loss_dollar = -200, avg_loss_pct = -20
    largest_win = 300, largest_loss = -200 avg_size_dollar = (1000 + 1000 +
    1000) / 3 = 1000 avg_size_pct = 1000 / 10000 × 100 = 10 avg_holding_winners
    = (5 + 7) / 2 = 6 avg_holding_losers = 10 expectancy = 0.6667 × 250 - 0.3333
    × 200 = 166.667 - 66.667 = 100 win_loss_ratio = 250 / 200 = 1.25
    consecutive: ordered by entry date — assume distinct dates, so the sequence
    is [trip1=W, trip2=L, trip3=W]. max wins = 1, max losses = 1. *)
let test_mixed_three_trips _ =
  let steps =
    [
      _step_with_trades ~date:(_date "2024-02-01")
        ~trades:
          [
            _make_trade ~id:"a-b" ~symbol:"AAPL" ~side:Buy ~quantity:10.0
              ~price:100.0;
          ];
      _step_with_trades ~date:(_date "2024-02-06")
        ~trades:
          [
            _make_trade ~id:"a-s" ~symbol:"AAPL" ~side:Sell ~quantity:10.0
              ~price:120.0;
          ];
      _step_with_trades ~date:(_date "2024-02-10")
        ~trades:
          [
            _make_trade ~id:"m-b" ~symbol:"MSFT" ~side:Buy ~quantity:20.0
              ~price:50.0;
          ];
      _step_with_trades ~date:(_date "2024-02-20")
        ~trades:
          [
            _make_trade ~id:"m-s" ~symbol:"MSFT" ~side:Sell ~quantity:20.0
              ~price:40.0;
          ];
      _step_with_trades ~date:(_date "2024-03-01")
        ~trades:
          [
            _make_trade ~id:"g-b" ~symbol:"GOOG" ~side:Buy ~quantity:5.0
              ~price:200.0;
          ];
      _step_with_trades ~date:(_date "2024-03-08")
        ~trades:
          [
            _make_trade ~id:"g-s" ~symbol:"GOOG" ~side:Sell ~quantity:5.0
              ~price:260.0;
          ];
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (NumTrades, float_equal 3.0);
         (LossRate, float_equal ~epsilon:1e-6 (1.0 /. 3.0 *. 100.0));
         (AvgWinDollar, float_equal 250.0);
         (AvgWinPct, float_equal 25.0);
         (AvgLossDollar, float_equal (-200.0));
         (AvgLossPct, float_equal (-20.0));
         (LargestWinDollar, float_equal 300.0);
         (LargestLossDollar, float_equal (-200.0));
         (AvgTradeSizeDollar, float_equal 1000.0);
         (AvgTradeSizePct, float_equal 10.0);
         (AvgHoldingDaysWinners, float_equal 6.0);
         (AvgHoldingDaysLosers, float_equal 10.0);
         (* expectancy = 2/3 × 250 − 1/3 × 200 = (500 − 200)/3 = 100. *)
         (Expectancy, float_equal ~epsilon:1e-6 100.0);
         (WinLossRatio, float_equal 1.25);
         (MaxConsecutiveWins, float_equal 1.0);
         (MaxConsecutiveLosses, float_equal 1.0);
       ])

(* ----- All wins (no losses) ----- *)

(** Two winning round-trips. avg_loss_dollar = 0 → win_loss_ratio = +∞. *)
let test_all_wins_sets_win_loss_ratio_to_infinity _ =
  let steps =
    [
      _step_with_trades ~date:(_date "2024-04-01")
        ~trades:
          [
            _make_trade ~id:"a-b" ~symbol:"AAA" ~side:Buy ~quantity:10.0
              ~price:100.0;
          ];
      _step_with_trades ~date:(_date "2024-04-08")
        ~trades:
          [
            _make_trade ~id:"a-s" ~symbol:"AAA" ~side:Sell ~quantity:10.0
              ~price:110.0;
          ];
      _step_with_trades ~date:(_date "2024-04-09")
        ~trades:
          [
            _make_trade ~id:"b-b" ~symbol:"BBB" ~side:Buy ~quantity:5.0
              ~price:200.0;
          ];
      _step_with_trades ~date:(_date "2024-04-16")
        ~trades:
          [
            _make_trade ~id:"b-s" ~symbol:"BBB" ~side:Sell ~quantity:5.0
              ~price:230.0;
          ];
    ]
  in
  let metrics = _run steps in
  let win_loss = Map.find_exn metrics WinLossRatio in
  assert_that win_loss (equal_to Float.infinity);
  assert_that metrics
    (map_includes
       [
         (NumTrades, float_equal 2.0);
         (LossRate, float_equal 0.0);
         (MaxConsecutiveWins, float_equal 2.0);
         (MaxConsecutiveLosses, float_equal 0.0);
       ])

(* ----- Consecutive run accounting ----- *)

(** Five round-trips in a [W L L W W] order — pin both consecutive runs. The PnL
    signs encode the pattern; pinned values are picked for clarity. *)
let test_consecutive_runs _ =
  let make_round_trip ~entry_date ~exit_date ~symbol ~entry_price ~exit_price =
    [
      _step_with_trades ~date:entry_date
        ~trades:
          [
            _make_trade ~id:(symbol ^ "-b") ~symbol ~side:Buy ~quantity:10.0
              ~price:entry_price;
          ];
      _step_with_trades ~date:exit_date
        ~trades:
          [
            _make_trade ~id:(symbol ^ "-s") ~symbol ~side:Sell ~quantity:10.0
              ~price:exit_price;
          ];
    ]
  in
  let steps =
    List.concat
      [
        make_round_trip ~entry_date:(_date "2024-05-01")
          ~exit_date:(_date "2024-05-05") ~symbol:"W1" ~entry_price:100.0
          ~exit_price:110.0 (* W *);
        make_round_trip ~entry_date:(_date "2024-05-06")
          ~exit_date:(_date "2024-05-10") ~symbol:"L1" ~entry_price:100.0
          ~exit_price:90.0 (* L *);
        make_round_trip ~entry_date:(_date "2024-05-11")
          ~exit_date:(_date "2024-05-15") ~symbol:"L2" ~entry_price:100.0
          ~exit_price:95.0 (* L *);
        make_round_trip ~entry_date:(_date "2024-05-16")
          ~exit_date:(_date "2024-05-20") ~symbol:"W2" ~entry_price:100.0
          ~exit_price:105.0 (* W *);
        make_round_trip ~entry_date:(_date "2024-05-21")
          ~exit_date:(_date "2024-05-25") ~symbol:"W3" ~entry_price:100.0
          ~exit_price:120.0 (* W *);
      ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (NumTrades, float_equal 5.0);
         (MaxConsecutiveWins, float_equal 2.0);
         (* W3 + W2 trailing run length 2 *)
         (MaxConsecutiveLosses, float_equal 2.0);
         (* L1 + L2 *)
       ])

(* ----- AvgTradeSizePct zero-initial-cash guard ----- *)

(** Exercises the documented [?initial_cash] default-0.0 guard in the .mli. Same
    single-trade fixture, but the computer is built without [~initial_cash] so
    the default of [0.0] applies. The guard must short- circuit the division and
    emit [AvgTradeSizePct = 0.0] (not NaN, not +inf). [AvgTradeSizeDollar] is
    unaffected by the guard and still equals the entry notional. *)
let test_avg_trade_size_pct_zero_initial_cash _ =
  let steps =
    [
      _step_with_trades ~date:(_date "2024-06-01")
        ~trades:
          [
            _make_trade ~id:"x-b" ~symbol:"XYZ" ~side:Buy ~quantity:10.0
              ~price:100.0;
          ];
      _step_with_trades ~date:(_date "2024-06-08")
        ~trades:
          [
            _make_trade ~id:"x-s" ~symbol:"XYZ" ~side:Sell ~quantity:10.0
              ~price:110.0;
          ];
    ]
  in
  let computer = Trading_simulation.Trade_aggregates_computer.computer () in
  let metrics = computer.run ~config:_config ~steps in
  assert_that metrics
    (map_includes
       [
         (NumTrades, float_equal 1.0);
         (AvgTradeSizeDollar, float_equal 1000.0);
         (AvgTradeSizePct, float_equal 0.0);
       ])

let suite =
  "Trade_aggregates_computer"
  >::: [
         "empty steps yields zero metrics"
         >:: test_empty_steps_yields_zero_metrics;
         "mixed three round-trips, all values pinned" >:: test_mixed_three_trips;
         "all wins → win/loss ratio = infinity"
         >:: test_all_wins_sets_win_loss_ratio_to_infinity;
         "consecutive runs over [W L L W W]" >:: test_consecutive_runs;
         "AvgTradeSizePct = 0 when initial_cash defaults to 0"
         >:: test_avg_trade_size_pct_zero_initial_cash;
       ]

let () = run_test_tt_main suite
