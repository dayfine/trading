(** Portfolio types and position management *)

open Core
open Trading_base.Types

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
  cash : cash;
  positions : (symbol, portfolio_position) Hashtbl.t;
  realized_pnl : realized_pnl;
  created_at : Time_ns_unix.t;
  updated_at : Time_ns_unix.t;
}
(** Portfolio containing cash, positions, and P&L *)
