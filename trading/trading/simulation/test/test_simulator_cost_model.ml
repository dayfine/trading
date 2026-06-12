(** Pins the simulator's [on_trade_fill] post-fill adjustment hook.

    Three variants exercise the wiring contract:

    1. [on_trade_fill = None] — byte-equal to the pre-PR baseline (the
    [Cancel_handler.apply_trades_best_effort] path takes the identity branch).
    2.
    [on_trade_fill = Some Cost_model.apply_per_trade_commission retail_default]
    — [retail_default.per_trade_commission = 0.0], so cash matches the baseline
    byte-for-byte even though the hook is wired. 3.
    [on_trade_fill = Some Cost_model.apply_per_trade_commission custom] with
    [per_trade_commission = 1.50] — cash differs from the baseline by exactly
    [N_trades * 1.50] (the per-trade flat commission is added to each trade's
    [commission] field before the portfolio accounts for it).

    The simulator hook is strategy-agnostic and cost-model-agnostic; tests
    construct the hook directly from
    [Backtest_cost_model.Cost_model.apply_per_trade_commission] to avoid
    inverting the layering (the simulator does not depend on the higher-layer
    cost-model module). *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Cost_model = Backtest_cost_model.Cost_model

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close ~volume =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume;
      adjusted_close = close;
      active_through = None;
    }

(* Mirrors test_simulator.sample_config / sample_aapl_prices so the
   baselines below stay legible. *)
let sample_config =
  {
    start_date = date_of_string "2024-01-02";
    end_date = date_of_string "2024-01-05";
    initial_cash = 10000.0;
    commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let sample_aapl_prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:150.0 ~high:155.0 ~low:149.0 ~close:154.0 ~volume:1000000;
    make_daily_price
      ~date:(date_of_string "2024-01-03")
      ~open_price:154.0 ~high:158.0 ~low:153.0 ~close:157.0 ~volume:1200000;
  ]

(* Build deps with an optional [on_trade_fill] hook. The Noop strategy keeps
   the test focused on the fill-path enrichment; we submit a market order
   directly to the order manager rather than going through a strategy. *)
let _make_deps ?on_trade_fill data_dir =
  create_deps ~symbols:[ "AAPL" ] ~data_dir
    ~strategy:(module Noop_strategy)
    ~commission:sample_config.commission ?on_trade_fill ()

(* Submit a 10-share AAPL market buy onto the order manager so the first
   step's fill path produces one trade. *)
let _submit_aapl_market_buy ~order_manager ~quantity =
  let order_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order =
    match Trading_orders.Create_order.create_order order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  ignore (Trading_orders.Manager.submit_orders order_manager [ order ])

(* The pre-PR baseline cash after one filled market buy.
   Quantity 10 @ open price 150.0 + 1.0 minimum-commission floor = 9000 - 1 = 8999. *)
let _baseline_expected_cash =
  let quantity = 10.0 in
  let open_price = 150.0 in
  let baseline_commission = 1.0 in
  sample_config.initial_cash -. (quantity *. open_price) -. baseline_commission

(* Variant 1: on_trade_fill = None preserves byte-equal baseline. *)
let test_no_hook_matches_baseline _ =
  with_test_data "simulator_cost_model_none"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps = _make_deps data_dir in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      _submit_aapl_market_buy ~order_manager:deps.order_manager ~quantity:10.0;
      let _, result = step_exn sim in
      assert_that result
        (all_of
           [
             field (fun r -> r.trades) (size_is 1);
             field
               (fun r -> r.portfolio.current_cash)
               (float_equal _baseline_expected_cash);
           ]))

(* Variant 2: on_trade_fill = Some retail_default's per_trade_commission
   is 0.0, so the enrichment is the identity even though the hook is
   wired. Pins the byte-equal-on-zero-cost contract. *)
let test_retail_default_preserves_baseline _ =
  with_test_data "simulator_cost_model_retail_default"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps =
        _make_deps
          ~on_trade_fill:
            (Cost_model.apply_per_trade_commission Cost_model.retail_default)
          data_dir
      in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      _submit_aapl_market_buy ~order_manager:deps.order_manager ~quantity:10.0;
      let _, result = step_exn sim in
      assert_that result
        (all_of
           [
             field (fun r -> r.trades) (size_is 1);
             field
               (fun r -> r.portfolio.current_cash)
               (float_equal _baseline_expected_cash);
           ]))

(* Variant 3: a custom cost-model with per_trade_commission = 1.50 makes
   cash drop by exactly that flat fee relative to the baseline. The trade
   recorded on the step also carries the bumped commission, since the hook
   runs before the trade is accepted into the step_result. *)
let test_custom_per_trade_subtracts_exact_delta _ =
  let flat_fee = 1.50 in
  let custom_cm = { Cost_model.zero with per_trade_commission = flat_fee } in
  with_test_data "simulator_cost_model_custom"
    [ ("AAPL", sample_aapl_prices) ]
    ~f:(fun data_dir ->
      let deps =
        _make_deps
          ~on_trade_fill:(Cost_model.apply_per_trade_commission custom_cm)
          data_dir
      in
      let sim = Test_helpers.create_exn ~config:sample_config ~deps in
      _submit_aapl_market_buy ~order_manager:deps.order_manager ~quantity:10.0;
      let _, result = step_exn sim in
      assert_that result
        (all_of
           [
             field (fun r -> r.trades) (size_is 1);
             field
               (fun r -> r.portfolio.current_cash)
               (float_equal (_baseline_expected_cash -. flat_fee));
             field
               (fun r ->
                 match r.trades with
                 | [ t ] -> t.Trading_base.Types.commission
                 | _ -> Float.nan)
               (* Engine's baseline commission (1.0 minimum-floor at qty=10)
                  plus the cost-model's 1.50 per-trade flat fee. *)
               (float_equal 2.50);
           ]))

let suite =
  "Simulator cost_model wiring"
  >::: [
         "on_trade_fill=None matches baseline" >:: test_no_hook_matches_baseline;
         "on_trade_fill=retail_default (per_trade=0) preserves baseline"
         >:: test_retail_default_preserves_baseline;
         "on_trade_fill=custom per_trade=1.50 subtracts exact delta"
         >:: test_custom_per_trade_subtracts_exact_delta;
       ]

let () = run_test_tt_main suite
