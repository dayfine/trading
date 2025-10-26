(** Portfolio calculations and computed fields *)

open Trading_base.Types
open Types

val position_quantity : portfolio_position -> float
(** Compute total quantity from all lots in position *)

val avg_cost_of_position : portfolio_position -> float
(** Compute average cost per share from position lots. Returns 0.0 if quantity
    is ~0. *)

val market_value : portfolio_position -> price -> float
(** Calculate market value of position at given price *)

val unrealized_pnl : portfolio_position -> price -> float
(** Calculate unrealized P&L of position at given price *)

val portfolio_value :
  portfolio_position list ->
  cash_value ->
  (symbol * price) list ->
  float Status.status_or
(** Calculate total portfolio value given current market prices. Includes cash +
    sum of all position market values *)

val realized_pnl_from_trades : trade_with_pnl list -> float
(** Calculate total realized P&L from trade history with P&L *)

val position_cost_basis : portfolio_position -> float
(** Calculate total cost basis of position (quantity * avg_cost) *)
