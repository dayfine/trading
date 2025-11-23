(** Simulation module types *)

open Core

type symbol_prices = {
  symbol : string;
  prices : Types.Daily_price.t list;  (** sorted by date, ascending *)
}
[@@deriving show, eq]
(** Historical price data for a single symbol *)

type simulation_config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  symbols : string list;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]
(** Configuration for running a simulation *)
