open Core
module BO = Tuner.Bayesian_opt
module GS = Tuner.Grid_search

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

let write_bo_log ~output_path ~spec ~objective ~observations
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

let write_best_sexp ?(int_keys = []) ~output_path ~best_params () =
  let sexps = GS.cell_to_overrides ~int_keys best_params in
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

let write_convergence_md ~output_path ~objective ~observations ~tail =
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc (_convergence_title objective);
      _write_convergence_rows oc observations;
      Out_channel.output_string oc tail)
