open Core
open OUnit2
open Matchers
open Weinstein_strategy
module Config = Weinstein_strategy_config
module Margin_config = Trading_portfolio.Margin_config

(* ------------------------------------------------------------------ *)
(* Pure signal: flip_age_weeks / is_dawn                               *)
(* slope_lookback = 1, slope_threshold = 0.0 => "rising at offset o"   *)
(* iff ma.(o) >= ma.(o+1). Offset 0 is the current (newest) week.      *)
(* ------------------------------------------------------------------ *)

let ma_of arr ~week_offset =
  if week_offset >= 0 && week_offset < Array.length arr then
    Some arr.(week_offset)
  else None

let flip_age arr ~max_flip_age_weeks =
  Leverage_dawn.flip_age_weeks ~get_ma:(ma_of arr) ~slope_lookback:1
    ~slope_threshold:0.0 ~max_flip_age_weeks

(* A young post-bear uptrend: MA rising for the 3 most recent weeks (offsets
   0..2), the flip (older week non-rising) at offset 3 -> age 2. *)
let young_uptrend = [| 110.0; 108.0; 106.0; 104.0; 105.0; 106.0; 107.0 |]

let test_young_flip_is_dawn _ =
  assert_that
    (flip_age young_uptrend ~max_flip_age_weeks:52)
    (is_some_and (equal_to 2))

let test_flip_age_boundary_inclusive _ =
  (* age 2 with max 2 => still dawn (inclusive boundary). *)
  assert_that
    (flip_age young_uptrend ~max_flip_age_weeks:2)
    (is_some_and (equal_to 2))

let test_old_flip_beyond_window_not_dawn _ =
  (* age 2 with max 1 => flip predates the window => not dawn. *)
  assert_that (flip_age young_uptrend ~max_flip_age_weeks:1) is_none

let test_current_slope_negative_not_dawn _ =
  (* MA declining into the current week (offset 0 not rising). *)
  let declining = [| 100.0; 102.0; 104.0; 106.0 |] in
  assert_that (flip_age declining ~max_flip_age_weeks:52) is_none

let test_data_boundary_inconclusive_not_dawn _ =
  (* MA rising through the whole available history: no non-rising week is ever
     reached (the older anchor runs off the end), so the flip cannot be
     confirmed recent => not dawn (conservative). *)
  let all_rising = [| 106.0; 105.0; 104.0; 103.0 |] in
  assert_that (flip_age all_rising ~max_flip_age_weeks:52) is_none

let test_is_dawn_matches_flip_age _ =
  assert_that
    (Leverage_dawn.is_dawn ~get_ma:(ma_of young_uptrend) ~slope_lookback:1
       ~slope_threshold:0.0 ~max_flip_age_weeks:52)
    (equal_to true)

(* ------------------------------------------------------------------ *)
(* effective_initial_long_margin_req                                   *)
(* ------------------------------------------------------------------ *)

let base_config : Config.config =
  Config.default_config ~universe:[ "AAA" ] ~index_symbol:"IDX"

let dawn_enabled_config : Config.config =
  {
    base_config with
    dawn_leverage_enabled = true;
    (* Base = the permissive rung the simulator funds at; must be <= the dawn
       rung so [validate] passes and a levered dawn entry actually funds. *)
    initial_long_margin_req = 0.75;
    dawn_initial_long_margin_req = 0.75;
    dawn_max_ma_flip_age_weeks = 52;
  }

let test_effective_req_dawn_active _ =
  assert_that
    (Leverage_dawn.effective_initial_long_margin_req ~config:dawn_enabled_config
       ~dawn_active:true)
    (float_equal 0.75)

let test_effective_req_not_dawn _ =
  assert_that
    (Leverage_dawn.effective_initial_long_margin_req ~config:dawn_enabled_config
       ~dawn_active:false)
    (float_equal 1.0)

let test_effective_req_disabled_ignores_dawn _ =
  (* Even a dawn week uses the base requirement when the mechanism is off. *)
  assert_that
    (Leverage_dawn.effective_initial_long_margin_req ~config:base_config
       ~dawn_active:true)
    (float_equal 1.0)

(* ------------------------------------------------------------------ *)
(* validate                                                            *)
(* ------------------------------------------------------------------ *)

let armed_margin (config : Config.config) : Config.config =
  {
    config with
    margin_config = { config.margin_config with Margin_config.enabled = true };
  }

let raises_failure f =
  try
    f ();
    false
  with Failure _ -> true

let test_validate_disabled_is_noop _ =
  assert_that
    (raises_failure (fun () -> Leverage_dawn.validate base_config))
    (equal_to false)

let test_validate_enabled_requires_margin_armed _ =
  (* enabled but margin disarmed (default) => raise. *)
  assert_that
    (raises_failure (fun () -> Leverage_dawn.validate dawn_enabled_config))
    (equal_to true)

let test_validate_enabled_armed_ok _ =
  assert_that
    (raises_failure (fun () ->
         Leverage_dawn.validate (armed_margin dawn_enabled_config)))
    (equal_to false)

let test_validate_req_above_one_raises _ =
  let cfg =
    armed_margin { dawn_enabled_config with dawn_initial_long_margin_req = 1.5 }
  in
  assert_that
    (raises_failure (fun () -> Leverage_dawn.validate cfg))
    (equal_to true)

let test_validate_req_zero_raises _ =
  let cfg =
    armed_margin { dawn_enabled_config with dawn_initial_long_margin_req = 0.0 }
  in
  assert_that
    (raises_failure (fun () -> Leverage_dawn.validate cfg))
    (equal_to true)

let test_validate_base_exceeds_dawn_req_raises _ =
  (* Base req = 1.0 (cash account) is more restrictive than the dawn rung 0.75:
     the simulator would fund at 1.0 and floor-reject the levered dawn entry (the
     B1 misconfiguration). validate must catch base > dawn. *)
  let cfg =
    armed_margin { dawn_enabled_config with initial_long_margin_req = 1.0 }
  in
  assert_that
    (raises_failure (fun () -> Leverage_dawn.validate cfg))
    (equal_to true)

(* ------------------------------------------------------------------ *)
(* R1/R2: defaults are the no-op; fields survive a sexp round-trip     *)
(* (a real sexp field is exactly what Overlay_validator can merge as   *)
(* a Variant_matrix axis).                                             *)
(* ------------------------------------------------------------------ *)

let test_defaults_are_noop _ =
  assert_that base_config
    (all_of
       [
         field
           (fun (c : Config.config) -> c.dawn_leverage_enabled)
           (equal_to false);
         field
           (fun (c : Config.config) -> c.dawn_initial_long_margin_req)
           (float_equal 1.0);
       ])

let test_sexp_round_trip_preserves_dawn_fields _ =
  let cfg : Config.config =
    { dawn_enabled_config with dawn_max_ma_flip_age_weeks = 40 }
  in
  let round = Config.config_of_sexp (Config.sexp_of_config cfg) in
  assert_that round
    (all_of
       [
         field
           (fun (c : Config.config) -> c.dawn_leverage_enabled)
           (equal_to true);
         field
           (fun (c : Config.config) -> c.dawn_initial_long_margin_req)
           (float_equal 0.75);
         field
           (fun (c : Config.config) -> c.dawn_max_ma_flip_age_weeks)
           (equal_to 40);
       ])

(* ------------------------------------------------------------------ *)
(* Effect: dawn_effective_config swaps the entry-walk requirement on a *)
(* synthetic dawn tape, and is a no-op otherwise.                      *)
(* ------------------------------------------------------------------ *)

let _make_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* One daily bar per ISO week (consecutive Fridays), so each weekly bucket's
   close is exactly the supplied value in order. *)
let weekly_bar_reader closes =
  let start = Date.create_exn ~y:2015 ~m:Month.Jan ~d:2 in
  let bars =
    List.mapi closes ~f:(fun i close ->
        _make_bar ~date:(Date.add_days start (7 * i)) ~close)
  in
  let reader = Bar_reader.of_in_memory_bars [ ("IDX", bars) ] in
  (reader, List.last_exn bars |> fun (b : Types.Daily_price.t) -> b.date)

(* Fast stage config so the SMA reacts within the synthetic tape. *)
let fast_stage_config (c : Stage.config) =
  {
    c with
    ma_period = 4;
    ma_type = Stage.Sma;
    slope_lookback = 1;
    slope_threshold = 0.0;
  }

(* V-shape: 24 weeks declining 100 -> 77, then 24 weeks rising 77 -> 100. The
   SMA turns up ~24 weeks ago -> a young dawn well inside the 52-week window. *)
let v_shape_closes =
  let down = List.init 24 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let up = List.init 24 ~f:(fun i -> 77.0 +. Float.of_int i) in
  down @ up

let monotone_decline_closes = List.init 48 ~f:(fun i -> 120.0 -. Float.of_int i)

let effect_config closes ~enabled : Config.config =
  let reader, as_of = weekly_bar_reader closes in
  let cfg : Config.config =
    {
      base_config with
      stage_config = fast_stage_config base_config.stage_config;
      dawn_leverage_enabled = enabled;
      dawn_initial_long_margin_req = 0.75;
      dawn_max_ma_flip_age_weeks = 52;
    }
  in
  Leverage_dawn.dawn_effective_config cfg ~bar_reader:reader ~current_date:as_of

let test_effect_dawn_tape_levers _ =
  assert_that
    (effect_config v_shape_closes ~enabled:true)
    (field
       (fun (c : Config.config) -> c.initial_long_margin_req)
       (float_equal 0.75))

let test_effect_non_dawn_tape_unchanged _ =
  assert_that
    (effect_config monotone_decline_closes ~enabled:true)
    (field
       (fun (c : Config.config) -> c.initial_long_margin_req)
       (float_equal 1.0))

let test_effect_disabled_unchanged _ =
  assert_that
    (effect_config v_shape_closes ~enabled:false)
    (field
       (fun (c : Config.config) -> c.initial_long_margin_req)
       (float_equal 1.0))

(* ------------------------------------------------------------------ *)
(* End-to-end funding (B1): the dawn signal SIZES the entry walk, and  *)
(* the permissive BASE req FUNDS the fill. On a dawn week a levered     *)
(* entry actually funds into long_margin_debit; off-dawn no new debit.  *)
(* Exercises both readers of initial_long_margin_req the .mli names:    *)
(* dawn_effective_config (sizing) + apply_single_trade_with_long_margin *)
(* at the base req (funding, what Panel_runner feeds the simulator).    *)
(* ------------------------------------------------------------------ *)

module Portfolio = Trading_portfolio.Portfolio
module Portfolio_margin = Trading_portfolio.Portfolio_margin
module Tb = Trading_base.Types

(* An armed dawn config whose BASE initial_long_margin_req is the permissive dawn
   rung (0.75) — the value the simulator funds fills at. The dawn-week entry walk
   requests the same rung; off-dawn it is raised to a cash account. *)
let armed_funding_config ~enabled : Config.config =
  {
    base_config with
    stage_config = fast_stage_config base_config.stage_config;
    dawn_leverage_enabled = enabled;
    initial_long_margin_req = 0.75;
    dawn_initial_long_margin_req = 0.75;
    dawn_max_ma_flip_age_weeks = 52;
    margin_config =
      { base_config.margin_config with Margin_config.enabled = true };
  }

let _funding_equity = 10_000.0
let _funding_price = 100.0

(* Size a BUY to the effective entry-walk ceiling for [closes] (equity/req when a
   fractional req is in force on a dawn week, the cash gate otherwise), then fund
   it through the simulator fill seam at the permissive base req. Returns the
   resulting long_margin_debit. *)
let debit_after_dawn_entry closes ~enabled =
  let cfg = armed_funding_config ~enabled in
  let reader, as_of = weekly_bar_reader closes in
  let eff =
    Leverage_dawn.dawn_effective_config cfg ~bar_reader:reader
      ~current_date:as_of
  in
  let target_notional =
    if Float.( < ) eff.initial_long_margin_req 1.0 then
      _funding_equity /. eff.initial_long_margin_req
    else _funding_equity
  in
  let quantity = Float.round_down (target_notional /. _funding_price) in
  let trade : Tb.trade =
    {
      id = "t1";
      order_id = "o1";
      symbol = "AAA";
      side = Tb.Buy;
      quantity;
      price = _funding_price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio = Portfolio.create ~initial_cash:_funding_equity () in
  match
    Portfolio_margin.apply_single_trade_with_long_margin
      ~initial_long_margin_req:cfg.initial_long_margin_req portfolio trade
  with
  | Ok (p : Portfolio.t) -> p.long_margin_debit
  | Error err -> assert_failure ("dawn entry funding: " ^ Status.show err)

let test_dawn_week_funds_levered_entry _ =
  (* v-shape dawn tape: entry walk sizes at 0.75 (1.33x = $13,300 > $10,000
     cash), the base-req funding path borrows the shortfall into the debit. *)
  assert_that
    (debit_after_dawn_entry v_shape_closes ~enabled:true)
    (gt (module Float_ord) 0.0)

let test_non_dawn_week_no_new_debit _ =
  (* Monotone decline (not dawn): entry walk is raised to a cash account, so the
     order fits cash and the base-req funding path creates no new debit. *)
  assert_that
    (debit_after_dawn_entry monotone_decline_closes ~enabled:true)
    (float_equal 0.0)

let test_base_cash_account_req_would_reject _ =
  (* B1 root-cause pin: had the simulator kept the OLD base req = 1.0 (cash
     account), the same dawn-week levered order is floor-rejected — no funding.
     The fix is exactly to run the simulator at the permissive base req. *)
  let trade : Tb.trade =
    {
      id = "t1";
      order_id = "o1";
      symbol = "AAA";
      side = Tb.Buy;
      quantity = 133.0;
      price = _funding_price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  assert_that
    (Portfolio_margin.apply_single_trade_with_long_margin
       ~initial_long_margin_req:1.0
       (Portfolio.create ~initial_cash:_funding_equity ())
       trade)
    is_error

let suite =
  "leverage_dawn"
  >::: [
         "young_flip_is_dawn" >:: test_young_flip_is_dawn;
         "flip_age_boundary_inclusive" >:: test_flip_age_boundary_inclusive;
         "old_flip_beyond_window_not_dawn"
         >:: test_old_flip_beyond_window_not_dawn;
         "current_slope_negative_not_dawn"
         >:: test_current_slope_negative_not_dawn;
         "data_boundary_inconclusive_not_dawn"
         >:: test_data_boundary_inconclusive_not_dawn;
         "is_dawn_matches_flip_age" >:: test_is_dawn_matches_flip_age;
         "effective_req_dawn_active" >:: test_effective_req_dawn_active;
         "effective_req_not_dawn" >:: test_effective_req_not_dawn;
         "effective_req_disabled_ignores_dawn"
         >:: test_effective_req_disabled_ignores_dawn;
         "validate_disabled_is_noop" >:: test_validate_disabled_is_noop;
         "validate_enabled_requires_margin_armed"
         >:: test_validate_enabled_requires_margin_armed;
         "validate_enabled_armed_ok" >:: test_validate_enabled_armed_ok;
         "validate_req_above_one_raises" >:: test_validate_req_above_one_raises;
         "validate_req_zero_raises" >:: test_validate_req_zero_raises;
         "validate_base_exceeds_dawn_req_raises"
         >:: test_validate_base_exceeds_dawn_req_raises;
         "defaults_are_noop" >:: test_defaults_are_noop;
         "sexp_round_trip_preserves_dawn_fields"
         >:: test_sexp_round_trip_preserves_dawn_fields;
         "effect_dawn_tape_levers" >:: test_effect_dawn_tape_levers;
         "effect_non_dawn_tape_unchanged"
         >:: test_effect_non_dawn_tape_unchanged;
         "effect_disabled_unchanged" >:: test_effect_disabled_unchanged;
         "dawn_week_funds_levered_entry" >:: test_dawn_week_funds_levered_entry;
         "non_dawn_week_no_new_debit" >:: test_non_dawn_week_no_new_debit;
         "base_cash_account_req_would_reject"
         >:: test_base_cash_account_req_would_reject;
       ]

let () = run_test_tt_main suite
