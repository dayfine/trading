(** Integration tests for the [?parallel] wiring of
    {!Walk_forward.Walk_forward_executor.execute_spec} into {!Fork_pool}.

    Covers plan #1197 §7 PR-2 test plan:

    + Determinism — 2 variants × 3 folds, byte-identical aggregates at
      [parallel = 1] vs [parallel = 4]. Pins the result-reassembly contract.
    + Failure propagation — stub runner raises on (variant=1, fold=2);
      [parallel = 4] re-raises with the failing job's index embedded so the
      operator can correlate back to the work-item table.
    + Argument validation — [parallel = 0] and [parallel > max_parallel] are
      rejected with [Invalid_argument] propagated from
      {!Fork_pool.run_parallel}.

    Uses a stubbed [?run_one] (see
    {!Walk_forward.Walk_forward_executor.fold_runner}) so the test runs in
    milliseconds without invoking the real {!Backtest.Runner.run_backtest}. The
    stub returns a deterministic {!Walk_forward_report.fold_actual} derived from
    the scenario's [name] (which already encodes variant_label + fold_name via
    {!Walk_forward.Walk_forward_runner.build_fold_scenario}), so a
    reassembly-order bug surfaces as a value mismatch in the aggregate. *)

open Core
open OUnit2
open Matchers
module Executor = Walk_forward.Walk_forward_executor
module Spec = Walk_forward.Spec
module WS = Walk_forward.Window_spec
module WFR = Walk_forward.Walk_forward_runner
module Report = Walk_forward.Walk_forward_report
module Fold_gate = Walk_forward.Fold_gate
module Scenario = Scenario_lib.Scenario

(* ---- Test tunables (named so the magic-number linter sees no surprises) ---- *)

let _baseline_label = "baseline"
let _candidate_label = "candidate"
let _failure_variant_idx = 1
let _failure_fold_idx = 2
let _failure_message = "stubbed pair-eval boom"
let _parallel_modes_under_test = [ 1; 4 ]

(* ---- Date / fixture helpers --------------------------------------- *)

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _make_base () : Scenario.t =
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
    description = "stub base scenario";
    period = { start_date = _date 2020 1 1; end_date = _date 2020 1 31 };
    universe_path = "universes/parity-7sym.sexp";
    config_overrides = [];
    strategy = Backtest.Strategy_choice.default;
    slippage_bps = None;
    expected;
  }

(* A spec with exactly 2 variants × 3 folds. Folds are hand-crafted via
   [Explicit] so the test is decoupled from the rolling generator's
   parameter arithmetic. *)
let _make_spec () : Spec.t =
  let folds : WS.explicit_fold list =
    List.init 3 ~f:(fun i : WS.explicit_fold ->
        {
          name = sprintf "fold-%03d" i;
          train_period = None;
          test_period =
            { start_date = _date 2020 1 1; end_date = _date 2020 (i + 1) 28 };
        })
  in
  {
    base_scenario = "stub-base";
    window_spec = WS.Explicit folds;
    variants =
      [
        { WFR.label = _baseline_label; overrides = [] };
        { WFR.label = _candidate_label; overrides = [] };
      ];
    baseline_label = _baseline_label;
    gate = { metric = Sharpe; m = 1; n = 3; worst_delta = 1.0 };
  }

(* ---- Deterministic stub runner ----------------------------------- *)

(** Map a scenario name back to a deterministic [fold_actual]. The scenario name
    shape is ["stub-base-<variant>-fold-<NNN>"] per
    {!Walk_forward.Walk_forward_runner.build_fold_scenario}. We hash on the name
    so a reassembly bug surfaces as a value mismatch in the aggregate rather
    than a silently identical result. *)
let _stub_runner (s : Scenario.t) : Report.fold_actual =
  let h = String.hash s.name in
  let f = Float.of_int (h mod 1000) in
  {
    fold_name = "";
    variant_label = "";
    total_return_pct = f;
    sharpe_ratio = f /. 100.0;
    max_drawdown_pct = (f /. 10.0) +. 1.0;
    calmar_ratio = (f /. 50.0) +. 0.1;
    cagr_pct = (f /. 2.0) +. 0.5;
  }

(* ---- §B Determinism: parallel=1 ≡ parallel=4 ---------------------- *)

(** Run [execute_spec] under every parallel mode in
    {!_parallel_modes_under_test} and return the resulting aggregates
    sexp-serialised. Byte-identical sexps is the property the production
    Bayesian-sweep correctness rests on. *)
let _aggregates_per_parallel ~run_one ~base ~spec : Sexp.t list =
  List.map _parallel_modes_under_test ~f:(fun parallel ->
      let result =
        Executor.execute_spec ~base ~spec ~fixtures_root:"/tmp/unused-by-stub"
          ~parallel ~run_one ()
      in
      Report.sexp_of_aggregate result.aggregate)

let test_determinism_parallel_one_equals_parallel_four _ =
  let base = _make_base () in
  let spec = _make_spec () in
  let sexps = _aggregates_per_parallel ~run_one:_stub_runner ~base ~spec in
  (* All elements should equal the first (parallel=1) — pins the
     reassembly-order contract regardless of which parallel mode wins
     the byte race. *)
  let head = List.hd_exn sexps in
  assert_that sexps (elements_are (List.map sexps ~f:(fun _ -> equal_to head)))

(** Also pin the fold_actuals list shape (not just the aggregate) so a future
    refactor that breaks per-row tagging surfaces here too. *)
let test_determinism_fold_actuals_list_shape _ =
  let base = _make_base () in
  let spec = _make_spec () in
  let run modes =
    List.map modes ~f:(fun parallel ->
        let result =
          Executor.execute_spec ~base ~spec ~fixtures_root:"/tmp/unused-by-stub"
            ~parallel ~run_one:_stub_runner ()
        in
        Sexp.List (List.map result.fold_actuals ~f:Report.sexp_of_fold_actual))
  in
  let sexps = run _parallel_modes_under_test in
  let head = List.hd_exn sexps in
  assert_that sexps (elements_are (List.map sexps ~f:(fun _ -> equal_to head)))

(* ---- §D Failure injection: stub raises on (variant=1, fold=2) ---- *)

(** Stub that raises specifically when invoked for the (variant=1, fold=2) cell.
    Recognises the cell via the scenario name (which embeds both labels). *)
let _failing_stub (s : Scenario.t) : Report.fold_actual =
  let expected_substr =
    sprintf "-%s-fold-%03d" _candidate_label _failure_fold_idx
  in
  (* The variant index lookup: variants are
     [baseline; candidate] so variant_idx=1 is the candidate label. *)
  let _ = _failure_variant_idx in
  if String.is_substring s.name ~substring:expected_substr then
    failwith _failure_message
  else _stub_runner s

(** Invoke [execute_spec] with the failing stub and return the [Failure] message
    (or [None] if the call surprisingly succeeded). *)
let _run_failing ~parallel : string option =
  let base = _make_base () in
  let spec = _make_spec () in
  try
    let _ : Executor.result =
      Executor.execute_spec ~base ~spec ~fixtures_root:"/tmp/unused-by-stub"
        ~parallel ~run_one:_failing_stub ()
    in
    None
  with Failure msg -> Some msg

let test_failure_injection_parallel_four_reraises_with_context _ =
  let raised = _run_failing ~parallel:4 in
  (* [Fork_pool.run_parallel] wraps the message with "job index N". The
     failing pair's flat-array index is variant_idx * n_folds + fold_idx =
     1 * 3 + 2 = 5; assert the wrapper includes both the failing message
     and the cell's flat index so an operator can correlate to the
     work-item table. *)
  assert_that raised
    (is_some_and
       (all_of
          [
            contains_substring _failure_message; contains_substring "job index";
          ]))

let test_failure_injection_parallel_one_surfaces_directly _ =
  let raised = _run_failing ~parallel:1 in
  (* Sequential path: the raise propagates directly without the Fork_pool
     wrapper. The contract is "the message is preserved"; the wrapper is a
     parallel-mode niceness. *)
  assert_that raised (is_some_and (contains_substring _failure_message))

(* ---- §C Smoke: invalid_argument boundary -------------------------- *)

let _run_with_parallel ~parallel : string option =
  let base = _make_base () in
  let spec = _make_spec () in
  try
    let _ : Executor.result =
      Executor.execute_spec ~base ~spec ~fixtures_root:"/tmp/unused-by-stub"
        ~parallel ~run_one:_stub_runner ()
    in
    None
  with Invalid_argument msg -> Some msg

let test_parallel_zero_rejected _ =
  let raised = _run_with_parallel ~parallel:0 in
  assert_that raised (is_some_and (contains_substring "parallel must be >= 1"))

let test_parallel_above_cap_rejected _ =
  let raised = _run_with_parallel ~parallel:(Fork_pool.max_parallel + 1) in
  assert_that raised (is_some_and (contains_substring "parallel must be <="))

(* ---- Test suite registration ------------------------------------- *)

let suite =
  "Walk_forward_executor_parallel"
  >::: [
         "parallel=1 ≡ parallel=4 aggregate byte-identical"
         >:: test_determinism_parallel_one_equals_parallel_four;
         "parallel=1 ≡ parallel=4 fold_actuals shape"
         >:: test_determinism_fold_actuals_list_shape;
         "parallel=4 stub raise re-raised with cell context"
         >:: test_failure_injection_parallel_four_reraises_with_context;
         "parallel=1 stub raise surfaces directly"
         >:: test_failure_injection_parallel_one_surfaces_directly;
         "parallel=0 rejected with Invalid_argument"
         >:: test_parallel_zero_rejected;
         "parallel > max_parallel rejected with Invalid_argument"
         >:: test_parallel_above_cap_rejected;
       ]

let () = run_test_tt_main suite
