open Core
open Trading_simulation_types.Simulator_types

let compute_base ~computers ~config ~steps =
  List.fold computers ~init:Trading_simulation_types.Metric_types.empty
    ~f:(fun acc (computer : any_metric_computer) ->
      Trading_simulation_types.Metric_types.merge acc
        (computer.run ~config ~steps))

let compute_derived ~derived_computers ~config ~base_metrics =
  List.fold derived_computers ~init:base_metrics
    ~f:(fun acc (dc : derived_metric_computer) ->
      Trading_simulation_types.Metric_types.merge acc
        (dc.compute ~config ~base_metrics:acc))
