(** Unit tests for {!Walk_forward.Walk_forward_report}. Pure markdown shape
    checks — no backtest invocation. *)

open OUnit2
open Core
open Matchers
module Report = Walk_forward.Walk_forward_report
module FG = Walk_forward.Fold_gate

let _fa ~fold ~variant ~ret ~sharpe ~maxdd ~calmar : Report.fold_actual =
  {
    fold_name = fold;
    variant_label = variant;
    total_return_pct = ret;
    sharpe_ratio = sharpe;
    max_drawdown_pct = maxdd;
    calmar_ratio = calmar;
  }

let _baseline_gate ?(metric = FG.Sharpe) ?(m = 2) ?(n = 3) ?(worst_delta = 0.5)
    () : FG.t =
  { metric; m; n; worst_delta }

(* ---------- Validation ---------- *)

let test_empty_folds_raises _ =
  assert_raises
    (Failure "Walk_forward_report.compute: fold_actuals must be non-empty")
    (fun () ->
      Report.render ~baseline_label:"baseline" ~gate:(_baseline_gate ())
        ~fold_actuals:[])

let test_baseline_not_present_raises _ =
  let folds =
    [
      _fa ~fold:"fold-000" ~variant:"A" ~ret:1.0 ~sharpe:1.0 ~maxdd:5.0
        ~calmar:1.0;
    ]
  in
  let exn =
    try
      let _ =
        Report.render ~baseline_label:"baseline" ~gate:(_baseline_gate ~n:1 ())
          ~fold_actuals:folds
      in
      None
    with Failure _ as e -> Some e
  in
  assert_that exn
    (is_some_and
       (matching ~msg:"Expected Failure baseline-not-present"
          (function
            | Failure msg
              when String.is_substring msg ~substring:"baseline_label" ->
                Some ()
            | _ -> None)
          (equal_to ())))

(* ---------- Section headings present ---------- *)

let _three_fold_two_variant_setup () =
  let baseline =
    [
      _fa ~fold:"fold-000" ~variant:"baseline" ~ret:5.0 ~sharpe:0.5 ~maxdd:8.0
        ~calmar:0.6;
      _fa ~fold:"fold-001" ~variant:"baseline" ~ret:6.0 ~sharpe:0.6 ~maxdd:9.0
        ~calmar:0.7;
      _fa ~fold:"fold-002" ~variant:"baseline" ~ret:4.0 ~sharpe:0.4 ~maxdd:7.0
        ~calmar:0.5;
    ]
  in
  let variant =
    [
      _fa ~fold:"fold-000" ~variant:"cellE" ~ret:8.0 ~sharpe:0.9 ~maxdd:6.0
        ~calmar:1.1;
      _fa ~fold:"fold-001" ~variant:"cellE" ~ret:7.0 ~sharpe:0.7 ~maxdd:10.0
        ~calmar:0.8;
      _fa ~fold:"fold-002" ~variant:"cellE" ~ret:5.0 ~sharpe:0.45 ~maxdd:8.0
        ~calmar:0.55;
    ]
  in
  baseline @ variant

let test_render_contains_all_four_section_headers _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let md = Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds in
  assert_that md
    (all_of
       [
         contains_substring "# Walk-forward CV report";
         contains_substring "## 1. Per-fold metrics";
         contains_substring "## 2. Stability";
         contains_substring "## 3. Cross-fold sensitivity";
         contains_substring "## 4. Go/no-go verdict";
       ])

let test_render_contains_pass_when_variant_wins _ =
  (* cellE wins 3/3 on Sharpe (0.9>0.5, 0.7>0.6, 0.45>0.4). Gate m=2/3, Δ=0.5
     — no fold trails so should PASS. *)
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 ~worst_delta:0.5 () in
  let md = Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds in
  assert_that md
    (all_of [ contains_substring "cellE"; contains_substring "PASS" ])

let test_render_contains_fail_when_m_threshold_missed _ =
  (* baseline > cellE on all 3 folds; require cellE wins ≥2 — must FAIL. *)
  let folds =
    [
      _fa ~fold:"fold-000" ~variant:"baseline" ~ret:9.0 ~sharpe:1.5 ~maxdd:5.0
        ~calmar:1.5;
      _fa ~fold:"fold-001" ~variant:"baseline" ~ret:9.0 ~sharpe:1.5 ~maxdd:5.0
        ~calmar:1.5;
      _fa ~fold:"fold-002" ~variant:"baseline" ~ret:9.0 ~sharpe:1.5 ~maxdd:5.0
        ~calmar:1.5;
      _fa ~fold:"fold-000" ~variant:"cellE" ~ret:1.0 ~sharpe:0.2 ~maxdd:10.0
        ~calmar:0.2;
      _fa ~fold:"fold-001" ~variant:"cellE" ~ret:1.0 ~sharpe:0.2 ~maxdd:10.0
        ~calmar:0.2;
      _fa ~fold:"fold-002" ~variant:"cellE" ~ret:1.0 ~sharpe:0.2 ~maxdd:10.0
        ~calmar:0.2;
    ]
  in
  let gate = _baseline_gate ~m:2 ~n:3 ~worst_delta:100.0 () in
  let md = Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds in
  assert_that md (contains_substring "FAIL")

let test_per_fold_table_renders_decimal_metrics _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let md = Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds in
  (* baseline fold-000 has return 5.0 and Sharpe 0.5 — should appear formatted *)
  assert_that md
    (all_of [ contains_substring "5.00"; contains_substring "0.500" ])

let test_stability_row_shows_mean_and_stdev _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let md = Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds in
  (* The stability table uses "μ ± σ" header; verify the symbol pair appears. *)
  assert_that md (contains_substring "μ ± σ")

let test_sensitivity_row_per_variant _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let md = Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds in
  (* cellE wins on 3 folds (0.9>0.5, 0.7>0.6, 0.45>0.4). Sensitivity table
     should report "cellE | 3 | 3". *)
  assert_that md (contains_substring "| cellE | 3 | 3 |")

(* ---------- Determinism ---------- *)

let test_render_is_deterministic _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let md1 =
    Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds
  in
  let md2 =
    Report.render ~baseline_label:"baseline" ~gate ~fold_actuals:folds
  in
  assert_that md1 (equal_to md2)

(* ---------- compute aggregate ---------- *)

let test_compute_stability_per_variant _ =
  (* baseline Sharpe = mean(0.5, 0.6, 0.4) = 0.5, stdev = 0.1.
     cellE Sharpe = mean(0.9, 0.7, 0.45) = 0.6833…, stdev ~ 0.2255. *)
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let agg =
    Report.compute ~baseline_label:"baseline" ~gate ~fold_actuals:folds
  in
  assert_that agg
    (all_of
       [
         field (fun (a : Report.aggregate) -> a.fold_count) (equal_to 3);
         field
           (fun (a : Report.aggregate) -> a.baseline_label)
           (equal_to "baseline");
         field
           (fun (a : Report.aggregate) -> a.metric_label)
           (equal_to "Sharpe");
         field
           (fun (a : Report.aggregate) -> a.stability)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (s : Report.variant_stability) -> s.variant_label)
                      (equal_to "baseline");
                    field
                      (fun (s : Report.variant_stability) ->
                        s.sharpe_ratio.mean)
                      (float_equal ~epsilon:1e-4 0.5);
                    field
                      (fun (s : Report.variant_stability) ->
                        s.sharpe_ratio.stdev)
                      (float_equal ~epsilon:1e-4 0.1);
                    field
                      (fun (s : Report.variant_stability) -> s.sharpe_ratio.min)
                      (float_equal ~epsilon:1e-4 0.4);
                    field
                      (fun (s : Report.variant_stability) -> s.sharpe_ratio.max)
                      (float_equal ~epsilon:1e-4 0.6);
                  ];
                all_of
                  [
                    field
                      (fun (s : Report.variant_stability) -> s.variant_label)
                      (equal_to "cellE");
                    field
                      (fun (s : Report.variant_stability) ->
                        s.sharpe_ratio.mean)
                      (float_equal ~epsilon:1e-3 0.6833);
                  ];
              ]);
       ])

let test_compute_sensitivity_excludes_baseline _ =
  (* cellE strictly wins 3/3 on Sharpe vs baseline. *)
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let agg =
    Report.compute ~baseline_label:"baseline" ~gate ~fold_actuals:folds
  in
  assert_that agg.sensitivity
    (elements_are
       [
         all_of
           [
             field
               (fun (s : Report.variant_sensitivity) -> s.variant_label)
               (equal_to "cellE");
             field
               (fun (s : Report.variant_sensitivity) -> s.wins_on_gate_metric)
               (equal_to 3);
           ];
       ])

let test_compute_verdict_pass _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 ~worst_delta:0.5 () in
  let agg =
    Report.compute ~baseline_label:"baseline" ~gate ~fold_actuals:folds
  in
  assert_that agg.verdicts
    (elements_are
       [
         all_of
           [
             field (fun (label, _) -> label) (equal_to "cellE");
             field
               (fun (_, v) -> v)
               (matching ~msg:"Expected Pass verdict with 3/3 wins"
                  (function FG.Pass { wins; n } -> Some (wins, n) | _ -> None)
                  (equal_to (3, 3)));
           ];
       ])

let test_compute_validates_baseline _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  assert_raises
    (Failure
       "Walk_forward_report.compute: baseline_label \"missing\" not present in \
        fold_actuals (labels: baseline, cellE)") (fun () ->
      Report.compute ~baseline_label:"missing" ~gate ~fold_actuals:folds
      |> ignore)

let test_aggregate_sexp_round_trip _ =
  let folds = _three_fold_two_variant_setup () in
  let gate = _baseline_gate ~m:2 ~n:3 () in
  let agg =
    Report.compute ~baseline_label:"baseline" ~gate ~fold_actuals:folds
  in
  let parsed = Report.aggregate_of_sexp (Report.sexp_of_aggregate agg) in
  assert_that parsed
    (all_of
       [
         field (fun (a : Report.aggregate) -> a.fold_count) (equal_to 3);
         field
           (fun (a : Report.aggregate) -> a.baseline_label)
           (equal_to "baseline");
         field
           (fun (a : Report.aggregate) -> a.metric_label)
           (equal_to "Sharpe");
         field
           (fun (a : Report.aggregate) -> List.length a.stability)
           (equal_to 2);
         field
           (fun (a : Report.aggregate) -> List.length a.sensitivity)
           (equal_to 1);
         field
           (fun (a : Report.aggregate) -> List.length a.verdicts)
           (equal_to 1);
       ])

(* ---------- Sexp round-trip ---------- *)

let test_fold_actual_sexp_round_trip _ =
  let fa =
    _fa ~fold:"fold-007" ~variant:"X" ~ret:12.3 ~sharpe:0.8 ~maxdd:6.7
      ~calmar:1.2
  in
  let parsed = Report.fold_actual_of_sexp (Report.sexp_of_fold_actual fa) in
  assert_that parsed
    (all_of
       [
         field
           (fun (f : Report.fold_actual) -> f.fold_name)
           (equal_to "fold-007");
         field
           (fun (f : Report.fold_actual) -> f.total_return_pct)
           (float_equal 12.3);
       ])

let suite =
  "Walk_forward_report"
  >::: [
         "empty folds raises" >:: test_empty_folds_raises;
         "baseline not present raises" >:: test_baseline_not_present_raises;
         "render contains all 4 section headers"
         >:: test_render_contains_all_four_section_headers;
         "render PASS when variant wins"
         >:: test_render_contains_pass_when_variant_wins;
         "render FAIL when M-threshold missed"
         >:: test_render_contains_fail_when_m_threshold_missed;
         "per-fold table formats decimals"
         >:: test_per_fold_table_renders_decimal_metrics;
         "stability row shows μ ± σ" >:: test_stability_row_shows_mean_and_stdev;
         "sensitivity row per variant" >:: test_sensitivity_row_per_variant;
         "render is deterministic" >:: test_render_is_deterministic;
         "compute stability per variant" >:: test_compute_stability_per_variant;
         "compute sensitivity excludes baseline"
         >:: test_compute_sensitivity_excludes_baseline;
         "compute verdict Pass" >:: test_compute_verdict_pass;
         "compute validates baseline_label" >:: test_compute_validates_baseline;
         "aggregate sexp round-trip" >:: test_aggregate_sexp_round_trip;
         "fold_actual sexp round-trip" >:: test_fold_actual_sexp_round_trip;
       ]

let () = run_test_tt_main suite
