open OUnit2
open Core
open Matchers
open Synthetic

let _default_cfg ?(target = 500) ?(seed = 17) () =
  Synth_v2.default_config
    ~start_date:(Date.of_string "2030-01-01")
    ~start_price:100.0 ~target_length_days:target ~seed

let _unwrap_or_fail msg = function
  | Ok v -> v
  | Error e -> assert_failure (msg ^ ": " ^ Status.show e)

(* ------------------------------------------------------------------ *)
(* Output length matches request                                        *)
(* ------------------------------------------------------------------ *)

let test_output_length _ =
  assert_that
    (Synth_v2.generate (_default_cfg ~target:500 ()))
    (is_ok_and_holds (size_is 500))

(* ------------------------------------------------------------------ *)
(* Determinism                                                          *)
(* ------------------------------------------------------------------ *)

let test_determinism_same_seed _ =
  let cfg = _default_cfg ~target:200 () in
  let bars1 = _unwrap_or_fail "first run failed" (Synth_v2.generate cfg) in
  let bars2 = _unwrap_or_fail "second run failed" (Synth_v2.generate cfg) in
  assert_that (List.equal Types.Daily_price.equal bars1 bars2) (equal_to true)

let test_different_seeds_differ _ =
  let cfg1 = _default_cfg ~target:200 ~seed:17 () in
  let cfg2 = _default_cfg ~target:200 ~seed:99 () in
  let bars1 = _unwrap_or_fail "seed=17 failed" (Synth_v2.generate cfg1) in
  let bars2 = _unwrap_or_fail "seed=99 failed" (Synth_v2.generate cfg2) in
  assert_that (List.equal Types.Daily_price.equal bars1 bars2) (equal_to false)

(* ------------------------------------------------------------------ *)
(* Dates strictly increase + business days only                         *)
(* ------------------------------------------------------------------ *)

let test_dates_monotonic_business_days _ =
  let cfg = _default_cfg ~target:50 () in
  let bars = _unwrap_or_fail "generate failed" (Synth_v2.generate cfg) in
  let dates = List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.date) in
  let pairs = List.zip_exn (List.drop_last_exn dates) (List.tl_exn dates) in
  let strictly_increasing =
    List.for_all pairs ~f:(fun (a, b) -> Date.compare a b < 0)
  in
  let all_weekdays =
    List.for_all dates ~f:(fun d ->
        match Date.day_of_week d with Sat | Sun -> false | _ -> true)
  in
  assert_that strictly_increasing (equal_to true);
  assert_that all_weekdays (equal_to true)

(* ------------------------------------------------------------------ *)
(* OHLC well-formed: low <= open <= high, low <= close <= high          *)
(* ------------------------------------------------------------------ *)

let test_ohlc_well_formed _ =
  let cfg = _default_cfg ~target:200 () in
  let bars = _unwrap_or_fail "generate failed" (Synth_v2.generate cfg) in
  let ok_bar (b : Types.Daily_price.t) =
    Float.(b.low_price <= b.open_price)
    && Float.(b.open_price <= b.high_price)
    && Float.(b.low_price <= b.close_price)
    && Float.(b.close_price <= b.high_price)
    && Float.(b.close_price > 0.0)
  in
  assert_that (List.for_all bars ~f:ok_bar) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Validation — non-positive target                                     *)
(* ------------------------------------------------------------------ *)

let test_validation_zero_target _ =
  let cfg = _default_cfg ~target:0 () in
  assert_that (Synth_v2.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_zero_start_price _ =
  let cfg = { (_default_cfg ()) with start_price = 0.0 } in
  assert_that (Synth_v2.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_missing_garch_for_regime _ =
  let cfg =
    {
      (_default_cfg ()) with
      garch_per_regime =
        [
          (Regime_hmm.Bull, { omega = 1e-6; alpha = 0.05; beta = 0.93 });
          (* Bear and Crisis missing *)
        ];
    }
  in
  assert_that (Synth_v2.generate cfg) (is_error_with Status.Invalid_argument)

let test_validation_invalid_garch _ =
  let cfg =
    {
      (_default_cfg ()) with
      garch_per_regime =
        [
          (* alpha + beta > 1 is non-stationary *)
          (Regime_hmm.Bull, { omega = 1e-6; alpha = 0.6; beta = 0.5 });
          (Regime_hmm.Bear, { omega = 1e-5; alpha = 0.10; beta = 0.85 });
          (Regime_hmm.Crisis, { omega = 5e-5; alpha = 0.20; beta = 0.75 });
        ];
    }
  in
  assert_that (Synth_v2.generate cfg) (is_error_with Status.Invalid_argument)

(* ------------------------------------------------------------------ *)
(* All bar prices remain finite over a long simulation                  *)
(* ------------------------------------------------------------------ *)

let test_long_simulation_finite _ =
  (* 80yr ≈ 252 * 80 = 20160 bars. Use 20000 for speed and pin numerical
     stability boundary. *)
  let cfg = _default_cfg ~target:20000 ~seed:23 () in
  let bars = _unwrap_or_fail "generate failed" (Synth_v2.generate cfg) in
  let finite =
    List.for_all bars ~f:(fun (b : Types.Daily_price.t) ->
        Float.is_finite b.close_price && Float.(b.close_price > 0.0))
  in
  assert_that finite (equal_to true)

(* ------------------------------------------------------------------ *)
(* default_config defaults round-trip                                   *)
(* ------------------------------------------------------------------ *)

let test_default_config_uses_defaults _ =
  let cfg = _default_cfg () in
  assert_that cfg.hmm.initial_regime (equal_to Regime_hmm.Bull);
  assert_that cfg.garch_per_regime (size_is 3);
  assert_that cfg.drift_per_regime (size_is 3)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "synth_v2"
  >::: [
         "output length matches request" >:: test_output_length;
         "determinism — same seed identical" >:: test_determinism_same_seed;
         "different seeds differ" >:: test_different_seeds_differ;
         "dates monotonic business days" >:: test_dates_monotonic_business_days;
         "OHLC bars well-formed" >:: test_ohlc_well_formed;
         "validation: zero target" >:: test_validation_zero_target;
         "validation: zero start_price" >:: test_validation_zero_start_price;
         "validation: missing GARCH for regime"
         >:: test_validation_missing_garch_for_regime;
         "validation: non-stationary GARCH" >:: test_validation_invalid_garch;
         "long simulation stays finite" >:: test_long_simulation_finite;
         "default_config wires all defaults"
         >:: test_default_config_uses_defaults;
       ]

let () = run_test_tt_main suite
