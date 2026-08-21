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

let benchmark_return ~adapter ~benchmark_symbol ~date =
  let%bind.Option symbol = benchmark_symbol in
  let%bind.Option curr =
    Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol ~date
  in
  let%bind.Option prev =
    Trading_simulation_data.Market_data_adapter.get_previous_bar adapter ~symbol
      ~date
  in
  let prev_close = prev.Types.Daily_price.adjusted_close in
  if Float.(prev_close <= 0.0) then None
  else
    let curr_close = curr.Types.Daily_price.adjusted_close in
    Some ((curr_close -. prev_close) /. prev_close *. 100.0)
