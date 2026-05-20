(** Unit tests for {!Tuner_bin.Bayesian_runner_evaluator.build_walk_forward}.

    The new walk-forward path drives one walk-forward CV sweep per BO suggestion
    and scalarises via {!Tuner_bin.Bayesian_runner_scoring.score_cell}. These
    tests pin the contract using a STUB executor — no real backtest is invoked.
    Each test constructs a hand-built
    {!Walk_forward.Walk_forward_executor.result} aggregate and asserts:

    - the score matches what {!Bayesian_runner_scoring.score_cell} computes on
      the stub aggregate;
    - the candidate label is [bo-iter-N] where N is the in-closure iteration
      counter (starts at 0);
    - the two-variant spec the evaluator hands to the executor carries
      [variants = [ baseline; bo-iter-N ]] with the baseline label preserved
      from the walk-forward spec and the candidate's overrides matching
      [Tuner.Grid_search.cell_to_overrides parameters];
    - the [executor] argument is invoked exactly once per call;
    - the diagnostic metric_set is a one-element list (one walk-forward run per
      BO iteration); and
    - scorer-error propagation raises [Failure] (the BO loop cannot consume a
      non-finite metric).

    No filesystem access. No backtest invocation. *)

open OUnit2
open Core
open Matchers
module Evaluator = Tuner_bin.Bayesian_runner_evaluator
module Scoring = Tuner_bin.Bayesian_runner_scoring
module Wf_types = Walk_forward.Walk_forward_types
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_spec = Walk_forward.Spec
module Wf_runner = Walk_forward.Walk_forward_runner
module WS = Walk_forward.Window_spec
module FG = Walk_forward.Fold_gate
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types
module Scenario = Scenario_lib.Scenario

(* ---------- shared helpers ---------- *)

let _epsilon = 1e-9
let _baseline_label = "cell-E"
let _fixtures_root = "/unused-fixtures-root"
let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _stats ?(stdev = Float.nan) ?(min = Float.nan) ?(max = Float.nan) ~mean () :
    Wf_types.per_metric_stats =
  { mean; stdev; min; max }

let _stability_record ~label ~sharpe_mean ~maxdd_mean ?(calmar_mean = 0.0)
    ?(total_return_mean = 0.0) ?(cagr_mean = Float.nan)
    ?(avg_holding_days_mean = Float.nan) () : Wf_types.variant_stability =
  {
    variant_label = label;
    total_return_pct = _stats ~mean:total_return_mean ();
    sharpe_ratio = _stats ~mean:sharpe_mean ();
    max_drawdown_pct = _stats ~mean:maxdd_mean ();
    calmar_ratio = _stats ~mean:calmar_mean ();
    cagr_pct = _stats ~mean:cagr_mean ();
    avg_holding_days = _stats ~mean:avg_holding_days_mean ();
  }

let _pass_verdict ?(wins = 3) ?(n = 3) () : FG.verdict = Pass { wins; n }

let _fail_verdict ?(wins = 0) ?(n = 3) ?(worst_fold = "fold-001")
    ?(worst_gap = 0.5) ?(reason = "M-threshold miss") () : FG.verdict =
  Fail { wins; n; worst_fold; worst_gap; reason }

(** Hand-built aggregate carrying a baseline + a candidate row. *)
let _make_aggregate ~baseline_label ~candidate_label ~baseline_sharpe
    ~baseline_maxdd ~candidate_sharpe ~candidate_maxdd ~candidate_verdict
    ?(fold_count = 3) () : Wf_types.aggregate =
  {
    fold_count;
    baseline_label;
    metric_label = "sharpe_ratio";
    stability =
      [
        _stability_record ~label:baseline_label ~sharpe_mean:baseline_sharpe
          ~maxdd_mean:baseline_maxdd ();
        _stability_record ~label:candidate_label ~sharpe_mean:candidate_sharpe
          ~maxdd_mean:candidate_maxdd ();
      ];
    sensitivity = [];
    verdicts = [ (candidate_label, candidate_verdict) ];
  }

(** A baseline-only aggregate, suitable for the [baseline_aggregate] argument of
    {!Evaluator.build_walk_forward}. *)
let _make_baseline_aggregate ~baseline_label ~baseline_sharpe ~baseline_maxdd
    ?(fold_count = 3) () : Wf_types.aggregate =
  {
    fold_count;
    baseline_label;
    metric_label = "sharpe_ratio";
    stability =
      [
        _stability_record ~label:baseline_label ~sharpe_mean:baseline_sharpe
          ~maxdd_mean:baseline_maxdd ();
      ];
    sensitivity = [];
    verdicts = [];
  }

(** A minimal walk-forward spec template. Tests don't actually run it — the stub
    executor ignores [spec.window_spec] and [spec.base_scenario]; only
    [spec.baseline_label] and [spec.gate] are read by the evaluator (via
    {!_build_two_variant_spec}). *)
let _make_walk_forward_spec ~baseline_label : Wf_spec.t =
  {
    base_scenario = "ignored-by-stub.sexp";
    window_spec =
      Rolling
        {
          start_date = _date 2020 1 1;
          end_date = _date 2020 6 30;
          train_days = 0;
          test_days = 30;
          step_days = 30;
        };
    variants = [];
    baseline_label;
    gate = { metric = Sharpe; m = 2; n = 3; worst_delta = 0.30 };
  }

(** A trivial base scenario; the stub executor ignores it. Only the fields
    {!Scenario.t} insists on are populated. *)
let _make_base_scenario () : Scenario.t =
  let expected : Scenario.expected =
    {
      total_return_pct = { min_f = -100.0; max_f = 500.0 };
      total_trades = { min_f = 0.0; max_f = 1000.0 };
      win_rate = { min_f = 0.0; max_f = 100.0 };
      sharpe_ratio = { min_f = -2.0; max_f = 3.0 };
      max_drawdown_pct = { min_f = 0.0; max_f = 90.0 };
      avg_holding_days = { min_f = 0.0; max_f = 500.0 };
      open_positions_value = None;
      unrealized_pnl = None;
      sortino_ratio_annualized = None;
      calmar_ratio = None;
      ulcer_index = None;
      wall_seconds = None;
    }
  in
  {
    name = "stub-base";
    description = "stub base scenario for evaluator unit tests";
    period = { start_date = _date 2020 1 1; end_date = _date 2020 12 31 };
    universe_path = "ignored.sexp";
    config_overrides = [];
    strategy = Backtest.Strategy_choice.default;
    slippage_bps = None;
    expected;
  }

type stub_call = { base : Scenario.t; spec : Wf_spec.t; fixtures_root : string }
(** A stub executor that records each call into [calls] and returns a
    caller-supplied result. *)

let _make_stub_executor ~(result : Wf_executor.result) :
    Evaluator.executor * stub_call list ref =
  let calls = ref [] in
  let exec ~base ~spec ~fixtures_root =
    calls := { base; spec; fixtures_root } :: !calls;
    result
  in
  (exec, calls)

(* ---------- 1. Score matches Scoring.score_cell on stub aggregate ---------- *)

let test_score_matches_scoring_module _ =
  (* Hand build a candidate aggregate with bo-iter-0 (the first call's
     synthesised label); the baseline aggregate is built separately. The
     expected score is what Scoring.score_cell would produce: candidate is
     better than baseline (Sharpe 1.2 vs 0.5, MaxDD 10.0 vs 15.0, Pass) →
     score = +1.2 (no MaxDD penalty since candidate MaxDD improves; no gate
     penalty since Pass). *)
  let candidate_label = "bo-iter-0" in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:1.2
      ~candidate_maxdd:10.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, _calls = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let score, _metric_sets =
    evaluator ~parameters:[ ("initial_stop_buffer", 1.10) ]
  in
  assert_that score (float_equal ~epsilon:_epsilon 1.2)

(* ---------- 2. Candidate label is bo-iter-N (counter increments) ---------- *)

let test_candidate_label_increments_per_call _ =
  (* Pin the candidate label by encoding a distinct (sharpe, maxdd) into
     the stub aggregate for each call. The closure's iter counter must
     produce "bo-iter-0" on the first call and "bo-iter-1" on the second;
     each call returns an aggregate whose candidate row matches that
     label. *)
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  (* Mutable cell so the stub returns different aggregates per call. *)
  let next_n = ref 0 in
  let exec : Evaluator.executor =
   fun ~base:_ ~spec ~fixtures_root:_ ->
    let n = !next_n in
    next_n := n + 1;
    let expected_label = sprintf "bo-iter-%d" n in
    (* Confirm the evaluator built the spec with the right candidate label. *)
    let candidate_variant =
      List.find_exn spec.variants ~f:(fun (v : Wf_runner.variant) ->
          not (String.equal v.label _baseline_label))
    in
    assert_equal
      ~msg:(sprintf "expected candidate label %s" expected_label)
      expected_label candidate_variant.label;
    let candidate_agg =
      _make_aggregate ~baseline_label:_baseline_label
        ~candidate_label:expected_label ~baseline_sharpe:0.5
        ~baseline_maxdd:15.0
        ~candidate_sharpe:(0.1 *. Float.of_int (n + 1))
        ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
    in
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let evaluator =
    Evaluator.build_walk_forward ~executor:exec ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let score_0, _ = evaluator ~parameters:[ ("x", 0.0) ] in
  let score_1, _ = evaluator ~parameters:[ ("x", 1.0) ] in
  (* First call: candidate Sharpe = 0.1 → score = 0.1.
     Second call: candidate Sharpe = 0.2 → score = 0.2. *)
  assert_that score_0 (float_equal ~epsilon:_epsilon 0.1);
  assert_that score_1 (float_equal ~epsilon:_epsilon 0.2)

(* ---------- 3. Two-variant spec carries baseline + candidate ---------- *)

let test_two_variant_spec_carries_baseline_and_candidate _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.7
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let parameters = [ ("initial_stop_buffer", 1.20) ] in
  let _score, _metric_sets = evaluator ~parameters in
  (* One call recorded; the spec.variants list is [ baseline; candidate ]
     in that order; baseline overrides are empty; candidate overrides match
     Grid_search.cell_to_overrides parameters. *)
  let expected_candidate_overrides = GS.cell_to_overrides parameters in
  assert_that !calls
    (elements_are
       [
         field
           (fun (c : stub_call) -> c.spec.variants)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (v : Wf_runner.variant) -> v.label)
                      (equal_to _baseline_label);
                    field
                      (fun (v : Wf_runner.variant) -> v.overrides)
                      (size_is 0);
                  ];
                all_of
                  [
                    field
                      (fun (v : Wf_runner.variant) -> v.label)
                      (equal_to "bo-iter-0");
                    field
                      (fun (v : Wf_runner.variant) -> v.overrides)
                      (elements_are
                         (List.map expected_candidate_overrides ~f:equal_to));
                  ];
              ]);
       ])

(* ---------- 4. Executor invoked exactly once per call ---------- *)

let test_executor_invoked_once_per_call _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.8
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let _score, _ = evaluator ~parameters:[ ("x", 0.0) ] in
  assert_that !calls (size_is 1)

(* ---------- 5. Metric_set list is single-element ---------- *)

let test_metric_set_list_is_single_element _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.8
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, _ = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let _score, metric_sets = evaluator ~parameters:[ ("x", 0.0) ] in
  assert_that metric_sets (size_is 1)

(* ---------- 6. Metric_set carries candidate's stability stats ---------- *)

let test_metric_set_contents_match_candidate_stability _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  (* Candidate Sharpe = 0.85, MaxDD = 12.0. Expect those values to surface
     in the diagnostic metric_set. *)
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.85
      ~candidate_maxdd:12.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, _ = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let _score, metric_sets = evaluator ~parameters:[ ("x", 0.0) ] in
  let metric_set = List.hd_exn metric_sets in
  assert_that
    (Map.find metric_set Metric_types.SharpeRatio)
    (is_some_and (float_equal ~epsilon:_epsilon 0.85));
  assert_that
    (Map.find metric_set Metric_types.MaxDrawdown)
    (is_some_and (float_equal ~epsilon:_epsilon 12.0))

(* ---------- 7. Scorer error propagates as Failure ---------- *)

let test_scorer_error_propagates_as_failure _ =
  (* Build an aggregate that the scorer rejects: zero fold_count → Status
     Invalid_argument. The evaluator must convert this to a Failure rather
     than silently returning a NaN. *)
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let bad_candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.5
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ~fold_count:0
      ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = bad_candidate_agg }
  in
  let executor, _ = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let raised =
    try
      let _ = evaluator ~parameters:[ ("x", 0.0) ] in
      false
    with Failure msg -> String.is_substring msg ~substring:"score_cell failed"
  in
  assert_that raised (equal_to true)

(* ---------- 8. Gate Fail penalty applied via scorer ---------- *)

let test_gate_fail_penalty_applied _ =
  (* Verify the path: a Fail verdict on the candidate flows into the score
     via the scorer's gate_penalty term. Score should be exactly
     candidate_sharpe - 10.0 (no MaxDD excess, gate penalty = 10.0). *)
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.9
      ~candidate_maxdd:15.0 ~candidate_verdict:(_fail_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, _ = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let score, _ = evaluator ~parameters:[ ("x", 0.0) ] in
  (* Expected: 0.9 - 10.0 = -9.1 *)
  assert_that score (float_equal ~epsilon:_epsilon (-9.1))

(* ---------- 9. fixtures_root threaded to executor ---------- *)

let test_fixtures_root_threaded_to_executor _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.7
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:"/custom/path" ()
  in
  let _ = evaluator ~parameters:[ ("x", 0.0) ] in
  assert_that !calls
    (elements_are
       [ field (fun c -> c.fixtures_root) (equal_to "/custom/path") ])

(* ---------- 10. Walk-forward spec template's gate preserved ---------- *)

let test_two_variant_spec_preserves_gate _ =
  (* The evaluator's two-variant spec must keep the same gate as the
     template. PR-C explicitly hands the [walk_forward_spec]'s [gate] field
     through unchanged so the score_cell verdict lookup matches what the
     executor produced. *)
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.7
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let template_spec = _make_walk_forward_spec ~baseline_label:_baseline_label in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:template_spec ~baseline_aggregate:baseline_agg
      ~objective:Tuner.Grid_search.Sharpe ~fixtures_root:_fixtures_root ()
  in
  let _ = evaluator ~parameters:[ ("x", 0.0) ] in
  assert_that !calls
    (elements_are
       [
         field
           (fun (c : stub_call) -> c.spec.gate)
           (all_of
              [
                field (fun (g : FG.t) -> g.metric) (equal_to FG.Sharpe);
                field (fun (g : FG.t) -> g.m) (equal_to 2);
                field (fun (g : FG.t) -> g.n) (equal_to 3);
              ]);
       ])

(* ---------- 11. baseline_label flows through the spec ---------- *)

let test_baseline_label_passed_through_spec _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:"my-baseline" ~baseline_sharpe:0.5
      ~baseline_maxdd:15.0 ()
  in
  let candidate_agg : Wf_types.aggregate =
    {
      fold_count = 3;
      baseline_label = "my-baseline";
      metric_label = "sharpe_ratio";
      stability =
        [
          _stability_record ~label:"my-baseline" ~sharpe_mean:0.5
            ~maxdd_mean:15.0 ();
          _stability_record ~label:"bo-iter-0" ~sharpe_mean:0.85
            ~maxdd_mean:15.0 ();
        ];
      sensitivity = [];
      verdicts = [ ("bo-iter-0", _pass_verdict ()) ];
    }
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:(_make_walk_forward_spec ~baseline_label:"my-baseline")
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let _ = evaluator ~parameters:[ ("x", 0.0) ] in
  assert_that !calls
    (elements_are
       [
         field
           (fun (c : stub_call) -> c.spec.baseline_label)
           (equal_to "my-baseline");
       ])

(* ---------- 12. Parameters thread into candidate overrides ---------- *)

let test_parameters_thread_into_candidate_overrides _ =
  (* The candidate variant's overrides must equal
     Tuner.Grid_search.cell_to_overrides parameters in the same order. *)
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.7
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base:(_make_base_scenario ())
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let parameters =
    [
      ("initial_stop_buffer", 1.15);
      ("portfolio_config.risk_per_trade_pct", 0.015);
    ]
  in
  let _ = evaluator ~parameters in
  let expected_overrides = GS.cell_to_overrides parameters in
  assert_that !calls
    (elements_are
       [
         field
           (fun (c : stub_call) ->
             (* The candidate variant is the non-baseline entry in
                spec.variants. *)
             let candidate =
               List.find_exn c.spec.variants ~f:(fun (v : Wf_runner.variant) ->
                   not (String.equal v.label _baseline_label))
             in
             candidate.overrides)
           (elements_are (List.map expected_overrides ~f:equal_to));
       ])

(* ---------- 13. base scenario threaded to executor ---------- *)

let test_base_scenario_threaded_to_executor _ =
  let baseline_agg =
    _make_baseline_aggregate ~baseline_label:_baseline_label
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ()
  in
  let candidate_agg =
    _make_aggregate ~baseline_label:_baseline_label ~candidate_label:"bo-iter-0"
      ~baseline_sharpe:0.5 ~baseline_maxdd:15.0 ~candidate_sharpe:0.7
      ~candidate_maxdd:15.0 ~candidate_verdict:(_pass_verdict ()) ()
  in
  let exec_result : Wf_executor.result =
    { fold_actuals = []; aggregate = candidate_agg }
  in
  let executor, calls = _make_stub_executor ~result:exec_result in
  let base = _make_base_scenario () in
  let evaluator =
    Evaluator.build_walk_forward ~executor ~base
      ~walk_forward_spec:
        (_make_walk_forward_spec ~baseline_label:_baseline_label)
      ~baseline_aggregate:baseline_agg ~objective:Tuner.Grid_search.Sharpe
      ~fixtures_root:_fixtures_root ()
  in
  let _ = evaluator ~parameters:[ ("x", 0.0) ] in
  assert_that !calls
    (elements_are
       [ field (fun (c : stub_call) -> c.base.name) (equal_to "stub-base") ])

(* ---------- 14. default_executor exists with expected signature ---------- *)

(** CP4: [default_executor] is the production wiring exposed in the mli. Pin
    that it is a value of type [executor] — type-check only, no runtime
    invocation (which would call the real backtest). *)
let test_default_executor_type_exists _ =
  let _ : Evaluator.executor = Evaluator.default_executor in
  assert_that true (equal_to true)

(* ---------- 15. make_executor (plan #1197 §7 PR-3) -------------------- *)

(** CP4: [make_executor] is the production wiring exposed in the mli that
    accepts a [?parallel] degree (plan #1197 §7 PR-3). Pin that the function
    returns a value of type [executor] for both the default (omitted) and
    explicit-parallel forms — type-check only, no runtime invocation (which
    would call the real backtest). *)
let test_make_executor_default_type_exists _ =
  let _ : Evaluator.executor = Evaluator.make_executor () in
  assert_that true (equal_to true)

let test_make_executor_with_parallel_type_exists _ =
  let _ : Evaluator.executor = Evaluator.make_executor ~parallel:4 () in
  assert_that true (equal_to true)

let suite =
  "Tuner_bin.Bayesian_runner_evaluator.build_walk_forward"
  >::: [
         "score matches Scoring.score_cell on stub aggregate"
         >:: test_score_matches_scoring_module;
         "candidate label increments per call (bo-iter-N)"
         >:: test_candidate_label_increments_per_call;
         "two-variant spec carries baseline + candidate in order"
         >:: test_two_variant_spec_carries_baseline_and_candidate;
         "executor invoked exactly once per call"
         >:: test_executor_invoked_once_per_call;
         "metric_set list is single-element"
         >:: test_metric_set_list_is_single_element;
         "metric_set carries candidate's stability stats"
         >:: test_metric_set_contents_match_candidate_stability;
         "scorer Status.Error propagates as Failure"
         >:: test_scorer_error_propagates_as_failure;
         "gate Fail penalty applied via scorer (sharpe - 10.0)"
         >:: test_gate_fail_penalty_applied;
         "fixtures_root threaded to executor"
         >:: test_fixtures_root_threaded_to_executor;
         "two-variant spec preserves the template's gate"
         >:: test_two_variant_spec_preserves_gate;
         "baseline_label flows through the two-variant spec"
         >:: test_baseline_label_passed_through_spec;
         "parameters thread into candidate overrides"
         >:: test_parameters_thread_into_candidate_overrides;
         "base scenario threaded to executor"
         >:: test_base_scenario_threaded_to_executor;
         "default_executor exists with expected signature"
         >:: test_default_executor_type_exists;
         "make_executor () returns an executor (PR-3)"
         >:: test_make_executor_default_type_exists;
         "make_executor ~parallel:N returns an executor (PR-3)"
         >:: test_make_executor_with_parallel_type_exists;
       ]

let () = run_test_tt_main suite
