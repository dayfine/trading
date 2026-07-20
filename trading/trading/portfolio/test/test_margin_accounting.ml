(* Tests for margin accounting Phase 1 (issue #859).

   Covers four behavioural surfaces:
   - flag-off bit-equality: apply_*_with_margin under default config is a
     pass-through of apply_single_trade / apply_trades
   - flag-on initial collateral lock on short entry + release on cover
   - flag-on borrow-fee accrual
   - flag-on maintenance-margin threshold (boundary + breach + no-trigger)

   The flag-off regression is the load-bearing invariant: enabling this
   work behind a config flag must not perturb any existing baseline. *)

open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Portfolio
open Trading_portfolio.Portfolio_margin
module Margin_config = Trading_portfolio.Margin_config
open Matchers

(* Test data builder — mirrors the one in test_portfolio.ml. Kept inline
   per .claude/rules/test-patterns.md (simple constructors stay in test
   files). *)
let make_trade ~id ~order_id ~symbol ~side ~quantity ~price ?(commission = 0.0)
    () =
  {
    id;
    order_id;
    symbol;
    side;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.now ();
  }

(* Domain helper: Ok-or-fail for setup paths that should never fail. *)
let apply_trades_with_margin_exn portfolio trades ~margin_config ~error_msg =
  match apply_trades_with_margin ~margin_config portfolio trades with
  | Ok value -> value
  | Error err -> assert_failure (error_msg ^ ": " ^ Status.show err)

let apply_trades_exn portfolio trades ~error_msg =
  match apply_trades portfolio trades with
  | Ok value -> value
  | Error err -> assert_failure (error_msg ^ ": " ^ Status.show err)

(* ========================================================================== *)
(* Flag-off bit-equality regression                                           *)
(* ========================================================================== *)

(* The single most important guarantee: with [enabled = false], all
   margin-aware APIs collapse to no-ops that produce portfolios bit-equal
   to the legacy entry points. This is what lets us land this change
   without re-pinning every long-only golden. *)

let test_flag_off_short_entry_matches_legacy _ =
  let cash = 10_000.0 in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
        ~quantity:100.0 ~price:50.0 ();
    ]
  in
  let legacy =
    apply_trades_exn
      (create ~initial_cash:cash ())
      trades ~error_msg:"legacy short entry"
  in
  assert_that
    (apply_trades_with_margin ~margin_config:Margin_config.default_config
       (create ~initial_cash:cash ())
       trades)
    (is_ok_and_holds (equal_to (legacy : t)))

let test_flag_off_long_only_sequence_bit_equal _ =
  (* Run a multi-trade long-only sequence through both code paths and
     assert bit-equal final portfolios. This is the regression that
     guards every long-only golden. *)
  let cash = 100_000.0 in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ~commission:1.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy ~quantity:50.0
        ~price:200.0 ~commission:1.0 ();
      make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
        ~quantity:30.0 ~price:160.0 ~commission:1.0 ();
      make_trade ~id:"t4" ~order_id:"o4" ~symbol:"MSFT" ~side:Sell
        ~quantity:50.0 ~price:220.0 ~commission:1.0 ();
    ]
  in
  let legacy =
    apply_trades_exn (create ~initial_cash:cash ()) trades ~error_msg:"legacy"
  in
  assert_that
    (apply_trades_with_margin ~margin_config:Margin_config.default_config
       (create ~initial_cash:cash ())
       trades)
    (is_ok_and_holds (equal_to (legacy : t)))

let test_flag_off_borrow_fee_is_noop _ =
  let portfolio =
    apply_trades_exn
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  let after_fee =
    accrue_daily_borrow_fee ~margin_config:Margin_config.default_config
      portfolio
      [ ("AAPL", 60.0) ]
  in
  assert_that after_fee (equal_to (portfolio : t))

let test_flag_off_maintenance_check_returns_empty _ =
  let portfolio =
    apply_trades_exn
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  (* Even with the price moved well past the would-be trigger, no symbols
     are flagged because the flag is off. *)
  assert_that
    (check_maintenance_margin ~margin_config:Margin_config.default_config
       portfolio
       [ ("AAPL", 100.0) ])
    (elements_are [])

(* ========================================================================== *)
(* Flag-on: initial collateral lock on short entry                            *)
(* ========================================================================== *)

let on_config =
  { Margin_config.default_config with Margin_config.enabled = true }

let test_short_entry_locks_collateral _ =
  (* 100 shares @ $50, notional $5000. With initial_margin_pct=0.50, total
     collateral = 1.5 * 5000 = $7500. current_cash credits proceeds as
     usual (+$5000); available_cash = 10000 + 5000 - 7500 = $7500. *)
  let portfolio = create ~initial_cash:10_000.0 () in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:50.0 ()
  in
  assert_that
    (apply_single_trade_with_margin ~margin_config:on_config portfolio trade)
    (is_ok_and_holds
       (all_of
          [
            field (fun p -> p.current_cash) (float_equal 15_000.0);
            field (fun p -> p.locked_collateral) (float_equal 7_500.0);
            field (fun p -> available_cash p) (float_equal 7_500.0);
          ]))

let test_short_entry_rejected_when_insufficient_collateral _ =
  (* 100 shares @ $50, notional $5000, collateral 7500. Cash $5000 means
     after proceeds = $10000, but lock would be $7500, leaving only $2500
     of available cash — still positive, so accept. Bump to a tighter
     case: cash $1000 → after proceeds = $6000, lock $7500 → available
     -$1500 < 0 → reject. *)
  let portfolio = create ~initial_cash:1_000.0 () in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell ~quantity:100.0
      ~price:50.0 ()
  in
  assert_that
    (apply_single_trade_with_margin ~margin_config:on_config portfolio trade)
    is_error

let test_short_cover_releases_collateral _ =
  (* Open short 100 @ $50 (lock $7500), then cover all 100 @ $50.
     Cover cash change: -5000. Released collateral: factor * 100 * 50 =
     1.5 * 5000 = $7500. Final: current_cash = 10000, locked = 0. *)
  let portfolio = create ~initial_cash:10_000.0 () in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
        ~quantity:100.0 ~price:50.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:50.0 ();
    ]
  in
  assert_that
    (apply_trades_with_margin ~margin_config:on_config portfolio trades)
    (is_ok_and_holds
       (all_of
          [
            field (fun p -> p.current_cash) (float_equal 10_000.0);
            field (fun p -> p.locked_collateral) (float_equal 0.0);
          ]))

let test_short_partial_cover_releases_proportional_collateral _ =
  (* Open short 100 @ $50 (lock $7500), then cover 40 @ $50.
     Released: 1.5 * 40 * 50 = $3000. Final locked = $4500.
     Cash: 10000 + 5000 - 2000 = $13000. *)
  let portfolio = create ~initial_cash:10_000.0 () in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
        ~quantity:100.0 ~price:50.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Buy ~quantity:40.0
        ~price:50.0 ();
    ]
  in
  assert_that
    (apply_trades_with_margin ~margin_config:on_config portfolio trades)
    (is_ok_and_holds
       (all_of
          [
            field (fun p -> p.current_cash) (float_equal 13_000.0);
            field (fun p -> p.locked_collateral) (float_equal 4_500.0);
          ]))

let test_long_trade_under_margin_on_does_not_lock _ =
  (* Buy of 100 @ $50: pure long entry, no collateral changes. Confirms
     classification routes correctly when margin is on. *)
  let portfolio = create ~initial_cash:10_000.0 () in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:100.0
      ~price:50.0 ()
  in
  assert_that
    (apply_single_trade_with_margin ~margin_config:on_config portfolio trade)
    (is_ok_and_holds
       (all_of
          [
            field (fun p -> p.current_cash) (float_equal 5_000.0);
            field (fun p -> p.locked_collateral) (float_equal 0.0);
          ]))

(* ========================================================================== *)
(* Flag-on: maintenance margin breach                                         *)
(* ========================================================================== *)

(* With defaults im=0.50, mm=0.25, trigger price for short at entry $50:
     p_trigger = 50 * 1.50 / 1.25 = $60.
   At price < $60 the ratio is >= 0.25 → no trigger.
   At price = $60 the ratio is exactly 0.25 (borderline → no trigger because
     the rule is strict-less-than).
   At price > $60 (even by a cent) the ratio is < 0.25 → trigger. *)

let test_maintenance_breach_far_past_trigger _ =
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  assert_that
    (check_maintenance_margin ~margin_config:on_config portfolio
       [ ("AAPL", 70.0) ])
    (elements_are [ equal_to "AAPL" ])

let test_maintenance_at_threshold_no_trigger _ =
  (* Exactly at the trigger price → ratio = maintenance_margin_pct.
     Rule is strict less-than, so this must NOT fire. *)
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  assert_that
    (check_maintenance_margin ~margin_config:on_config portfolio
       [ ("AAPL", 60.0) ])
    (elements_are [])

let test_maintenance_one_bp_above_threshold_triggers _ =
  (* Just past the trigger by 1 bp ($60.006) → ratio dips below 0.25,
     symbol flagged. *)
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  assert_that
    (check_maintenance_margin ~margin_config:on_config portfolio
       [ ("AAPL", 60.006) ])
    (elements_are [ equal_to "AAPL" ])

let test_maintenance_well_below_trigger_no_flag _ =
  (* Price moved against entry but still inside the cushion. *)
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  assert_that
    (check_maintenance_margin ~margin_config:on_config portfolio
       [ ("AAPL", 55.0) ])
    (elements_are [])

let test_maintenance_long_position_ignored _ =
  (* Maintenance margin applies only to shorts. A long position is
     never returned by check_maintenance_margin even if its price has
     halved. *)
  let portfolio =
    apply_trades_exn
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"long entry"
  in
  assert_that
    (check_maintenance_margin ~margin_config:on_config portfolio
       [ ("AAPL", 1.0) ])
    (elements_are [])

let test_maintenance_check_sorts_flagged_symbols _ =
  (* Two shorts both breach — the returned list should be sorted by
     symbol so downstream audit ordering is deterministic. *)
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:30_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"ZZZ" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAA" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"two shorts"
  in
  assert_that
    (check_maintenance_margin ~margin_config:on_config portfolio
       [ ("AAA", 70.0); ("ZZZ", 70.0) ])
    (elements_are [ equal_to "AAA"; equal_to "ZZZ" ])

(* ========================================================================== *)
(* Flag-on: daily borrow-fee accrual                                          *)
(* ========================================================================== *)

(* Default config: 50 bps annual, 252 trading days → daily rate ≈
   1.984e-5. On 100 shares short at $50 (notional $5000), one day of fee =
   5000 * (0.005 / 252) ≈ $0.0992. *)

let _expected_daily_fee notional cfg =
  notional *. Margin_config.daily_borrow_rate cfg

let test_borrow_fee_single_day _ =
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
      ]
      ~error_msg:"short entry"
  in
  let prices = [ ("AAPL", 50.0) ] in
  let expected_fee = _expected_daily_fee 5_000.0 on_config in
  let after =
    accrue_daily_borrow_fee ~margin_config:on_config portfolio prices
  in
  assert_that after
    (all_of
       [
         field
           (fun p -> p.current_cash)
           (float_equal (portfolio.current_cash -. expected_fee));
         field (fun p -> p.accrued_borrow_fee) (float_equal expected_fee);
       ])

let test_borrow_fee_one_trading_year _ =
  (* Accruing 252 daily fees at constant notional should sum to almost
     exactly the annual rate * notional. *)
  let cfg = on_config in
  let entry_price = 50.0 in
  let qty = 100.0 in
  let notional = entry_price *. qty in
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:cfg
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:qty ~price:entry_price ();
      ]
      ~error_msg:"short entry"
  in
  let prices = [ ("AAPL", entry_price) ] in
  let n_days = Float.to_int Margin_config.trading_days_per_year in
  let final =
    List.init n_days ~f:(fun _ -> ())
    |> List.fold ~init:portfolio ~f:(fun acc () ->
        accrue_daily_borrow_fee ~margin_config:cfg acc prices)
  in
  let expected_total = notional *. cfg.short_borrow_fee_annual_pct in
  assert_that final.accrued_borrow_fee
    (float_equal ~epsilon:1e-9 expected_total)

let test_borrow_fee_zero_when_no_shorts _ =
  let portfolio =
    apply_trades_exn
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:50.0 ~price:50.0 ();
      ]
      ~error_msg:"long entry"
  in
  let after =
    accrue_daily_borrow_fee ~margin_config:on_config portfolio
      [ ("AAPL", 50.0) ]
  in
  assert_that after
    (all_of
       [
         field (fun p -> p.current_cash) (float_equal portfolio.current_cash);
         field (fun p -> p.accrued_borrow_fee) (float_equal 0.0);
       ])

let test_sum_short_notional_combines_positions _ =
  let portfolio =
    apply_trades_with_margin_exn ~margin_config:on_config
      (create ~initial_cash:30_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
          ~quantity:100.0 ~price:50.0 ();
        make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Sell
          ~quantity:50.0 ~price:100.0 ();
      ]
      ~error_msg:"two shorts"
  in
  (* AAPL marked $60: 100 * 60 = 6000. MSFT marked $110: 50 * 110 = 5500.
     Total: 11500. *)
  assert_that
    (sum_short_notional portfolio [ ("AAPL", 60.0); ("MSFT", 110.0) ])
    (float_equal 11_500.0)

(* ========================================================================== *)
(* Flag-on: HTB tiered borrow rate + tiered maintenance (margin M3a)          *)
(* ========================================================================== *)

(* A HTB borrow-rate table: sub-$17 names pay 50%/yr, everything else the flat
   50bps fallback. Sits in the test, not baked into code (R1). *)
let htb_borrow_config =
  {
    on_config with
    Margin_config.short_borrow_rate_tiers =
      [ { Trading_portfolio.Short_margin_tiers.price_below = 17.0; value = 0.50 } ];
  }

(* Two shorts at $10 (HTB tier) and $50 (flat fallback). Each position pays its
   own price-tiered rate; the total is their sum. *)
let _two_price_shorts () =
  apply_trades_with_margin_exn ~margin_config:on_config
    (create ~initial_cash:30_000.0 ())
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"CHEAP" ~side:Sell
        ~quantity:100.0 ~price:10.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"RICH" ~side:Sell
        ~quantity:100.0 ~price:50.0 ();
    ]
    ~error_msg:"two shorts"

let test_borrow_fee_tiered_charges_per_price _ =
  let portfolio = _two_price_shorts () in
  let prices = [ ("CHEAP", 10.0); ("RICH", 50.0) ] in
  (* CHEAP: notional 1000 at 50%/yr; RICH: notional 5000 at flat 50bps. *)
  let expected_fee =
    (1_000.0 *. (0.50 /. Margin_config.trading_days_per_year))
    +. (5_000.0 *. (0.005 /. Margin_config.trading_days_per_year))
  in
  assert_that
    (accrue_daily_borrow_fee ~margin_config:htb_borrow_config portfolio prices)
    (field (fun p -> p.accrued_borrow_fee) (float_equal ~epsilon:1e-12 expected_fee))

let test_borrow_fee_empty_tiers_bit_equal_flat _ =
  (* Empty tier table (the default) → every short pays the flat rate, so the
     per-position sum equals the legacy sum_short_notional * flat_daily_rate. *)
  let portfolio = _two_price_shorts () in
  let prices = [ ("CHEAP", 10.0); ("RICH", 50.0) ] in
  let expected_fee = _expected_daily_fee 6_000.0 on_config in
  assert_that
    (accrue_daily_borrow_fee ~margin_config:on_config portfolio prices)
    (field (fun p -> p.accrued_borrow_fee) (float_equal ~epsilon:1e-12 expected_fee))

(* A short 100 @ $10, marked $10: equity_ratio = (1.5*10 - 10)/10 = 0.5. Above
   the flat 25% (not flagged), but below a 100% sub-$17 tier (flagged). *)
let _cheap_short () =
  apply_trades_with_margin_exn ~margin_config:on_config
    (create ~initial_cash:10_000.0 ())
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"CHEAP" ~side:Sell
        ~quantity:100.0 ~price:10.0 ();
    ]
    ~error_msg:"cheap short"

let test_maintenance_flat_does_not_flag_cheap_short _ =
  assert_that
    (check_maintenance_margin ~margin_config:on_config (_cheap_short ())
       [ ("CHEAP", 10.0) ])
    (elements_are [])

let test_maintenance_tiered_flags_cheap_short _ =
  let tiered_config =
    {
      on_config with
      Margin_config.short_maintenance_tiers =
        [
          { Trading_portfolio.Short_margin_tiers.price_below = 17.0; value = 1.0 };
        ];
    }
  in
  assert_that
    (check_maintenance_margin ~margin_config:tiered_config (_cheap_short ())
       [ ("CHEAP", 10.0) ])
    (elements_are [ equal_to "CHEAP" ])

let test_margin_config_round_trip_preserves_tiers _ =
  let armed =
    {
      Margin_config.default_config with
      Margin_config.short_borrow_rate_tiers =
        [ { Trading_portfolio.Short_margin_tiers.price_below = 5.0; value = 1.0 } ];
      Margin_config.short_maintenance_tiers =
        [
          { Trading_portfolio.Short_margin_tiers.price_below = 17.0; value = 0.83 };
        ];
    }
  in
  assert_that
    (Margin_config.t_of_sexp (Margin_config.sexp_of_t armed))
    (equal_to (armed : Margin_config.t))

let test_pre_m3a_margin_config_sexp_parses_with_empty_tiers _ =
  (* A pre-M3a margin_config sexp (no tier fields) must decode with empty
     tables — the [@sexp.default []] back-compat contract. *)
  let sexp =
    Sexp.of_string
      "((enabled true) (initial_margin_pct 0.5) (maintenance_margin_pct 0.25) \
       (short_borrow_fee_annual_pct 0.005))"
  in
  assert_that
    (Margin_config.t_of_sexp sexp)
    (all_of
       [
         field (fun c -> c.Margin_config.short_borrow_rate_tiers) (size_is 0);
         field (fun c -> c.Margin_config.short_maintenance_tiers) (size_is 0);
       ])

(* ========================================================================== *)
(* Long-margin (levered long) accounting — margin M1b-2                       *)
(* ========================================================================== *)

(* Armed leverage: initial_long_margin_req = 0.5 (2x buying power), interest
   10%/yr. The disarmed default is req = 1.0 (a cash account). *)
let armed_req = 0.5
let armed_rate = 0.10

let apply_long_margin_exn ?(initial_long_margin_req = armed_req) portfolio trade
    ~error_msg =
  match
    apply_single_trade_with_long_margin ~initial_long_margin_req portfolio trade
  with
  | Ok v -> v
  | Error err -> assert_failure (error_msg ^ ": " ^ Status.show err)

(* Levered long entry funding the shortfall into long_margin_debit. cash $1000,
   buy 20 @ $100 → cost $2000, borrow $1000. *)
let _levered_buy_portfolio () =
  apply_long_margin_exn
    (create ~initial_cash:1_000.0 ())
    (make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:20.0
       ~price:100.0 ())
    ~error_msg:"levered buy"

let test_disarmed_over_cash_buy_still_rejected _ =
  (* req = 1.0 (cash account): a buy exceeding cash is rejected exactly like the
     base apply — the cash floor is untouched, no debit is funded. *)
  let portfolio = create ~initial_cash:1_000.0 () in
  let trade =
    make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy ~quantity:20.0
      ~price:100.0 ()
  in
  assert_that
    (apply_single_trade_with_long_margin ~initial_long_margin_req:1.0 portfolio
       trade)
    is_error

let test_disarmed_sequence_bit_equal_to_legacy _ =
  (* Parity pin: the long-margin apply at req = 1.0 over a mixed buy/sell
     sequence is bit-equal to the legacy [apply_trades] (long_margin_debit stays
     0.0, captured by whole-record equality). *)
  let cash = 100_000.0 in
  let trades =
    [
      make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
        ~quantity:100.0 ~price:150.0 ~commission:1.0 ();
      make_trade ~id:"t2" ~order_id:"o2" ~symbol:"MSFT" ~side:Buy ~quantity:50.0
        ~price:200.0 ~commission:1.0 ();
      make_trade ~id:"t3" ~order_id:"o3" ~symbol:"AAPL" ~side:Sell
        ~quantity:30.0 ~price:160.0 ~commission:1.0 ();
    ]
  in
  let legacy =
    apply_trades_exn (create ~initial_cash:cash ()) trades ~error_msg:"legacy"
  in
  let via_margin =
    List.fold trades ~init:(create ~initial_cash:cash ()) ~f:(fun acc tr ->
        apply_long_margin_exn ~initial_long_margin_req:1.0 acc tr
          ~error_msg:"disarmed")
  in
  assert_that via_margin (equal_to (legacy : t))

let test_levered_buy_creates_debit _ =
  (* Armed: cash $1000, buy 20 @ $100 = $2000. Own cash spent to $0, $1000
     borrowed into long_margin_debit; equity_cash = 0 - 1000 = -1000. *)
  assert_that
    (_levered_buy_portfolio ())
    (all_of
       [
         field (fun p -> p.current_cash) (float_equal 0.0);
         field (fun p -> p.long_margin_debit) (float_equal 1_000.0);
         field (fun p -> equity_cash p) (float_equal (-1_000.0));
       ])

let test_levered_buy_equity_subtracts_debit _ =
  (* NAV honesty: marked at the entry price, portfolio value on equity_cash =
     -1000 + 20*100 = $1000 — exactly the $1000 of own capital, no phantom gain
     from the borrowed cash. *)
  let after = _levered_buy_portfolio () in
  assert_that
    (Trading_portfolio.Calculations.portfolio_value after.positions
       (equity_cash after)
       [ ("AAPL", 100.0) ])
    (is_ok_and_holds (float_equal 1_000.0))

let test_levered_buy_within_cash_takes_no_debit _ =
  (* Armed but the buy fits within available cash: no borrow, byte-identical to
     the base apply (debit stays 0). cash $10000, buy 20 @ $100 = $2000. *)
  let after =
    apply_long_margin_exn
      (create ~initial_cash:10_000.0 ())
      (make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
         ~quantity:20.0 ~price:100.0 ())
      ~error_msg:"within-cash buy"
  in
  assert_that after
    (all_of
       [
         field (fun p -> p.current_cash) (float_equal 8_000.0);
         field (fun p -> p.long_margin_debit) (float_equal 0.0);
       ])

let test_armed_short_open_does_not_fund_debit _ =
  (* Leverage relaxes long buys only. A Sell opening a short under armed req
     takes the base apply path — no long_margin_debit. *)
  let after =
    apply_long_margin_exn
      (create ~initial_cash:10_000.0 ())
      (make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Sell
         ~quantity:100.0 ~price:50.0 ())
      ~error_msg:"short open"
  in
  assert_that after
    (all_of
       [
         field (fun p -> p.current_cash) (float_equal 15_000.0);
         field (fun p -> p.long_margin_debit) (float_equal 0.0);
       ])

let test_levered_exit_clears_debit_then_cash _ =
  (* Exit pays down the debit first. From (cash 0, debit 1000, 20 sh @ 100),
     sell 20 @ $120 → proceeds $2400; paydown min(1000,2400)=1000 → debit 0,
     cash 2400-1000=1400. *)
  let after =
    apply_long_margin_exn
      (_levered_buy_portfolio ())
      (make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
         ~quantity:20.0 ~price:120.0 ())
      ~error_msg:"exit clears debit"
  in
  assert_that after
    (all_of
       [
         field (fun p -> p.current_cash) (float_equal 1_400.0);
         field (fun p -> p.long_margin_debit) (float_equal 0.0);
       ])

let test_levered_exit_partial_proceeds_leaves_residual_debit _ =
  (* Proceeds below the debit: cash stays $0, debit only partly paid. From
     (cash 0, debit 1000, 20 sh @ 100), sell 20 @ $40 → proceeds $800; paydown
     min(1000,800)=800 → cash 0, debit 200. *)
  let after =
    apply_long_margin_exn
      (_levered_buy_portfolio ())
      (make_trade ~id:"t2" ~order_id:"o2" ~symbol:"AAPL" ~side:Sell
         ~quantity:20.0 ~price:40.0 ())
      ~error_msg:"exit residual debit"
  in
  assert_that after
    (all_of
       [
         field (fun p -> p.current_cash) (float_equal 0.0);
         field (fun p -> p.long_margin_debit) (float_equal 200.0);
       ])

let test_long_margin_interest_n_ticks _ =
  (* N days of interest capitalize onto the debit:
     debit_N = debit_0 * (1 + rate/252)^N. Checked at N=3 against the same math
     as Long_buying_power.long_margin_interest_charge. *)
  let daily = armed_rate /. Margin_config.trading_days_per_year in
  let after =
    List.init 3 ~f:(fun _ -> ())
    |> List.fold ~init:(_levered_buy_portfolio ()) ~f:(fun acc () ->
        accrue_daily_long_margin_interest ~rate_annual_pct:armed_rate acc)
  in
  let expected = 1_000.0 *. ((1.0 +. daily) ** 3.0) in
  assert_that after.long_margin_debit (float_equal ~epsilon:1e-9 expected)

let test_long_margin_interest_zero_rate_noop _ =
  let p0 = _levered_buy_portfolio () in
  assert_that
    (accrue_daily_long_margin_interest ~rate_annual_pct:0.0 p0)
    (equal_to (p0 : t))

let test_long_margin_interest_no_debit_noop _ =
  (* Positive rate but no debit (cash account): unchanged. *)
  let p0 =
    apply_trades_exn
      (create ~initial_cash:10_000.0 ())
      [
        make_trade ~id:"t1" ~order_id:"o1" ~symbol:"AAPL" ~side:Buy
          ~quantity:20.0 ~price:100.0 ();
      ]
      ~error_msg:"cash buy"
  in
  assert_that
    (accrue_daily_long_margin_interest ~rate_annual_pct:armed_rate p0)
    (equal_to (p0 : t))

(* ========================================================================== *)
(* Default config sanity                                                      *)
(* ========================================================================== *)

let test_default_config_is_disabled _ =
  assert_that Margin_config.default_config.enabled (equal_to false)

let test_default_config_factor_matches_book _ =
  (* Default initial_margin_pct = 0.50 → factor = 1.50. *)
  assert_that
    (Margin_config.total_collateral_factor Margin_config.default_config)
    (float_equal 1.5)

(* ========================================================================== *)
(* Test suite                                                                 *)
(* ========================================================================== *)

let suite =
  "test_margin_accounting"
  >::: [
         "test_flag_off_short_entry_matches_legacy"
         >:: test_flag_off_short_entry_matches_legacy;
         "test_flag_off_long_only_sequence_bit_equal"
         >:: test_flag_off_long_only_sequence_bit_equal;
         "test_flag_off_borrow_fee_is_noop" >:: test_flag_off_borrow_fee_is_noop;
         "test_flag_off_maintenance_check_returns_empty"
         >:: test_flag_off_maintenance_check_returns_empty;
         "test_short_entry_locks_collateral"
         >:: test_short_entry_locks_collateral;
         "test_short_entry_rejected_when_insufficient_collateral"
         >:: test_short_entry_rejected_when_insufficient_collateral;
         "test_short_cover_releases_collateral"
         >:: test_short_cover_releases_collateral;
         "test_short_partial_cover_releases_proportional_collateral"
         >:: test_short_partial_cover_releases_proportional_collateral;
         "test_long_trade_under_margin_on_does_not_lock"
         >:: test_long_trade_under_margin_on_does_not_lock;
         "test_maintenance_breach_far_past_trigger"
         >:: test_maintenance_breach_far_past_trigger;
         "test_maintenance_at_threshold_no_trigger"
         >:: test_maintenance_at_threshold_no_trigger;
         "test_maintenance_one_bp_above_threshold_triggers"
         >:: test_maintenance_one_bp_above_threshold_triggers;
         "test_maintenance_well_below_trigger_no_flag"
         >:: test_maintenance_well_below_trigger_no_flag;
         "test_maintenance_long_position_ignored"
         >:: test_maintenance_long_position_ignored;
         "test_maintenance_check_sorts_flagged_symbols"
         >:: test_maintenance_check_sorts_flagged_symbols;
         "test_borrow_fee_single_day" >:: test_borrow_fee_single_day;
         "test_borrow_fee_one_trading_year" >:: test_borrow_fee_one_trading_year;
         "test_borrow_fee_zero_when_no_shorts"
         >:: test_borrow_fee_zero_when_no_shorts;
         "test_sum_short_notional_combines_positions"
         >:: test_sum_short_notional_combines_positions;
         "test_borrow_fee_tiered_charges_per_price"
         >:: test_borrow_fee_tiered_charges_per_price;
         "test_borrow_fee_empty_tiers_bit_equal_flat"
         >:: test_borrow_fee_empty_tiers_bit_equal_flat;
         "test_maintenance_flat_does_not_flag_cheap_short"
         >:: test_maintenance_flat_does_not_flag_cheap_short;
         "test_maintenance_tiered_flags_cheap_short"
         >:: test_maintenance_tiered_flags_cheap_short;
         "test_margin_config_round_trip_preserves_tiers"
         >:: test_margin_config_round_trip_preserves_tiers;
         "test_pre_m3a_margin_config_sexp_parses_with_empty_tiers"
         >:: test_pre_m3a_margin_config_sexp_parses_with_empty_tiers;
         "test_disarmed_over_cash_buy_still_rejected"
         >:: test_disarmed_over_cash_buy_still_rejected;
         "test_disarmed_sequence_bit_equal_to_legacy"
         >:: test_disarmed_sequence_bit_equal_to_legacy;
         "test_levered_buy_creates_debit" >:: test_levered_buy_creates_debit;
         "test_levered_buy_equity_subtracts_debit"
         >:: test_levered_buy_equity_subtracts_debit;
         "test_levered_buy_within_cash_takes_no_debit"
         >:: test_levered_buy_within_cash_takes_no_debit;
         "test_armed_short_open_does_not_fund_debit"
         >:: test_armed_short_open_does_not_fund_debit;
         "test_levered_exit_clears_debit_then_cash"
         >:: test_levered_exit_clears_debit_then_cash;
         "test_levered_exit_partial_proceeds_leaves_residual_debit"
         >:: test_levered_exit_partial_proceeds_leaves_residual_debit;
         "test_long_margin_interest_n_ticks"
         >:: test_long_margin_interest_n_ticks;
         "test_long_margin_interest_zero_rate_noop"
         >:: test_long_margin_interest_zero_rate_noop;
         "test_long_margin_interest_no_debit_noop"
         >:: test_long_margin_interest_no_debit_noop;
         "test_default_config_is_disabled" >:: test_default_config_is_disabled;
         "test_default_config_factor_matches_book"
         >:: test_default_config_factor_matches_book;
       ]

let () = run_test_tt_main suite
