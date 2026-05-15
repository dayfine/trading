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
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface

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

let _run_with_margin ~test_name ~symbols_with_data ~strategy ~margin_config
    ~config =
  let result_ref = ref None in
  with_test_data test_name symbols_with_data ~f:(fun data_dir ->
      let symbols = List.map symbols_with_data ~f:fst in
      let deps =
        create_deps ~symbols ~data_dir ~strategy ~commission:config.commission
          ~margin_config ()
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
      ~margin_config:Margin_config.default_config ~config
  in
  let r_on_no_shorts =
    _run_with_margin ~test_name:"margin_on_long_only"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:50.0)
      ~margin_config:_on_config ~config
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
      ~margin_config:_on_config ~config
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
      ~margin_config:_on_config ~config
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
      ~margin_config:Margin_config.default_config ~config
  in
  let r_on =
    _run_with_margin ~test_name:"margin_long_on"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy:(_long_strategy ~symbol:"AAPL" ~quantity:50.0)
      ~margin_config:_on_config ~config
  in
  (* Long-only: fee accrual is 0 (no shorts) and maintenance check is a
     no-op. Equity-state projections must be bit-equal across the two
     margin modes. *)
  assert_that
    (_equity_state_of_portfolio r_off.final_portfolio)
    (equal_to (_equity_state_of_portfolio r_on.final_portfolio : _equity_state))

let suite =
  "margin_runner"
  >::: [
         "default_off_long_only_bit_equal"
         >:: test_default_off_long_only_bit_equal;
         "borrow_fee_accrual_multi_day" >:: test_borrow_fee_accrual_multi_day;
         "maintenance_margin_force_cover"
         >:: test_maintenance_margin_force_cover;
         "flag_on_long_only_bit_equal" >:: test_flag_on_long_only_bit_equal;
       ]

let () = run_test_tt_main suite
