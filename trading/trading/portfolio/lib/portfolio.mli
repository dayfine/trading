(** Portfolio management with opaque type ensuring consistency *)

open Trading_base.Types
open Status
open Types

type t
(** Opaque portfolio type. Internal state is managed to maintain consistency. *)

val create : initial_cash:cash_value -> t
(** Create a new portfolio with initial cash balance *)

val apply_trades : t -> trade list -> t status_or
(** Apply trades sequentially. Trades are processed in order. Returns Error if
    any trade would create invalid state (e.g., insufficient position to sell).
    Order matters: [Buy 100 AAPL; Sell 50 AAPL] vs [Sell 50 AAPL; Buy 100 AAPL]
*)

val get_cash : t -> cash_value
(** Get current cash balance *)

val get_initial_cash : t -> cash_value
(** Get initial cash balance *)

val get_trade_history : t -> trade_with_pnl list
(** Get complete trade history with realized P&L in chronological order *)

val get_total_realized_pnl : t -> float
(** Get total realized P&L from all trades *)

val get_position : t -> symbol -> portfolio_position option
(** Get position for a specific symbol *)

val list_positions : t -> portfolio_position list
(** List all positions in the portfolio *)

val validate : t -> status
(** Validate internal consistency. Should always succeed for properly
    constructed portfolios. Reconstructs portfolio from initial_cash and
    trade_history, compares with stored state. *)
