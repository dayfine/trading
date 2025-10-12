(** Portfolio calculations and computed fields *)

open Trading_base.Types
open Types

val market_value : portfolio_position -> price -> float
(** Calculate market value of position at given price *)

val unrealized_pnl : portfolio_position -> price -> float
(** Calculate unrealized P&L of position at given price *)

val portfolio_value :
  Trading_base.Types.symbol list ->
  portfolio_position list ->
  cash_value ->
  (symbol * price) list ->
  float
(** Calculate total portfolio value given current market prices. Includes cash +
    sum of all position market values *)

val realized_pnl_from_trades : trade list -> float
(** Calculate realized P&L from trade history *)

val position_cost_basis : portfolio_position -> float
(** Calculate total cost basis of position (quantity * avg_cost) *)
