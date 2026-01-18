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
}
(** External dependencies injected into the simulator. The simulator lazily
    loads price data from CSV storage and executes the strategy on each step. *)

(** {1 Simulator Types} *)

type t
(** Abstract simulator type *)

type step_result = {
  date : Date.t;  (** The date this step executed on *)
  portfolio : Trading_portfolio.Portfolio.t;  (** Portfolio state after step *)
  trades : Trading_base.Types.trade list;
      (** Trades executed during this step (empty if no orders filled) *)
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

val submit_orders : t -> Trading_orders.Types.order list -> Status.status list
(** Submit orders to the simulator. Orders will be processed in the next step.
*)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. Returns [Completed] when simulation reaches
    end date, or [Stepped] with updated simulator and step result. *)

val run :
  t -> (step_result list * Trading_portfolio.Portfolio.t) Status.status_or
(** Run the full simulation from start to end date. Returns list of step results
    and final portfolio. *)
