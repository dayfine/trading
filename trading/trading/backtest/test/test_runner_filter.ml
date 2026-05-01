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
    splits_applied = [];
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

(* -------------------------------------------------------------------- *)
(* Phase 3: summary metrics overlay matches range-filtered round_trips    *)
(* -------------------------------------------------------------------- *)

(** Reconciler-surfaced regression: on [panel-golden-2019-full], summary's
    WinCount disagreed with the count of [pnl_dollars > 0] rows in [trades.csv].
    Root cause: the simulator runs from [warmup_start] to [end_date] and its
    [Summary_computer] folds over the warmup steps too, while the runner's
    [round_trips] are derived from [steps_in_range] (steps with
    [date >= start_date]). When complete round-trips fall in the warmup window,
    the simulator's metric set counts them but [trades.csv] does not.

    [Backtest.Runner._make_summary] now overlays
    [Metrics.compute_round_trip_metric_set runner_round_trips] onto
    [sim_result.metrics] so the [Summary.t]'s WinCount/LossCount/etc. match
    [trades.csv]. The overlay's semantics: keys present in the overlay win, keys
    only in the simulator metric set are preserved (Sharpe, MaxDrawdown, CAGR,
    etc., which are still computed from the full step series).

    This test pins the alignment by composing the two public surfaces the runner
    uses ([compute_round_trip_metric_set] + [Metric_types.merge]) — full
    integration through [run_backtest] would require a real panel + scenario,
    which is the smoke-fixture's domain. The synthetic case here mirrors the
    panel-golden-2019-full bug exactly: simulator says 3 wins / 6 losses (warmup
    contributed an extra 1 win + 1 loss); runner's range-filtered round_trips
    show 2 wins / 5 losses. Post-overlay the summary must show 2 wins / 5
    losses, never 3 / 6. *)
let test_summary_metrics_overlay_aligns_with_range_round_trips _ =
  let open Trading_simulation_types.Metric_types in
  (* Simulator-reported metric_set: 3 wins + 6 losses (includes 1 win +
     1 loss from the warmup window). *)
  let sim_metrics =
    of_alist_exn
      [
        (TotalPnl, -8000.0);
        (WinCount, 3.0);
        (LossCount, 6.0);
        (WinRate, 33.33);
        (AvgHoldingDays, 18.0);
        (ProfitFactor, 0.4);
        (* Non-round-trip metrics that the simulator computes from the
           full step series — these must survive the overlay unchanged. *)
        (SharpeRatio, 0.6);
        (MaxDrawdown, 2.0);
        (CAGR, 1.83);
      ]
  in
  (* Runner's range-filtered round_trips: 2 wins, 5 losses. *)
  let make_round_trip ~symbol ~pnl =
    {
      Trading_simulation.Metrics.symbol;
      side = Trading_base.Types.Buy;
      entry_date = date_of_string "2019-05-04";
      exit_date = date_of_string "2019-05-07";
      days_held = 3;
      entry_price = 100.0;
      exit_price = 100.0;
      quantity = 100.0;
      pnl_dollars = pnl;
      pnl_percent = pnl /. 100.0;
    }
  in
  let runner_round_trips =
    [
      make_round_trip ~symbol:"W1" ~pnl:1500.0;
      make_round_trip ~symbol:"W2" ~pnl:1000.0;
      make_round_trip ~symbol:"L1" ~pnl:(-2000.0);
      make_round_trip ~symbol:"L2" ~pnl:(-1500.0);
      make_round_trip ~symbol:"L3" ~pnl:(-1000.0);
      make_round_trip ~symbol:"L4" ~pnl:(-500.0);
      make_round_trip ~symbol:"L5" ~pnl:(-250.0);
    ]
  in
  let overlay =
    Trading_simulation.Metrics.compute_round_trip_metric_set runner_round_trips
  in
  let aligned = merge sim_metrics overlay in
  assert_that aligned
    (map_includes
       [
         (* The reconciler's arithmetic count must equal the summary's
            count post-overlay. Both reflect runner_round_trips, not the
            simulator's full-step view. *)
         (WinCount, float_equal 2.0);
         (LossCount, float_equal 5.0);
         (WinRate, float_equal ~epsilon:1e-2 (2.0 /. 7.0 *. 100.0));
         (TotalPnl, float_equal (-2750.0));
         (* Non-overlay metrics (Sharpe, MaxDrawdown, CAGR) survive. *)
         (SharpeRatio, float_equal 0.6);
         (MaxDrawdown, float_equal 2.0);
         (CAGR, float_equal 1.83);
       ])

(* -------------------------------------------------------------------- *)
(* Phase 4: stop_info entry_date filter — drop warmup-window entries     *)
(* -------------------------------------------------------------------- *)

(** Regression: warmup-emit leak in [stop_log]. The simulator runs from
    [warmup_start] so [Stop_log] observes [EntryComplete] transitions for
    positions opened during warmup. [Result_writer._pop_stop_info] pops by
    symbol-FIFO when rendering [trades.csv]; if the same symbol re-trades across
    the [start_date] boundary, the warmup stop_info (sorted first by
    [position_id]) gets attached to the in-window round-trip's row, corrupting
    [entry_stop] / [exit_stop] / [exit_trigger] columns.

    [Runner.filter_stop_infos_in_window] drops [stop_info]s whose
    [entry_date < start_date] before the writer sees them, so only in-window
    positions populate the trades.csv columns. [entry_date = None] (test
    fixtures that don't drive {!Stop_log.set_current_date}) is kept
    permissively. *)
let _stop_info ?entry_date ~position_id ~symbol () : Backtest.Stop_log.stop_info
    =
  {
    position_id;
    symbol;
    entry_date;
    entry_stop = Some 100.0;
    exit_stop = Some 95.0;
    exit_trigger = None;
  }

let test_filter_stop_infos_drops_warmup_entries _ =
  let start_date = date_of_string "2019-01-02" in
  let warmup_open =
    _stop_info
      ~entry_date:(date_of_string "2018-08-15")
      ~position_id:"AAPL-warmup" ~symbol:"AAPL" ()
  in
  let in_window =
    _stop_info
      ~entry_date:(date_of_string "2019-03-01")
      ~position_id:"AAPL-window" ~symbol:"AAPL" ()
  in
  let kept =
    Backtest.Runner.filter_stop_infos_in_window [ warmup_open; in_window ]
      ~start_date
  in
  assert_that kept
    (elements_are
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.position_id)
           (equal_to "AAPL-window");
       ])

let test_filter_stop_infos_keeps_unstamped _ =
  let start_date = date_of_string "2019-01-02" in
  let unstamped = _stop_info ~position_id:"AAPL-1" ~symbol:"AAPL" () in
  let kept =
    Backtest.Runner.filter_stop_infos_in_window [ unstamped ] ~start_date
  in
  assert_that kept (size_is 1)

let test_filter_stop_infos_keeps_boundary _ =
  (* entry_date == start_date is in-window (>=). *)
  let start_date = date_of_string "2019-01-02" in
  let boundary =
    _stop_info ~entry_date:start_date ~position_id:"AAPL-1" ~symbol:"AAPL" ()
  in
  let kept =
    Backtest.Runner.filter_stop_infos_in_window [ boundary ] ~start_date
  in
  assert_that kept (size_is 1)

let suite =
  "Runner_filter"
  >::: [
         "is_trading_day: empty portfolio returns true"
         >:: test_is_trading_day_empty_portfolio;
         "is_trading_day: flat-value + open position returns false"
         >:: test_is_trading_day_flat_value_with_positions;
         "round-trip extraction must not be gated on is_trading_day"
         >:: test_round_trip_extraction_survives_non_trading_day_filter;
         "summary metrics overlay aligns with range-filtered round_trips"
         >:: test_summary_metrics_overlay_aligns_with_range_round_trips;
         "filter_stop_infos drops warmup entries"
         >:: test_filter_stop_infos_drops_warmup_entries;
         "filter_stop_infos keeps unstamped (entry_date None) entries"
         >:: test_filter_stop_infos_keeps_unstamped;
         "filter_stop_infos keeps entries on the start_date boundary"
         >:: test_filter_stop_infos_keeps_boundary;
       ]

let () = run_test_tt_main suite
