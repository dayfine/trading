(** Unit tests for [Backtest_cost_model.Cost_model].

    Covers the four cost components in isolation, the zero-cost default,
    per-trade vs per-share commission interaction, the engine-config conversion,
    and the validate guard. Follows [.claude/rules/test-patterns.md] — one
    [assert_that] per value, no nested asserts inside callbacks. *)

open OUnit2
open Core
open Matchers
module CM = Backtest_cost_model.Cost_model

(* ------------------------------------------------------------------ *)
(* Test data builders                                                   *)
(* ------------------------------------------------------------------ *)

let make_trade ?(id = "T1") ?(order_id = "O1") ?(symbol = "AAPL")
    ?(side = Trading_base.Types.Buy) ?(quantity = 100.0) ?(price = 50.0)
    ?(commission = 0.0) () : Trading_base.Types.trade =
  {
    id;
    order_id;
    symbol;
    side;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.epoch;
  }

(* ------------------------------------------------------------------ *)
(* zero / defaults                                                      *)
(* ------------------------------------------------------------------ *)

let test_zero_is_frictionless _ =
  assert_that CM.zero
    (all_of
       [
         field (fun (t : CM.t) -> t.per_trade_commission) (float_equal 0.0);
         field (fun (t : CM.t) -> t.per_share_commission) (float_equal 0.0);
         field (fun (t : CM.t) -> t.bid_ask_spread_bps) (float_equal 0.0);
         field
           (fun (t : CM.t) -> t.market_impact_bps_per_pct_adv)
           (float_equal 0.0);
       ])

let test_retail_default_has_only_spread _ =
  assert_that CM.retail_default
    (all_of
       [
         field (fun (t : CM.t) -> t.per_trade_commission) (float_equal 0.0);
         field (fun (t : CM.t) -> t.per_share_commission) (float_equal 0.0);
         field (fun (t : CM.t) -> t.bid_ask_spread_bps) (float_equal 5.0);
         field
           (fun (t : CM.t) -> t.market_impact_bps_per_pct_adv)
           (float_equal 0.0);
       ])

let test_institutional_default_has_per_share_and_impact _ =
  assert_that CM.institutional_default
    (all_of
       [
         field (fun (t : CM.t) -> t.per_share_commission) (float_equal 0.005);
         field (fun (t : CM.t) -> t.bid_ask_spread_bps) (float_equal 2.0);
         field
           (fun (t : CM.t) -> t.market_impact_bps_per_pct_adv)
           (float_equal 1.0);
       ])

(* ------------------------------------------------------------------ *)
(* validate                                                             *)
(* ------------------------------------------------------------------ *)

let test_validate_zero_ok _ = assert_that (CM.validate CM.zero) is_ok

let test_validate_retail_ok _ =
  assert_that (CM.validate CM.retail_default) is_ok

let test_validate_negative_per_trade_rejected _ =
  let bad = { CM.zero with per_trade_commission = -1.0 } in
  assert_that (CM.validate bad) is_error

let test_validate_negative_per_share_rejected _ =
  let bad = { CM.zero with per_share_commission = -0.0001 } in
  assert_that (CM.validate bad) is_error

let test_validate_negative_spread_rejected _ =
  let bad = { CM.zero with bid_ask_spread_bps = -1.0 } in
  assert_that (CM.validate bad) is_error

let test_validate_negative_impact_rejected _ =
  let bad = { CM.zero with market_impact_bps_per_pct_adv = -0.5 } in
  assert_that (CM.validate bad) is_error

let test_validate_nan_rejected _ =
  let bad = { CM.zero with bid_ask_spread_bps = Float.nan } in
  assert_that (CM.validate bad) is_error

let test_validate_inf_rejected _ =
  let bad = { CM.zero with per_share_commission = Float.infinity } in
  assert_that (CM.validate bad) is_error

(* ------------------------------------------------------------------ *)
(* to_engine_costs                                                      *)
(* ------------------------------------------------------------------ *)

let test_engine_costs_zero _ =
  let commission, slippage = CM.to_engine_costs CM.zero in
  assert_that (commission, slippage)
    (all_of
       [
         field
           (fun (c, _) -> c.Trading_engine.Types.per_share)
           (float_equal 0.0);
         field (fun (c, _) -> c.Trading_engine.Types.minimum) (float_equal 0.0);
         field (fun (_, s) -> s) (equal_to 0);
       ])

let test_engine_costs_per_share_forwarded _ =
  let cm = { CM.zero with per_share_commission = 0.005 } in
  let commission, slippage = CM.to_engine_costs cm in
  assert_that (commission, slippage)
    (all_of
       [
         field
           (fun (c, _) -> c.Trading_engine.Types.per_share)
           (float_equal 0.005);
         field (fun (c, _) -> c.Trading_engine.Types.minimum) (float_equal 0.0);
         field (fun (_, s) -> s) (equal_to 0);
       ])

let test_engine_costs_spread_rounded_to_int _ =
  (* 4.6 bps rounds to 5; 2.0 bps stays 2 *)
  let cm = { CM.zero with bid_ask_spread_bps = 4.6 } in
  let _, slippage = CM.to_engine_costs cm in
  assert_that slippage (equal_to 5)

let test_engine_costs_spread_truncates_fractional _ =
  let cm = { CM.zero with bid_ask_spread_bps = 2.0 } in
  let _, slippage = CM.to_engine_costs cm in
  assert_that slippage (equal_to 2)

let test_engine_costs_per_trade_NOT_in_engine_costs _ =
  (* Flat per-trade commission is applied via apply_per_trade_commission,
     NOT folded into the engine's per-share record. *)
  let cm = { CM.zero with per_trade_commission = 1.0 } in
  let commission, _ = CM.to_engine_costs cm in
  assert_that commission.Trading_engine.Types.per_share (float_equal 0.0)

(* ------------------------------------------------------------------ *)
(* apply_per_trade_commission                                           *)
(* ------------------------------------------------------------------ *)

let test_per_trade_commission_adds_flat _ =
  let cm = { CM.zero with per_trade_commission = 1.50 } in
  let trade = make_trade ~commission:0.0 () in
  let adjusted = CM.apply_per_trade_commission cm trade in
  assert_that adjusted.commission (float_equal 1.50)

let test_per_trade_commission_independent_of_share_count _ =
  (* Same flat fee whether the trade is 1 share or 10_000 *)
  let cm = { CM.zero with per_trade_commission = 0.50 } in
  let small = CM.apply_per_trade_commission cm (make_trade ~quantity:1.0 ()) in
  let large =
    CM.apply_per_trade_commission cm (make_trade ~quantity:10_000.0 ())
  in
  assert_that
    (small.commission, large.commission)
    (all_of
       [
         field (fun (s, _) -> s) (float_equal 0.50);
         field (fun (_, l) -> l) (float_equal 0.50);
       ])

let test_per_trade_commission_stacks_on_existing _ =
  let cm = { CM.zero with per_trade_commission = 1.0 } in
  let trade = make_trade ~commission:2.50 () in
  let adjusted = CM.apply_per_trade_commission cm trade in
  assert_that adjusted.commission (float_equal 3.50)

let test_per_trade_commission_zero_is_identity _ =
  let cm = CM.zero in
  let trade = make_trade ~commission:1.23 () in
  let adjusted = CM.apply_per_trade_commission cm trade in
  assert_that adjusted (equal_to trade)

(* ------------------------------------------------------------------ *)
(* market_impact_bps                                                    *)
(* ------------------------------------------------------------------ *)

let test_market_impact_zero_coef_is_zero _ =
  let bps = CM.market_impact_bps CM.zero ~adv_pct:5.0 in
  assert_that bps (float_equal 0.0)

let test_market_impact_linear_in_adv _ =
  (* 2 bps/1%ADV * 3% ADV = 6 bps *)
  let cm = { CM.zero with market_impact_bps_per_pct_adv = 2.0 } in
  let bps = CM.market_impact_bps cm ~adv_pct:3.0 in
  assert_that bps (float_equal 6.0)

let test_market_impact_negative_adv_clamped _ =
  let cm = { CM.zero with market_impact_bps_per_pct_adv = 2.0 } in
  let bps = CM.market_impact_bps cm ~adv_pct:(-1.0) in
  assert_that bps (float_equal 0.0)

(* ------------------------------------------------------------------ *)
(* apply_market_impact                                                  *)
(* ------------------------------------------------------------------ *)

let test_apply_market_impact_buy_pays_up _ =
  (* 10 bps impact: buy fills at 100 * 1.001 = 100.10 *)
  let cm = { CM.zero with market_impact_bps_per_pct_adv = 10.0 } in
  let p = CM.apply_market_impact cm ~adv_pct:1.0 ~side:Buy ~fill_price:100.0 in
  assert_that p (float_equal ~epsilon:1e-6 100.10)

let test_apply_market_impact_sell_takes_down _ =
  (* 10 bps impact: sell fills at 100 / 1.001 = 99.9001 *)
  let cm = { CM.zero with market_impact_bps_per_pct_adv = 10.0 } in
  let p = CM.apply_market_impact cm ~adv_pct:1.0 ~side:Sell ~fill_price:100.0 in
  assert_that p (float_equal ~epsilon:1e-6 (100.0 /. 1.001))

let test_apply_market_impact_zero_coef_identity _ =
  let p =
    CM.apply_market_impact CM.zero ~adv_pct:5.0 ~side:Buy ~fill_price:75.0
  in
  assert_that p (float_equal 75.0)

let test_apply_market_impact_zero_adv_identity _ =
  let cm = { CM.zero with market_impact_bps_per_pct_adv = 10.0 } in
  let p = CM.apply_market_impact cm ~adv_pct:0.0 ~side:Buy ~fill_price:75.0 in
  assert_that p (float_equal 75.0)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "cost_model"
  >::: [
         "zero_is_frictionless" >:: test_zero_is_frictionless;
         "retail_default_has_only_spread"
         >:: test_retail_default_has_only_spread;
         "institutional_default_has_per_share_and_impact"
         >:: test_institutional_default_has_per_share_and_impact;
         "validate_zero_ok" >:: test_validate_zero_ok;
         "validate_retail_ok" >:: test_validate_retail_ok;
         "validate_negative_per_trade_rejected"
         >:: test_validate_negative_per_trade_rejected;
         "validate_negative_per_share_rejected"
         >:: test_validate_negative_per_share_rejected;
         "validate_negative_spread_rejected"
         >:: test_validate_negative_spread_rejected;
         "validate_negative_impact_rejected"
         >:: test_validate_negative_impact_rejected;
         "validate_nan_rejected" >:: test_validate_nan_rejected;
         "validate_inf_rejected" >:: test_validate_inf_rejected;
         "engine_costs_zero" >:: test_engine_costs_zero;
         "engine_costs_per_share_forwarded"
         >:: test_engine_costs_per_share_forwarded;
         "engine_costs_spread_rounded_to_int"
         >:: test_engine_costs_spread_rounded_to_int;
         "engine_costs_spread_truncates_fractional"
         >:: test_engine_costs_spread_truncates_fractional;
         "engine_costs_per_trade_NOT_in_engine_costs"
         >:: test_engine_costs_per_trade_NOT_in_engine_costs;
         "per_trade_commission_adds_flat"
         >:: test_per_trade_commission_adds_flat;
         "per_trade_commission_independent_of_share_count"
         >:: test_per_trade_commission_independent_of_share_count;
         "per_trade_commission_stacks_on_existing"
         >:: test_per_trade_commission_stacks_on_existing;
         "per_trade_commission_zero_is_identity"
         >:: test_per_trade_commission_zero_is_identity;
         "market_impact_zero_coef_is_zero"
         >:: test_market_impact_zero_coef_is_zero;
         "market_impact_linear_in_adv" >:: test_market_impact_linear_in_adv;
         "market_impact_negative_adv_clamped"
         >:: test_market_impact_negative_adv_clamped;
         "apply_market_impact_buy_pays_up"
         >:: test_apply_market_impact_buy_pays_up;
         "apply_market_impact_sell_takes_down"
         >:: test_apply_market_impact_sell_takes_down;
         "apply_market_impact_zero_coef_identity"
         >:: test_apply_market_impact_zero_coef_identity;
         "apply_market_impact_zero_adv_identity"
         >:: test_apply_market_impact_zero_adv_identity;
       ]

let () = run_test_tt_main suite
