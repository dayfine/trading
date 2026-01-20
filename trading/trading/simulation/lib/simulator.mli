(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Input Types} *)

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]
(** Configuration for running a simulation *)

type dependencies = {
  symbols : string list;  (** Watchlist of symbols to track *)
  data_dir : Fpath.t;  (** Directory containing CSV price files *)
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
      (** Trading strategy to run on each step *)
  engine : Trading_engine.Engine.t;  (** Trade execution engine *)
  order_manager : Trading_orders.Manager.order_manager;  (** Order manager *)
  market_data_adapter : Market_data_adapter.t;  (** Market data provider *)
}
(** External dependencies injected into the simulator. The simulator lazily
    loads price data from CSV storage and executes the strategy on each step. *)

val create_deps :
  symbols:string list ->
  data_dir:Fpath.t ->
  strategy:(module Trading_strategy.Strategy_interface.STRATEGY) ->
  commission:Trading_engine.Types.commission_config ->
  dependencies
(** Create standard dependencies with default engine, order manager, and
    adapter. Use this for the common case; inject custom components directly
    into the dependencies record for testing. *)

(** {1 Simulator Types} *)

type t
(** Abstract simulator type *)

type step_result = {
  date : Date.t;  (** The date this step executed on *)
  portfolio : Trading_portfolio.Portfolio.t;  (** Portfolio state after step *)
  trades : Trading_base.Types.trade list;
      (** Trades from orders that filled during this step *)
  orders_submitted : Trading_orders.Types.order list;
      (** Orders submitted for execution on the next step *)
}
[@@deriving show, eq]
(** Result of a single simulation step *)

type step_outcome =
  | Stepped of t * step_result
  | Completed of Trading_portfolio.Portfolio.t
      (** Outcome of calling step - either advanced or simulation complete *)

(** {1 Creation} *)

val create : config:config -> deps:dependencies -> t
(** Create a simulator from config and dependencies.

    @param config Simulation configuration (dates, cash, commission)
    @param deps External dependencies (symbols, data directory, strategy) *)

(** {1 Running} *)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. Returns [Completed] when simulation reaches
    end date, or [Stepped] with updated simulator and step result. *)

val run :
  t -> (step_result list * Trading_portfolio.Portfolio.t) Status.status_or
(** Run the full simulation from start to end date. Returns list of step results
    and final portfolio. *)
