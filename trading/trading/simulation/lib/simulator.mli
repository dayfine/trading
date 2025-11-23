(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Types} *)

type t
(** Abstract simulator type *)

type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  trades : Trading_base.Types.trade list;
}
(** Result of a single simulation step *)

type run_result = {
  steps : step_result list;
  final_portfolio : Trading_portfolio.Portfolio.t;
}
(** Result of a full simulation run *)

(** {1 Creation} *)

val create :
  config:Sim_types.simulation_config ->
  prices:Sim_types.symbol_prices list ->
  (t, Status.t) result
(** Create a simulator from config and historical prices. Returns error if
    config is invalid or prices are insufficient. *)

(** {1 Running} *)

val step : t -> (t * step_result, Status.t) result
(** Advance simulation by one day. Returns error if simulation is complete or an
    execution error occurs. *)

val run : t -> (run_result, Status.t) result
(** Run the full simulation from start to end date. Returns error if any step
    fails. *)

(** {1 Inspection} *)

val current_date : t -> Date.t
(** Get the current simulation date *)

val is_complete : t -> bool
(** Check if simulation has reached end date *)
