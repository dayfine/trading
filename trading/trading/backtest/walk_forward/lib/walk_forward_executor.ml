open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module WS = Window_spec
module WFR = Walk_forward_runner
module Report = Walk_forward_report

type result = {
  fold_actuals : Report.fold_actual list;
  aggregate : Report.aggregate;
}

type progress_callback =
  variant_label:string ->
  fold_name:string ->
  test_start:Date.t ->
  test_end:Date.t ->
  unit

type fold_runner = Scenario.t -> Report.fold_actual

let noop_progress ~variant_label:_ ~fold_name:_ ~test_start:_ ~test_end:_ = ()

(** Number of calendar days inclusive between [start_date] and [end_date]. *)
let _test_days (period : Scenario.period) =
  Date.diff period.end_date period.start_date + 1

(** Run a single scenario via {!Backtest.Runner.run_backtest} and project its
    summary metrics into a {!Report.fold_actual}. The [fold_name] and
    [variant_label] fields are filled by the caller — {!_evaluate_one_pair}.

    Split out of {!_run_one} so [result] is unreachable as soon as this function
    returns — that lets the post-call [Gc.compact] in {!_run_one} reclaim the
    ~90 MB of transient Daily_panels-cached data the backtest allocates. The
    [\@inline never] annotation prevents the compiler from inlining the body
    back into {!_run_one}, which would keep [result] live as a stack root across
    the [Gc.compact] call. See
    [dev/notes/bayesian-int-rounding-bug-2026-05-19.md]. *)
let[@inline never] _extract_fold ~fixtures_root ~bar_data_source
    (s : Scenario.t) : Report.fold_actual =
  let resolved = Filename.concat fixtures_root s.universe_path in
  let sector_map_override =
    Universe_file.to_sector_map_override (Universe_file.load resolved)
  in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ~strategy_choice:s.strategy
      ?slippage_bps:s.slippage_bps ?bar_data_source ()
  in
  let summary = result.summary in
  let get k = Map.find summary.metrics k |> Option.value ~default:Float.nan in
  let total_return =
    (summary.final_portfolio_value -. summary.initial_cash)
    /. summary.initial_cash *. 100.0
  in
  let test_days = _test_days s.period in
  let open Trading_simulation_types.Metric_types in
  {
    Report.fold_name = "";
    variant_label = "";
    total_return_pct = total_return;
    sharpe_ratio = get SharpeRatio;
    max_drawdown_pct = get MaxDrawdown;
    calmar_ratio = get CalmarRatio;
    cagr_pct = WFR.cagr_pct ~test_days ~total_return_pct:total_return;
    avg_holding_days = get AvgHoldingDays;
  }

let _run_one ~fixtures_root ~bar_data_source (s : Scenario.t) :
    Report.fold_actual =
  let fold = _extract_fold ~fixtures_root ~bar_data_source s in
  (* Partial bandaid for cumulative-state OOM (2026-05-19): each
     [Backtest.Runner.run_backtest] call leaks ~90 MB to the OCaml major
     heap. Forcing [Gc.compact] here reduces that to ~25 MB/backtest by
     reclaiming the transient ~65 MB that's actually unreachable. The
     remaining 25 MB is a genuine reference leak (not collectible by GC)
     whose root cause is unidentified — see
     dev/notes/bayesian-int-rounding-bug-2026-05-19.md §"Root cause
     identified 2026-05-19 PM". The complete fix is fork-per-fold (plan
     PR #1197); with that landed, even at parallel=1 each backtest runs
     in a child whose exit reclaims the leak, so this [Gc.compact] can
     be removed. *)
  Stdlib.Gc.compact ();
  fold

(** Emit one progress event for the given (variant, fold) pair. *)
let _call_progress ~progress ~(variant : WFR.variant) ~(fold : WS.fold) =
  progress ~variant_label:variant.label ~fold_name:fold.name
    ~test_start:fold.test_period.start_date ~test_end:fold.test_period.end_date

(** Build the (per-pair) job closure. The closure is what {!Fork_pool} either
    invokes directly (parallel=1 fast path) or runs inside a forked child
    (parallel>1). To stay safe under fork, the closure captures only the inputs
    it needs — no parent-process mutable state.

    The [emit_progress_inside_job] flag controls when [progress] fires. When
    [true] (parallel=1 fast path), the callback runs inside the closure
    immediately before [run_one] — preserving the original live-stderr trail the
    operator saw. When [false] (parallel>1), progress is emitted up-front in the
    parent before any forks so the schedule appears in a deterministic order
    regardless of child completion ordering. *)
let _build_pair_job ~(run_one : fold_runner) ~base ~(fold : WS.fold)
    ~(variant : WFR.variant) ~progress ~emit_progress_inside_job :
    unit -> Report.fold_actual =
 fun () ->
  if emit_progress_inside_job then _call_progress ~progress ~variant ~fold;
  let scenario = WFR.build_fold_scenario ~base ~fold ~variant in
  let actual_no_tag = run_one scenario in
  { actual_no_tag with fold_name = fold.name; variant_label = variant.label }

(** Emit one progress event per (variant, fold) pair. Called once up-front in
    the parent before any forks so the operator sees the full schedule even when
    forks run out-of-order in the child processes. *)
let _emit_progress ~progress ~variants ~folds =
  List.iter variants ~f:(fun variant ->
      List.iter folds ~f:(fun fold -> _call_progress ~progress ~variant ~fold))

(** Build the flat job array indexed by [variant_idx * n_folds + fold_idx].
    Order is canonical (variants outer, folds inner) so the array read-back
    after [Fork_pool.run_parallel] is already in
    {!Walk_forward_report.compute}'s expected shape — no Hashtbl reassembly
    required. *)
let _build_job_array ~run_one ~base ~variants ~folds ~progress
    ~emit_progress_inside_job : (unit -> Report.fold_actual) array =
  let n_folds = List.length folds in
  let n_variants = List.length variants in
  let variants_arr = Array.of_list variants in
  let folds_arr = Array.of_list folds in
  Array.init (n_variants * n_folds) ~f:(fun i ->
      let vi = i / n_folds in
      let fi = i mod n_folds in
      _build_pair_job ~run_one ~base ~fold:folds_arr.(fi)
        ~variant:variants_arr.(vi) ~progress ~emit_progress_inside_job)

let _evaluate_all ~run_one ~base ~(spec : Spec.t) ~progress ~parallel =
  let folds = WS.generate spec.window_spec in
  (* parallel=1 keeps the original live-stderr progress trail; parallel>1
     emits up-front because child processes can't share the parent's
     deterministic schedule otherwise. *)
  let emit_progress_inside_job = parallel = 1 in
  if not emit_progress_inside_job then
    _emit_progress ~progress ~variants:spec.variants ~folds;
  let jobs =
    _build_job_array ~run_one ~base ~variants:spec.variants ~folds ~progress
      ~emit_progress_inside_job
  in
  let results = Fork_pool.run_parallel ~parallel ~jobs in
  Array.to_list results

let execute_spec ~base ~(spec : Spec.t) ~fixtures_root
    ?(progress = noop_progress) ?(parallel = 1) ?bar_data_source ?run_one () :
    result =
  let run_one =
    match run_one with
    | Some f -> f
    | None -> _run_one ~fixtures_root ~bar_data_source
  in
  let fold_actuals = _evaluate_all ~run_one ~base ~spec ~progress ~parallel in
  let aggregate =
    Report.compute ~baseline_label:spec.baseline_label ~gate:spec.gate
      ~fold_actuals
  in
  { fold_actuals; aggregate }
