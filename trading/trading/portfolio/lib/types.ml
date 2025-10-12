open Core
open Trading_base.Types

type cash = float [@@deriving show, eq]
type realized_pnl = float [@@deriving show, eq]
type unrealized_pnl = float [@@deriving show, eq]

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;
  avg_cost : price;
  market_value : price option;
  unrealized_pnl : unrealized_pnl;
}
[@@deriving show, eq]

type portfolio = {
  cash : cash;
  positions : (symbol, portfolio_position) Hashtbl.t;
  realized_pnl : realized_pnl;
  created_at : Time_ns_unix.t;
  updated_at : Time_ns_unix.t;
}
