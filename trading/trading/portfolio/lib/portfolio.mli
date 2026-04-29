(** Portfolio management with immutable value type *)

open Trading_base.Types
open Status
open Types

type t = {
  initial_cash : cash_value;
  trade_history : trade_with_pnl list;
  current_cash : cash_value;
  positions : portfolio_position list;
  accounting_method : accounting_method;
  unrealized_pnl_per_position : (symbol * float) list;
}
[@@deriving show, eq, sexp]
(** Portfolio type. All fields are accessible for pattern matching and direct
    access. The portfolio is functionally immutable - [apply_trades] returns a
    new portfolio rather than modifying the existing one.

    Fields:
    - [initial_cash]: Starting cash balance
    - [trade_history]: Complete history of trades with realized P&L
    - [current_cash]: Current cash balance (derived from initial_cash and
      trades)
    - [positions]: Current positions as sorted list (by symbol)
    - [accounting_method]: Cost basis accounting method (AverageCost or FIFO)
    - [unrealized_pnl_per_position]: Mark-to-market unrealized P&L per symbol,
      sorted by symbol. Updated by [mark_to_market]; consumed by
      [apply_single_trade] when computing the effective cash floor. Empty when
      the portfolio has never been marked, or for positions with no market price
      feed. *)

val create :
  ?accounting_method:accounting_method -> initial_cash:cash_value -> unit -> t
(** Create a new portfolio with initial cash balance and optional accounting
    method (default: AverageCost). This is the only safe way to construct a
    valid portfolio. *)

val get_position : t -> symbol -> portfolio_position option
(** Find a position by symbol. Returns None if no position exists for the
    symbol. *)

val apply_single_trade : t -> trade -> t status_or
(** Apply a single trade, returning a new portfolio. Returns Error if the trade
    would push effective cash below 0, where effective cash =
    [current_cash + cash_change_from_trade + sum(min(0,
     unrealized_pnl_per_position))].

    Cash floor semantics (soft, not strict-margin): unrealized losses on open
    positions count against the available cash floor. The check fires on Buy AND
    Sell sides — short entries (Sell opening a position) and short covers (Buy
    reducing a short) both go through the same effective cash floor. This bounds
    the unrealized paper loss a portfolio can carry on shorts before further
    activity is rejected.

    Strict broker-margin semantics (collateral pre-locked at short entry,
    refunded on cover) are deliberately deferred — see
    [dev/notes/short-side-gaps-2026-04-29.md] §G3.

    The unrealized-pnl accumulator is NOT updated by this function — it is a
    separate mark-to-market input fed via [mark_to_market]. After a trade:
    positions fully closed are dropped from the accumulator; new positions seed
    at 0.0; positions whose size changed but did not close keep their existing
    accumulator entry (stale until next mark). *)

val apply_trades : t -> trade list -> t status_or
(** Apply trades sequentially, returning a new portfolio. Trades are processed
    in order. Returns Error if any trade would create invalid state (e.g.,
    insufficient position to sell, insufficient cash).

    Order matters: [Buy 100 AAPL; Sell 50 AAPL] vs [Sell 50 AAPL; Buy 100 AAPL]
*)

val mark_to_market : t -> (symbol * price) list -> t
(** Update [unrealized_pnl_per_position] from current market prices. For each
    open position whose symbol appears in the price list, computes
    [Calculations.unrealized_pnl] and stores it. Positions whose symbol is not
    in the price list are dropped from the accumulator (no stale entries survive
    a mark). The result is sorted by symbol.

    Callers are expected to invoke this on every market-data tick for cash-floor
    enforcement on shorts to be effective. The function is pure and total —
    missing prices are not an error. *)

val validate : t -> status
(** Validate internal consistency by reconstructing portfolio from initial_cash
    and trade_history, then comparing with stored state. Should always succeed
    for portfolios created via [create] and modified via [apply_trades]. The
    [unrealized_pnl_per_position] field is mark-to-market state, not derivable
    from trade history alone, so it is excluded from this check. *)
