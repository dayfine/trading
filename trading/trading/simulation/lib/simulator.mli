(** Simulation engine for backtesting trading strategies.

    Core types are defined in {!Simulator_types} and included here. *)

include module type of Trading_simulation_types.Simulator_types

(** {1 Simulator} *)

type t
(** Abstract simulator type *)

type step_outcome =
  | Stepped of t * step_result  (** Simulation advanced one step *)
  | Completed of run_result  (** Simulation complete with final results *)

(** {1 Dependencies} *)

type dependencies = {
  symbols : string list;
  data_dir : Fpath.t;
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
  engine : Trading_engine.Engine.t;
  order_manager : Trading_orders.Manager.order_manager;
  market_data_adapter : Trading_simulation_data.Market_data_adapter.t;
  computers : any_metric_computer list;
  strategy_cadence : Types.Cadence.t;
      (** How often to call the strategy. [Daily] (default) calls every step.
          [Weekly] calls only on Fridays. [Monthly] calls only on the last day
          of each month. Non-strategy days still process pending orders and fill
          existing orders against intraday price paths. *)
}

val create_deps :
  symbols:string list ->
  data_dir:Fpath.t ->
  strategy:(module Trading_strategy.Strategy_interface.STRATEGY) ->
  commission:Trading_engine.Types.commission_config ->
  ?strategy_cadence:Types.Cadence.t ->
  ?computers:any_metric_computer list ->
  unit ->
  dependencies
(** Create standard dependencies with default engine, order manager, and
    adapter.

    @param strategy_cadence
      How often to call the strategy. Default: [Daily] (every step). Use
      [Weekly] for the Weinstein system (Friday close calls only). *)

(** {1 Creation} *)

val create : config:config -> deps:dependencies -> t Status.status_or
(** Create a simulator. Returns error if end_date <= start_date. *)

(** {1 Running} *)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. *)

val run : t -> run_result Status.status_or
(** Run the full simulation from start to end date. *)

val get_config : t -> config
