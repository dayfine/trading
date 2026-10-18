(** Output writers for the [bayesian_runner] BO loop: [bo_log.csv], [best.sexp]
    and [convergence.md]. Split out of {!Bayesian_runner_runner}; pure file
    emission, no BO state. *)

val write_bo_log :
  output_path:string ->
  spec:Bayesian_runner_spec.t ->
  objective:Tuner.Grid_search.objective ->
  observations:Tuner.Bayesian_opt.observation list ->
  per_iteration_metrics:
    Trading_simulation_types.Metric_types.metric_set list list ->
  unit
(** Write one CSV row per (iteration, scenario): params, all metrics, objective.
*)

val write_best_sexp :
  ?int_keys:string list ->
  output_path:string ->
  best_params:(string * float) list ->
  unit ->
  unit
(** Write the best parameters as a list of config-override sexps. *)

val write_convergence_md :
  output_path:string ->
  objective:Tuner.Grid_search.objective ->
  observations:Tuner.Bayesian_opt.observation list ->
  tail:string ->
  unit
(** Write the running-best convergence table followed by [tail] verbatim. *)
