open Trading_base.Types

type cash_value = float [@@deriving show, eq]

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;
  avg_cost : price;
}
[@@deriving show, eq]

type trade_with_pnl = { trade : Trading_base.Types.trade; realized_pnl : float }
[@@deriving show, eq]
