(** Portfolio manager for handling portfolio state and order integration *)

open Trading_base.Types
open Trading_orders.Types
open Types

type portfolio_manager
(** Opaque type representing a portfolio management system *)

val create : cash -> portfolio_manager
(** Create a new portfolio manager with initial cash balance *)

val get_portfolio : portfolio_manager -> portfolio
(** Get the current portfolio state *)

val apply_order_execution : portfolio_manager -> order -> portfolio_manager
(** Apply an executed order to update portfolio positions and cash *)

val check_buying_power : portfolio_manager -> order -> bool
(** Check if portfolio has sufficient cash/position for an order *)

val get_position : portfolio_manager -> symbol -> portfolio_position option
(** Get position for a specific symbol *)

val list_positions : portfolio_manager -> portfolio_position list
(** List all positions in the portfolio *)
