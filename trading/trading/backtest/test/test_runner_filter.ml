(** Regression tests for the [Runner] step-filtering boundary.

    The [is_trading_day] heuristic was introduced by PR #393 so that
    mark-to-market aware metrics like [UnrealizedPnl] ignore weekend/holiday
    steps where the simulator falls back to [portfolio_value = cash]. The
    heuristic was subsequently mis-applied to round-trip extraction, silently
    dropping ~95% of trades from [trades.csv] on large multi-year runs when
    entry+exit happened to land on steps that look "non-trading" to the
    heuristic (e.g. because the only non-[Holding] positions are
    [Entering]/[Closed], which contribute 0.0 to the mark-to-market portfolio
    value).

    These tests pin the invariant that round-trip extraction must see steps
    flagged as non-trading by [is_trading_day]. *)

open OUnit2
open Core
open Matchers
open Trading_simulation

let date_of_string = Date.of_string

let _sample_commission =
  { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

let _make_trade ~id ~order_id ~symbol ~side ~quantity ~price =
  {
    Trading_base.Types.id;
    order_id;
    symbol;
    side;
    quantity;
    price;
    commission = 0.0;
    timestamp = Time_ns_unix.now ();
  }

(** Build a synthetic step with no mark-to-market signal
    ([portfolio_value = current_cash]) — the exact shape [is_trading_day]
    classifies as non-trading when positions are open. *)
let _make_step_with_trades ~date ~portfolio ~trades =
  {
    Trading_simulation_types.Simulator_types.date;
    portfolio;
    portfolio_value = portfolio.Trading_portfolio.Portfolio.current_cash;
    trades;
    orders_submitted = [];
  }

(* -------------------------------------------------------------------- *)
(* Phase 1: [is_trading_day] classifies our synthetic steps correctly    *)
(* -------------------------------------------------------------------- *)

(** An empty portfolio (no positions) is treated as a trading day — the
    mark-to-market heuristic only kicks in once there is something to mark. *)
let test_is_trading_day_empty_portfolio _ =
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let step =
    _make_step_with_trades
      ~date:(date_of_string "2024-01-06") (* Saturday, no price bars *)
      ~portfolio ~trades:[]
  in
  assert_that (Backtest.Runner.is_trading_day step) (equal_to true)

(** Once we hold a real position but [portfolio_value = cash] (the simulator's
    fallback on weekends/holidays), the heuristic marks the step as non-trading.
    This is the exact state that used to hide trade fills from [trades.csv]. *)
let test_is_trading_day_flat_value_with_positions _ =
  let portfolio_with_position =
    let initial = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
    match
      Trading_portfolio.Portfolio.apply_single_trade initial
        (_make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL"
           ~side:Trading_base.Types.Buy ~quantity:10.0 ~price:100.0)
    with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure
          ("portfolio apply_trades failed: " ^ Status.show err)
  in
  let step =
    _make_step_with_trades
      ~date:(date_of_string "2024-01-06")
      ~portfolio:portfolio_with_position ~trades:[]
  in
  (* portfolio has an open position but portfolio_value = cash — the
     heuristic classifies this as a non-trading day, which is the exact
     gotcha that used to drop round-trips. *)
  assert_that (Backtest.Runner.is_trading_day step) (equal_to false)

(* -------------------------------------------------------------------- *)
(* Phase 2: round-trip extraction must NOT be gated on is_trading_day    *)
(* -------------------------------------------------------------------- *)

(** The core regression. Build two steps, each with a trade fill on a step the
    [is_trading_day] heuristic flags as non-trading. Pre-fix, pairing
    [steps = List.filter ~f:is_trading_day] with [extract_round_trips] discards
    both steps, so the resulting [round_trips] list is empty even though one
    buy/sell pair completed. Post-fix, round-trip extraction operates on the
    unfiltered in-range step list and returns the expected pair. *)
let test_round_trip_extraction_survives_non_trading_day_filter _ =
  let portfolio_flat =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let portfolio_with_position =
    match
      Trading_portfolio.Portfolio.apply_single_trade portfolio_flat
        (_make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL"
           ~side:Trading_base.Types.Buy ~quantity:10.0 ~price:100.0)
    with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure ("apply_trade failed: " ^ Status.show err)
  in
  let steps_in_range =
    [
      _make_step_with_trades
        ~date:(date_of_string "2024-01-02")
        ~portfolio:portfolio_flat
        ~trades:
          [
            _make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL"
              ~side:Trading_base.Types.Buy ~quantity:10.0 ~price:100.0;
          ];
      _make_step_with_trades
        ~date:(date_of_string "2024-01-15")
        ~portfolio:portfolio_with_position
        ~trades:
          [
            _make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL"
              ~side:Trading_base.Types.Sell ~quantity:10.0 ~price:110.0;
          ];
    ]
  in
  (* Sanity: with positions open but portfolio_value = cash, the heuristic
     rejects at least the second step — simulating the exact bug path. *)
  let filtered_out =
    List.filter steps_in_range ~f:(fun s ->
        not (Backtest.Runner.is_trading_day s))
  in
  assert_that (List.length filtered_out) (gt (module Int_ord) 0);
  (* The in-range (unfiltered) list still produces one round-trip. *)
  let round_trips = Metrics.extract_round_trips steps_in_range in
  assert_that round_trips
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Metrics.trade_metrics) -> t.symbol)
               (equal_to "AAPL");
             field
               (fun (t : Metrics.trade_metrics) -> t.entry_price)
               (float_equal 100.0);
             field
               (fun (t : Metrics.trade_metrics) -> t.exit_price)
               (float_equal 110.0);
             field
               (fun (t : Metrics.trade_metrics) -> t.quantity)
               (float_equal 10.0);
           ];
       ]);
  (* The bug: applying is_trading_day before round-trip extraction drops
     the pair entirely. Pinning the pre-fix behaviour here guards against
     re-regression if someone "helpfully" reintroduces the filter. *)
  let filtered_steps =
    List.filter steps_in_range ~f:Backtest.Runner.is_trading_day
  in
  let buggy_round_trips = Metrics.extract_round_trips filtered_steps in
  assert_that
    (List.length round_trips - List.length buggy_round_trips)
    (gt (module Int_ord) 0)

let suite =
  "Runner_filter"
  >::: [
         "is_trading_day: empty portfolio returns true"
         >:: test_is_trading_day_empty_portfolio;
         "is_trading_day: flat-value + open position returns false"
         >:: test_is_trading_day_flat_value_with_positions;
         "round-trip extraction must not be gated on is_trading_day"
         >:: test_round_trip_extraction_survives_non_trading_day_filter;
       ]

let () = run_test_tt_main suite
