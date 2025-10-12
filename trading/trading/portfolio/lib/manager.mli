(** Portfolio manager for handling multiple portfolios and order integration *)

open Trading_base.Types
open Trading_orders.Types
open Types

type portfolio_manager
(** Opaque type representing a portfolio management system *)

val create : unit -> portfolio_manager
(** Create a new portfolio manager instance *)

val create_portfolio : portfolio_manager -> portfolio_id -> cash -> portfolio_id
(** Create a new portfolio with initial cash balance *)

val get_portfolio : portfolio_manager -> portfolio_id -> portfolio option
(** Retrieve a portfolio by ID *)

val list_portfolios : portfolio_manager -> portfolio list
(** List all managed portfolios *)

val apply_order_execution : portfolio_manager -> portfolio_id -> order -> portfolio_manager
(** Apply an executed order to update portfolio positions and cash *)

val check_buying_power : portfolio_manager -> portfolio_id -> order -> bool
(** Check if portfolio has sufficient cash for an order *)

val get_portfolio_value : portfolio_manager -> portfolio_id -> (symbol * price) list -> float option
(** Calculate total portfolio value with current market prices *)

val update_market_prices : portfolio_manager -> (symbol * price) list -> portfolio_manager
(** Update market prices for all portfolios *)

val get_cash_balance : portfolio_manager -> portfolio_id -> cash option
(** Get cash balance for a specific portfolio *)

val transfer_cash : portfolio_manager -> portfolio_id -> cash -> portfolio_manager
(** Add or remove cash from a portfolio *)

val get_position : portfolio_manager -> portfolio_id -> symbol -> portfolio_position option
(** Get position for a specific symbol in a portfolio *)

val list_positions : portfolio_manager -> portfolio_id -> portfolio_position list
(** List all positions in a portfolio *)

val calculate_total_pnl : portfolio_manager -> portfolio_id -> (symbol * price) list -> (realized_pnl * unrealized_pnl) option
(** Calculate total realized and unrealized P&L for a portfolio *)