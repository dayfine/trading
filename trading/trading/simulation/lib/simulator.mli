(** Simulation engine for backtesting trading strategies *)

(** {1 Re-exported Types}

    These types are defined in {!Simulator_types} and re-exported here for
    convenience. *)

type config = Simulator_types.config = {
  start_date : Core.Date.t;
  end_date : Core.Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]
(** Configuration for running a simulation *)

type step_result = Simulator_types.step_result = {
  date : Core.Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  portfolio_value : float;
  trades : Trading_base.Types.trade list;
  orders_submitted : Trading_orders.Types.order list;
}
[@@deriving show, eq]
(** Result of a single simulation step *)

type run_result = Simulator_types.run_result = {
  steps : step_result list;
  final_portfolio : Trading_portfolio.Portfolio.t;
  metrics : Metric_types.metric_set;
}
(** Complete result of running a simulation with metrics *)

type 'state metric_computer = 'state Simulator_types.metric_computer = {
  name : string;
  init : config:config -> 'state;
  update : state:'state -> step:step_result -> 'state;
  finalize : state:'state -> config:config -> Metric_types.metric list;
}
(** A metric computer that folds over simulation steps to produce metrics. *)

type any_metric_computer = Simulator_types.any_metric_computer = {
  run : config:config -> steps:step_result list -> Metric_types.metric list;
}
(** Type-erased wrapper for heterogeneous collections of metric computers *)

val wrap_computer : 'state metric_computer -> any_metric_computer
(** Wrap a typed metric computer for use in heterogeneous collections *)

(** {1 Simulator Types} *)

type t
(** Abstract simulator type *)

type step_outcome =
  | Stepped of t * step_result  (** Simulation advanced one step *)
  | Completed of run_result  (** Simulation complete with final results *)

(** {1 Dependencies} *)

type dependencies = {
  symbols : string list;  (** Watchlist of symbols to track *)
  data_dir : Fpath.t;  (** Directory containing CSV price files *)
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
      (** Trading strategy to run on each step *)
  engine : Trading_engine.Engine.t;  (** Trade execution engine *)
  order_manager : Trading_orders.Manager.order_manager;  (** Order manager *)
  market_data_adapter : Market_data_adapter.t;  (** Market data provider *)
  computers : any_metric_computer list;  (** Metric computers to use *)
}
(** External dependencies injected into the simulator. *)

val create_deps :
  symbols:string list ->
  data_dir:Fpath.t ->
  strategy:(module Trading_strategy.Strategy_interface.STRATEGY) ->
  commission:Trading_engine.Types.commission_config ->
  ?computers:any_metric_computer list ->
  unit ->
  dependencies
(** Create standard dependencies with default engine, order manager, and
    adapter. Use this for the common case; inject custom components directly
    into the dependencies record for testing.

    @param computers
      Metric computers to use. If not specified, no metrics are computed. *)

(** {1 Creation} *)

val create : config:config -> deps:dependencies -> t
(** Create a simulator from config and dependencies.

    @param config Simulation configuration (dates, cash, commission)
    @param deps External dependencies (symbols, data directory, strategy) *)

(** {1 Running} *)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. Returns [Completed] when simulation reaches
    end date, or [Stepped] with updated simulator and step result. *)

val run : t -> run_result Status.status_or
(** Run the full simulation from start to end date. Returns run_result with
    steps, final portfolio, and computed metrics. *)

val get_config : t -> config
(** Get the config from a simulator. Useful for metric computers that need
    access to simulation parameters. *)
