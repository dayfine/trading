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
  strategy_cadence : Types.Cadence.t;
      (** How often to call the strategy. [Daily] calls every step. [Weekly]
          calls only on Fridays. [Monthly] calls only on the last trading day of
          each month. Non-strategy days still process pending orders. *)
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
  splits_applied : Trading_portfolio.Split_event.t list;
      (** Split events detected and applied to held positions at the start of
          this step, in detection order. Empty on non-split days (the common
          case). Used for diagnostics and parity checks. *)
  benchmark_return : float option;
      (** Benchmark per-step percent return for this date, if a benchmark symbol
          was configured on [dependencies] and a prior bar exists for it.
          Computed as
          [(today.adjusted_close - prev.adjusted_close) / prev.adjusted_close *
           100.0] from the market data adapter. [None] when no benchmark is
          configured, when the benchmark has no bar for [date]
          (weekend/holiday/missing data), or when there is no prior bar (the
          first appearance of the benchmark in the simulation window). The
          antifragility computer reads this field per step to assemble its
          benchmark series. *)
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
  finalize : state:'state -> config:config -> Metric_types.metric_set;
      (** Produce final metrics from accumulated state *)
}
(** A metric computer that folds over simulation steps to produce metrics. *)

type any_metric_computer = {
  run : config:config -> steps:step_result list -> Metric_types.metric_set;
}
(** Type-erased wrapper for heterogeneous collections of metric computers *)

val wrap_computer : 'state metric_computer -> any_metric_computer
(** Wrap a typed metric computer for use in heterogeneous collections *)

(** {1 Derived Metric Computers} *)

type derived_metric_computer = {
  name : string;
  depends_on : Metric_types.metric_type list;
      (** Metrics that must be computed before this one. *)
  compute :
    config:config ->
    base_metrics:Metric_types.metric_set ->
    Metric_types.metric_set;
      (** Produce derived metrics from the base metric set. *)
}
(** A metric computed from other metrics, not from simulation steps. The
    simulator runs these after all step-based computers, in dependency order. *)

type metric_suite = {
  computers : any_metric_computer list;
  derived : derived_metric_computer list;
}
(** Bundle of step-based and derived metric computers. *)
