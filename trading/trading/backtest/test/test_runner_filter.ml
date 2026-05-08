(** Regression tests for the [Runner] step-filtering boundary.

    [is_trading_day] reads the authoritative [step_result.had_market_bars] flag
    set by the simulator from the per-tick [today_bars] list. Replaced the prior
    portfolio-value-vs-cash heuristic, which falsely classified
    post-corporate-action days (held symbol with no further bars →
    [Calculations.portfolio_value] errors → caller silently substitutes [cash])
    as non-trading and silently truncated [equity_curve.csv] /
    [summary.final_portfolio_value] at the day before the gap.

    These tests pin two invariants: 1. [is_trading_day] mirrors
    [had_market_bars] exactly. 2. Round-trip extraction operates on the
    unfiltered in-range step list (must not be gated on [is_trading_day]). *)

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

(** Build a synthetic step. [had_market_bars] defaults to [true] since most
    tests want trading-day semantics; the non-trading-day case sets it
    explicitly to [false]. *)
let _make_step_with_trades ?(had_market_bars = true) ~date ~portfolio ~trades ()
    =
  let portfolio_value = portfolio.Trading_portfolio.Portfolio.current_cash in
  let portfolio_summary =
    Trading_simulation_types.Portfolio_summary.of_portfolio portfolio
      ~position_value_total:0.0
  in
  {
    Trading_simulation_types.Simulator_types.date;
    portfolio = portfolio_summary;
    portfolio_value;
    trades;
    orders_submitted = [];
    splits_applied = [];
    benchmark_return = None;
    had_market_bars;
  }

(* -------------------------------------------------------------------- *)
(* Phase 1: [is_trading_day] mirrors [had_market_bars] exactly           *)
(* -------------------------------------------------------------------- *)

(** A step the simulator marked as bar-bearing is a trading day, regardless of
    portfolio state. *)
let test_is_trading_day_with_bars _ =
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let step =
    _make_step_with_trades ~had_market_bars:true
      ~date:(date_of_string "2024-01-08") (* Monday *)
      ~portfolio ~trades:[] ()
  in
  assert_that (Backtest.Runner.is_trading_day step) (equal_to true)

(** A step with no bars (weekend/holiday/pre-listing) is not a trading day,
    regardless of portfolio state. *)
let test_is_trading_day_without_bars _ =
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  let step =
    _make_step_with_trades ~had_market_bars:false
      ~date:(date_of_string "2024-01-06") (* Saturday *)
      ~portfolio ~trades:[] ()
  in
  assert_that (Backtest.Runner.is_trading_day step) (equal_to false)

(** Post-corporate-action regression: the run holds a position whose symbol has
    no further bars (delisting / merger / suspension) but the broader market is
    still trading, so [had_market_bars = true]. The prior value-vs-cash
    heuristic dropped these days from [equity_curve.csv] because
    [Calculations.portfolio_value] errored and the fallback returned cash. The
    new contract keeps the day. *)
let test_is_trading_day_held_symbol_with_no_bar _ =
  let portfolio_with_position =
    let initial = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
    match
      Trading_portfolio.Portfolio.apply_single_trade initial
        (_make_trade ~id:"t1" ~order_id:"o1" ~symbol:"ANDV"
           ~side:Trading_base.Types.Buy ~quantity:10.0 ~price:100.0)
    with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure
          ("portfolio apply_trades failed: " ^ Status.show err)
  in
  let step =
    _make_step_with_trades ~had_market_bars:true
      ~date:(date_of_string "2018-10-01")
      ~portfolio:portfolio_with_position ~trades:[] ()
  in
  assert_that (Backtest.Runner.is_trading_day step) (equal_to true)

(* -------------------------------------------------------------------- *)
(* Phase 2: round-trip extraction must NOT be gated on is_trading_day    *)
(* -------------------------------------------------------------------- *)

(** Round-trip extraction operates on the unfiltered in-range step list. The
    [is_trading_day] filter is only valid for mark-to-market consumers (the
    equity curve, [UnrealizedPnl]) — applying it before
    [Metrics.extract_round_trips] silently drops trades whose entry+exit landed
    on bar-less days. This pins that round-trip extraction sees every step
    regardless of [had_market_bars]. *)
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
      (* Both steps simulate the failure-mode path: trade fills happened on
         days the simulator marked as non-trading (had_market_bars=false). *)
      _make_step_with_trades ~had_market_bars:false
        ~date:(date_of_string "2024-01-02")
        ~portfolio:portfolio_flat
        ~trades:
          [
            _make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL"
              ~side:Trading_base.Types.Buy ~quantity:10.0 ~price:100.0;
          ]
        ();
      _make_step_with_trades ~had_market_bars:false
        ~date:(date_of_string "2024-01-15")
        ~portfolio:portfolio_with_position
        ~trades:
          [
            _make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL"
              ~side:Trading_base.Types.Sell ~quantity:10.0 ~price:110.0;
          ]
        ();
    ]
  in
  (* Sanity: every step is non-trading by [is_trading_day] — the exact bug
     path. *)
  let filtered_out =
    List.filter steps_in_range ~f:(fun s ->
        not (Backtest.Runner.is_trading_day s))
  in
  assert_that (List.length filtered_out) (equal_to 2);
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
  (* If is_trading_day is mis-applied before round-trip extraction, the pair
     is dropped entirely. Pin that mis-use produces zero round-trips. *)
  let filtered_steps =
    List.filter steps_in_range ~f:Backtest.Runner.is_trading_day
  in
  let buggy_round_trips = Metrics.extract_round_trips filtered_steps in
  assert_that buggy_round_trips (size_is 0)

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

(* -------------------------------------------------------------------- *)
(* Phase 5: force-liquidation event filter — drop warmup-window events  *)
(* -------------------------------------------------------------------- *)

(** Regression: warmup-emit leak in [force_liquidation_log]. The simulator runs
    from [warmup_start] so [Audit_recorder.record_force_liquidation] observes
    events from the warmup window. Without filtering, those events leak into
    [force_liquidations.sexp] and inflate downstream consumers' counts.

    [Runner.filter_force_liquidations_in_window] drops events with
    [date < start_date]. *)
let _force_liq_event ~date ~symbol : Portfolio_risk.Force_liquidation.event =
  {
    symbol;
    position_id = symbol ^ "-1";
    date;
    side = Trading_base.Types.Long;
    entry_price = 100.0;
    current_price = 40.0;
    quantity = 100.0;
    cost_basis = 10_000.0;
    unrealized_pnl = -6_000.0;
    unrealized_pnl_pct = -0.6;
    reason = Portfolio_risk.Force_liquidation.Per_position;
  }

let test_filter_force_liquidations_drops_warmup _ =
  let start_date = date_of_string "2019-01-02" in
  let warmup =
    _force_liq_event ~date:(date_of_string "2018-09-15") ~symbol:"AAPL"
  in
  let in_window =
    _force_liq_event ~date:(date_of_string "2019-04-12") ~symbol:"MSFT"
  in
  let kept =
    Backtest.Runner.filter_force_liquidations_in_window [ warmup; in_window ]
      ~start_date
  in
  assert_that kept
    (elements_are
       [
         field
           (fun (e : Portfolio_risk.Force_liquidation.event) -> e.symbol)
           (equal_to "MSFT");
       ])

let test_filter_force_liquidations_keeps_boundary _ =
  let start_date = date_of_string "2019-01-02" in
  let boundary = _force_liq_event ~date:start_date ~symbol:"AAPL" in
  let kept =
    Backtest.Runner.filter_force_liquidations_in_window [ boundary ] ~start_date
  in
  assert_that kept (size_is 1)

(* -------------------------------------------------------------------- *)
(* Phase 6: trade_audit + cascade_summary filters                        *)
(* -------------------------------------------------------------------- *)

(** Regression: warmup-emit leak in [trade_audit]. The audit recorder fires from
    [warmup_start], so [audit_record]s with warmup-window [entry.entry_date] and
    [cascade_summary]s with warmup-window [date] sit in the collector at
    teardown.

    [Runner.filter_audit_records_in_window] /
    [Runner.filter_cascade_summaries_in_window] drop entries before [start_date]
    from [trade_audit.sexp]. *)
let _entry ~entry_date ~position_id ~symbol :
    Backtest.Trade_audit.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend = Bullish;
    macro_confidence = 0.5;
    macro_indicators = [];
    stage = Stage1 { weeks_in_base = 0 };
    ma_direction = Flat;
    ma_slope_pct = 0.0;
    rs_trend = None;
    rs_value = None;
    volume_quality = None;
    volume_ratio = None;
    resistance_quality = None;
    support_quality = None;
    sector_name = "Tech";
    sector_rating = Neutral;
    cascade_score = 0;
    cascade_grade = D;
    cascade_score_components = [];
    cascade_rationale = [];
    side = Long;
    suggested_entry = 100.0;
    suggested_stop = 95.0;
    installed_stop = 95.0;
    stop_floor_kind = Buffer_fallback;
    risk_pct = 0.05;
    initial_position_value = 10_000.0;
    initial_risk_dollars = 500.0;
    alternatives_considered = [];
  }

let _audit_record ~entry_date ~position_id ~symbol :
    Backtest.Trade_audit.audit_record =
  { entry = _entry ~entry_date ~position_id ~symbol; exit_ = None }

let test_filter_audit_records_drops_warmup _ =
  let start_date = date_of_string "2019-01-02" in
  let warmup =
    _audit_record
      ~entry_date:(date_of_string "2018-08-01")
      ~position_id:"A-1" ~symbol:"AAPL"
  in
  let in_window =
    _audit_record
      ~entry_date:(date_of_string "2019-04-15")
      ~position_id:"M-1" ~symbol:"MSFT"
  in
  let kept =
    Backtest.Runner.filter_audit_records_in_window [ warmup; in_window ]
      ~start_date
  in
  assert_that kept
    (elements_are
       [
         field
           (fun (r : Backtest.Trade_audit.audit_record) -> r.entry.symbol)
           (equal_to "MSFT");
       ])

let _cascade_summary ~date : Backtest.Trade_audit.cascade_summary =
  {
    date;
    total_stocks = 100;
    candidates_after_held = 100;
    macro_trend = Bullish;
    long_macro_admitted = 0;
    long_breakout_admitted = 0;
    long_sector_admitted = 0;
    long_grade_admitted = 0;
    long_top_n_admitted = 0;
    short_macro_admitted = 0;
    short_breakdown_admitted = 0;
    short_sector_admitted = 0;
    short_rs_hard_gate_admitted = 0;
    short_grade_admitted = 0;
    short_top_n_admitted = 0;
    entered = 0;
  }

let test_filter_cascade_summaries_drops_warmup _ =
  let start_date = date_of_string "2019-01-02" in
  let warmup = _cascade_summary ~date:(date_of_string "2018-09-07") in
  let in_window = _cascade_summary ~date:(date_of_string "2019-03-15") in
  let kept =
    Backtest.Runner.filter_cascade_summaries_in_window [ warmup; in_window ]
      ~start_date
  in
  assert_that kept
    (elements_are
       [
         field
           (fun (s : Backtest.Trade_audit.cascade_summary) -> s.date)
           (equal_to (date_of_string "2019-03-15"));
       ])

let suite =
  "Runner_filter"
  >::: [
         "is_trading_day: had_market_bars=true returns true"
         >:: test_is_trading_day_with_bars;
         "is_trading_day: had_market_bars=false returns false"
         >:: test_is_trading_day_without_bars;
         "is_trading_day: held symbol with no bar but market open returns true \
          (post-corporate-action regression)"
         >:: test_is_trading_day_held_symbol_with_no_bar;
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
         "filter_force_liquidations drops warmup-window events"
         >:: test_filter_force_liquidations_drops_warmup;
         "filter_force_liquidations keeps events on the start_date boundary"
         >:: test_filter_force_liquidations_keeps_boundary;
         "filter_audit_records drops warmup entries"
         >:: test_filter_audit_records_drops_warmup;
         "filter_cascade_summaries drops warmup entries"
         >:: test_filter_cascade_summaries_drops_warmup;
       ]

let () = run_test_tt_main suite
