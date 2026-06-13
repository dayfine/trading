(** Metric aggregation helpers for the simulator's [_build_run_result] —
    extracted from [simulator.ml] to keep that coordinator under the file-length
    limit. Pure folds over the configured metric computers. *)

open Trading_simulation_types.Simulator_types

val compute_base :
  computers:any_metric_computer list ->
  config:config ->
  steps:step_result list ->
  Trading_simulation_types.Metric_types.metric_set
(** Run every step-based computer over [steps] and merge their metric sets,
    seeded from {!Trading_simulation_types.Metric_types.empty}. *)

val compute_derived :
  derived_computers:derived_metric_computer list ->
  config:config ->
  base_metrics:Trading_simulation_types.Metric_types.metric_set ->
  Trading_simulation_types.Metric_types.metric_set
(** Fold the derived computers over [base_metrics] in list order — callers must
    pre-sort by dependency. *)
