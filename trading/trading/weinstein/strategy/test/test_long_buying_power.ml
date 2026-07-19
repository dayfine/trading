open Core
open OUnit2
open Matchers
open Weinstein_strategy
module Margin_config = Trading_portfolio.Margin_config

let equity = 100_000.0

(* --- long_notional_ceiling --- *)

let test_ceiling_defaults_is_infinity _ =
  (* Config defaults: exposure disabled (0.0) + cash account (req 1.0) => no
     explicit ceiling. This is the R1 no-op: byte-identical to the pre-M1 inline
     [Float.infinity] the entry walk used. *)
  assert_that
    (Long_buying_power.long_notional_ceiling ~max_long_exposure_pct_entry:0.0
       ~initial_long_margin_req:1.0 ~equity)
    (equal_to Float.infinity)

let test_ceiling_e_capped_equals_equity _ =
  (* E-capped (#1965): exposure 1.0, cash account. Ceiling = min(equity, inf) =
     equity — the exact E-capped config is preserved. *)
  assert_that
    (Long_buying_power.long_notional_ceiling ~max_long_exposure_pct_entry:1.0
       ~initial_long_margin_req:1.0 ~equity)
    (float_equal equity)

let test_ceiling_exposure_term_binds _ =
  (* Exposure 0.7, cash account: exposure term binds at 0.7 * equity. *)
  assert_that
    (Long_buying_power.long_notional_ceiling ~max_long_exposure_pct_entry:0.7
       ~initial_long_margin_req:1.0 ~equity)
    (float_equal 70_000.0)

let test_ceiling_margin_term_opens_leverage _ =
  (* Exposure disabled, req 0.5 (Reg-T 2x): ceiling rises to 2 * equity of
     buying power. *)
  assert_that
    (Long_buying_power.long_notional_ceiling ~max_long_exposure_pct_entry:0.0
       ~initial_long_margin_req:0.5 ~equity)
    (float_equal 200_000.0)

let test_ceiling_min_of_both_terms _ =
  (* Both opted in: exposure 0.7 (=70k) vs margin 2x (=200k). min binds at the
     exposure term. *)
  assert_that
    (Long_buying_power.long_notional_ceiling ~max_long_exposure_pct_entry:0.7
       ~initial_long_margin_req:0.5 ~equity)
    (float_equal 70_000.0)

let test_ceiling_req_zero_guard_is_infinity _ =
  (* Guard: a non-positive requirement is treated as "no ceiling", never a
     division by zero. *)
  assert_that
    (Long_buying_power.long_notional_ceiling ~max_long_exposure_pct_entry:0.0
       ~initial_long_margin_req:0.0 ~equity)
    (equal_to Float.infinity)

(* --- daily_long_margin_rate --- *)

let test_daily_rate_zero_is_zero _ =
  assert_that
    (Long_buying_power.daily_long_margin_rate ~annual_pct:0.0)
    (float_equal 0.0)

let test_daily_rate_uses_252_daycount _ =
  (* Same day-count convention as the short borrow fee (252). *)
  assert_that
    (Long_buying_power.daily_long_margin_rate ~annual_pct:0.10)
    (float_equal (0.10 /. Margin_config.trading_days_per_year))

(* --- long_margin_interest_charge --- *)

let test_interest_zero_rate_is_zero _ =
  (* R1 no-op: default rate 0.0 charges nothing even on a positive debit. *)
  assert_that
    (Long_buying_power.long_margin_interest_charge ~rate_annual_pct:0.0
       ~debit_balance:50_000.0)
    (float_equal 0.0)

let test_interest_positive_debit_charged _ =
  (* One trading day of interest on a 50k debit at 10% annual. *)
  assert_that
    (Long_buying_power.long_margin_interest_charge ~rate_annual_pct:0.10
       ~debit_balance:50_000.0)
    (float_equal (50_000.0 *. 0.10 /. Margin_config.trading_days_per_year))

let test_interest_nonpositive_debit_is_zero _ =
  (* A credit / zero balance is charged nothing (no debit to finance). *)
  assert_that
    (Long_buying_power.long_margin_interest_charge ~rate_annual_pct:0.10
       ~debit_balance:(-25_000.0))
    (float_equal 0.0)

(* --- config wiring / round-trip --- *)

let test_default_config_no_op_values _ =
  let cfg =
    Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"SPY"
  in
  assert_that cfg
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.initial_long_margin_req)
           (float_equal 1.0);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.long_margin_rate_annual_pct)
           (float_equal 0.0);
         field
           (fun (c : Weinstein_strategy.config) -> c.maintenance_long_pct)
           (float_equal 0.0);
       ])

let test_config_round_trip_preserves_values _ =
  (* A non-default levered config survives sexp round-trip (R2 overlay path). *)
  let base =
    Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"SPY"
  in
  let levered =
    {
      base with
      initial_long_margin_req = 0.5;
      long_margin_rate_annual_pct = 0.08;
      maintenance_long_pct = 0.25;
    }
  in
  let round_tripped =
    Weinstein_strategy.config_of_sexp
      (Weinstein_strategy.sexp_of_config levered)
  in
  assert_that round_tripped
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.initial_long_margin_req)
           (float_equal 0.5);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.long_margin_rate_annual_pct)
           (float_equal 0.08);
         field
           (fun (c : Weinstein_strategy.config) -> c.maintenance_long_pct)
           (float_equal 0.25);
       ])

let test_pre_m1_sexp_parses_with_defaults _ =
  (* A config sexp that predates the margin work (no initial_long_margin_req /
     long_margin_rate_annual_pct / maintenance_long_pct fields) must parse with
     the no-op defaults — old scenario sexps replay bit-identically
     (experiment-flag-discipline R1). *)
  let base =
    Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"SPY"
  in
  let full = Weinstein_strategy.sexp_of_config base in
  let stripped =
    match full with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List (Sexp.Atom k :: _) ->
                not
                  (String.equal k "initial_long_margin_req"
                  || String.equal k "long_margin_rate_annual_pct"
                  || String.equal k "maintenance_long_pct")
            | _ -> true))
    | other -> other
  in
  assert_that
    (Weinstein_strategy.config_of_sexp stripped)
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.initial_long_margin_req)
           (float_equal 1.0);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.long_margin_rate_annual_pct)
           (float_equal 0.0);
         field
           (fun (c : Weinstein_strategy.config) -> c.maintenance_long_pct)
           (float_equal 0.0);
       ])

let suite =
  "long_buying_power"
  >::: [
         "ceiling: defaults => infinity" >:: test_ceiling_defaults_is_infinity;
         "ceiling: E-capped => equity" >:: test_ceiling_e_capped_equals_equity;
         "ceiling: exposure term binds" >:: test_ceiling_exposure_term_binds;
         "ceiling: margin term opens leverage"
         >:: test_ceiling_margin_term_opens_leverage;
         "ceiling: min of both terms" >:: test_ceiling_min_of_both_terms;
         "ceiling: req<=0 guard => infinity"
         >:: test_ceiling_req_zero_guard_is_infinity;
         "daily rate: zero => zero" >:: test_daily_rate_zero_is_zero;
         "daily rate: 252 day-count" >:: test_daily_rate_uses_252_daycount;
         "interest: zero rate => zero" >:: test_interest_zero_rate_is_zero;
         "interest: positive debit charged"
         >:: test_interest_positive_debit_charged;
         "interest: non-positive debit => zero"
         >:: test_interest_nonpositive_debit_is_zero;
         "config: default no-op values" >:: test_default_config_no_op_values;
         "config: round-trip preserves values"
         >:: test_config_round_trip_preserves_values;
         "config: pre-M1 sexp parses with defaults"
         >:: test_pre_m1_sexp_parses_with_defaults;
       ]

let () = run_test_tt_main suite
