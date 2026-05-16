open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types
module Wf_types = Walk_forward.Walk_forward_types
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_runner = Walk_forward.Walk_forward_runner

type scenario = Scenario.t

type t =
  parameters:(string * float) list -> float * Metric_types.metric_set list

(* ------------------------------------------------------------------ *)
(* Legacy per-scenario evaluator. Kept until PR-E flips the binary.    *)
(* ------------------------------------------------------------------ *)

let _sector_map_of_scenario ~fixtures_root (s : scenario) =
  let resolved = Filename.concat fixtures_root s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run_one ~fixtures_root (s : scenario) parameters =
  let cell_overrides = GS.cell_to_overrides parameters in
  let merged_overrides = s.config_overrides @ cell_overrides in
  let sector_map_override = _sector_map_of_scenario ~fixtures_root s in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:merged_overrides
      ?sector_map_override ~strategy_choice:s.strategy ()
  in
  result.summary.metrics

let _lookup_scenario scenarios_by_path path =
  match Hashtbl.find scenarios_by_path path with
  | Some s -> s
  | None ->
      failwithf
        "Bayesian_runner_evaluator: unknown scenario path %S (must be one of \
         the spec's [scenarios] entries)"
        path ()

let _mean = function
  | [] -> Float.neg_infinity
  | xs -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

let build ~fixtures_root ~scenarios ~scenarios_by_path ~objective : t =
 fun ~parameters ->
  let metric_sets =
    List.map scenarios ~f:(fun path ->
        let s = _lookup_scenario scenarios_by_path path in
        _run_one ~fixtures_root s parameters)
  in
  let scalars = List.map metric_sets ~f:(GS.evaluate_objective objective) in
  (_mean scalars, metric_sets)

(* ------------------------------------------------------------------ *)
(* Walk-forward evaluator (PR-C).                                      *)
(* ------------------------------------------------------------------ *)

type executor =
  base:Scenario.t ->
  spec:Walk_forward.Spec.t ->
  fixtures_root:string ->
  Wf_executor.result

let default_executor : executor =
 fun ~base ~spec ~fixtures_root ->
  Wf_executor.execute_spec ~base ~spec ~fixtures_root
    ~progress:Wf_executor.noop_progress ()

let _candidate_label_for_iter (iter : int) : string = sprintf "bo-iter-%d" iter

let _build_two_variant_spec ~(baseline_label : string)
    ~(candidate_label : string) ~(parameters : (string * float) list)
    ~(template : Walk_forward.Spec.t) : Walk_forward.Spec.t =
  let baseline : Wf_runner.variant =
    { label = baseline_label; overrides = [] }
  in
  let candidate : Wf_runner.variant =
    { label = candidate_label; overrides = GS.cell_to_overrides parameters }
  in
  { template with variants = [ baseline; candidate ] }

(** Project the candidate variant's per-metric stability stats into a
    [metric_set] for the [bo_log.csv] writer. Only the means are surfaced —
    stdev/min/max would require widening the writer's column set, which is
    PR-E's job. Missing variants are mapped to an empty metric_set rather than
    raising, so the diagnostic path stays usable even when the scorer rejects
    the cell. *)
let _stability_to_metric_set ~(label : string) (agg : Wf_types.aggregate) :
    Metric_types.metric_set =
  let stab_opt =
    List.find agg.stability ~f:(fun v -> String.equal v.variant_label label)
  in
  let empty = Map.empty (module Metric_types.Metric_type) in
  match stab_opt with
  | None -> empty
  | Some stab ->
      let pairs =
        [
          (Metric_types.SharpeRatio, stab.sharpe_ratio.mean);
          (Metric_types.MaxDrawdown, stab.max_drawdown_pct.mean);
          (Metric_types.CalmarRatio, stab.calmar_ratio.mean);
          (Metric_types.TotalReturnPct, stab.total_return_pct.mean);
          (Metric_types.CAGR, stab.cagr_pct.mean);
        ]
      in
      List.fold pairs ~init:empty ~f:(fun acc (k, v) ->
          Map.set acc ~key:k ~data:v)

let _score_or_fail ~candidate_label ~baseline_label ~candidate_aggregate
    ~baseline_aggregate ~parameters : float =
  let result =
    Bayesian_runner_scoring.score_cell ~parameters ~candidate_label
      ~baseline_label ~candidate_aggregate ~baseline_aggregate
  in
  match result with
  | Ok score -> score
  | Error err ->
      failwithf
        "Bayesian_runner_evaluator: score_cell failed for candidate %S: %s"
        candidate_label (Status.show err) ()

let build_walk_forward ~(executor : executor) ~(base : Scenario.t)
    ~(walk_forward_spec : Walk_forward.Spec.t)
    ~(baseline_aggregate : Wf_types.aggregate) ~(fixtures_root : string) () : t
    =
  let iter_counter = ref 0 in
  let baseline_label = walk_forward_spec.baseline_label in
  fun ~parameters ->
    let n = !iter_counter in
    iter_counter := n + 1;
    let candidate_label = _candidate_label_for_iter n in
    let spec =
      _build_two_variant_spec ~baseline_label ~candidate_label ~parameters
        ~template:walk_forward_spec
    in
    let result = executor ~base ~spec ~fixtures_root in
    let score =
      _score_or_fail ~candidate_label ~baseline_label
        ~candidate_aggregate:result.aggregate ~baseline_aggregate ~parameters
    in
    let metric_set =
      _stability_to_metric_set ~label:candidate_label result.aggregate
    in
    (score, [ metric_set ])
