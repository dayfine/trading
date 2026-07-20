(** Unit tests for {!Walk_forward.Variant_matrix}.

    Pins the expansion contract: cartesian cell count, deterministic seeded
    sampling, exact labels + override sexps for a small known matrix, and the
    expansion-time validation that turns a typo'd axis key into a loud [Failure]
    rather than a silent no-op cell. *)

open OUnit2
open Core
open Matchers
module VM = Walk_forward.Variant_matrix
module WFR = Walk_forward.Walk_forward_runner

(* Real config key-paths so [Overlay_validator] accepts the generated overrides.
   [stage3_exit_margin_pct] is a top-level float field; [hysteresis_weeks] lives
   under [stage3_force_exit_config]; [enable_laggard_rotation] is a top-level
   bool flag. *)
let _margin_axis =
  VM.Key
    {
      path = [ "stage3_exit_margin_pct" ];
      values = Sexp.[ Atom "0.0"; Atom "0.02" ];
    }

let _hysteresis_axis =
  VM.Key
    {
      path = [ "stage3_force_exit_config"; "hysteresis_weeks" ];
      values = Sexp.[ Atom "1"; Atom "2"; Atom "3" ];
    }

let _laggard_axis =
  VM.Flag
    {
      name = "enable_laggard_rotation";
      values = Sexp.[ Atom "true"; Atom "false" ];
    }

(* [neutral_blocks_longs] is a top-level bool flag on [Weinstein_strategy.config]
   — proves the entry-gate axis resolves through [Overlay_validator]. *)
let _neutral_blocks_longs_axis =
  VM.Flag
    {
      name = "neutral_blocks_longs";
      values = Sexp.[ Atom "true"; Atom "false" ];
    }

(* Catch a [Failure] from [thunk]; returns [true] iff one was raised. *)
let _raises_failure thunk =
  try
    ignore (thunk ());
    false
  with Failure _ -> true

(* ---------- Cartesian count = product of axis sizes ---------- *)

let test_cartesian_count_is_product _ =
  let t =
    { VM.axes = [ _hysteresis_axis; _laggard_axis ]; expansion = VM.Cartesian }
  in
  (* 3 hysteresis values * 2 laggard values = 6 cells. *)
  assert_that (List.length (VM.expand t)) (equal_to 6)

let test_single_axis_cartesian_count _ =
  let t = { VM.axes = [ _hysteresis_axis ]; expansion = VM.Cartesian } in
  assert_that (List.length (VM.expand t)) (equal_to 3)

(* ---------- Exact labels + overrides for a known small matrix ---------- *)

let test_known_matrix_labels_and_overrides _ =
  let t =
    { VM.axes = [ _hysteresis_axis; _laggard_axis ]; expansion = VM.Cartesian }
  in
  (* First axis varies slowest: (h=1,lr=true),(h=1,lr=false),(h=2,lr=true),... *)
  assert_that (VM.expand t)
    (elements_are
       [
         all_of
           [
             field
               (fun (v : WFR.variant) -> v.label)
               (equal_to "hysteresis_weeks=1__enable_laggard_rotation=true");
             field
               (fun (v : WFR.variant) -> v.overrides)
               (elements_are
                  [
                    equal_to
                      (Sexp.of_string
                         "((stage3_force_exit_config ((hysteresis_weeks 1))))");
                    equal_to (Sexp.of_string "((enable_laggard_rotation true))");
                  ]);
           ];
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to "hysteresis_weeks=1__enable_laggard_rotation=false");
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to "hysteresis_weeks=2__enable_laggard_rotation=true");
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to "hysteresis_weeks=2__enable_laggard_rotation=false");
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to "hysteresis_weeks=3__enable_laggard_rotation=true");
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to "hysteresis_weeks=3__enable_laggard_rotation=false");
       ])

let test_single_component_override_shape _ =
  let t = { VM.axes = [ _margin_axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((stage3_exit_margin_pct 0.0))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((stage3_exit_margin_pct 0.02))") ]);
       ])

(* Proves R2 (experiment-flag-discipline): the [neutral_blocks_longs] entry-gate
   flag is a real top-level [Weinstein_strategy.config] field, so the flag axis
   expands and passes [Overlay_validator] validation, yielding the expected
   single-component override sexps. *)
let test_neutral_blocks_longs_flag_axis_expands _ =
  let t =
    { VM.axes = [ _neutral_blocks_longs_axis ]; expansion = VM.Cartesian }
  in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((neutral_blocks_longs true))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((neutral_blocks_longs false))") ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the macro-bearish held-exposure
   trim mechanism: both [enable_macro_bearish_exposure_trim] (flag) and
   [macro_bearish_max_long_exposure_pct] (float key) are real top-level
   [Weinstein_strategy.config] fields, so the combined axis expands and passes
   [Overlay_validator] validation. This is the "axis the day it lands" gate. *)
let test_macro_bearish_trim_axes_expand _ =
  let flag_axis =
    VM.Flag
      {
        name = "enable_macro_bearish_exposure_trim";
        values = Sexp.[ Atom "true"; Atom "false" ];
      }
  in
  let cap_axis =
    VM.Key
      {
        path = [ "macro_bearish_max_long_exposure_pct" ];
        values = Sexp.[ Atom "0.0"; Atom "0.35" ];
      }
  in
  let t = { VM.axes = [ flag_axis; cap_axis ]; expansion = VM.Cartesian } in
  (* 2 flag values * 2 cap values = 4 cells; first axis varies slowest. *)
  assert_that (VM.expand t)
    (elements_are
       [
         all_of
           [
             field
               (fun (v : WFR.variant) -> v.label)
               (equal_to
                  "enable_macro_bearish_exposure_trim=true__macro_bearish_max_long_exposure_pct=0.0");
             field
               (fun (v : WFR.variant) -> v.overrides)
               (elements_are
                  [
                    equal_to
                      (Sexp.of_string
                         "((enable_macro_bearish_exposure_trim true))");
                    equal_to
                      (Sexp.of_string
                         "((macro_bearish_max_long_exposure_pct 0.0))");
                  ]);
           ];
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to
              "enable_macro_bearish_exposure_trim=true__macro_bearish_max_long_exposure_pct=0.35");
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to
              "enable_macro_bearish_exposure_trim=false__macro_bearish_max_long_exposure_pct=0.0");
         field
           (fun (v : WFR.variant) -> v.label)
           (equal_to
              "enable_macro_bearish_exposure_trim=false__macro_bearish_max_long_exposure_pct=0.35");
       ])

(* Proves R2 (experiment-flag-discipline) for the resistance-v2 continuous
   overhead-supply scoring weight: [w_overhead_supply] is a real
   [Screener.scoring_weights] field reached via the nested
   [screening_config.weights] path, and — critically — it is serialized with
   [@sexp.default None] (NOT [@sexp.option]), so [Overlay_validator] finds the
   key in the base config and the axis expands to the expected nested override
   sexps ([int option] value [(N)] = [Some N]). This is the "axis the day it
   lands" gate for PR-D. *)
let test_w_overhead_supply_weight_axis_expands _ =
  let axis =
    VM.Key
      {
        path = [ "screening_config"; "weights"; "w_overhead_supply" ];
        values = Sexp.[ List [ Atom "10" ]; List [ Atom "20" ] ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((screening_config ((weights ((w_overhead_supply \
                      (10)))))))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((screening_config ((weights ((w_overhead_supply \
                      (20)))))))");
              ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the [short_min_price] short-entry
   gate: it is a real top-level float key on [Weinstein_strategy.config] (same
   mechanism as [stage3_exit_margin_pct]), so the axis expands and passes
   [Overlay_validator] validation with no overlay-validator change. The no-op
   default value [0.0] and the researched ~$17 economic floor sit on the same
   axis. *)
let test_short_min_price_axis_expands _ =
  let axis =
    VM.Key
      {
        path = [ "short_min_price" ];
        values = Sexp.[ Atom "0.0"; Atom "17.0" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         all_of
           [
             field
               (fun (v : WFR.variant) -> v.label)
               (equal_to "short_min_price=0.0");
             field
               (fun (v : WFR.variant) -> v.overrides)
               (elements_are
                  [ equal_to (Sexp.of_string "((short_min_price 0.0))") ]);
           ];
         all_of
           [
             field
               (fun (v : WFR.variant) -> v.label)
               (equal_to "short_min_price=17.0");
             field
               (fun (v : WFR.variant) -> v.overrides)
               (elements_are
                  [ equal_to (Sexp.of_string "((short_min_price 17.0))") ]);
           ];
       ])

(* Proves R2 (experiment-flag-discipline) for the reserved short sleeve
   ([project_short_funnel_crowded_out]): [short_sleeve_fraction] is a real
   top-level float key on [Weinstein_strategy.config] (same mechanism as
   [short_min_price] / [stage3_exit_margin_pct]), so the flag axis expands and
   passes [Overlay_validator] validation with no overlay-validator change. The
   no-op default [0.0] and the experimental sleeve fractions sit on one axis. *)
let test_short_sleeve_fraction_axis_expands _ =
  let axis =
    VM.Flag
      {
        name = "short_sleeve_fraction";
        values = Sexp.[ Atom "0.0"; Atom "0.1"; Atom "0.2"; Atom "0.3" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((short_sleeve_fraction 0.0))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((short_sleeve_fraction 0.1))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((short_sleeve_fraction 0.2))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((short_sleeve_fraction 0.3))") ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the long-side maintenance
   force-reduce (margin M2): [maintenance_long_pct] is a real top-level float key
   on [Weinstein_strategy.config] (same mechanism as [short_sleeve_fraction] /
   [initial_long_margin_req]), so the axis expands and passes [Overlay_validator]
   validation with no overlay-validator change. The no-op default [0.0] and an
   experimental requirement sit on one axis. *)
let test_maintenance_long_pct_axis_expands _ =
  let axis =
    VM.Flag
      {
        name = "maintenance_long_pct";
        values = Sexp.[ Atom "0.0"; Atom "0.25" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((maintenance_long_pct 0.0))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((maintenance_long_pct 0.25))") ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the M3a short borrow-availability
   gate: [short_borrow_min_dollar_adv] is a real top-level float key on
   [Weinstein_strategy.config] (same mechanism as [short_min_price]), so the
   axis expands and passes [Overlay_validator] validation with no
   overlay-validator change. The no-op default [0.0] and a positive ADV floor
   sit on one axis. *)
let test_short_borrow_min_dollar_adv_axis_expands _ =
  let axis =
    VM.Key
      {
        path = [ "short_borrow_min_dollar_adv" ];
        values = Sexp.[ Atom "0.0"; Atom "1000000.0" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to (Sexp.of_string "((short_borrow_min_dollar_adv 0.0))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string "((short_borrow_min_dollar_adv 1000000.0))");
              ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the M3a short maintenance tier
   TABLE: [short_maintenance_tiers] is a real field on the nested
   [margin_config] record, reached via the [margin_config.short_maintenance_tiers]
   path, and its value is a sexp-valued tier list (mirrors the nested
   record-valued [screening_config.weights.w_overhead_supply] axis). The axis
   expands and passes [Overlay_validator] validation with no overlay-validator
   change — the tier table is searchable the day it lands. *)
let test_short_maintenance_tiers_axis_expands _ =
  let axis =
    VM.Key
      {
        path = [ "margin_config"; "short_maintenance_tiers" ];
        values =
          Sexp.[ List []; of_string "(((price_below 17.0) (value 1.0)))" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((margin_config ((short_maintenance_tiers ()))))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((margin_config ((short_maintenance_tiers (((price_below \
                      17.0) (value 1.0)))))))");
              ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the [suppress_warmup_trading]
   warmup-trading gate (#1549 A2): it is a real top-level bool flag on
   [Weinstein_strategy.config] (same mechanism as [neutral_blocks_longs]), so
   the flag axis expands and passes [Overlay_validator] validation with no
   overlay-validator change. The no-op default [false] and the experimental
   [true] sit on the same axis. *)
let test_suppress_warmup_trading_flag_axis_expands _ =
  let axis =
    VM.Flag
      {
        name = "suppress_warmup_trading";
        values = Sexp.[ Atom "true"; Atom "false" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((suppress_warmup_trading true))") ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [ equal_to (Sexp.of_string "((suppress_warmup_trading false))") ]);
       ])

(* Proves R2 (experiment-flag-discipline) for resistance-v2 lever (a): the
   [virgin_crossing_readmission] re-admission flag is a real top-level bool on
   [Weinstein_strategy.config], so its [(flag ...)] axis expands to the expected
   single-component override sexps (validation of the resolved path is pinned in
   test_runner_hypothesis_overrides). "Axis the day it lands." *)
let test_virgin_crossing_readmission_flag_axis_expands _ =
  let axis =
    VM.Flag
      {
        name = "virgin_crossing_readmission";
        values = Sexp.[ Atom "true"; Atom "false" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to (Sexp.of_string "((virgin_crossing_readmission true))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string "((virgin_crossing_readmission false))");
              ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the NS1 cash-floor closing-trade
   exemption (#1557#3): [exempt_closing_trades_from_cash_floor] is a real bool
   field on [Portfolio_risk.config], which is the [portfolio_config] field of
   [Weinstein_strategy.config]. So the nested key path
   [portfolio_config.exempt_closing_trades_from_cash_floor] expands and passes
   [Overlay_validator] validation (same nesting mechanism as
   [stage3_force_exit_config.hysteresis_weeks]) with no overlay-validator
   change. The no-op default [false] and the experimental [true] sit on the same
   axis. *)
let test_cash_floor_exemption_nested_axis_expands _ =
  let axis =
    VM.Key
      {
        path = [ "portfolio_config"; "exempt_closing_trades_from_cash_floor" ];
        values = Sexp.[ Atom "true"; Atom "false" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((portfolio_config \
                      ((exempt_closing_trades_from_cash_floor true))))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((portfolio_config \
                      ((exempt_closing_trades_from_cash_floor false))))");
              ]);
       ])

(* Proves R2 (experiment-flag-discipline) for the vol-scaled stop distance lever
   (P0b): [vol_scaled_stop_atr_mult] is a real float field on
   [Weinstein_stops.config], which is the [stops_config] field of
   [Weinstein_strategy.config]. So the nested key path
   [stops_config.vol_scaled_stop_atr_mult] expands and passes [Overlay_validator]
   validation (same nesting mechanism as the cash-floor exemption above) with no
   overlay-validator change. The no-op default [0.0] and the experimental
   widens-the-floor values sit on the same axis. *)
let test_vol_scaled_stop_nested_axis_expands _ =
  let axis =
    VM.Key
      {
        path = [ "stops_config"; "vol_scaled_stop_atr_mult" ];
        values = Sexp.[ Atom "0.0"; Atom "1.0"; Atom "1.5"; Atom "2.0" ];
      }
  in
  let t = { VM.axes = [ axis ]; expansion = VM.Cartesian } in
  assert_that (VM.expand t)
    (elements_are
       [
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((stops_config ((vol_scaled_stop_atr_mult 0.0))))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((stops_config ((vol_scaled_stop_atr_mult 1.0))))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((stops_config ((vol_scaled_stop_atr_mult 1.5))))");
              ]);
         field
           (fun (v : WFR.variant) -> v.overrides)
           (elements_are
              [
                equal_to
                  (Sexp.of_string
                     "((stops_config ((vol_scaled_stop_atr_mult 2.0))))");
              ]);
       ])

(* ---------- Sampled determinism + fallback ---------- *)

let test_sampled_determinism _ =
  let t =
    {
      VM.axes = [ _hysteresis_axis; _laggard_axis ];
      expansion = VM.Sampled { n = 3; seed = 7 };
    }
  in
  let labels run =
    List.map (VM.expand run) ~f:(fun (v : WFR.variant) -> v.label)
  in
  (* Same seed -> identical label sequence; size = n. *)
  assert_that (labels t) (all_of [ size_is 3; equal_to (labels t) ])

let test_sampled_different_seed_differs _ =
  let mk seed =
    {
      VM.axes = [ _hysteresis_axis; _laggard_axis ];
      expansion = VM.Sampled { n = 2; seed };
    }
  in
  let labels run =
    List.map (VM.expand run) ~f:(fun (v : WFR.variant) -> v.label)
    |> List.sort ~compare:String.compare
  in
  (* Seeds 1 and 2 draw different 2-subsets of the 6-cell product. *)
  assert_that
    (List.equal String.equal (labels (mk 1)) (labels (mk 2)))
    (equal_to false)

let test_sampled_n_ge_product_is_full_cartesian _ =
  let t =
    {
      VM.axes = [ _hysteresis_axis; _laggard_axis ];
      (* n (100) >= product size (6) -> full cartesian fallback. *)
      expansion = VM.Sampled { n = 100; seed = 0 };
    }
  in
  assert_that (List.length (VM.expand t)) (equal_to 6)

(* ---------- Expansion-time validation (the 81-cell guard) ---------- *)

let test_bad_axis_key_raises _ =
  let bad =
    VM.Key
      { path = [ "this_is_not_a_real_config_key" ]; values = Sexp.[ Atom "1" ] }
  in
  let t = { VM.axes = [ bad ]; expansion = VM.Cartesian } in
  assert_that (_raises_failure (fun () -> VM.expand t)) (equal_to true)

let test_bad_nested_key_raises _ =
  let bad =
    VM.Key
      {
        path = [ "stage3_force_exit_config"; "not_a_field" ];
        values = Sexp.[ Atom "1" ];
      }
  in
  let t = { VM.axes = [ bad ]; expansion = VM.Cartesian } in
  assert_that (_raises_failure (fun () -> VM.expand t)) (equal_to true)

let test_empty_axes_raises _ =
  let t = { VM.axes = []; expansion = VM.Cartesian } in
  assert_that (_raises_failure (fun () -> VM.expand t)) (equal_to true)

let suite =
  "Walk_forward_variant_matrix"
  >::: [
         "cartesian count = product of axis sizes"
         >:: test_cartesian_count_is_product;
         "single-axis cartesian count" >:: test_single_axis_cartesian_count;
         "known matrix expands to exact labels + overrides"
         >:: test_known_matrix_labels_and_overrides;
         "single-component path override shape"
         >:: test_single_component_override_shape;
         "neutral_blocks_longs flag axis expands + validates"
         >:: test_neutral_blocks_longs_flag_axis_expands;
         "macro-bearish trim flag + cap axes expand + validate"
         >:: test_macro_bearish_trim_axes_expand;
         "short_min_price float axis expands"
         >:: test_short_min_price_axis_expands;
         "w_overhead_supply nested weight axis expands + validates"
         >:: test_w_overhead_supply_weight_axis_expands;
         "short_borrow_min_dollar_adv axis expands"
         >:: test_short_borrow_min_dollar_adv_axis_expands;
         "short_maintenance_tiers axis expands"
         >:: test_short_maintenance_tiers_axis_expands;
         "short_sleeve_fraction flag axis expands"
         >:: test_short_sleeve_fraction_axis_expands;
         "maintenance_long_pct axis expands"
         >:: test_maintenance_long_pct_axis_expands;
         "suppress_warmup_trading flag axis expands"
         >:: test_suppress_warmup_trading_flag_axis_expands;
         "virgin_crossing_readmission flag axis expands"
         >:: test_virgin_crossing_readmission_flag_axis_expands;
         "cash-floor exemption nested axis expands + validates"
         >:: test_cash_floor_exemption_nested_axis_expands;
         "vol-scaled stop nested axis expands + validates"
         >:: test_vol_scaled_stop_nested_axis_expands;
         "sampled determinism (same seed -> same labels)"
         >:: test_sampled_determinism;
         "sampled different seed -> different subset"
         >:: test_sampled_different_seed_differs;
         "sampled n >= product size falls back to full cartesian"
         >:: test_sampled_n_ge_product_is_full_cartesian;
         "bad top-level axis key raises at expansion time"
         >:: test_bad_axis_key_raises;
         "bad nested axis key raises at expansion time"
         >:: test_bad_nested_key_raises;
         "empty axes raises" >:: test_empty_axes_raises;
       ]

let () = run_test_tt_main suite
