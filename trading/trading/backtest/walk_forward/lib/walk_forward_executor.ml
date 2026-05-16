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

let noop_progress ~variant_label:_ ~fold_name:_ ~test_start:_ ~test_end:_ = ()

(** Number of calendar days inclusive between [start_date] and [end_date]. *)
let _test_days (period : Scenario.period) =
  Date.diff period.end_date period.start_date + 1

(** Run a single scenario via {!Backtest.Runner.run_backtest} and project its
    summary metrics into a {!Report.fold_actual}. The [fold_name] and
    [variant_label] fields are filled by the caller — {!_evaluate_one_pair}. *)
let _run_one ~fixtures_root (s : Scenario.t) : Report.fold_actual =
  let resolved = Filename.concat fixtures_root s.universe_path in
  let sector_map_override =
    Universe_file.to_sector_map_override (Universe_file.load resolved)
  in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:s.config_overrides
      ?sector_map_override ~strategy_choice:s.strategy
      ?slippage_bps:s.slippage_bps ()
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
    fold_name = "";
    variant_label = "";
    total_return_pct = total_return;
    sharpe_ratio = get SharpeRatio;
    max_drawdown_pct = get MaxDrawdown;
    calmar_ratio = get CalmarRatio;
    cagr_pct = WFR.cagr_pct ~test_days ~total_return_pct:total_return;
  }

let _evaluate_one_pair ~fixtures_root ~base ~(fold : WS.fold)
    ~(variant : WFR.variant) ~(progress : progress_callback) =
  progress ~variant_label:variant.label ~fold_name:fold.name
    ~test_start:fold.test_period.start_date ~test_end:fold.test_period.end_date;
  let scenario = WFR.build_fold_scenario ~base ~fold ~variant in
  let actual_no_tag = _run_one ~fixtures_root scenario in
  { actual_no_tag with fold_name = fold.name; variant_label = variant.label }

let _evaluate_all ~fixtures_root ~base ~(spec : Spec.t) ~progress =
  let folds = WS.generate spec.window_spec in
  List.concat_map spec.variants ~f:(fun variant ->
      List.map folds ~f:(fun fold ->
          _evaluate_one_pair ~fixtures_root ~base ~fold ~variant ~progress))

let execute_spec ~base ~(spec : Spec.t) ~fixtures_root
    ?(progress = noop_progress) () : result =
  let fold_actuals = _evaluate_all ~fixtures_root ~base ~spec ~progress in
  let aggregate =
    Report.compute ~baseline_label:spec.baseline_label ~gate:spec.gate
      ~fold_actuals
  in
  { fold_actuals; aggregate }
