(** Supporting types for portfolio management *)

open Trading_base.Types

type cash = float [@@deriving show, eq]
(** Cash balance in the portfolio *)

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;
  avg_cost : price;
}
[@@deriving show, eq]
(** Position with cost basis tracking. Market value and P&L are computed
    separately. *)
