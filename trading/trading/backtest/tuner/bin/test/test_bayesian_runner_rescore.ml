(** Unit tests for {!Tuner_bin.Bayesian_runner_rescore}.

    The rescorer is pure: input = per-iter fold actuals + baseline fold actuals
    + metric + threshold, output = a {!report} record (also pure markdown via
      {!Bayesian_runner_rescore.report_to_markdown}). Tests construct synthetic
      [bo_rescore_input] + [fold_actual list] inputs by hand — no real BO sweep,
      no walk-forward run, no file I/O except a single round-trip fixture to
      validate {!load_input} / {!load_baseline_fold_actuals} parsing.

    Coverage map (plan §M1 T1.5):

    - Identity (candidate == baseline) → mean Δ = 0 across all candidates →
      spread = 0 → verdict = Fail (acceptance gate requires > 0).
    - Hand-pinned 3-candidate × 4-fold fixture: per-candidate mean Δ computed
      against a known baseline; verifies the matching-by-fold-name plumbing.
    - Spread acceptance boundaries: spread = 5.0 (Pass), spread = 0.5 (Fail);
      pin the comparison strictly-greater contract.
    - Partial overlap: candidate carries a fold absent in baseline → silently
      dropped (matches {!Bayesian_runner_scoring.paired_delta} semantics);
      candidate with zero overlap → exception bubbles up (the disjoint-pair
      callsite-bug contract is preserved through the rescorer).
    - Sexp round-trip: dump a synthetic input + baseline, load via the public
      loaders, re-score, assert the round-trip is faithful. Pins the on-disk
      schema_version contract.
    - Schema-mismatch loader rejects future shape drift.
    - Markdown renderer pins the verdict line / metric label / spread row. *)

open OUnit2
open Core
open Matchers
module Rescore = Tuner_bin.Bayesian_runner_rescore
module Wf = Walk_forward.Walk_forward_types

let _epsilon = 1e-9

(* ---------- synthetic fold_actual builders ---------- *)

(** Construct a synthetic [fold_actual]. Mirrors the helper in
    [test_bayesian_runner_scoring.ml]: NaN defaults for fields the test does not
    pin, so a typo or wrong-metric dispatch fails loudly. *)
let _fold_actual ?(variant_label = "candidate") ?(total_return_pct = Float.nan)
    ?(sharpe_ratio = Float.nan) ?(max_drawdown_pct = Float.nan)
    ?(calmar_ratio = Float.nan) ?(cagr_pct = Float.nan)
    ?(avg_holding_days = Float.nan) ~fold_name () : Wf.fold_actual =
  {
    fold_name;
    variant_label;
    total_return_pct;
    sharpe_ratio;
    max_drawdown_pct;
    calmar_ratio;
    cagr_pct;
    avg_holding_days;
  }

let _baseline_sharpes =
  [ ("fold-000", 0.5); ("fold-001", 0.7); ("fold-002", 0.3); ("fold-003", 1.0) ]

let _baseline_actuals () =
  List.map _baseline_sharpes ~f:(fun (fold_name, s) ->
      _fold_actual ~fold_name ~sharpe_ratio:s ~variant_label:"cell-E" ())

(** Build a synthetic candidate whose per-fold Sharpe equals baseline_Sharpe +
    [delta_per_fold]: yields a constant-Δ candidate whose mean Δ =
    delta_per_fold and stdev Δ = 0. *)
let _make_constant_offset_candidate ~label ~delta : Rescore.candidate =
  let actuals =
    List.map _baseline_sharpes ~f:(fun (fold_name, s) ->
        _fold_actual ~fold_name ~sharpe_ratio:(s +. delta) ~variant_label:label
          ())
  in
  { label; parameters = [ ("knob", delta) ]; fold_actuals = actuals }

(** Build a synthetic input with N candidates whose mean Δ values are the list
    [deltas], in order. Each candidate is named ["bo-iter-NNN"]. *)
let _make_synthetic_input (deltas : float list) : Rescore.bo_rescore_input =
  let candidates =
    List.mapi deltas ~f:(fun i delta ->
        let label = sprintf "bo-iter-%03d" i in
        _make_constant_offset_candidate ~label ~delta)
  in
  { schema_version = Rescore.current_schema_version; candidates }

(* ---------- spread_of ---------- *)

(** Hand-pinned: spread of a list with known min/max. *)
let test_spread_of_basic _ =
  assert_that
    (Rescore.spread_of [ 1.0; 5.0; 2.0; -1.0; 4.0 ])
    (float_equal ~epsilon:_epsilon 6.0)

(** Empty input collapses to 0.0 — the report renderer wants a total function.
*)
let test_spread_of_empty _ =
  assert_that (Rescore.spread_of []) (float_equal ~epsilon:_epsilon 0.0)

(** Singleton: max == min, spread 0. Pins the no-spread degenerate case. *)
let test_spread_of_singleton _ =
  assert_that (Rescore.spread_of [ 3.14 ]) (float_equal ~epsilon:_epsilon 0.0)

(* ---------- named constants ---------- *)

(** Pin the three named constants extracted from magic numbers — historical
    surface, multiplier, and the derived default. Future tuning that changes any
    of these will be caught here, forcing the change to be deliberate. *)
let test_default_min_spread_is_5x_historical _ =
  assert_that Rescore.historical_flat_surface
    (float_equal ~epsilon:_epsilon 0.81);
  assert_that Rescore.flat_surface_multiplier
    (float_equal ~epsilon:_epsilon 5.0);
  assert_that Rescore.default_min_spread (float_equal ~epsilon:_epsilon 4.05);
  assert_that Rescore.default_min_spread
    (float_equal ~epsilon:_epsilon
       (Rescore.flat_surface_multiplier *. Rescore.historical_flat_surface))

(* ---------- rescore_candidate ---------- *)

(** Identity: candidate fold_actuals == baseline fold_actuals → mean Δ = 0,
    stdev Δ = 0, n_matched = 4. The constant-offset builder with delta = 0.0
    produces exactly this. *)
let test_rescore_candidate_identity _ =
  let cand = _make_constant_offset_candidate ~label:"id" ~delta:0.0 in
  let result =
    Rescore.rescore_candidate cand ~baseline_fold_actuals:(_baseline_actuals ())
      ~metric:`Sharpe
  in
  assert_that result
    (all_of
       [
         field (fun (r : Rescore.candidate_rescore) -> r.label) (equal_to "id");
         field
           (fun (r : Rescore.candidate_rescore) -> r.mean_delta)
           (float_equal ~epsilon:_epsilon 0.0);
         field
           (fun (r : Rescore.candidate_rescore) -> r.stdev_delta)
           (float_equal ~epsilon:_epsilon 0.0);
         field (fun (r : Rescore.candidate_rescore) -> r.n_matched) (equal_to 4);
       ])

(** Constant offset: candidate Sharpe = baseline + 0.25 on every fold → mean Δ =
    0.25, stdev = 0. *)
let test_rescore_candidate_constant_offset _ =
  let cand = _make_constant_offset_candidate ~label:"c" ~delta:0.25 in
  let result =
    Rescore.rescore_candidate cand ~baseline_fold_actuals:(_baseline_actuals ())
      ~metric:`Sharpe
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Rescore.candidate_rescore) -> r.mean_delta)
           (float_equal ~epsilon:_epsilon 0.25);
         field
           (fun (r : Rescore.candidate_rescore) -> r.stdev_delta)
           (float_equal ~epsilon:_epsilon 0.0);
         field (fun (r : Rescore.candidate_rescore) -> r.n_matched) (equal_to 4);
       ])

(** Partial overlap: candidate carries one fold not in baseline + one baseline
    fold not in candidate. Only the intersecting folds contribute. Pins the
    silently-drop-mismatched-folds contract inherited from
    {!Bayesian_runner_scoring.paired_delta}. *)
let test_rescore_candidate_partial_overlap _ =
  let baseline =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.0 ();
      _fold_actual ~fold_name:"f2" ~sharpe_ratio:0.3 () (* not in candidate *);
    ]
  in
  let cand : Rescore.candidate =
    {
      label = "partial";
      parameters = [];
      fold_actuals =
        [
          _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.8 ();
          _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.4 ();
          _fold_actual ~fold_name:"f3" ~sharpe_ratio:99.0 ()
          (* dropped — not in baseline *);
        ];
    }
  in
  let result =
    Rescore.rescore_candidate cand ~baseline_fold_actuals:baseline
      ~metric:`Sharpe
  in
  (* Δ on f0 = 0.3; Δ on f1 = 0.4; mean = 0.35; n_matched = 2. *)
  assert_that result
    (all_of
       [
         field
           (fun (r : Rescore.candidate_rescore) -> r.mean_delta)
           (float_equal ~epsilon:_epsilon 0.35);
         field (fun (r : Rescore.candidate_rescore) -> r.n_matched) (equal_to 2);
       ])

(** Disjoint pair: no shared fold names → exception bubbles up from
    {!Bayesian_runner_scoring.paired_delta}. Verifies the rescorer does not
    swallow the disjoint-pair signal. *)
let test_rescore_candidate_disjoint_raises _ =
  let baseline =
    [
      _fold_actual ~fold_name:"a0" ~sharpe_ratio:0.5 ();
      _fold_actual ~fold_name:"a1" ~sharpe_ratio:1.0 ();
    ]
  in
  let cand : Rescore.candidate =
    {
      label = "disjoint";
      parameters = [];
      fold_actuals =
        [
          _fold_actual ~fold_name:"b0" ~sharpe_ratio:0.8 ();
          _fold_actual ~fold_name:"b1" ~sharpe_ratio:1.5 ();
        ];
    }
  in
  let f () =
    let _ =
      Rescore.rescore_candidate cand ~baseline_fold_actuals:baseline
        ~metric:`Sharpe
    in
    ()
  in
  match
    try
      f ();
      None
    with
    | Failure msg -> Some msg
    | exn -> assert_failure ("expected Failure, got: " ^ Exn.to_string exn)
  with
  | None -> assert_failure "expected Failure on disjoint fold names"
  | Some msg ->
      assert_bool
        ("Failure message should mention no fold names matched: " ^ msg)
        (String.is_substring msg ~substring:"no fold names matched")

(* ---------- build_report end-to-end ---------- *)

(** Hand-pinned 3-candidate × 4-fold fixture. Pins the per-candidate mean Δ
    values + the overall spread + the verdict. Each candidate's offset against
    the baseline is the [delta] argument; spread = max - min across the three
    candidate mean Δ values.

    Three candidates with deltas [-1.0; 2.0; 4.0]: means are [-1.0; 2.0; 4.0],
    spread = 4.0 - (-1.0) = 5.0; passes the default threshold 4.05. *)
let test_build_report_three_candidate_passes _ =
  let input = _make_synthetic_input [ -1.0; 2.0; 4.0 ] in
  let baseline_actuals = _baseline_actuals () in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals:baseline_actuals
      ~metric:`Sharpe ~min_spread:Rescore.default_min_spread
  in
  assert_that report
    (all_of
       [
         field (fun (r : Rescore.report) -> r.candidates) (size_is 3);
         field
           (fun (r : Rescore.report) -> r.spread)
           (float_equal ~epsilon:_epsilon 5.0);
         field
           (fun (r : Rescore.report) -> r.min_spread)
           (float_equal ~epsilon:_epsilon Rescore.default_min_spread);
         field (fun (r : Rescore.report) -> r.verdict) (equal_to Rescore.Pass);
       ])

(** Boundary FAIL: spread exactly 0.5 — well below the default 4.05. *)
let test_build_report_below_threshold_fails _ =
  let input = _make_synthetic_input [ 0.0; 0.25; 0.5 ] in
  let baseline_actuals = _baseline_actuals () in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals:baseline_actuals
      ~metric:`Sharpe ~min_spread:Rescore.default_min_spread
  in
  assert_that report
    (all_of
       [
         field
           (fun (r : Rescore.report) -> r.spread)
           (float_equal ~epsilon:_epsilon 0.5);
         field (fun (r : Rescore.report) -> r.verdict) (equal_to Rescore.Fail);
       ])

(** Strictly-greater contract: spread == min_spread → Fail (not Pass). The plan
    §M1 T1.5 acceptance gate is "spread > 5× 0.81", a strict inequality. *)
let test_build_report_exactly_at_threshold_fails _ =
  let input = _make_synthetic_input [ 0.0; 2.0 ] in
  let baseline_actuals = _baseline_actuals () in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals:baseline_actuals
      ~metric:`Sharpe ~min_spread:2.0
  in
  assert_that report
    (all_of
       [
         field
           (fun (r : Rescore.report) -> r.spread)
           (float_equal ~epsilon:_epsilon 2.0);
         field (fun (r : Rescore.report) -> r.verdict) (equal_to Rescore.Fail);
       ])

(** Empty input: zero candidates → spread 0 → Fail. The report still renders
    successfully (does not raise). *)
let test_build_report_empty_input_fails _ =
  let input : Rescore.bo_rescore_input =
    { schema_version = Rescore.current_schema_version; candidates = [] }
  in
  let baseline_actuals = _baseline_actuals () in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals:baseline_actuals
      ~metric:`Sharpe ~min_spread:Rescore.default_min_spread
  in
  assert_that report
    (all_of
       [
         field (fun (r : Rescore.report) -> r.candidates) (size_is 0);
         field
           (fun (r : Rescore.report) -> r.spread)
           (float_equal ~epsilon:_epsilon 0.0);
         field (fun (r : Rescore.report) -> r.verdict) (equal_to Rescore.Fail);
       ])

(* ---------- markdown rendering ---------- *)

(** Verdict line + metric label + spread row appear in the markdown output. The
    test is intentionally substring-based: the renderer's exact pixel layout is
    allowed to drift (formatting, headers), but these three semantic anchors
    must remain. *)
let test_markdown_pass_contains_verdict_and_spread _ =
  let input = _make_synthetic_input [ -1.0; 2.0; 4.0 ] in
  let baseline_actuals = _baseline_actuals () in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals:baseline_actuals
      ~metric:`Sharpe ~min_spread:Rescore.default_min_spread
  in
  let md = Rescore.report_to_markdown report ~metric:`Sharpe in
  assert_bool "markdown contains PASS verdict"
    (String.is_substring md ~substring:"PASS");
  assert_bool "markdown contains metric label Sharpe"
    (String.is_substring md ~substring:"Sharpe");
  assert_bool "markdown contains spread value 5.000000"
    (String.is_substring md ~substring:"5.000000");
  assert_bool "markdown contains historical flat-surface anchor 0.81"
    (String.is_substring md ~substring:"0.81")

(** FAIL verdict surfaces in the markdown when the spread is below threshold. *)
let test_markdown_fail_contains_fail_label _ =
  let input = _make_synthetic_input [ 0.0; 0.5 ] in
  let baseline_actuals = _baseline_actuals () in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals:baseline_actuals
      ~metric:`Sharpe ~min_spread:Rescore.default_min_spread
  in
  let md = Rescore.report_to_markdown report ~metric:`Sharpe in
  assert_bool "markdown contains FAIL verdict"
    (String.is_substring md ~substring:"FAIL")

(* ---------- file I/O round-trip ---------- *)

(** Create a fresh per-test scratch path under the OUnit-provided directory.
    OUnit's [bracket_tmpdir] would be the canonical choice, but the simple
    [Filename_unix.temp_dir] is enough — the file content is overwritten on each
    test invocation and the cleanup is left to the OS / next CI run. Used only
    by the round-trip tests below. *)
let _tmp_dir () = Filename_unix.temp_dir "rescore_test_" ""

(** Round-trip a synthetic input + baseline via the public loaders. Pins the
    on-disk shape: the schema_version is required and matches
    [current_schema_version]; the baseline is a flat sexp list of fold_actuals
    (matches the existing walk_forward_runner output shape). *)
let test_sexp_round_trip _ =
  let tmp = _tmp_dir () in
  let input = _make_synthetic_input [ -1.0; 2.0; 4.0 ] in
  let baseline = _baseline_actuals () in
  let input_path = Filename.concat tmp "rescore_input.sexp" in
  let baseline_path = Filename.concat tmp "baseline_fold_actuals.sexp" in
  Out_channel.write_all input_path
    ~data:(Sexp.to_string_hum (Rescore.sexp_of_bo_rescore_input input));
  Out_channel.write_all baseline_path
    ~data:
      (Sexp.to_string_hum
         (Sexp.List (List.map baseline ~f:Wf.sexp_of_fold_actual)));
  let loaded_input = Rescore.load_input input_path in
  let loaded_baseline = Rescore.load_baseline_fold_actuals baseline_path in
  let report =
    Rescore.build_report ~input:loaded_input
      ~baseline_fold_actuals:loaded_baseline ~metric:`Sharpe
      ~min_spread:Rescore.default_min_spread
  in
  assert_that report
    (all_of
       [
         field
           (fun (r : Rescore.report) -> r.spread)
           (float_equal ~epsilon:_epsilon 5.0);
         field (fun (r : Rescore.report) -> r.verdict) (equal_to Rescore.Pass);
       ])

(** load_input rejects a file with a different schema_version. Pins the
    forward-compat contract: future shape drift must be deliberate. *)
let test_load_input_rejects_schema_mismatch _ =
  let tmp = _tmp_dir () in
  let input_path = Filename.concat tmp "wrong_version.sexp" in
  let wrong_version : Rescore.bo_rescore_input =
    { schema_version = 999; candidates = [] }
  in
  Out_channel.write_all input_path
    ~data:(Sexp.to_string_hum (Rescore.sexp_of_bo_rescore_input wrong_version));
  let f () =
    let _ = Rescore.load_input input_path in
    ()
  in
  match
    try
      f ();
      None
    with
    | Failure msg -> Some msg
    | exn -> assert_failure ("expected Failure, got: " ^ Exn.to_string exn)
  with
  | None -> assert_failure "expected Failure on schema_version mismatch"
  | Some msg ->
      assert_bool
        ("Failure message should mention schema_version mismatch: " ^ msg)
        (String.is_substring msg ~substring:"schema_version")

(** Discriminator dispatch: the [metric] argument is plumbed through to
    [paired_delta]. Pins that the rescorer honours [`Total_return_pct]
    correctly. *)
let test_total_return_metric_dispatch _ =
  let baseline =
    [
      _fold_actual ~fold_name:"f0" ~sharpe_ratio:0.5 ~total_return_pct:10.0 ();
      _fold_actual ~fold_name:"f1" ~sharpe_ratio:1.0 ~total_return_pct:20.0 ();
    ]
  in
  let cand : Rescore.candidate =
    {
      label = "tr-test";
      parameters = [];
      fold_actuals =
        [
          _fold_actual ~fold_name:"f0" ~sharpe_ratio:99.0 ~total_return_pct:15.0
            ();
          _fold_actual ~fold_name:"f1" ~sharpe_ratio:99.0 ~total_return_pct:30.0
            ();
        ];
    }
  in
  let result =
    Rescore.rescore_candidate cand ~baseline_fold_actuals:baseline
      ~metric:`Total_return_pct
  in
  (* Δ on f0 = 5.0; Δ on f1 = 10.0; mean = 7.5. Sharpe noise (99.0) on
     candidate must NOT corrupt the score — proves dispatch is correct. *)
  assert_that result
    (all_of
       [
         field
           (fun (r : Rescore.candidate_rescore) -> r.mean_delta)
           (float_equal ~epsilon:_epsilon 7.5);
         field (fun (r : Rescore.candidate_rescore) -> r.n_matched) (equal_to 2);
       ])

let suite =
  "Tuner_bin.Bayesian_runner_rescore"
  >::: [
         "spread_of basic" >:: test_spread_of_basic;
         "spread_of empty" >:: test_spread_of_empty;
         "spread_of singleton" >:: test_spread_of_singleton;
         "default_min_spread = 5 * historical_flat_surface"
         >:: test_default_min_spread_is_5x_historical;
         "rescore_candidate identity → mean Δ = 0"
         >:: test_rescore_candidate_identity;
         "rescore_candidate constant offset → mean Δ = offset"
         >:: test_rescore_candidate_constant_offset;
         "rescore_candidate partial overlap drops mismatched folds"
         >:: test_rescore_candidate_partial_overlap;
         "rescore_candidate disjoint folds raises"
         >:: test_rescore_candidate_disjoint_raises;
         "build_report 3-candidate spread 5.0 → Pass"
         >:: test_build_report_three_candidate_passes;
         "build_report spread 0.5 < threshold → Fail"
         >:: test_build_report_below_threshold_fails;
         "build_report spread == threshold → Fail (strict >)"
         >:: test_build_report_exactly_at_threshold_fails;
         "build_report empty candidates → Fail"
         >:: test_build_report_empty_input_fails;
         "markdown PASS contains verdict + spread + 0.81 anchor"
         >:: test_markdown_pass_contains_verdict_and_spread;
         "markdown FAIL contains FAIL label"
         >:: test_markdown_fail_contains_fail_label;
         "sexp round-trip via public loaders" >:: test_sexp_round_trip;
         "load_input rejects schema_version mismatch"
         >:: test_load_input_rejects_schema_mismatch;
         "metric=`Total_return_pct dispatch"
         >:: test_total_return_metric_dispatch;
       ]

let () = run_test_tt_main suite
