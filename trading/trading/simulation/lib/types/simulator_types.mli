(** Core types for the simulation engine.

    This module contains types shared between the simulator and metric
    computers, avoiding circular dependencies. *)

open Core

(** {1 Configuration} *)

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]
(** Configuration for running a simulation *)

(** {1 Step Result} *)

type step_result = {
  date : Date.t;  (** The date this step executed on *)
  portfolio : Trading_portfolio.Portfolio.t;  (** Portfolio state after step *)
  portfolio_value : float;
      (** Total portfolio value: cash + market value of all positions *)
  trades : Trading_base.Types.trade list;
      (** Trades from orders that filled during this step *)
  orders_submitted : Trading_orders.Types.order list;
      (** Orders submitted for execution on the next step *)
}
[@@deriving show, eq]
(** Result of a single simulation step *)

(** {1 Run Result} *)

type run_result = {
  steps : step_result list;
      (** Non-empty list of step results in chronological order. The final
          portfolio can be obtained from [(List.last_exn steps).portfolio]. *)
  metrics : Metric_types.metric_set;  (** Computed metrics from the simulation *)
}
(** Complete result of running a simulation with metrics *)

(** {1 Metric Computer Abstraction} *)

type 'state metric_computer = {
  name : string;  (** Identifier for this computer *)
  init : config:config -> 'state;  (** Create initial state from config *)
  update : state:'state -> step:step_result -> 'state;
      (** Update state with a simulation step *)
  finalize : state:'state -> config:config -> Metric_types.metric list;
      (** Produce final metrics from accumulated state *)
}
(** A metric computer that folds over simulation steps to produce metrics. *)

type any_metric_computer = {
  run : config:config -> steps:step_result list -> Metric_types.metric list;
}
(** Type-erased wrapper for heterogeneous collections of metric computers *)

val wrap_computer : 'state metric_computer -> any_metric_computer
(** Wrap a typed metric computer for use in heterogeneous collections *)
