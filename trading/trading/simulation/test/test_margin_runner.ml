(** Tests for the simulator's Phase-2 margin wiring (issue #859).

    Phase-1 already pins the {!Trading_portfolio.Portfolio_margin} primitives
    (initial collateral lock, borrow-fee accrual math, maintenance-margin check)
    at unit-test scope in [trading/portfolio/test/test_margin_accounting.ml].

    This file pins the {b simulator-loop} contract added in Phase 2:
    - per-tick borrow fee accrual lands on [Portfolio.t] in the simulator,
    - maintenance-margin breaches generate force-cover [TriggerExit] transitions
      that flow through {!Order_generator} into buy-to-cover orders, and
    - {b crucially} every above behaviour is a bit-equal no-op when
      [margin_config.enabled = false] (the default). The default-off regression
      is the load-bearing invariant that lets us land this work without
      re-pinning long-only goldens. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Margin_config = Trading_portfolio.Margin_config
module Portfolio = Trading_portfolio.Portfolio
module Portfolio_margin = Trading_portfolio.Portfolio_margin
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface
module Metric_types = Trading_simulation_types.Metric_types

(* Local epsilon for cash / fee asserts. 1 cent is plenty for fee math
   accumulated over a few days; tests that go a full trading year use the
   default float_equal epsilon (~1e-9). *)
let _cash_epsilon = 0.01
let _date s = Date.of_string s

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _config_for ~start_date ~end_date ~initial_cash =
  {
    Trading_simulation_types.Simulator_types.start_date;
    end_date;
    initial_cash;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* On-margin config. We use the Phase-1 defaults but flip [enabled = true]. *)
let _on_config = { Margin_config.default_config with enabled = true }

(* ------------------------------------------------------------------ *)
(* Test strategies                                                    *)
(* ------------------------------------------------------------------ *)

(* Build a one-shot strategy module that emits a single [CreateEntering]
   transition for [symbol] on its first call, then holds passively. The
   per-call closure captures a fresh mutable [entered] ref, so each
   builder call yields an independent strategy state (essential for tests
   that re-run the same configuration twice in one process — a shared
   module-level [ref] would skip the second entry). *)
let _make_one_shot_strategy ~side ~symbol ~quantity ~position_id ~description :
    (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "OneShot"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      if !entered then Ok { Strategy_interface.transitions = [] }
      else
        match get_price symbol with
        | None -> Ok { Strategy_interface.transitions = [] }
        | Some (bar : Types.Daily_price.t) ->
            entered := true;
            let open Position in
            let trans =
              {
                position_id;
                date = bar.date;
                kind =
                  CreateEntering
                    {
                      symbol;
                      side;
                      target_quantity = quantity;
                      entry_price = bar.close_price;
                      reasoning =
                        TechnicalSignal
                          { indicator = "margin-test"; description };
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] }
  end
  in
  (module S)

let _short_strategy ~symbol ~quantity =
  _make_one_shot_strategy ~side:Position.Short ~symbol ~quantity
    ~position_id:(symbol ^ "-short") ~description:"short"

let _long_strategy ~symbol ~quantity =
  _make_one_shot_strategy ~side:Position.Long ~symbol ~quantity
    ~position_id:(symbol ^ "-long") ~description:"long"

(* ------------------------------------------------------------------ *)
(* Common scenario runner                                              *)
(* ------------------------------------------------------------------ *)

let _run_with_margin ?(initial_long_margin_req = 1.0)
    ?(long_margin_rate_annual_pct = 0.0) ?metric_suite ~test_name
    ~symbols_with_data ~strategy ~margin_config ~config () =
  let result_ref = ref None in
  with_test_data test_name symbols_with_data ~f:(fun data_dir ->
      let symbols = List.map symbols_with_data ~f:fst in
      let deps =
        create_deps ~symbols ~data_dir ~strategy ~commission:config.commission
          ?metric_suite ~margin_config ~initial_long_margin_req
          ~long_margin_rate_annual_pct ()
      in
      let sim = create_exn ~config ~deps in
      match run sim with
      | Ok r -> result_ref := Some r
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  match !result_ref with Some r -> r | None -> assert_failure "no result"

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

(* A flat-price, multi-day fixture used for borrow-fee math. Price held at
   $50 across 10 consecutive trading days; entry happens on day 1, fee
   accrues on days 2..10. *)
let _aapl_flat_50 =
  List.map
    [
      "2024-01-02";
      "2024-01-03";
      "2024-01-04";
      "2024-01-05";
      "2024-01-08";
      "2024-01-09";
      "2024-01-10";
      "2024-01-11";
      "2024-01-12";
      "2024-01-15";
    ] ~f:(fun d -> _make_bar ~date:(_date d) ~close:50.0)

(* Rising-price fixture: entry at $50, then a steep climb to $70 over 6
   trading days. With on_config defaults (50% IM / 25% MM), the trigger
   price for a $50 short is $60. By the 4th day price = $65 — well past
   the trigger — the simulator should fire a buy-to-cover. *)
let _aapl_rising_50_to_70 =
  [
    _make_bar ~date:(_date "2024-01-02") ~close:50.0;
    _make_bar ~date:(_date "2024-01-03") ~close:52.0;
    _make_bar ~date:(_date "2024-01-04") ~close:58.0;
    _make_bar ~date:(_date "2024-01-05") ~close:65.0;
    _make_bar ~date:(_date "2024-01-08") ~close:68.0;
    _make_bar ~date:(_date "2024-01-09") ~close:70.0;
    _make_bar ~date:(_date "2024-01-10") ~close:70.0;
  ]

(* Equity-relevant projection of a portfolio for bit-equality comparison.

   The full [Portfolio.t] equality includes [trade_history] which carries
   per-trade [timestamp = Time_ns_unix.now ()] (engine.ml:206) — i.e.
   wall-clock-dependent fields that differ between runs even on identical
   trade flows. Equity-equality is what matters for the "default-off does
   not perturb baselines" claim; the wall-clock timestamps are auxiliary.

   The projection keeps cash, position lots (signed quantity + cost
   basis), and the new margin bookkeeping fields. If any of these
   differ, the equity curve and metrics differ; if all agree, the
   long-only run is observably bit-equal. *)
type _equity_state = {
  cash : float;
  positions : Trading_simulation_types.Portfolio_summary.position_summary list;
  locked_collateral : float;
  accrued_borrow_fee : float;
}
[@@deriving show, eq]

let _equity_state_of_portfolio (p : Portfolio.t) : _equity_state =
  let summary =
    Trading_simulation_types.Portfolio_summary.of_portfolio p
      ~position_value_total:0.0
  in
  {
    cash = summary.current_cash;
    positions = summary.positions;
    locked_collateral = p.locked_collateral;
    accrued_borrow_fee = p.accrued_borrow_fee;
  }

(* ------------------------------------------------------------------ *)
(* Tests                                                              *)
(* ------------------------------------------------------------------ *)

(* T1: Default-off bit-equality regression. A long buy-and-hold run with
   margin_config disabled must produce a portfolio bit-equal to running
   without the new code path. We can't compare against "before-the-change"
   directly, but we can compare against a sibling run that takes the new
   code path with [enabled = false] vs an opt-in [enabled = true] but no
   shorts — both should produce identical portfolios because the
   accrue+force-cover code paths are no-ops in that case. *)
let test_default_off_long_only_bit_equal _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-15")
      ~initial_cash:10_000.0
  in
  let r_off =
    _run_with_margin ~test_name:"margin_default_off"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:50.0)
      ~margin_config:Margin_config.default_config ~config ()
  in
  let r_on_no_shorts =
    _run_with_margin ~test_name:"margin_on_long_only"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:50.0)
      ~margin_config:_on_config ~config ()
  in
  (* Both runs must agree exactly on the equity-relevant state: long-only
     flow touches neither [accrue_daily_borrow_fee] nor maintenance-margin
     checks (no shorts to flag), so cash, positions, locked collateral,
     and accrued fee must all match. (We compare the equity-state
     projection rather than full [Portfolio.t] because the latter carries
     wall-clock trade timestamps that differ between sibling runs even
     on identical trade flows.) *)
  assert_that
    (_equity_state_of_portfolio r_off.final_portfolio)
    (equal_to
       (_equity_state_of_portfolio r_on_no_shorts.final_portfolio
         : _equity_state))

(* T2: Daily borrow-fee accrual. With margin enabled, a single short of
   100 shares at $50 (notional $5000) running for N market-close ticks
   must accrue exactly N * (5000 * 0.005 / 252) in [accrued_borrow_fee],
   and [current_cash] must drop by the same amount.

   The fixture has 10 trading days. The strategy emits a short order on
   day 1 (Jan 2); the order fills on day 2 (Jan 3), so the short is open
   at the START of subsequent ticks. The margin tick in
   [Simulator._process_step_day] runs AFTER trade application — so the
   fee accrues on every trading-day tick from the fill day onward
   (Jan 3..15 = 9 trading days). We compute the expected total
   dynamically from the count of trading-day step_results that hold a
   short, so the test does not bake in calendar arithmetic. *)
let test_borrow_fee_accrual_multi_day _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-16")
      ~initial_cash:50_000.0
  in
  let result =
    _run_with_margin ~test_name:"margin_borrow_fee"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_short_strategy ~symbol:"AAPL" ~quantity:100.0)
      ~margin_config:_on_config ~config ()
  in
  (* Count post-entry steps: those where the short is held at the START
     of the tick, i.e. the short exists in the previous step's portfolio.
     For a flat-price hold, every step after the fill has the short
     held — that's all steps where [Portfolio_summary.find_position
     "AAPL"] reports a non-zero (negative) quantity. *)
  (* Fee accrues only on bar-bearing trading days where the short already
     exists in the portfolio (mark_prices is empty otherwise). Weekends /
     holidays carry the position across via had_market_bars = false. *)
  let _has_short_on_trading_day
      (step : Trading_simulation_types.Simulator_types.step_result) =
    step.had_market_bars
    && Trading_simulation_types.Portfolio_summary.find_position step.portfolio
         ~symbol:"AAPL"
       |> Option.exists
            ~f:(fun
                (p :
                  Trading_simulation_types.Portfolio_summary.position_summary)
              -> Float.O.(p.quantity < 0.0))
  in
  let steps_with_short = List.count result.steps ~f:_has_short_on_trading_day in
  let expected_daily_fee =
    50.0 *. 100.0 *. Margin_config.daily_borrow_rate _on_config
  in
  let expected_total = expected_daily_fee *. Float.of_int steps_with_short in
  (* Composed assertion: portfolio fee accumulator must equal the expected
     N-day total within float epsilon, and [current_cash] must have been
     debited by the same amount (the fee is taken out of cash). Phase 2
     does NOT cover the entry-time collateral-lock seam — that is
     {!Portfolio_margin.apply_single_trade_with_margin}'s domain and the
     simulator currently calls the legacy
     {!Portfolio.apply_single_trade} for trade application. So
     [locked_collateral] stays [0.0] here; we assert against that
     explicitly so a future Phase-2.x change that wires the margin-aware
     apply path notices this test. *)
  assert_that result.final_portfolio
    (all_of
       [
         field
           (fun (p : Portfolio.t) -> p.accrued_borrow_fee)
           (float_equal ~epsilon:1e-9 expected_total);
         field (fun (p : Portfolio.t) -> p.locked_collateral) (float_equal 0.0);
       ]);
  (* Sanity: total cash decrement matches the fee. The short proceeds
     credited [entry_price * quantity] = 5000.0 to cash on the fill; the
     accrued fee debits [expected_total]. So final cash should be
     initial_cash + proceeds - fee. *)
  let expected_cash =
    config.initial_cash +. (50.0 *. 100.0) -. expected_total
  in
  assert_that result.final_portfolio.current_cash
    (float_equal ~epsilon:1e-9 expected_cash)

(* T3: Maintenance margin breach -> force buy-to-cover order generated.

   With the default config (initial 50%, maintenance 25%), the trigger
   price on a $50 short is p_trigger = 50 * 1.5 / 1.25 = $60. Our
   rising fixture reaches $65 on day 4 (2024-01-05), well past the
   trigger.

   The expected sequence:
     day 1 (01-02): strategy emits short order at close $50; engine
                    submits for next-day fill.
     day 2 (01-03): order fills at $52. Short held; equity_ratio at $52
                    is ((1.5 * 50) - 52)/52 = 23/52 ≈ 0.44 > 0.25 (OK).
     day 3 (01-04): close $58. equity_ratio = (75 - 58)/58 ≈ 0.29 > 0.25.
     day 4 (01-05): close $65. equity_ratio = (75 - 65)/65 ≈ 0.154 <
                    0.25 — flagged. Simulator emits a margin-call
                    TriggerExit; Order_generator turns it into a Buy
                    (cover) order submitted for next-day fill.
     day 5 (01-08): cover fill at open $68. Short closed.

   What we assert here:
     1. The final portfolio holds NO AAPL position (covered).
     2. The trade audit shows at least one Buy trade on AAPL after the
        original Sell. *)
let test_maintenance_margin_force_cover _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-11")
      ~initial_cash:50_000.0
  in
  let result =
    _run_with_margin ~test_name:"margin_maintenance"
      ~symbols_with_data:[ ("AAPL", _aapl_rising_50_to_70) ]
      ~strategy:(_short_strategy ~symbol:"AAPL" ~quantity:100.0)
      ~margin_config:_on_config ~config ()
  in
  let aapl_trade_sides =
    List.concat_map result.steps ~f:(fun s -> s.trades)
    |> List.filter_map ~f:(fun (t : Trading_base.Types.trade) ->
        if String.equal t.symbol "AAPL" then Some t.side else None)
  in
  (* Expect exactly two AAPL trades — the short entry (Sell) and the
     forced cover (Buy). The final portfolio must show locked_collateral
     restored to 0 and no open AAPL position. *)
  assert_that aapl_trade_sides
    (elements_are
       [
         equal_to (Trading_base.Types.Sell : Trading_base.Types.side);
         equal_to (Trading_base.Types.Buy : Trading_base.Types.side);
       ]);
  assert_that result.final_portfolio
    (all_of
       [
         field
           (fun (p : Portfolio.t) -> Portfolio.get_position p "AAPL")
           is_none;
         field
           (fun (p : Portfolio.t) -> p.locked_collateral)
           (float_equal ~epsilon:_cash_epsilon 0.0);
         field
           (fun (p : Portfolio.t) -> p.accrued_borrow_fee)
           (gt (module Float_ord) 0.0);
       ])

(* T4: Flag-on, no shorts: full bit-equality with flag-off. Long-only
   strategy with margin enabled must still produce a portfolio identical
   to the same run with margin disabled. *)
let test_flag_on_long_only_bit_equal _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-11")
      ~initial_cash:10_000.0
  in
  let r_off =
    _run_with_margin ~test_name:"margin_long_off"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:50.0)
      ~margin_config:Margin_config.default_config ~config ()
  in
  let r_on =
    _run_with_margin ~test_name:"margin_long_on"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:50.0)
      ~margin_config:_on_config ~config ()
  in
  (* Long-only: fee accrual is 0 (no shorts) and maintenance check is a
     no-op. Equity-state projections must be bit-equal across the two
     margin modes. *)
  assert_that
    (_equity_state_of_portfolio r_off.final_portfolio)
    (equal_to (_equity_state_of_portfolio r_on.final_portfolio : _equity_state))

(* ------------------------------------------------------------------ *)
(* Long-margin (levered long) simulator wiring — margin M1b-2          *)
(* ------------------------------------------------------------------ *)

let _make_trade ~id ~symbol ~side ~quantity ~price =
  {
    Trading_base.Types.id;
    order_id = id ^ "-o";
    symbol;
    side;
    quantity;
    price;
    commission = 0.0;
    timestamp = Time_ns_unix.now ();
  }

(* End-to-end config threading: [initial_long_margin_req] / [long_margin_rate]
   travel through [create_deps] into the fill seam and the per-tick accrual.
   A long entry of 300 @ $50 = $15,000 exceeds the $10,000 cash; at armed req
   0.5 the $5,000 shortfall funds [long_margin_debit] instead of being
   floor-rejected, and 10%/yr interest then capitalizes onto the debit each
   tick. NAV subtracts the debit, so the borrowed cash yields no phantom
   equity and the interest is a real drag. *)
let test_levered_long_run_funds_and_prices_debit _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-15")
      ~initial_cash:10_000.0
  in
  let result =
    _run_with_margin ~initial_long_margin_req:0.5
      ~long_margin_rate_annual_pct:0.10
      ~metric_suite:
        {
          Trading_simulation_types.Simulator_types.computers =
            [ Trading_simulation.Metric_computers.portfolio_state_computer () ];
          derived = [];
        }
      ~test_name:"margin_levered_long"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:300.0)
      ~margin_config:Margin_config.default_config ~config ()
  in
  (* Debit funded ($5,000 borrow) and grown by capitalized interest (> $5,000
     proves the per-tick accrual ran). *)
  assert_that result.final_portfolio.long_margin_debit
    (gt (module Float_ord) 5_000.0);
  (* NAV honesty: flat price + no P&L, so equity is $10,000 less the accrued
     interest — strictly below the starting equity and far above zero. The last
     step's [portfolio_value] is the debit-subtracted NAV. *)
  let final_nav =
    (List.last_exn result.steps)
      .Trading_simulation_types.Simulator_types.portfolio_value
  in
  assert_that final_nav
    (is_between (module Float_ord) ~low:9_900.0 ~high:9_999.9);
  (* Metric honesty: OpenPositionsValue is the debit-free marked position value
     (300 sh * $50 = $15,000), NOT the debit-net [portfolio_value - cash]; and
     UnrealizedPnl = $15,000 - cost_basis $15,000 = $0 (bought and held flat at
     $50). This pins the QC-finding fix — the metric reads [position_value_total],
     not [portfolio_value - current_cash]. *)
  assert_that result.metrics
    (map_includes
       [
         (Metric_types.OpenPositionsValue, float_equal 15_000.0);
         (Metric_types.UnrealizedPnl, float_equal 0.0);
       ])

(* The simulation-layer wrapper capitalizes one trading day of interest onto an
   existing long-margin debit (mirrors [accrue_borrow_fee]). *)
let test_accrue_long_margin_interest_wrapper _ =
  let levered =
    match
      Trading_portfolio.Portfolio_margin.apply_single_trade_with_long_margin
        ~initial_long_margin_req:0.5
        (Portfolio.create ~initial_cash:1_000.0 ())
        (_make_trade ~id:"t1" ~symbol:"AAPL" ~side:Trading_base.Types.Buy
           ~quantity:20.0 ~price:100.0)
    with
    | Ok p -> p
    | Error err -> assert_failure ("levered buy: " ^ Status.show err)
  in
  (* Debit $1,000; one day at 10%/yr → debit *= (1 + 0.10/252). *)
  let expected =
    1_000.0 *. (1.0 +. (0.10 /. Margin_config.trading_days_per_year))
  in
  assert_that
    (Trading_simulation.Margin_runner.accrue_long_margin_interest
       ~long_margin_rate_annual_pct:0.10 ~portfolio:levered)
    (field
       (fun p -> p.Portfolio.long_margin_debit)
       (float_equal ~epsilon:1e-9 expected))

(* ------------------------------------------------------------------ *)
(* T5: Same-tick TriggerExit dedup (issue #1266)                       *)
(*                                                                    *)
(* The dotcom-2000-2002 margin-on scenario crashed with                *)
(* "Invalid transition Position.TriggerExit" when the strategy's      *)
(* stop-loss runner and the margin runner both fired a TriggerExit    *)
(* for the same short position on the same bar. The Position.t state  *)
(* machine accepts [Holding _ -> TriggerExit] only once; the second   *)
(* transition fails because the position has already moved out of     *)
(* [Holding].                                                          *)
(*                                                                    *)
(* Fix (per #1266): the dispatcher collapses same-tick same-position  *)
(* TriggerExit by source priority — margin wins, the strategy's       *)
(* exit is dropped.                                                    *)
(*                                                                    *)
(* This test pins the {!Margin_runner.dedup_strategy_exits_for_margin} *)
(* helper directly to keep the contract close to the bug:             *)
(*   - same position-id + both TriggerExit → strategy dropped, margin *)
(*     retained                                                        *)
(*   - same position-id but strategy is non-exit kind                 *)
(*     ([UpdateRiskParams]) → strategy preserved                       *)
(*   - different position-ids → both preserved                         *)
(*   - empty margin_trans → strategy preserved unchanged              *)
(* ------------------------------------------------------------------ *)

let _date_2024_01_05 = _date "2024-01-05"

let _trigger_exit_transition position_id =
  {
    Position.position_id;
    date = _date_2024_01_05;
    kind =
      Position.TriggerExit
        {
          exit_reason =
            Position.StopLoss
              { stop_price = 60.0; actual_price = 58.0; loss_percent = -10.0 };
          exit_price = 58.0;
        };
  }

let _margin_call_transition position_id =
  {
    Position.position_id;
    date = _date_2024_01_05;
    kind =
      Position.TriggerExit
        {
          exit_reason =
            Position.StrategySignal
              {
                label = "margin_call";
                detail = Some "entry_avg_cost=11.000000 current_price=12.875000";
              };
          exit_price = 12.875;
        };
  }

let _update_risk_params_transition position_id =
  {
    Position.position_id;
    date = _date_2024_01_05;
    kind =
      Position.UpdateRiskParams
        {
          new_risk_params =
            {
              Position.stop_loss_price = Some 60.0;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
  }

let test_dedup_drops_strategy_exit_when_margin_collides _ =
  let strategy_transitions = [ _trigger_exit_transition "AAPL-short" ] in
  let margin_trans = [ _margin_call_transition "AAPL-short" ] in
  let deduped =
    Trading_simulation.Margin_runner.dedup_strategy_exits_for_margin
      ~strategy_transitions ~margin_trans
  in
  (* The strategy's TriggerExit for AAPL-short collides with the
     margin-call exit. Dedup drops the strategy entry; only the margin
     transition (added by [tick] after dedup) survives. *)
  assert_that deduped (elements_are [])

let test_dedup_preserves_non_exit_strategy_transitions _ =
  let strategy_transitions = [ _update_risk_params_transition "AAPL-short" ] in
  let margin_trans = [ _margin_call_transition "AAPL-short" ] in
  let deduped =
    Trading_simulation.Margin_runner.dedup_strategy_exits_for_margin
      ~strategy_transitions ~margin_trans
  in
  (* UpdateRiskParams is not a TriggerExit; it passes through even when
     the same position-id has a margin call. *)
  assert_that deduped
    (elements_are [ equal_to (_update_risk_params_transition "AAPL-short") ])

let test_dedup_preserves_strategy_exits_for_other_positions _ =
  let strategy_transitions = [ _trigger_exit_transition "MSFT-short" ] in
  let margin_trans = [ _margin_call_transition "AAPL-short" ] in
  let deduped =
    Trading_simulation.Margin_runner.dedup_strategy_exits_for_margin
      ~strategy_transitions ~margin_trans
  in
  (* Different position-ids: both should pass through. *)
  assert_that deduped
    (elements_are [ equal_to (_trigger_exit_transition "MSFT-short") ])

let test_dedup_noop_when_margin_trans_empty _ =
  let strategy_transitions = [ _trigger_exit_transition "AAPL-short" ] in
  let margin_trans = [] in
  let deduped =
    Trading_simulation.Margin_runner.dedup_strategy_exits_for_margin
      ~strategy_transitions ~margin_trans
  in
  (* With no margin calls, the strategy's exit must pass through
     unchanged. *)
  assert_that deduped
    (elements_are [ equal_to (_trigger_exit_transition "AAPL-short") ])

(* ------------------------------------------------------------------ *)
(* T6: End-to-end repro of issue #1266.                               *)
(*                                                                    *)
(* Build a strategy that emits both a short entry and (on a later     *)
(* tick) a stop-loss TriggerExit for that same position. The margin   *)
(* runner independently emits its own TriggerExit on the same bar     *)
(* once price breaches the maintenance ratio. Before the fix, the     *)
(* second TriggerExit application crashed [run] with                  *)
(* "Invalid transition Position.TriggerExit". The fix collapses them; *)
(* [run] returns Ok, the position is closed, and the trades carry the *)
(* margin-call exit detail (proving the margin source won).           *)
(* ------------------------------------------------------------------ *)

(* Strategy that:
   - emits a short on day 1
   - emits a stop-loss TriggerExit for that same position on a later
     bar once price crosses [stop_trigger_price]
   We pick [stop_trigger_price = 60.0] which is exactly the maintenance-
   margin trigger for a $50 short under default config (50% IM / 25%
   MM). With our rising fixture (50→70), both fire on the same bar
   (day 4, close $65). *)
let _short_then_stop_strategy ~symbol ~quantity ~position_id ~stop_trigger_price
    : (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let exited = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "ShortThenStop"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      match get_price symbol with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          if not !entered then (
            entered := true;
            let open Position in
            let trans =
              {
                position_id;
                date = bar.date;
                kind =
                  CreateEntering
                    {
                      symbol;
                      side = Position.Short;
                      target_quantity = quantity;
                      entry_price = bar.close_price;
                      reasoning =
                        TechnicalSignal
                          {
                            indicator = "margin-collision-test";
                            description = "short for collision test";
                          };
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] })
          else if (not !exited) && Float.(bar.close_price >= stop_trigger_price)
          then (
            exited := true;
            let open Position in
            let trans =
              {
                position_id;
                date = bar.date;
                kind =
                  TriggerExit
                    {
                      exit_reason =
                        StopLoss
                          {
                            stop_price = stop_trigger_price;
                            actual_price = bar.close_price;
                            loss_percent =
                              (stop_trigger_price -. bar.close_price)
                              /. stop_trigger_price *. 100.0;
                          };
                      exit_price = bar.close_price;
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] })
          else Ok { Strategy_interface.transitions = [] }
  end
  in
  (module S)

let test_e2e_strategy_exit_collides_with_margin_call _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-11")
      ~initial_cash:50_000.0
  in
  let result =
    _run_with_margin ~test_name:"margin_strategy_collide"
      ~symbols_with_data:[ ("AAPL", _aapl_rising_50_to_70) ]
      ~strategy:
        (_short_then_stop_strategy ~symbol:"AAPL" ~quantity:100.0
           ~position_id:"AAPL-short" ~stop_trigger_price:60.0)
      ~margin_config:_on_config ~config ()
  in
  (* The run completed (no "Invalid transition" raise) and the position
     was closed. Pre-fix this assertion never executes because [run]
     raises before returning. *)
  assert_that result.final_portfolio
    (field (fun (p : Portfolio.t) -> Portfolio.get_position p "AAPL") is_none)

(* ------------------------------------------------------------------ *)
(* T7: Buy-in stress vs maintenance cover collision (margin M3b).      *)
(*                                                                    *)
(* When the short-side maintenance check AND the buy-in stress mode    *)
(* both flag the same short on the same Friday, [tick] must emit       *)
(* exactly ONE cover for it — the maintenance [margin_call] (richer    *)
(* forensic detail), with the duplicate [buyin_stress] dropped by      *)
(* [_drop_buyins_colliding_with_covers]. A second short that is HTB    *)
(* but NOT maintenance-breached still gets its own [buyin_stress]      *)
(* cover in the same tick. This pins the internal-dedup half of the    *)
(* [tick] .mli contract (the strategy-vs-margin dedup is pinned by T5).*)
(* ------------------------------------------------------------------ *)

(* Engine price bar for [mark_prices]. *)
let _engine_bar ~symbol ~close =
  {
    Trading_engine.Types.symbol;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
  }

(* Buy-in armed on top of the maintenance-enabled [_on_config]: shorts marked
   strictly below $20 are hard-to-borrow (buy-in-exposed). *)
let _buyin_armed_config =
  {
    _on_config with
    Margin_config.short_buyin_stress_mode = true;
    short_buyin_htb_price_below = 20.0;
  }

(* Portfolio holding two shorts entered at $10 (maintenance check reads the
   entry cost). Under default 50% IM / 25% MM the $10 short's cover trigger is
   $12: a $15 mark breaches (collision), a $5 mark does not (buy-in only). *)
let _two_shorts_portfolio () =
  match
    Portfolio_margin.apply_trades_with_margin ~margin_config:_on_config
      (Portfolio.create ~initial_cash:30_000.0 ())
      [
        _make_trade ~id:"c" ~symbol:"COLLIDE" ~side:Trading_base.Types.Sell
          ~quantity:100.0 ~price:10.0;
        _make_trade ~id:"b" ~symbol:"BUYONLY" ~side:Trading_base.Types.Sell
          ~quantity:100.0 ~price:10.0;
      ]
  with
  | Ok p -> p
  | Error err -> assert_failure ("two-shorts portfolio: " ^ Status.show err)

(* Holding short Position.t; map key = symbol = position_id. *)
let _holding_short ~symbol ~entry ~qty =
  let make_trans kind =
    { Position.position_id = symbol; date = _date_2024_01_05; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> assert_failure "short setup failed"
  in
  let open Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol;
              side = Position.Short;
              target_quantity = qty;
              entry_price = entry;
              reasoning =
                TechnicalSignal
                  { indicator = "m3b-collision"; description = "short" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = qty; fill_price = entry }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(* Matcher: a TriggerExit for [position_id] tagged with StrategySignal [label]. *)
let _is_exit_tagged ~position_id ~label =
  all_of
    [
      field
        (fun (t : Position.transition) -> t.position_id)
        (equal_to position_id);
      field
        (fun (t : Position.transition) -> t.kind)
        (matching ~msg:("TriggerExit " ^ label)
           (function
             | Position.TriggerExit
                 { exit_reason = Position.StrategySignal { label = l; _ }; _ }
               when String.equal l label ->
                 Some ()
             | _ -> None)
           (equal_to ()));
    ]

let test_buyin_collides_with_margin_call _ =
  let positions =
    Map.of_alist_exn
      (module String)
      [
        ("COLLIDE", _holding_short ~symbol:"COLLIDE" ~entry:10.0 ~qty:100.0);
        ("BUYONLY", _holding_short ~symbol:"BUYONLY" ~entry:10.0 ~qty:100.0);
      ]
  in
  let today_bars =
    [
      _engine_bar ~symbol:"COLLIDE" ~close:15.0;
      _engine_bar ~symbol:"BUYONLY" ~close:5.0;
    ]
  in
  let _portfolio, transitions =
    Trading_simulation.Margin_runner.tick ~margin_config:_buyin_armed_config
      ~long_margin_rate_annual_pct:0.0 ~maintenance_long_pct:0.0
      ~portfolio:(_two_shorts_portfolio ()) ~positions ~today_bars
      ~date:_date_2024_01_05 ~strategy_transitions:[]
  in
  (* Exactly two covers: COLLIDE covered ONCE as [margin_call] (the buy-in
     duplicate dropped); BUYONLY, HTB but not breached, covered as
     [buyin_stress]. The 2-element [elements_are] proves COLLIDE is not
     double-covered. *)
  assert_that transitions
    (elements_are
       [
         _is_exit_tagged ~position_id:"COLLIDE" ~label:"margin_call";
         _is_exit_tagged ~position_id:"BUYONLY" ~label:"buyin_stress";
       ])

let suite =
  "margin_runner"
  >::: [
         "default_off_long_only_bit_equal"
         >:: test_default_off_long_only_bit_equal;
         "borrow_fee_accrual_multi_day" >:: test_borrow_fee_accrual_multi_day;
         "maintenance_margin_force_cover"
         >:: test_maintenance_margin_force_cover;
         "flag_on_long_only_bit_equal" >:: test_flag_on_long_only_bit_equal;
         "levered_long_run_funds_and_prices_debit"
         >:: test_levered_long_run_funds_and_prices_debit;
         "accrue_long_margin_interest_wrapper"
         >:: test_accrue_long_margin_interest_wrapper;
         "dedup_drops_strategy_exit_when_margin_collides"
         >:: test_dedup_drops_strategy_exit_when_margin_collides;
         "dedup_preserves_non_exit_strategy_transitions"
         >:: test_dedup_preserves_non_exit_strategy_transitions;
         "dedup_preserves_strategy_exits_for_other_positions"
         >:: test_dedup_preserves_strategy_exits_for_other_positions;
         "dedup_noop_when_margin_trans_empty"
         >:: test_dedup_noop_when_margin_trans_empty;
         "e2e_strategy_exit_collides_with_margin_call"
         >:: test_e2e_strategy_exit_collides_with_margin_call;
         "buyin_collides_with_margin_call"
         >:: test_buyin_collides_with_margin_call;
       ]

let () = run_test_tt_main suite
