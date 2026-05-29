(** Unit tests for {!Walk_forward.Spec}.

    These exercise the three checked-in fixture spec sexps under
    [trading/test_data/walk_forward/]:
    - [cell_e_8fold_2026_05_08.sexp] — the 2026-05-08 hand-curated 8-fold
      experiment encoded as a [Window_spec.Explicit].
    - [cell_e_30fold_2026_05_16.sexp] — the 30-fold rolling window over the
      2010-2026 sp500 historical scenario.
    - [cell_e_full_history_28fold_2026_05_25.sexp] — the M4 (T4.1) 28-fold
      annual non-overlapping window over the 1998-2026 top-3000 universe.
      Single-variant (cell-E only), non-firing gate placeholder.

    The tests verify only that {!Spec.load} parses the fixture and that
    [Window_spec.generate] returns the right number of folds — no backtest is
    invoked. Running the actual sweeps is a local-only follow-up. *)

open OUnit2
open Core
open Matchers
module Spec = Walk_forward.Spec
module WS = Walk_forward.Window_spec

(** Walk the cwd up until we hit a directory that contains
    [trading/test_data/walk_forward/]. Mirrors the helper in
    [Scenarios.Test_scenario._scenarios_root]; needed because [dune runtest]'s
    cwd is [_build/default/trading/backtest/walk_forward/test]. *)
let _walk_forward_fixtures_root () =
  let target = "trading/test_data/walk_forward" in
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate = Filename.concat dir target in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let _fixture_path name =
  match _walk_forward_fixtures_root () with
  | Some root -> Filename.concat root name
  | None ->
      assert_failure
        (sprintf "Could not locate trading/test_data/walk_forward/ from cwd %s"
           (Stdlib.Sys.getcwd ()))

(* ---------- 8-fold Explicit fixture ---------- *)

let test_8fold_spec_parses _ =
  let spec = Spec.load (_fixture_path "cell_e_8fold_2026_05_08.sexp") in
  assert_that spec
    (all_of
       [
         field
           (fun (s : Spec.t) -> s.base_scenario)
           (equal_to "goldens-small/bull-crash-2015-2020.sexp");
         field (fun (s : Spec.t) -> s.baseline_label) (equal_to "cell-A");
         field (fun (s : Spec.t) -> List.length s.variants) (equal_to 2);
         field (fun (s : Spec.t) -> s.gate.n) (equal_to 8);
       ])

let test_8fold_window_spec_is_explicit _ =
  let spec = Spec.load (_fixture_path "cell_e_8fold_2026_05_08.sexp") in
  assert_that spec.window_spec
    (matching ~msg:"Expected Window_spec.Explicit variant"
       (function WS.Explicit fs -> Some fs | _ -> None)
       (size_is 8))

let test_8fold_generate_yields_8_folds_in_input_order _ =
  let spec = Spec.load (_fixture_path "cell_e_8fold_2026_05_08.sexp") in
  let folds = WS.generate spec.window_spec in
  let names = List.map folds ~f:(fun (f : WS.fold) -> f.name) in
  assert_that names
    (elements_are
       [
         equal_to "bull-crash-2015-2017";
         equal_to "bull-crash-2018-2020";
         equal_to "covid-2020-2022h1";
         equal_to "covid-2022h2-2024";
         equal_to "six-year-2018-2020";
         equal_to "six-year-2021-2023";
         equal_to "sp500-2019-2021h1";
         equal_to "sp500-2021h2-2023";
       ])

let test_8fold_variants_are_cellA_and_cellE _ =
  let spec = Spec.load (_fixture_path "cell_e_8fold_2026_05_08.sexp") in
  let labels =
    List.map spec.variants
      ~f:(fun (v : Walk_forward.Walk_forward_runner.variant) -> v.label)
  in
  assert_that labels (elements_are [ equal_to "cell-A"; equal_to "cell-E" ])

(* ---------- 30-fold Rolling fixture ---------- *)

let test_30fold_spec_parses _ =
  let spec = Spec.load (_fixture_path "cell_e_30fold_2026_05_16.sexp") in
  assert_that spec
    (all_of
       [
         field
           (fun (s : Spec.t) -> s.base_scenario)
           (equal_to "goldens-sp500-historical/sp500-2010-2026.sexp");
         field (fun (s : Spec.t) -> s.baseline_label) (equal_to "cell-E");
         field (fun (s : Spec.t) -> s.gate.n) (equal_to 30);
       ])

let test_30fold_window_spec_is_rolling _ =
  let spec = Spec.load (_fixture_path "cell_e_30fold_2026_05_16.sexp") in
  assert_that spec.window_spec
    (matching ~msg:"Expected Window_spec.Rolling variant"
       (function WS.Rolling r -> Some r | _ -> None)
       (all_of
          [
            field (fun (r : WS.rolling_spec) -> r.train_days) (equal_to 0);
            field (fun (r : WS.rolling_spec) -> r.test_days) (equal_to 365);
            field (fun (r : WS.rolling_spec) -> r.step_days) (equal_to 182);
          ]))

(** Plan §5 acceptance: ≥28 folds (target 30, allowance for end-of-range
    clamping). Per the plan-§5 arithmetic, the actual count should be ~30. *)
let test_30fold_generate_yields_close_to_30_folds _ =
  let spec = Spec.load (_fixture_path "cell_e_30fold_2026_05_16.sexp") in
  let folds = WS.generate spec.window_spec in
  let _min_acceptable = 28 in
  let _max_acceptable = 32 in
  assert_that (List.length folds)
    (is_between (module Int_ord) ~low:_min_acceptable ~high:_max_acceptable)

(* ---------- 28-fold Full-history fixture (M4 T4.1) ---------- *)

let _full_history_fixture = "cell_e_full_history_28fold_2026_05_25.sexp"

let test_28fold_spec_parses _ =
  let spec = Spec.load (_fixture_path _full_history_fixture) in
  assert_that spec
    (all_of
       [
         field
           (fun (s : Spec.t) -> s.base_scenario)
           (equal_to "goldens-sp500-historical/sp500-1998-2026.sexp");
         field (fun (s : Spec.t) -> s.baseline_label) (equal_to "cell-E");
         field (fun (s : Spec.t) -> List.length s.variants) (equal_to 1);
       ])

let test_28fold_window_spec_spans_1998_to_2026 _ =
  let spec = Spec.load (_fixture_path _full_history_fixture) in
  assert_that spec.window_spec
    (matching ~msg:"Expected Window_spec.Rolling variant"
       (function WS.Rolling r -> Some r | _ -> None)
       (all_of
          [
            field
              (fun (r : WS.rolling_spec) -> r.start_date)
              (equal_to (Date.of_string "1998-01-01"));
            field
              (fun (r : WS.rolling_spec) -> r.end_date)
              (equal_to (Date.of_string "2026-04-30"));
            field (fun (r : WS.rolling_spec) -> r.train_days) (equal_to 0);
            field (fun (r : WS.rolling_spec) -> r.test_days) (equal_to 365);
            field (fun (r : WS.rolling_spec) -> r.step_days) (equal_to 365);
          ]))

(** T4.1 acceptance: target 28 folds (28 calendar years × 1 fold/year); allow ±1
    for leap-year drift across the 28-year span. *)
let test_28fold_generate_yields_close_to_28_folds _ =
  let spec = Spec.load (_fixture_path _full_history_fixture) in
  let folds = WS.generate spec.window_spec in
  let _min_acceptable = 27 in
  let _max_acceptable = 29 in
  assert_that (List.length folds)
    (is_between (module Int_ord) ~low:_min_acceptable ~high:_max_acceptable)

let test_28fold_variants_is_cellE_only _ =
  let spec = Spec.load (_fixture_path _full_history_fixture) in
  let labels =
    List.map spec.variants
      ~f:(fun (v : Walk_forward.Walk_forward_runner.variant) -> v.label)
  in
  assert_that labels (elements_are [ equal_to "cell-E" ])

let test_28fold_gate_is_non_firing _ =
  let spec = Spec.load (_fixture_path _full_history_fixture) in
  assert_that spec.gate
    (all_of
       [
         field
           (fun (g : Walk_forward.Fold_gate.t) -> g.metric)
           (equal_to Walk_forward.Fold_gate.Sharpe);
         field (fun (g : Walk_forward.Fold_gate.t) -> g.m) (equal_to 0);
         field (fun (g : Walk_forward.Fold_gate.t) -> g.n) (equal_to 28);
       ])

(* ---------- Hysteresis 30-fold fixture (stage3 revisit, 2026-05-29) ---------- *)

let _hysteresis_fixture = "hysteresis_30fold_2026_05_29.sexp"

let test_hysteresis_spec_parses _ =
  let spec = Spec.load (_fixture_path _hysteresis_fixture) in
  assert_that spec
    (all_of
       [
         field
           (fun (s : Spec.t) -> s.base_scenario)
           (equal_to "goldens-sp500-historical/sp500-2010-2026.sexp");
         field (fun (s : Spec.t) -> s.baseline_label) (equal_to "h1-m0");
         field (fun (s : Spec.t) -> List.length s.variants) (equal_to 2);
         field (fun (s : Spec.t) -> s.gate.n) (equal_to 31);
       ])

let test_hysteresis_variants_are_h1m0_and_h2m02 _ =
  let spec = Spec.load (_fixture_path _hysteresis_fixture) in
  let labels =
    List.map spec.variants
      ~f:(fun (v : Walk_forward.Walk_forward_runner.variant) -> v.label)
  in
  assert_that labels (elements_are [ equal_to "h1-m0"; equal_to "h2-m02" ])

(** Pins the gate-count contract: the Rolling geometry yields exactly 31 OOS
    folds and [gate.n] must equal that count, otherwise [Fold_gate.evaluate]'s
    fold-count guard makes the runner SKIP the verdict (observed on the
    2026-05-29 run, which authored n=30 against 31 generated folds). *)
let test_hysteresis_gate_n_matches_generated_fold_count _ =
  let spec = Spec.load (_fixture_path _hysteresis_fixture) in
  let generated = List.length (WS.generate spec.window_spec) in
  assert_that generated (all_of [ equal_to 31; equal_to spec.gate.n ])

(* ---------- axes -> variants expansion on load (plan Gap A) ---------- *)

(* Write [contents] to a fresh temp file and return its path. The spec [load]
   path only reads the file, so a throwaway temp file is the simplest fixture. *)
let _write_temp_spec contents =
  let path = Stdlib.Filename.temp_file "wf_spec_axes" ".sexp" in
  Out_channel.write_all path ~data:contents;
  path

let _variant_labels (spec : Spec.t) =
  List.map spec.variants
    ~f:(fun (v : Walk_forward.Walk_forward_runner.variant) -> v.label)

(* axes-only: resolved variants = auto-baseline first, then the 2-cell matrix. *)
let _axes_only_spec =
  {|
((base_scenario "stub.sexp")
 (window_spec (Explicit (((name f0) (train_period ()) (test_period ((start_date 2020-01-01) (end_date 2020-12-31)))))))
 (baseline_label "base")
 (gate ((metric Sharpe) (m 1) (n 1) (worst_delta 1.0)))
 (axes ((axes (((key (stage3_exit_margin_pct)) (values (0.0 0.02))))) (expansion Cartesian))))
|}

let test_axes_only_expands_with_baseline _ =
  let spec = Spec.load (_write_temp_spec _axes_only_spec) in
  assert_that (_variant_labels spec)
    (elements_are
       [
         equal_to "base";
         equal_to "stage3_exit_margin_pct=0.0";
         equal_to "stage3_exit_margin_pct=0.02";
       ])

(* explicit variants + axes: explicit first, then baseline, then matrix. *)
let _explicit_plus_axes_spec =
  {|
((base_scenario "stub.sexp")
 (window_spec (Explicit (((name f0) (train_period ()) (test_period ((start_date 2020-01-01) (end_date 2020-12-31)))))))
 (variants (((label "hand") (overrides ()))))
 (baseline_label "base")
 (gate ((metric Sharpe) (m 1) (n 1) (worst_delta 1.0)))
 (axes ((axes (((flag enable_laggard_rotation) (values (true false))))) (expansion Cartesian))))
|}

let test_explicit_plus_axes_concatenates _ =
  let spec = Spec.load (_write_temp_spec _explicit_plus_axes_spec) in
  assert_that (_variant_labels spec)
    (elements_are
       [
         equal_to "hand";
         equal_to "base";
         equal_to "enable_laggard_rotation=true";
         equal_to "enable_laggard_rotation=false";
       ])

(* A typo'd axis key must fail at load (expansion-time validation, Gap B). *)
let _bad_axis_spec =
  {|
((base_scenario "stub.sexp")
 (window_spec (Explicit (((name f0) (train_period ()) (test_period ((start_date 2020-01-01) (end_date 2020-12-31)))))))
 (baseline_label "base")
 (gate ((metric Sharpe) (m 1) (n 1) (worst_delta 1.0)))
 (axes ((axes (((key (not_a_real_config_key)) (values (1))))) (expansion Cartesian))))
|}

let test_axes_bad_key_raises_on_load _ =
  let path = _write_temp_spec _bad_axis_spec in
  let raised =
    try
      ignore (Spec.load path);
      false
    with Failure _ -> true
  in
  assert_that raised (equal_to true)

(* A label collision must fail at load (Spec.load's [_check_unique_labels]
   fail-loud contract, qc-behavioral CP1/CP4). Here an explicit variant labeled
   "base" collides with the auto-injected baseline cell (label = baseline_label
   "base"). *)
let _colliding_label_spec =
  {|
((base_scenario "stub.sexp")
 (window_spec (Explicit (((name f0) (train_period ()) (test_period ((start_date 2020-01-01) (end_date 2020-12-31)))))))
 (variants (((label "base") (overrides ()))))
 (baseline_label "base")
 (gate ((metric Sharpe) (m 1) (n 1) (worst_delta 1.0)))
 (axes ((axes (((flag enable_laggard_rotation) (values (true false))))) (expansion Cartesian))))
|}

let test_axes_label_collision_raises_on_load _ =
  let path = _write_temp_spec _colliding_label_spec in
  let raised =
    try
      ignore (Spec.load path);
      false
    with Failure _ -> true
  in
  assert_that raised (equal_to true)

(* Backward-compat: an axes-absent spec resolves to its hand-written variants
   verbatim (no baseline injected, no reordering). *)
let test_no_axes_is_backward_compatible _ =
  let spec = Spec.load (_fixture_path "cell_e_8fold_2026_05_08.sexp") in
  assert_that (_variant_labels spec)
    (elements_are [ equal_to "cell-A"; equal_to "cell-E" ])

let suite =
  "Walk_forward_spec"
  >::: [
         "8-fold spec parses" >:: test_8fold_spec_parses;
         "8-fold window_spec is Explicit" >:: test_8fold_window_spec_is_explicit;
         "8-fold generate yields 8 folds in input order"
         >:: test_8fold_generate_yields_8_folds_in_input_order;
         "8-fold variants are cell-A and cell-E"
         >:: test_8fold_variants_are_cellA_and_cellE;
         "30-fold spec parses" >:: test_30fold_spec_parses;
         "30-fold window_spec is Rolling" >:: test_30fold_window_spec_is_rolling;
         "30-fold generate yields close to 30 folds"
         >:: test_30fold_generate_yields_close_to_30_folds;
         "28-fold (full-history) spec parses" >:: test_28fold_spec_parses;
         "28-fold window_spec spans 1998-01-01..2026-04-30"
         >:: test_28fold_window_spec_spans_1998_to_2026;
         "28-fold generate yields ~28 folds"
         >:: test_28fold_generate_yields_close_to_28_folds;
         "28-fold variants is cell-E only"
         >:: test_28fold_variants_is_cellE_only;
         "28-fold gate is non-firing placeholder"
         >:: test_28fold_gate_is_non_firing;
         "hysteresis 30-fold spec parses" >:: test_hysteresis_spec_parses;
         "hysteresis 30-fold variants are h1-m0 and h2-m02"
         >:: test_hysteresis_variants_are_h1m0_and_h2m02;
         "hysteresis gate.n matches generated fold count (31)"
         >:: test_hysteresis_gate_n_matches_generated_fold_count;
         "axes-only expands with auto-baseline"
         >:: test_axes_only_expands_with_baseline;
         "explicit variants + axes concatenate"
         >:: test_explicit_plus_axes_concatenates;
         "axes bad key raises on load" >:: test_axes_bad_key_raises_on_load;
         "axes label collision raises on load"
         >:: test_axes_label_collision_raises_on_load;
         "no-axes spec is backward-compatible"
         >:: test_no_axes_is_backward_compatible;
       ]

let () = run_test_tt_main suite
