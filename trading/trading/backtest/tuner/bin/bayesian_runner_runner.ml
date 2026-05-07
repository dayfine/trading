open Core
module BO = Tuner.Bayesian_opt
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types

type result = {
  best_params : (string * float) list;
  best_score : float;
  observations : BO.observation list;
  per_iteration_metrics : Metric_types.metric_set list list;
}

type evaluator =
  parameters:(string * float) list -> float * Metric_types.metric_set list

(** {1 BO loop} *)

let _suggest spec bo =
  match spec.Bayesian_runner_spec.n_acquisition_candidates with
  | None -> BO.suggest_next bo
  | Some n -> BO.suggest_next_with_candidates bo ~n_candidates:n

(** Run the BO ask/tell loop, accumulating
    [(observation, per-scenario metric sets)] in evaluation order. *)
let _run_loop spec ~evaluator =
  let config = Bayesian_runner_spec.to_bo_config spec in
  let initial = BO.create config in
  let rec loop bo iters_left rev_obs rev_metrics =
    if iters_left <= 0 then (bo, List.rev rev_obs, List.rev rev_metrics)
    else
      let parameters = _suggest spec bo in
      let metric, per_scenario = evaluator ~parameters in
      let obs = { BO.parameters; metric } in
      let bo = BO.observe bo obs in
      loop bo (iters_left - 1) (obs :: rev_obs) (per_scenario :: rev_metrics)
  in
  loop initial spec.total_budget [] []

(** {1 Output writers} *)

let _all_metric_types = Backtest.Comparison.all_metric_types

let _format_metric_value metrics mt =
  match Map.find metrics mt with Some v -> sprintf "%.6f" v | None -> ""

let _quote_csv_field s =
  if
    String.exists s ~f:(fun c ->
        Char.equal c ',' || Char.equal c '"' || Char.equal c '\n')
  then "\"" ^ String.substr_replace_all s ~pattern:"\"" ~with_:"\"\"" ^ "\""
  else s

let _csv_line fields =
  String.concat ~sep:"," (List.map fields ~f:_quote_csv_field) ^ "\n"

let _csv_header ~param_keys ~objective =
  let metric_labels =
    List.map _all_metric_types ~f:Backtest.Comparison.metric_label
  in
  let objective_col = "objective_" ^ GS.objective_label objective in
  ("iter" :: param_keys) @ ("scenario" :: metric_labels) @ [ objective_col ]

let _csv_row ~iter ~scenario ~parameters ~metrics ~objective_value =
  let param_values = List.map parameters ~f:(fun (_, v) -> sprintf "%.17g" v) in
  let metric_values =
    List.map _all_metric_types ~f:(_format_metric_value metrics)
  in
  (sprintf "%d" iter :: param_values)
  @ (scenario :: metric_values)
  @ [ sprintf "%.6f" objective_value ]

let _write_bo_log ~output_path ~spec ~objective ~observations
    ~per_iteration_metrics =
  let param_keys = List.map spec.Bayesian_runner_spec.bounds ~f:fst in
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc
        (_csv_line (_csv_header ~param_keys ~objective));
      List.iteri (List.zip_exn observations per_iteration_metrics)
        ~f:(fun i ((obs : BO.observation), metric_sets) ->
          List.iter2_exn spec.scenarios metric_sets ~f:(fun scenario metrics ->
              let row =
                _csv_row ~iter:i ~scenario ~parameters:obs.parameters ~metrics
                  ~objective_value:obs.metric
              in
              Out_channel.output_string oc (_csv_line row))))

let _write_best_sexp ~output_path ~best_params =
  let sexps = GS.cell_to_overrides best_params in
  let combined = Sexp.List sexps in
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum combined);
      Out_channel.output_string oc "\n")

let _convergence_title objective =
  sprintf
    "# Convergence report (objective: `%s`)\n\n\
     Running-best objective across the BO ask/tell loop. The [score] column is \
     the metric for that iteration's suggestion; [running_best] is the best \
     score seen so far up to and including that iteration.\n\n\
     | Iter | Score | Running best |\n\
     |---|---|---|\n"
    (GS.objective_label objective)

(** Stream a running-best line per observation. *)
let _write_convergence_rows oc observations =
  let _running =
    List.foldi observations ~init:Float.neg_infinity ~f:(fun i running obs ->
        let new_running = Float.max running obs.BO.metric in
        Out_channel.output_string oc
          (sprintf "| %d | %.6f | %.6f |\n" i obs.metric new_running);
        new_running)
  in
  ()

let _write_convergence_md ~output_path ~objective ~observations =
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc (_convergence_title objective);
      _write_convergence_rows oc observations)

(** {1 Top-level} *)

let _result_of bo observations per_iteration_metrics =
  match BO.best bo with
  | Some best ->
      {
        best_params = best.parameters;
        best_score = best.metric;
        observations;
        per_iteration_metrics;
      }
  | None ->
      {
        best_params = [];
        best_score = Float.neg_infinity;
        observations;
        per_iteration_metrics;
      }

let run_and_write ~(spec : Bayesian_runner_spec.t) ~out_dir ~evaluator =
  Core_unix.mkdir_p out_dir;
  let objective = Bayesian_runner_spec.to_grid_objective spec.objective in
  let bo, observations, per_iteration_metrics = _run_loop spec ~evaluator in
  let result = _result_of bo observations per_iteration_metrics in
  let log_path = Filename.concat out_dir "bo_log.csv" in
  let best_path = Filename.concat out_dir "best.sexp" in
  let conv_path = Filename.concat out_dir "convergence.md" in
  _write_bo_log ~output_path:log_path ~spec ~objective ~observations
    ~per_iteration_metrics;
  _write_best_sexp ~output_path:best_path ~best_params:result.best_params;
  _write_convergence_md ~output_path:conv_path ~objective ~observations;
  result
