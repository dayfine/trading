(** Pinned tests for {!Stability_turnover_computer}.

    Coverage:
    - [RollingSharpeStability] on a hand-rolled regime-switch equity curve:
      stable regime then erratic regime → nonzero positive stdev.
    - [PositionTurnover]: buy-and-hold scenario → 0; daily-rebalance scenario →
      strictly positive.
    - [PositionConcentrationHhi]: equal-weight two-symbol Friday book → 0.5;
      single-symbol Friday book → 1.0.
    - [TradeFrequencyAnnualized] (derived): NumTrades + window → trades/yr. *)

open OUnit2
open Core
open Trading_simulation_types.Metric_types
open Matchers
module Simulator_types = Trading_simulation_types.Simulator_types
module Portfolio_summary = Trading_simulation_types.Portfolio_summary

let _date s = Date.of_string s

let _config ?(start_date = _date "2024-01-01") ?(end_date = _date "2024-12-31")
    () =
  {
    Simulator_types.start_date;
    end_date;
    initial_cash = 100_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

(** Build a [position_summary] with the symbol's quantity and cost_basis. The
    HHI metric reads only [|cost_basis|]; the turnover metric reads only the
    same field (no [quantity] dependency in the current implementation). *)
let _pos ~symbol ~cost_basis : Portfolio_summary.position_summary =
  { symbol; quantity = 1.0; cost_basis }

let _summary ~cash ~positions : Portfolio_summary.t =
  let position_value_total =
    List.fold positions ~init:0.0
      ~f:(fun acc (p : Portfolio_summary.position_summary) ->
        acc +. Float.abs p.cost_basis)
  in
  { current_cash = cash; positions; position_value_total }

let _make_step ?(positions = []) ?(cash = 100_000.0) ~date ~portfolio_value () :
    Simulator_types.step_result =
  {
    date;
    portfolio = _summary ~cash ~positions;
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars = true;
  }

let _run steps =
  let computer = Trading_simulation.Stability_turnover_computer.computer () in
  computer.run ~config:(_config ()) ~steps

(** Hand-rolled equity curve: first half is gentle steady growth (low Sharpe
    volatility within each 90-day window), second half lurches between large
    gains and losses (high Sharpe volatility within each 90-day window). Two
    regimes → rolling-Sharpe series has nonzero spread. *)
let test_rolling_sharpe_stability_regime_switch _ =
  let make_returns regime_steady regime_erratic =
    List.init regime_steady ~f:(fun _ -> 0.05)
    @ List.init regime_erratic ~f:(fun i -> if i % 2 = 0 then 2.0 else -1.8)
  in
  (* 200 steady days + 200 erratic days = 400 days; enough for >2 windows of 90. *)
  let returns = make_returns 200 200 in
  let steps =
    List.folding_map returns ~init:100_000.0 ~f:(fun pv r ->
        let next = pv *. (1.0 +. (r /. 100.0)) in
        (next, next))
    |> List.mapi ~f:(fun i pv ->
        _make_step
          ~date:(Date.add_days (_date "2024-01-02") i)
          ~portfolio_value:pv ())
  in
  let metrics = _run steps in
  assert_that
    (Map.find_exn metrics RollingSharpeStability)
    (gt (module Float_ord) 0.0)

let test_position_turnover_buy_and_hold _ =
  (* Same positions held every day → zero turnover.
     Also pins [RollingSharpeStability] = 0.0 for a 30-day window: fewer than
     two full 90-day windows fit, so the .mli guard "0.0 when fewer than two
     full windows are available" is exercised here. *)
  let positions = [ _pos ~symbol:"AAPL" ~cost_basis:50_000.0 ] in
  let steps =
    List.init 30 ~f:(fun i ->
        _make_step ~positions ~cash:50_000.0
          ~date:(Date.add_days (_date "2024-01-02") i)
          ~portfolio_value:100_000.0 ())
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes
       [
         (PositionTurnover, float_equal ~epsilon:1e-9 0.0);
         (RollingSharpeStability, float_equal ~epsilon:1e-9 0.0);
       ])

let test_position_turnover_daily_rebalance _ =
  (* Alternate between two symbols every day → high turnover. *)
  let positions_a = [ _pos ~symbol:"AAPL" ~cost_basis:50_000.0 ] in
  let positions_b = [ _pos ~symbol:"MSFT" ~cost_basis:50_000.0 ] in
  let steps =
    List.init 20 ~f:(fun i ->
        let positions = if i % 2 = 0 then positions_a else positions_b in
        _make_step ~positions ~cash:50_000.0
          ~date:(Date.add_days (_date "2024-01-02") i)
          ~portfolio_value:100_000.0 ())
  in
  let metrics = _run steps in
  assert_that
    (Map.find_exn metrics PositionTurnover)
    (gt (module Float_ord) 0.0)

let test_hhi_equal_weight_two_symbols_on_friday _ =
  (* 2024-01-05 is a Friday. Two equal-cost-basis positions → HHI = 2 × 0.25
     = 0.5. *)
  let positions =
    [
      _pos ~symbol:"AAPL" ~cost_basis:50_000.0;
      _pos ~symbol:"MSFT" ~cost_basis:50_000.0;
    ]
  in
  let steps =
    [
      _make_step ~positions ~cash:0.0 ~date:(_date "2024-01-05")
        ~portfolio_value:100_000.0 ();
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes [ (PositionConcentrationHhi, float_equal ~epsilon:1e-9 0.5) ])

let test_hhi_single_position_on_friday _ =
  (* Friday with one position → HHI = 1.0. *)
  let positions = [ _pos ~symbol:"AAPL" ~cost_basis:100_000.0 ] in
  let steps =
    [
      _make_step ~positions ~cash:0.0 ~date:(_date "2024-01-05")
        ~portfolio_value:100_000.0 ();
    ]
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes [ (PositionConcentrationHhi, float_equal ~epsilon:1e-9 1.0) ])

let test_hhi_no_friday_yields_zero _ =
  (* All steps on non-Friday weekdays (Mon-Thu) → no samples → 0.0. *)
  let positions = [ _pos ~symbol:"AAPL" ~cost_basis:50_000.0 ] in
  let steps =
    List.init 4 ~f:(fun i ->
        _make_step ~positions ~cash:50_000.0
          ~date:(Date.add_days (_date "2024-01-01") i)
          ~portfolio_value:100_000.0 ())
  in
  let metrics = _run steps in
  assert_that metrics
    (map_includes [ (PositionConcentrationHhi, float_equal ~epsilon:1e-9 0.0) ])

(** Cover the derived computer end-to-end: feed a small [NumTrades] base set
    through the registered derived rule. *)
let test_trade_frequency_annualized_derived _ =
  let config =
    _config ~start_date:(_date "2023-01-01") ~end_date:(_date "2024-01-01") ()
  in
  let derived =
    Trading_simulation.Stability_turnover_computer
    .trade_frequency_annualized_derived
  in
  let base_metrics =
    Trading_simulation_types.Metric_types.singleton NumTrades 50.0
  in
  let result = derived.compute ~config ~base_metrics in
  (* 50 round-trips across 365 days → 50 × 365.25 / 365 ≈ 50.034. *)
  assert_that
    (Map.find_exn result TradeFrequencyAnnualized)
    (float_equal ~epsilon:0.1 50.034)

let test_trade_frequency_annualized_zero_window _ =
  let config =
    _config ~start_date:(_date "2024-01-01") ~end_date:(_date "2024-01-01") ()
  in
  let derived =
    Trading_simulation.Stability_turnover_computer
    .trade_frequency_annualized_derived
  in
  let base_metrics =
    Trading_simulation_types.Metric_types.singleton NumTrades 10.0
  in
  let result = derived.compute ~config ~base_metrics in
  assert_that result
    (map_includes [ (TradeFrequencyAnnualized, float_equal ~epsilon:1e-9 0.0) ])

let suite =
  "Stability_turnover_computer"
  >::: [
         "rolling sharpe stability: regime switch → nonzero spread"
         >:: test_rolling_sharpe_stability_regime_switch;
         "position turnover: buy-and-hold → 0"
         >:: test_position_turnover_buy_and_hold;
         "position turnover: daily rebalance → positive"
         >:: test_position_turnover_daily_rebalance;
         "hhi: equal-weight two symbols on Friday → 0.5"
         >:: test_hhi_equal_weight_two_symbols_on_friday;
         "hhi: single position on Friday → 1.0"
         >:: test_hhi_single_position_on_friday;
         "hhi: no Friday samples → 0.0" >:: test_hhi_no_friday_yields_zero;
         "trade frequency annualized derived: NumTrades over 1y → ≈ NumTrades"
         >:: test_trade_frequency_annualized_derived;
         "trade frequency annualized: zero-length window → 0"
         >:: test_trade_frequency_annualized_zero_window;
       ]

let () = run_test_tt_main suite
