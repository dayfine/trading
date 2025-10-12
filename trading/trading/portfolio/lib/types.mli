(** Portfolio types and position management *)

open Core
open Trading_base.Types

type portfolio_id = string [@@deriving show, eq]
(** Unique identifier for a portfolio *)

type cash = float [@@deriving show, eq]
(** Cash balance in the portfolio *)

type realized_pnl = float [@@deriving show, eq]
(** Realized profit and loss from closed positions *)

type unrealized_pnl = float [@@deriving show, eq]
(** Unrealized profit and loss from open positions *)

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;
  avg_cost : price;
  market_value : price option;
  unrealized_pnl : unrealized_pnl;
}
[@@deriving show, eq]
(** Extended position with cost basis and P&L tracking *)

type portfolio = {
  id : portfolio_id;
  cash : cash;
  positions : (symbol, portfolio_position) Hashtbl.t;
  realized_pnl : realized_pnl;
  created_at : Time_ns_unix.t;
  updated_at : Time_ns_unix.t;
}
(** Portfolio containing cash, positions, and P&L *)

val create_portfolio : portfolio_id -> cash -> portfolio
(** Create a new portfolio with initial cash balance *)

val get_position : portfolio -> symbol -> portfolio_position option
(** Get position for a specific symbol *)

val update_position : portfolio -> symbol -> quantity -> price -> portfolio
(** Update position with new trade (quantity can be negative for sells) *)

val calculate_portfolio_value : portfolio -> (symbol * price) list -> float
(** Calculate total portfolio value given current market prices *)

val get_cash_balance : portfolio -> cash
(** Get current cash balance *)

val update_cash : portfolio -> cash -> portfolio
(** Update cash balance *)

val list_positions : portfolio -> portfolio_position list
(** List all positions in the portfolio *)

val is_long : portfolio_position -> bool
(** Check if position is long (quantity > 0) *)

val is_short : portfolio_position -> bool
(** Check if position is short (quantity < 0) *)

val position_market_value : portfolio_position -> float option
(** Get market value of a position if market price is available *)

val update_market_prices : portfolio -> (symbol * price) list -> portfolio
(** Update market prices for positions and recalculate unrealized P&L *)