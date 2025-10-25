(** Supporting types for portfolio management *)

open Trading_base.Types

type cash_value = float [@@deriving show, eq]
(** Cash balance in the portfolio, denominated in US dollars *)

type lot_id = string [@@deriving show, eq]
(** Unique identifier for a position lot *)

type accounting_method = AverageCost | FIFO
[@@deriving show, eq]
(** Method for calculating cost basis and matching lots.
    - AverageCost: Combines all lots into a single lot with weighted average cost
    - FIFO: Keeps lots separate and matches oldest lots first when closing positions *)

type position_lot = {
  lot_id : lot_id;
  quantity : quantity;  (** Can be positive (long) or negative (short) *)
  cost_basis : float;
      (** Total cost basis for entire lot including commission *)
  acquisition_date : Core.Date.t;  (** Date when acquired *)
}
[@@deriving show, eq]
(** A single lot representing a portion of a position acquired at a specific
    time and price. The cost_basis includes the total cost for all shares in
    this lot, including commissions. *)

type portfolio_position = {
  symbol : symbol;
  quantity : quantity;  (** Total quantity across all lots *)
  lots : position_lot list;  (** Individual lots making up this position *)
  accounting_method : accounting_method;  (** Method used for this position *)
}
[@@deriving show, eq]
(** Position with lot-based cost basis tracking. The quantity field is the sum
    of all lot quantities. Average cost can be computed on demand from lots.
    The accounting_method determines how lots are combined or matched.
    Market value and P&L are computed separately. *)

type trade_with_pnl = { trade : Trading_base.Types.trade; realized_pnl : float }
[@@deriving show, eq]
(** Trade paired with its realized P&L. P&L is calculated at execution time
    based on cost basis of positions being closed. *)
