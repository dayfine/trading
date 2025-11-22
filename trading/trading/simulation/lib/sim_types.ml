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

type simulation_state = {
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  order_manager : Trading_orders.Manager.order_manager;
  engine : Trading_engine.Engine.t;
  price_history : symbol_prices list;
      (** accumulated price history for strategy lookback *)
}
(** Current state of a running simulation *)
