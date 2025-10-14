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

type trade_with_pnl = { trade : Trading_base.Types.trade; realized_pnl : float }
[@@deriving show, eq]
(** Trade paired with its realized P&L. P&L is calculated at execution time
    based on cost basis of positions being closed. *)
