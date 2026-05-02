(** Core types for the simulation engine. *)

open Core

(** {1 Configuration} *)

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
  strategy_cadence : Types.Cadence.t;
}
[@@deriving show, eq]

(** {1 Step Result} *)

type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  portfolio_value : float;
  trades : Trading_base.Types.trade list;
  orders_submitted : Trading_orders.Types.order list;
  splits_applied : Trading_portfolio.Split_event.t list;
  benchmark_return : float option;
}
[@@deriving show, eq]

(** {1 Run Result} *)

type run_result = {
  steps : step_result list;  (** Non-empty list of step results *)
  metrics : Metric_types.metric_set;
}

(** {1 Metric Computer Abstraction} *)

type 'state metric_computer = {
  name : string;
  init : config:config -> 'state;
  update : state:'state -> step:step_result -> 'state;
  finalize : state:'state -> config:config -> Metric_types.metric_set;
}

type any_metric_computer = {
  run : config:config -> steps:step_result list -> Metric_types.metric_set;
}

let wrap_computer (type s) (computer : s metric_computer) : any_metric_computer
    =
  {
    run =
      (fun ~config ~steps ->
        let state = computer.init ~config in
        let final_state =
          List.fold steps ~init:state ~f:(fun state step ->
              computer.update ~state ~step)
        in
        computer.finalize ~state:final_state ~config);
  }

(** {1 Derived Metric Computers} *)

type derived_metric_computer = {
  name : string;
  depends_on : Metric_types.metric_type list;
  compute :
    config:config ->
    base_metrics:Metric_types.metric_set ->
    Metric_types.metric_set;
}

type metric_suite = {
  computers : any_metric_computer list;
  derived : derived_metric_computer list;
}
