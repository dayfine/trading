(** Supporting types for portfolio management *)

open Trading_base.Types

type cash_value = float [@@deriving show, eq]
(** Cash balance in the portfolio, denominated in US dollars *)

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;
  avg_cost : price;
}
[@@deriving show, eq]
(** Position with cost basis tracking. Market value and P&L are computed
    separately. *)
