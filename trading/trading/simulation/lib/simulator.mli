(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Input Types} *)

type symbol_prices = {
  symbol : string;
  prices : Types.Daily_price.t list;  (** sorted by date, ascending *)
}
[@@deriving show, eq]
(** Historical price data for a single symbol *)

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]
(** Configuration for running a simulation *)

type dependencies = { prices : symbol_prices list }
(** External dependencies injected into the simulator *)

(** {1 Simulator Types} *)

type t
(** Abstract simulator type *)

type step_result = {
  date : Date.t;  (** The date this step executed on *)
  portfolio : Trading_portfolio.Portfolio.t;  (** Portfolio state after step *)
  trades : Trading_base.Types.trade list;
      (** Trades executed during this step (empty if no orders filled) *)
}
(** Result of a single simulation step *)

type step_outcome =
  | Stepped of t * step_result
  | Completed of Trading_portfolio.Portfolio.t
      (** Outcome of calling step - either advanced or simulation complete *)

(** {1 Creation} *)

val create : config:config -> deps:dependencies -> t
(** Create a simulator from config and dependencies *)

(** {1 Running} *)

val step : t -> step_outcome Status.status_or
(** Advance simulation by one day. Returns [Completed] when simulation reaches
    end date, or [Stepped] with updated simulator and step result. *)

val run :
  t -> (step_result list * Trading_portfolio.Portfolio.t) Status.status_or
(** Run the full simulation from start to end date. Returns list of step results
    and final portfolio. *)
