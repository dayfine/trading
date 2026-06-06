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
