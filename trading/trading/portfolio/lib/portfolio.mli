(** Portfolio management with immutable value type *)

open Trading_base.Types
open Status
open Types

type t = {
  initial_cash : cash_value;
  trade_history : trade_with_pnl list;
  current_cash : cash_value;
  positions : (symbol, portfolio_position) Core.Hashtbl.t;
  accounting_method : accounting_method;
}
(** Portfolio type. All fields are accessible for pattern matching and direct
    access. The portfolio is functionally immutable - [apply_trades] returns a
    new portfolio rather than modifying the existing one.

    Fields:
    - [initial_cash]: Starting cash balance
    - [trade_history]: Complete history of trades with realized P&L
    - [current_cash]: Current cash balance (derived from initial_cash and
      trades)
    - [positions]: Current positions indexed by symbol (copied on updates)
    - [accounting_method]: Cost basis accounting method (AverageCost or FIFO) *)

val create :
  ?accounting_method:accounting_method -> initial_cash:cash_value -> unit -> t
(** Create a new portfolio with initial cash balance and optional accounting
    method (default: AverageCost). This is the only safe way to construct a
    valid portfolio. *)

val apply_trades : t -> trade list -> t status_or
(** Apply trades sequentially, returning a new portfolio. Trades are processed
    in order. Returns Error if any trade would create invalid state (e.g.,
    insufficient position to sell, insufficient cash).

    Order matters: [Buy 100 AAPL; Sell 50 AAPL] vs [Sell 50 AAPL; Buy 100 AAPL]
*)

val validate : t -> status
(** Validate internal consistency by reconstructing portfolio from initial_cash
    and trade_history, then comparing with stored state. Should always succeed
    for portfolios created via [create] and modified via [apply_trades]. *)
