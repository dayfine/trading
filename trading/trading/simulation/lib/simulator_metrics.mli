(** Metric helpers for the simulator's result builders — extracted from
    [simulator.ml] to keep that coordinator under the file-length limit. Pure
    folds over the configured metric computers, plus the per-step benchmark
    return. *)

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

val benchmark_return :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  benchmark_symbol:string option ->
  date:Core.Date.t ->
  float option
(** [benchmark_return ~adapter ~benchmark_symbol ~date] is the configured
    benchmark's percentage change into [date], computed from [adjusted_close] so
    splits and dividends do not show up as returns. [None] when no benchmark is
    configured, when either bar is missing, or when the prior close is
    non-positive. Populates [step_result.benchmark_return], which the
    antifragility computer reads. *)
