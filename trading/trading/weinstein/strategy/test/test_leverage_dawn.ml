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
         "defaults_are_noop" >:: test_defaults_are_noop;
         "sexp_round_trip_preserves_dawn_fields"
         >:: test_sexp_round_trip_preserves_dawn_fields;
         "effect_dawn_tape_levers" >:: test_effect_dawn_tape_levers;
         "effect_non_dawn_tape_unchanged"
         >:: test_effect_non_dawn_tape_unchanged;
         "effect_disabled_unchanged" >:: test_effect_disabled_unchanged;
       ]

let () = run_test_tt_main suite
