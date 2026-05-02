open OUnit2
open Core
open Trading_simulation.Metrics
open Trading_simulation_types.Metric_types
open Trading_simulation_types.Metric_info_registry
open Trading_simulation.Metric_computers
open Trading_simulation.Simulator
open Matchers

let date_of_string s = Date.of_string s

(** Helper to run metric computers over steps and merge results *)
let run_computers ~computers ~config ~steps =
  List.fold computers ~init:empty ~f:(fun acc (c : any_metric_computer) ->
      merge acc (c.run ~config ~steps))

(* ==================== Metric Set Tests ==================== *)

let test_singleton _ =
  let metrics = singleton SharpeRatio 1.5 in
  assert_that metrics (contains_entry SharpeRatio (float_equal 1.5))

let test_of_alist_exn _ =
  let metrics =
    of_alist_exn [ (TotalPnl, 100.0); (SharpeRatio, 1.5); (MaxDrawdown, 5.0) ]
  in
  assert_that metrics
    (map_includes
       [
         (TotalPnl, float_equal 100.0);
         (SharpeRatio, float_equal 1.5);
         (MaxDrawdown, float_equal 5.0);
       ])

let test_merge _ =
  let m1 = of_alist_exn [ (TotalPnl, 100.0); (SharpeRatio, 1.0) ] in
  let m2 = of_alist_exn [ (SharpeRatio, 2.0); (MaxDrawdown, 5.0) ] in
  let merged = merge m1 m2 in
  assert_that merged
    (map_includes
       [
         (TotalPnl, float_equal 100.0);
         (SharpeRatio, float_equal 2.0);
         (MaxDrawdown, float_equal 5.0);
       ])

(* ==================== Format Tests ==================== *)

let test_format_metric_dollars _ =
  assert_that (format_metric TotalPnl 1234.56) (equal_to "Total P&L: $1234.56")

let test_format_metric_percent _ =
  assert_that (format_metric WinRate 75.5) (equal_to "Win Rate: 75.50%")

let test_format_metric_days _ =
  assert_that
    (format_metric AvgHoldingDays 12.5)
    (equal_to "Avg Holding Period: 12.5 days")

let test_format_metric_count _ =
  assert_that (format_metric WinCount 42.0) (equal_to "Winning Trades: 42")

let test_format_metric_ratio _ =
  assert_that
    (format_metric SharpeRatio 1.2345)
    (equal_to "Sharpe Ratio: 1.2345")

let test_format_metrics_multiple _ =
  let metrics = of_alist_exn [ (TotalPnl, 100.0); (WinRate, 50.0) ] in
  let s = format_metrics metrics in
  assert_bool "contains Total P&L"
    (String.is_substring s ~substring:"Total P&L");
  assert_bool "contains Win Rate" (String.is_substring s ~substring:"Win Rate")

(* ==================== Summary Stats Conversion Tests ==================== *)

let test_summary_stats_to_metrics _ =
  let stats =
    {
      total_pnl = 1500.0;
      avg_holding_days = 5.5;
      win_count = 7;
      loss_count = 3;
      win_rate = 70.0;
    }
  in
  let metrics = summary_stats_to_metrics stats in
  assert_that metrics
    (map_includes
       [
         (TotalPnl, float_equal 1500.0);
         (WinRate, float_equal 70.0);
         (WinCount, float_equal 7.0);
         (LossCount, float_equal 3.0);
         (AvgHoldingDays, float_equal 5.5);
       ])

(* ==================== extract_round_trips Tests ==================== *)

(** Build a trade record. Defaults the boilerplate fields so test cases stay
    focused on the side / price / quantity that matters. *)
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

(** Wrap a list of trades in a single [step_result] on [date]. The portfolio +
    portfolio_value fields are placeholders — [extract_round_trips] only
    consumes [step.trades] and [step.date]. *)
let _step_with_trades ~date ~trades =
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  {
    date;
    portfolio;
    portfolio_value = 10000.0;
    trades;
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
  }

(** Long round-trip: Buy@100 → Sell@110, quantity 10, profit $100. Pins the
    pre-existing contract — this test must keep passing after the short-side
    extension. *)
let test_extract_round_trips_long_pair _ =
  let buy =
    _make_trade ~id:"b1" ~symbol:"AAPL" ~side:Buy ~quantity:10.0 ~price:100.0
  in
  let sell =
    _make_trade ~id:"s1" ~symbol:"AAPL" ~side:Sell ~quantity:10.0 ~price:110.0
  in
  let steps =
    [
      _step_with_trades ~date:(date_of_string "2024-01-02") ~trades:[ buy ];
      _step_with_trades ~date:(date_of_string "2024-01-12") ~trades:[ sell ];
    ]
  in
  let trips = extract_round_trips steps in
  assert_that trips
    (elements_are
       [
         all_of
           [
             field (fun (t : trade_metrics) -> t.symbol) (equal_to "AAPL");
             field
               (fun (t : trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Buy);
             field
               (fun (t : trade_metrics) -> t.entry_price)
               (float_equal 100.0);
             field (fun (t : trade_metrics) -> t.exit_price) (float_equal 110.0);
             field (fun (t : trade_metrics) -> t.quantity) (float_equal 10.0);
             field
               (fun (t : trade_metrics) -> t.pnl_dollars)
               (float_equal 100.0);
             field (fun (t : trade_metrics) -> t.pnl_percent) (float_equal 10.0);
             field (fun (t : trade_metrics) -> t.days_held) (equal_to 10);
           ];
       ])

(** Short round-trip: Sell@110 → Buy@100 covers a short. Cover below entry means
    the short was profitable: pnl_dollars = (entry − cover) × qty = (110 − 100)
    × 10 = $100. Pins gap G2 from [dev/notes/short-side-gaps-2026-04-29.md]. *)
let test_extract_round_trips_short_pair_profit _ =
  let sell =
    _make_trade ~id:"s1" ~symbol:"BEAR" ~side:Sell ~quantity:10.0 ~price:110.0
  in
  let buy =
    _make_trade ~id:"b1" ~symbol:"BEAR" ~side:Buy ~quantity:10.0 ~price:100.0
  in
  let steps =
    [
      _step_with_trades ~date:(date_of_string "2024-01-02") ~trades:[ sell ];
      _step_with_trades ~date:(date_of_string "2024-01-09") ~trades:[ buy ];
    ]
  in
  let trips = extract_round_trips steps in
  assert_that trips
    (elements_are
       [
         all_of
           [
             field (fun (t : trade_metrics) -> t.symbol) (equal_to "BEAR");
             field
               (fun (t : trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Sell);
             (* Entry = sell-side fill price, exit = buy-to-cover fill price. *)
             field
               (fun (t : trade_metrics) -> t.entry_price)
               (float_equal 110.0);
             field (fun (t : trade_metrics) -> t.exit_price) (float_equal 100.0);
             field (fun (t : trade_metrics) -> t.quantity) (float_equal 10.0);
             (* (entry − cover) × qty = (110 − 100) × 10 = +100 *)
             field
               (fun (t : trade_metrics) -> t.pnl_dollars)
               (float_equal 100.0);
             (* pnl percent: (entry − cover) / entry × 100 = 10/110 × 100 *)
             field
               (fun (t : trade_metrics) -> t.pnl_percent)
               (float_equal ~epsilon:1e-6 (10.0 /. 110.0 *. 100.0));
             field (fun (t : trade_metrics) -> t.days_held) (equal_to 7);
           ];
       ])

(** Short round-trip with a cover ABOVE entry: short took a loss. P&L for a
    short is (entry − cover) × qty, so cover above entry yields negative. *)
let test_extract_round_trips_short_pair_loss _ =
  let sell =
    _make_trade ~id:"s1" ~symbol:"BEAR" ~side:Sell ~quantity:10.0 ~price:100.0
  in
  let buy =
    _make_trade ~id:"b1" ~symbol:"BEAR" ~side:Buy ~quantity:10.0 ~price:120.0
  in
  let steps =
    [
      _step_with_trades ~date:(date_of_string "2024-01-02") ~trades:[ sell ];
      _step_with_trades ~date:(date_of_string "2024-01-09") ~trades:[ buy ];
    ]
  in
  let trips = extract_round_trips steps in
  assert_that trips
    (elements_are
       [
         all_of
           [
             field
               (fun (t : trade_metrics) -> t.side)
               (equal_to Trading_base.Types.Sell);
             (* (100 − 120) × 10 = −200 *)
             field
               (fun (t : trade_metrics) -> t.pnl_dollars)
               (float_equal (-200.0));
             field
               (fun (t : trade_metrics) -> t.pnl_percent)
               (float_equal ~epsilon:1e-6 (-20.0));
           ];
       ])

(** Long and short legs in the same run, on different symbols, must both be
    paired up — independent per-symbol pairing means the order they arrive at
    [extract_round_trips] does not matter. *)
let test_extract_round_trips_long_and_short_mixed _ =
  let long_buy =
    _make_trade ~id:"l1" ~symbol:"AAPL" ~side:Buy ~quantity:5.0 ~price:200.0
  in
  let long_sell =
    _make_trade ~id:"l2" ~symbol:"AAPL" ~side:Sell ~quantity:5.0 ~price:220.0
  in
  let short_sell =
    _make_trade ~id:"s1" ~symbol:"BEAR" ~side:Sell ~quantity:10.0 ~price:50.0
  in
  let short_buy =
    _make_trade ~id:"s2" ~symbol:"BEAR" ~side:Buy ~quantity:10.0 ~price:40.0
  in
  let steps =
    [
      _step_with_trades
        ~date:(date_of_string "2024-01-02")
        ~trades:[ long_buy; short_sell ];
      _step_with_trades
        ~date:(date_of_string "2024-01-12")
        ~trades:[ long_sell; short_buy ];
    ]
  in
  let trips = extract_round_trips steps in
  let by_symbol =
    List.fold trips
      ~init:(Map.empty (module String))
      ~f:(fun acc (m : trade_metrics) -> Map.set acc ~key:m.symbol ~data:m)
  in
  assert_that by_symbol
    (map_includes
       [
         ( "AAPL",
           all_of
             [
               field
                 (fun (t : trade_metrics) -> t.side)
                 (equal_to Trading_base.Types.Buy);
               field
                 (fun (t : trade_metrics) -> t.pnl_dollars)
                 (float_equal 100.0);
             ] );
         ( "BEAR",
           all_of
             [
               field
                 (fun (t : trade_metrics) -> t.side)
                 (equal_to Trading_base.Types.Sell);
               field
                 (fun (t : trade_metrics) -> t.pnl_dollars)
                 (float_equal 100.0);
             ] );
       ])

(** A dangling Sell with no Buy follow-up (e.g., open short position at the end
    of the simulation window) must NOT be reported as a round-trip. The pairing
    only fires when a complete close trade arrives. *)
let test_extract_round_trips_unclosed_short_dropped _ =
  let sell =
    _make_trade ~id:"s1" ~symbol:"BEAR" ~side:Sell ~quantity:10.0 ~price:100.0
  in
  let steps =
    [ _step_with_trades ~date:(date_of_string "2024-01-02") ~trades:[ sell ] ]
  in
  let trips = extract_round_trips steps in
  assert_that trips (size_is 0)

(* ==================== Metric Computer Tests ==================== *)

(* Helper to create a mock step_result *)
let make_step_result ~date ~portfolio_value =
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  {
    date;
    portfolio;
    portfolio_value;
    trades = [];
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
  }

let make_config () =
  {
    start_date = date_of_string "2024-01-01";
    end_date = date_of_string "2024-01-10";
    initial_cash = 10000.0;
    commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

(* ==================== Sharpe Ratio Tests ==================== *)

let test_sharpe_ratio_zero_with_no_data _ =
  let config = make_config () in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps:[] in
  assert_that metrics (contains_entry SharpeRatio (float_equal 0.0))

let test_sharpe_ratio_zero_with_single_point _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry SharpeRatio (float_equal 0.0))

let test_sharpe_ratio_zero_with_constant_value _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry SharpeRatio (float_equal 0.0))

let test_sharpe_ratio_positive_with_gains _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10200.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:10300.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* Consistent ~1% daily gains yield high Sharpe due to low volatility *)
  assert_that
    (Map.find metrics SharpeRatio)
    (is_some_and (float_equal ~epsilon:100.0 1963.0))

let test_sharpe_ratio_negative_with_losses _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9900.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:9800.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:9700.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* Consistent ~1% daily losses yield negative Sharpe with low volatility *)
  assert_that
    (Map.find metrics SharpeRatio)
    (is_some_and (float_equal ~epsilon:100.0 (-1925.0)))

let test_sharpe_ratio_with_risk_free_rate _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10200.0;
    ]
  in
  let computer_no_rf = sharpe_ratio_computer () in
  let computer_with_rf = sharpe_ratio_computer ~risk_free_rate:0.05 () in
  let metrics_no_rf =
    run_computers ~computers:[ computer_no_rf ] ~config ~steps
  in
  let metrics_with_rf =
    run_computers ~computers:[ computer_with_rf ] ~config ~steps
  in
  let sharpe_no_rf = Map.find_exn metrics_no_rf SharpeRatio in
  let sharpe_with_rf = Map.find_exn metrics_with_rf SharpeRatio in
  assert_that sharpe_with_rf (lt (module Float_ord) sharpe_no_rf)

(* ==================== Maximum Drawdown Tests ==================== *)

let test_max_drawdown_zero_with_no_decline _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10200.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry MaxDrawdown (float_equal 0.0))

let test_max_drawdown_captures_decline _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:11000.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:9900.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry MaxDrawdown (float_equal 10.0))

let test_max_drawdown_captures_largest _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9500.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:12000.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:9600.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry MaxDrawdown (float_equal 20.0))

let test_max_drawdown_with_recovery _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9000.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10500.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:10500.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry MaxDrawdown (float_equal 10.0))

(* ==================== Summary Computer Tests ==================== *)

let test_summary_computer_with_no_trades _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = summary_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* No round-trip trades, but ProfitFactor is always emitted (0.0) *)
  assert_that metrics (contains_entry ProfitFactor (float_equal 0.0))

(* ==================== Multiple Computers Tests ==================== *)

let test_run_computers_combines_results _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10000.0;
    ]
  in
  let computers = [ sharpe_ratio_computer (); max_drawdown_computer () ] in
  let metrics = run_computers ~computers ~config ~steps in
  (* Sharpe: 1% gain then ~1% loss, near-zero mean return *)
  assert_that
    (Map.find metrics SharpeRatio)
    (is_some_and (float_equal ~epsilon:1.0 0.0));
  (* Max drawdown: peak 10100 -> 10000 = 0.99% decline *)
  assert_that
    (Map.find metrics MaxDrawdown)
    (is_some_and (float_equal ~epsilon:0.01 0.99))

let test_default_computers _ =
  let computers = default_computers () in
  (* Default set: summary, sharpe, max_drawdown, cagr, portfolio_state,
     trade_aggregates (M5.2b), return_basics (M5.2b), omega_ratio (M5.2c),
     drawdown_analytics (M5.2c), distributional (M5.2d), antifragility
     (M5.2d). *)
  assert_that computers (size_is 11)

(* ==================== Factory Tests ==================== *)

let test_create_computer_sharpe _ =
  let computer = create_computer SharpeRatio in
  let config = make_config () in
  let steps = [] in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry SharpeRatio (float_equal 0.0))

let test_create_computer_max_drawdown _ =
  let computer = create_computer MaxDrawdown in
  let config = make_config () in
  let steps = [] in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry MaxDrawdown (float_equal 0.0))

(* ==================== Profit Factor Tests ==================== *)

let test_profit_factor_all_winners _ =
  let config = make_config () in
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let buy_trade =
    {
      Trading_base.Types.id = "t1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = 10.0;
      price = 100.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let sell_trade =
    {
      Trading_base.Types.id = "t2";
      order_id = "o2";
      symbol = "AAPL";
      side = Sell;
      quantity = 10.0;
      price = 110.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let steps =
    [
      {
        date = date_of_string "2024-01-01";
        portfolio;
        portfolio_value = 10000.0;
        trades = [ buy_trade ];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
      {
        date = date_of_string "2024-01-10";
        portfolio;
        portfolio_value = 10100.0;
        trades = [ sell_trade ];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = summary_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (Map.find metrics ProfitFactor)
    (is_some_and (float_equal Float.infinity))

let test_profit_factor_no_trades _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = summary_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry ProfitFactor (float_equal 0.0))

(* ==================== compute_round_trip_metric_set Tests ==================== *)

(** Build a synthetic [trade_metrics] record. Defaults the boilerplate fields so
    test cases stay focused on [side] and [pnl_dollars]. *)
let _make_round_trip ?(symbol = "SYM") ?(side = Trading_base.Types.Buy)
    ?(entry_date = date_of_string "2024-01-02")
    ?(exit_date = date_of_string "2024-01-12") ?(days_held = 10)
    ?(entry_price = 100.0) ?(exit_price = 110.0) ?(quantity = 10.0) ~pnl_dollars
    () =
  let pnl_percent = pnl_dollars /. (entry_price *. quantity) *. 100.0 in
  {
    symbol;
    side;
    entry_date;
    exit_date;
    days_held;
    entry_price;
    exit_price;
    quantity;
    pnl_dollars;
    pnl_percent;
  }

(** The flagship invariant: WinCount + LossCount equal the round-trip count, and
    both reflect [pnl_dollars]'s sign. Synthetic 5 round-trips with 3 long wins,
    1 long loss, 1 short win → [n_wins = 4], [n_losses = 1]. Pre-fix to
    [Backtest.Runner._make_summary], the simulator's Summary_computer counted
    warmup-window pairs that the runner's range-filtered [round_trips] did not,
    so summary's WinCount disagreed with [List.count round_trips ~f:(pnl > 0)].
    This test pins [compute_round_trip_metric_set] — the fix's load-bearing
    helper — to the round-trip-derived count, which is what trades.csv reports.
*)
let test_compute_round_trip_metric_set_mixed_long_short _ =
  let round_trips =
    [
      _make_round_trip ~symbol:"LONG_W1" ~side:Buy ~pnl_dollars:100.0 ();
      _make_round_trip ~symbol:"LONG_W2" ~side:Buy ~pnl_dollars:200.0 ();
      _make_round_trip ~symbol:"LONG_W3" ~side:Buy ~pnl_dollars:300.0 ();
      _make_round_trip ~symbol:"LONG_L1" ~side:Buy ~pnl_dollars:(-150.0) ();
      _make_round_trip ~symbol:"SHORT_W1" ~side:Sell ~pnl_dollars:50.0 ();
    ]
  in
  let metrics = compute_round_trip_metric_set round_trips in
  (* WinCount + LossCount must equal the round-trip count (no overcounting,
     no off-by-one), and the win count must equal the arithmetic count of
     pnl_dollars > 0 — the same predicate the reconciler applies to
     trades.csv. *)
  let arithmetic_wins =
    List.count round_trips ~f:(fun (m : trade_metrics) ->
        Float.(m.pnl_dollars > 0.0))
  in
  assert_that arithmetic_wins (equal_to 4);
  assert_that metrics
    (map_includes
       [
         (WinCount, float_equal 4.0);
         (LossCount, float_equal 1.0);
         (WinRate, float_equal 80.0);
         (TotalPnl, float_equal 500.0);
         (* gross_profit = 100+200+300+50 = 650; gross_loss = 150;
            profit_factor = 650 / 150 ≈ 4.333... *)
         (ProfitFactor, float_equal ~epsilon:1e-6 (650.0 /. 150.0));
       ])

(** Empty round-trip list emits only [ProfitFactor = 0.0], matching the legacy
    [Summary_computer] convention (so existing callers / goldens that pin "no
    trades" → [ProfitFactor = 0] stay green). The win/loss counts are omitted
    from the overlay; the runner's [Metric_types.merge sim_metrics overlay]
    therefore falls back to the simulator's WinCount/LossCount when the runner's
    range-filtered [round_trips] is empty — which means the simulator's reading
    also produced no round-trips on the steps it saw, so this is a graceful
    no-op. *)
let test_compute_round_trip_metric_set_empty _ =
  let metrics = compute_round_trip_metric_set [] in
  assert_that metrics (contains_entry ProfitFactor (float_equal 0.0));
  assert_that (Map.mem metrics WinCount) (equal_to false);
  assert_that (Map.mem metrics LossCount) (equal_to false);
  assert_that (Map.mem metrics TotalPnl) (equal_to false)

(** All winners → [LossCount = 0], [ProfitFactor = +inf] (matches the existing
    profit-factor convention from Summary_computer). *)
let test_compute_round_trip_metric_set_all_winners _ =
  let round_trips =
    [
      _make_round_trip ~symbol:"W1" ~pnl_dollars:50.0 ();
      _make_round_trip ~symbol:"W2" ~pnl_dollars:75.0 ();
    ]
  in
  let metrics = compute_round_trip_metric_set round_trips in
  assert_that metrics
    (map_includes
       [
         (WinCount, float_equal 2.0);
         (LossCount, float_equal 0.0);
         (WinRate, float_equal 100.0);
         (TotalPnl, float_equal 125.0);
         (ProfitFactor, float_equal Float.infinity);
       ])

(* ==================== CAGR Tests ==================== *)

let test_cagr_zero_with_no_data _ =
  let config = make_config () in
  let computer = cagr_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps:[] in
  assert_that metrics (contains_entry CAGR (float_equal 0.0))

let test_cagr_with_growth _ =
  let config =
    {
      (make_config ()) with
      start_date = date_of_string "2023-01-01";
      end_date = date_of_string "2024-01-01";
    }
  in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2023-01-02")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:11000.0;
    ]
  in
  let computer = cagr_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* 10% growth over ~1 year should give ~10% CAGR *)
  assert_that (Map.find metrics CAGR)
    (is_some_and (float_equal ~epsilon:0.5 10.0))

let test_cagr_with_loss _ =
  let config =
    {
      (make_config ()) with
      start_date = date_of_string "2023-01-01";
      end_date = date_of_string "2024-01-01";
    }
  in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2023-01-02")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:9000.0;
    ]
  in
  let computer = cagr_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics (contains_entry CAGR (lt (module Float_ord) 0.0))

(* ==================== CalmarRatio Tests ==================== *)

let test_calmar_ratio_inputs _ =
  let config =
    {
      (make_config ()) with
      start_date = date_of_string "2023-01-01";
      end_date = date_of_string "2024-01-01";
    }
  in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2023-01-02")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2023-06-01")
        ~portfolio_value:11000.0;
      make_step_result
        ~date:(date_of_string "2023-09-01")
        ~portfolio_value:10500.0;
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:12000.0;
    ]
  in
  let computers = [ cagr_computer (); max_drawdown_computer () ] in
  let metrics = run_computers ~computers ~config ~steps in
  let cagr = Map.find_exn metrics CAGR in
  let max_dd = Map.find_exn metrics MaxDrawdown in
  (* CalmarRatio is computed by simulator post-hoc; verify inputs are present *)
  assert_that cagr (gt (module Float_ord) 0.0);
  assert_that max_dd (gt (module Float_ord) 0.0)

(* ==================== Portfolio State Tests ==================== *)

let test_portfolio_state_no_steps _ =
  let config = make_config () in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps:[] in
  assert_that (Map.is_empty metrics) (equal_to true)

let test_portfolio_state_with_trades _ =
  let config = make_config () in
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let trade =
    {
      Trading_base.Types.id = "t1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = 10.0;
      price = 100.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let steps =
    [
      {
        date = date_of_string "2024-01-01";
        portfolio;
        portfolio_value = 10000.0;
        trades = [ trade ];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
      {
        date = date_of_string "2024-01-05";
        portfolio;
        portfolio_value = 10050.0;
        trades = [ trade; trade ];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* 3 total trades across 2 steps. The portfolio passed into each step is
     the empty-positions fixture (no held positions), so OpenPositionsValue
     collapses to [portfolio_value - cash = 50.0] and UnrealizedPnl collapses
     to the same value (cost basis sum is 0 when no positions are held). *)
  assert_that
    (Map.find metrics TradeFrequency)
    (is_some_and (gt (module Float_ord) 0.0));
  assert_that
    (Map.find metrics OpenPositionCount)
    (is_some_and (float_equal 0.0));
  assert_that metrics (contains_entry OpenPositionsValue (float_equal 50.0));
  assert_that metrics (contains_entry UnrealizedPnl (float_equal 50.0))

(** Build a portfolio with one open long position by applying a buy trade. *)
let _portfolio_with_open_position ~symbol ~quantity ~price =
  let base = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let buy =
    {
      Trading_base.Types.id = "t1";
      order_id = "o1";
      symbol;
      side = Buy;
      quantity;
      price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  match Trading_portfolio.Portfolio.apply_single_trade base buy with
  | Ok p -> p
  | Error err ->
      OUnit2.assert_failure
        ("failed to build test portfolio: " ^ Status.show err)

(** Reproduces the OpenPositionsValue=0 bug (originally tracked as
    UnrealizedPnl=0 before the rename). The simulator produces a step every
    calendar day. On the final day (often a weekend), price bars are missing, so
    [_compute_portfolio_value] falls back to [portfolio_value = cash] even
    though positions are open — leaving a spurious zero in the summary. The
    computer must skip those steps and use the last real mark-to-market step. *)
let test_portfolio_state_skips_non_trading_final_step _ =
  let config = make_config () in
  let portfolio =
    _portfolio_with_open_position ~symbol:"AAPL" ~quantity:10.0 ~price:100.0
  in
  let cash = portfolio.current_cash in
  let mtm_value = cash +. (10.0 *. 105.0) in
  let steps =
    [
      {
        (* Trading day — position marked to market at $105: MTM = $1050. *)
        date = date_of_string "2024-01-05";
        portfolio;
        portfolio_value = mtm_value;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
      {
        (* Non-trading day — simulator fell back to cash. *)
        date = date_of_string "2024-01-06";
        portfolio;
        portfolio_value = cash;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* 1 long position, qty=10, entry $100, current $105:
     - OpenPositionsValue = mtm_value - cash = 1050.0 (10 * $105)
     - cost_basis sum = 10 * $100 = 1000.0
     - UnrealizedPnl = OpenPositionsValue - cost_basis = 50.0 (10 * $5 gain) *)
  assert_that metrics
    (map_includes
       [
         (* OpenPositionCount still comes from the absolute final step
            (positions don't depend on price bars). *)
         (OpenPositionCount, float_equal 1.0);
         (* OpenPositionsValue derived from the last marked-to-market step. *)
         (OpenPositionsValue, float_equal (mtm_value -. cash));
         (UnrealizedPnl, float_equal 50.0);
       ])

(** Guard: when every step is marked-to-market, the final step wins unchanged.
*)
let test_portfolio_state_uses_last_step_when_all_trading_days _ =
  let config = make_config () in
  let portfolio =
    _portfolio_with_open_position ~symbol:"AAPL" ~quantity:10.0 ~price:100.0
  in
  let cash = portfolio.current_cash in
  let steps =
    [
      {
        date = date_of_string "2024-01-05";
        portfolio;
        portfolio_value = cash +. 500.0;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
      {
        date = date_of_string "2024-01-06";
        portfolio;
        portfolio_value = cash +. 800.0;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* 1 long position, qty=10, entry $100. Final step pins
     OpenPositionsValue = 800.0 (= portfolio_value - cash). cost_basis = 10 *
     $100 = 1000.0, so UnrealizedPnl = 800 - 1000 = -200.0 — the
     hand-constructed final mtm represents an $80/share mark, i.e. a $20/share
     paper loss. *)
  assert_that metrics
    (map_includes
       [
         (OpenPositionCount, float_equal 1.0);
         (OpenPositionsValue, float_equal 800.0);
         (UnrealizedPnl, float_equal (-200.0));
       ])

(** Round-trip the new [OpenPositionsValue] / [UnrealizedPnl] split through the
    full long-only formula on a single Holding position: enter at $100, current
    bar $130, qty 100. *)
let test_portfolio_state_long_unrealized_pnl _ =
  let config = make_config () in
  let portfolio =
    _portfolio_with_open_position ~symbol:"BULL" ~quantity:100.0 ~price:100.0
  in
  let cash = portfolio.current_cash in
  let current_price = 130.0 in
  let portfolio_value = cash +. (100.0 *. current_price) in
  let steps =
    [
      {
        date = date_of_string "2024-01-05";
        portfolio;
        portfolio_value;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* 100 shares of BULL @ entry $100, current $130:
     - OpenPositionsValue = 100 * $130 = $13,000
     - UnrealizedPnl = (130 - 100) * 100 = +$3,000 *)
  assert_that metrics
    (map_includes
       [
         (OpenPositionCount, float_equal 1.0);
         (OpenPositionsValue, float_equal 13_000.0);
         (UnrealizedPnl, float_equal 3_000.0);
       ])

(** Build a portfolio with one open short position by applying a sell trade.
    Mirror of [_portfolio_with_open_position] for the short side. *)
let _portfolio_with_open_short ~symbol ~quantity ~price =
  let base = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let sell =
    {
      Trading_base.Types.id = "s1";
      order_id = "o1";
      symbol;
      side = Sell;
      quantity;
      price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  match Trading_portfolio.Portfolio.apply_single_trade base sell with
  | Ok p -> p
  | Error err ->
      OUnit2.assert_failure
        ("failed to build short test portfolio: " ^ Status.show err)

(** Short-side counterpart: enter short at $100, current bar $80, qty 100.
    OpenPositionsValue is signed-negative; UnrealizedPnl is positive (shorts
    profit on price drops). *)
let test_portfolio_state_short_unrealized_pnl _ =
  let config = make_config () in
  let portfolio =
    _portfolio_with_open_short ~symbol:"BEAR" ~quantity:100.0 ~price:100.0
  in
  let cash = portfolio.current_cash in
  let current_price = 80.0 in
  (* signed_qty = -100 ; market_value contribution = -100 * 80 = -$8,000. *)
  let portfolio_value = cash +. (-100.0 *. current_price) in
  let steps =
    [
      {
        date = date_of_string "2024-01-05";
        portfolio;
        portfolio_value;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  (* 100 shares short BEAR @ entry $100, current $80:
     - OpenPositionsValue = -100 * $80 = -$8,000 (signed: shorts contribute
       negative mtm)
     - UnrealizedPnl = (80 - 100) * (-100) = +$2,000 (short gains $20/share) *)
  assert_that metrics
    (map_includes
       [
         (OpenPositionCount, float_equal 1.0);
         (OpenPositionsValue, float_equal (-8_000.0));
         (UnrealizedPnl, float_equal 2_000.0);
       ])

(** Mixed-portfolio guard: one long + one short, hand-pinned via arithmetic.
    Confirms the signed-qty formula composes additively across positions. *)
let test_portfolio_state_mixed_unrealized_pnl _ =
  let config = make_config () in
  let base = Trading_portfolio.Portfolio.create ~initial_cash:100_000.0 () in
  let buy =
    {
      Trading_base.Types.id = "b1";
      order_id = "ob";
      symbol = "BULL";
      side = Buy;
      quantity = 100.0;
      price = 100.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let sell =
    {
      Trading_base.Types.id = "s1";
      order_id = "os";
      symbol = "BEAR";
      side = Sell;
      quantity = 50.0;
      price = 200.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio =
    match Trading_portfolio.Portfolio.apply_trades base [ buy; sell ] with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure
          ("failed to build mixed test portfolio: " ^ Status.show err)
  in
  let cash = portfolio.current_cash in
  (* BULL current $130 (long winner): mtm contribution = 100 * 130 = +$13,000;
     UnrealizedPnl_BULL = (130-100) * 100 = +$3,000.
     BEAR current $250 (short loser, price went UP): mtm contribution =
     -50 * 250 = -$12,500; UnrealizedPnl_BEAR = (250-200) * -50 = -$2,500. *)
  let bull_mtm = 100.0 *. 130.0 in
  let bear_mtm = -50.0 *. 250.0 in
  let portfolio_value = cash +. bull_mtm +. bear_mtm in
  let steps =
    [
      {
        date = date_of_string "2024-01-05";
        portfolio;
        portfolio_value;
        trades = [];
        orders_submitted = [];
        splits_applied = [];
        benchmark_return = None;
      };
    ]
  in
  let computer = portfolio_state_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics
    (map_includes
       [
         (OpenPositionCount, float_equal 2.0);
         (* +$13,000 + (-$12,500) = +$500 *)
         (OpenPositionsValue, float_equal 500.0);
         (* +$3,000 + (-$2,500) = +$500 *)
         (UnrealizedPnl, float_equal 500.0);
       ])

(* ==================== Test Suite ==================== *)

let suite =
  "Metrics Tests"
  >::: [
         (* Metric set tests *)
         "singleton" >:: test_singleton;
         "of_alist_exn" >:: test_of_alist_exn;
         "merge" >:: test_merge;
         (* Format tests *)
         "format_metric dollars" >:: test_format_metric_dollars;
         "format_metric percent" >:: test_format_metric_percent;
         "format_metric days" >:: test_format_metric_days;
         "format_metric count" >:: test_format_metric_count;
         "format_metric ratio" >:: test_format_metric_ratio;
         "format_metrics multiple" >:: test_format_metrics_multiple;
         (* Summary stats conversion *)
         "summary_stats_to_metrics" >:: test_summary_stats_to_metrics;
         (* extract_round_trips tests *)
         "extract_round_trips long pair" >:: test_extract_round_trips_long_pair;
         "extract_round_trips short pair profit"
         >:: test_extract_round_trips_short_pair_profit;
         "extract_round_trips short pair loss"
         >:: test_extract_round_trips_short_pair_loss;
         "extract_round_trips long and short mixed"
         >:: test_extract_round_trips_long_and_short_mixed;
         "extract_round_trips unclosed short dropped"
         >:: test_extract_round_trips_unclosed_short_dropped;
         (* Sharpe ratio tests *)
         "sharpe ratio zero with no data"
         >:: test_sharpe_ratio_zero_with_no_data;
         "sharpe ratio zero with single point"
         >:: test_sharpe_ratio_zero_with_single_point;
         "sharpe ratio zero with constant value"
         >:: test_sharpe_ratio_zero_with_constant_value;
         "sharpe ratio positive with gains"
         >:: test_sharpe_ratio_positive_with_gains;
         "sharpe ratio negative with losses"
         >:: test_sharpe_ratio_negative_with_losses;
         "sharpe ratio with risk free rate"
         >:: test_sharpe_ratio_with_risk_free_rate;
         (* Max drawdown tests *)
         "max drawdown zero with no decline"
         >:: test_max_drawdown_zero_with_no_decline;
         "max drawdown captures decline" >:: test_max_drawdown_captures_decline;
         "max drawdown captures largest" >:: test_max_drawdown_captures_largest;
         "max drawdown with recovery" >:: test_max_drawdown_with_recovery;
         (* Summary computer tests *)
         "summary computer with no trades"
         >:: test_summary_computer_with_no_trades;
         (* Multiple computers tests *)
         "run_computers combines results"
         >:: test_run_computers_combines_results;
         "default_computers" >:: test_default_computers;
         (* Factory tests *)
         "create_computer SharpeRatio" >:: test_create_computer_sharpe;
         "create_computer MaxDrawdown" >:: test_create_computer_max_drawdown;
         (* Profit factor tests *)
         "profit factor all winners" >:: test_profit_factor_all_winners;
         "profit factor no trades" >:: test_profit_factor_no_trades;
         (* compute_round_trip_metric_set tests *)
         "compute_round_trip_metric_set mixed long+short"
         >:: test_compute_round_trip_metric_set_mixed_long_short;
         "compute_round_trip_metric_set empty"
         >:: test_compute_round_trip_metric_set_empty;
         "compute_round_trip_metric_set all winners"
         >:: test_compute_round_trip_metric_set_all_winners;
         (* CAGR tests *)
         "cagr zero with no data" >:: test_cagr_zero_with_no_data;
         "cagr with growth" >:: test_cagr_with_growth;
         "cagr with loss" >:: test_cagr_with_loss;
         (* Calmar ratio tests *)
         "calmar ratio inputs" >:: test_calmar_ratio_inputs;
         (* Portfolio state tests *)
         "portfolio state no steps" >:: test_portfolio_state_no_steps;
         "portfolio state with trades" >:: test_portfolio_state_with_trades;
         "portfolio state skips non-trading final step"
         >:: test_portfolio_state_skips_non_trading_final_step;
         "portfolio state uses last step when all trading days"
         >:: test_portfolio_state_uses_last_step_when_all_trading_days;
         "portfolio state long unrealized pnl"
         >:: test_portfolio_state_long_unrealized_pnl;
         "portfolio state short unrealized pnl"
         >:: test_portfolio_state_short_unrealized_pnl;
         "portfolio state mixed unrealized pnl"
         >:: test_portfolio_state_mixed_unrealized_pnl;
       ]

let () = run_test_tt_main suite
