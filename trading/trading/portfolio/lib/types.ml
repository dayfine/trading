open Trading_base.Types

type cash_value = float [@@deriving show, eq]

type lot_id = string [@@deriving show, eq]

type accounting_method = AverageCost | FIFO [@@deriving show, eq]

type position_lot = {
  lot_id : lot_id;
  quantity : quantity;
  cost_basis : float;  (* Total cost for this lot including commission *)
  acquisition_date : Core.Date.t;
}
[@@deriving show, eq]

type portfolio_position = {
  symbol : symbol;
  lots : position_lot list;  (* Individual lots *)
  accounting_method : accounting_method;
}
[@@deriving show, eq]

type trade_with_pnl = { trade : Trading_base.Types.trade; realized_pnl : float }
[@@deriving show, eq]
