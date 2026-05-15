(** Walk-forward CV runner — wires [Window_spec] + [Walk_forward_runner] +
    [Walk_forward_report] to {!Backtest.Runner.run_backtest} via the same
    per-scenario invocation pattern used by
    {!Tuner_bin.Bayesian_runner_evaluator.build}.

    Reads a top-level sexp spec describing:
    - [base_scenario] — path to the base scenario sexp file
    - [window_spec] — {!Walk_forward.Window_spec.t}
    - [variants] — list of {!Walk_forward.Walk_forward_runner.variant}
    - [baseline_label] — which variant is the baseline for the report
    - [gate] — {!Walk_forward.Fold_gate.t}

    Writes [walk_forward_report.md] and [fold_actuals.sexp] under [--out-dir].

    Usage:
    {v
      walk_forward_runner.exe --spec <spec.sexp> --out-dir <dir>
                              [--fixtures-root <path>]
    v}

    This binary is the integration seam for Phase 3: the Bayesian optimizer
    consumes the same harness with variant-overrides chosen by the BO loop
    instead of hard-coded in the spec. *)

open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Fixtures_root = Scenario_lib.Fixtures_root
module WS = Walk_forward.Window_spec
module WFR = Walk_forward.Walk_forward_runner
module FG = Walk_forward.Fold_gate
module Report = Walk_forward.Walk_forward_report
module Spec = Walk_forward.Spec

(* -------------- argument parsing -------------- *)

type cli_args = {
  spec_path : string;
  out_dir : string;
  fixtures_root : string option;
}

let _usage_msg =
  "Usage: walk_forward_runner.exe --spec <spec.sexp> --out-dir <dir> \
   [--fixtures-root <path>]"

let _parse_args argv =
  let rec loop spec out fixtures = function
    | [] -> (
        match (spec, out) with
        | Some s, Some o ->
            { spec_path = s; out_dir = o; fixtures_root = fixtures }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--spec" :: p :: rest -> loop (Some p) out fixtures rest
    | "--out-dir" :: p :: rest -> loop spec (Some p) fixtures rest
    | "--fixtures-root" :: p :: rest -> loop spec out (Some p) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None argv

(* -------------- per-scenario evaluation -------------- *)

(** Number of calendar days inclusive between [start_date] and [end_date]. *)
let _test_days (period : Scenario.period) =
  Date.diff period.end_date period.start_date + 1

(** Run a single scenario via [Backtest.Runner.run_backtest], in process —
    mirrors the per-suggestion shape used by
    {!Tuner_bin.Bayesian_runner_evaluator}. *)
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
    (* filled by caller — see _evaluate_one_pair *)
    variant_label = "";
    total_return_pct = total_return;
    sharpe_ratio = get SharpeRatio;
    max_drawdown_pct = get MaxDrawdown;
    calmar_ratio = get CalmarRatio;
    cagr_pct = WFR.cagr_pct ~test_days ~total_return_pct:total_return;
  }

(** Tag a per-(variant, fold) actual with the metadata the renderer needs. *)
let _evaluate_one_pair ~fixtures_root ~base ~(fold : WS.fold)
    ~(variant : WFR.variant) =
  let scenario = WFR.build_fold_scenario ~base ~fold ~variant in
  let actual_no_tag = _run_one ~fixtures_root scenario in
  { actual_no_tag with fold_name = fold.name; variant_label = variant.label }

(** Evaluate the full grid of (variant x fold) — sequential. Parallel execution
    is a follow-up; mirrors [Scenario_runner._run_scenarios_parallel] when
    wall-time demands it. *)
let _evaluate_all ~fixtures_root ~base ~(spec : Spec.t) =
  let folds = WS.generate spec.window_spec in
  List.concat_map spec.variants ~f:(fun variant ->
      List.map folds ~f:(fun fold ->
          eprintf "[walk_forward] running variant=%s fold=%s [%s..%s]\n%!"
            variant.label fold.name
            (Date.to_string fold.test_period.start_date)
            (Date.to_string fold.test_period.end_date);
          _evaluate_one_pair ~fixtures_root ~base ~fold ~variant))

(* -------------- output writers -------------- *)

let _write_report ~out_dir ~(spec : Spec.t)
    (fold_actuals : Report.fold_actual list) =
  let md =
    Report.render ~baseline_label:spec.baseline_label ~gate:spec.gate
      ~fold_actuals
  in
  let path = Filename.concat out_dir "walk_forward_report.md" in
  Out_channel.write_all path ~data:md;
  eprintf "[walk_forward] wrote %s\n%!" path

let _write_fold_actuals ~out_dir (fold_actuals : Report.fold_actual list) =
  let sexp = Sexp.List (List.map fold_actuals ~f:Report.sexp_of_fold_actual) in
  let path = Filename.concat out_dir "fold_actuals.sexp" in
  Sexp.save_hum path sexp;
  eprintf "[walk_forward] wrote %s\n%!" path

(** Persist the structured aggregate so Phase 3 (Bayesian optimizer) can consume
    it directly without parsing the markdown report. *)
let _write_aggregate ~out_dir ~(spec : Spec.t)
    (fold_actuals : Report.fold_actual list) =
  let agg =
    Report.compute ~baseline_label:spec.baseline_label ~gate:spec.gate
      ~fold_actuals
  in
  let path = Filename.concat out_dir "aggregate.sexp" in
  Sexp.save_hum path (Report.sexp_of_aggregate agg);
  eprintf "[walk_forward] wrote %s\n%!" path

(* -------------- main -------------- *)

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let spec = Spec.load args.spec_path in
  Core_unix.mkdir_p args.out_dir;
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let base = Scenario.load spec.base_scenario in
  eprintf "[walk_forward] spec=%s base=%s baseline=%s variants=%d folds=%d\n%!"
    args.spec_path spec.base_scenario spec.baseline_label
    (List.length spec.variants)
    (List.length (WS.generate spec.window_spec));
  let fold_actuals = _evaluate_all ~fixtures_root ~base ~spec in
  _write_fold_actuals ~out_dir:args.out_dir fold_actuals;
  _write_report ~out_dir:args.out_dir ~spec fold_actuals;
  _write_aggregate ~out_dir:args.out_dir ~spec fold_actuals;
  eprintf "[walk_forward] done\n%!"

let () = _main ()
