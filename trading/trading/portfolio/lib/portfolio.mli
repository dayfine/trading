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
  locked_collateral : cash_value;
  accrued_borrow_fee : cash_value;
  exempt_closing_trades_from_cash_floor : bool;
  long_margin_debit : cash_value;
}
[@@deriving show, eq, sexp]
(** Portfolio type. All fields are accessible for pattern matching and direct
    access. The portfolio is functionally immutable - [apply_trades] returns a
    new portfolio rather than modifying the existing one.

    Fields:
    - [initial_cash]: Starting cash balance
    - [trade_history]: Complete history of trades with realized P&L, stored
      **newest-first** (most recent trade at the head). Readers that need
      chronological order must [List.rev] before consuming. The newest-first
      convention enables O(1) append in [apply_single_trade] and lets successive
      [step_result.portfolio] snapshots share spines, which is load-bearing for
      backtest memory at scale (15 y / 3 700 trades).
    - [current_cash]: Current cash balance (derived from initial_cash and
      trades)
    - [positions]: Current positions as sorted list (by symbol)
    - [accounting_method]: Cost basis accounting method (AverageCost or FIFO)
    - [unrealized_pnl_per_position]: Mark-to-market unrealized P&L per symbol,
      sorted by symbol. Updated by [mark_to_market]; consumed by
      [apply_single_trade] when computing the effective cash floor. Empty when
      the portfolio has never been marked, or for positions with no market price
      feed.
    - [locked_collateral]: Cash pledged against open short positions under
      Reg-T-style margin accounting (issue #859 Phase 1). [0.0] under the legacy
      Stance-A semantics and whenever [Margin_config.enabled = false].
      Maintained by the margin-aware APIs ([apply_single_trade_with_margin],
      [apply_trades_with_margin]); the [available_cash] helper exposes
      [current_cash -. locked_collateral] as the spendable balance.
    - [accrued_borrow_fee]: Running total of borrow fees deducted from
      [current_cash] over the portfolio's lifetime (issue #859 Phase 1). [0.0]
      unless [Margin_config.enabled = true] and [accrue_daily_borrow_fee] has
      been called. Exposed for audit reporting and tests — not consumed by
      trading logic.
    - [exempt_closing_trades_from_cash_floor]: NS1 (#1557#3). When [true],
      [apply_single_trade]'s cash floor skips the solvency check for the
      reducing portion of a closing trade (long sell / short cover). [false]
      (the [create] default) reproduces the prior behaviour exactly. A plain
      bool so this module stays strategy-agnostic; the strategy layer sets it
      from [Portfolio_risk.config.exempt_closing_trades_from_cash_floor]. See
      [apply_single_trade] for the exact semantics.
    - [long_margin_debit]: borrowed cash funding levered long positions (margin
      M1b-2, Option A). [0.0] under a cash account and whenever leverage is
      disarmed. Written only by the long-margin-aware apply in
      {!Portfolio_margin} ([apply_single_trade_with_long_margin]); every NAV /
      equity read subtracts it via [Portfolio_margin.equity_cash], so borrowed
      cash never inflates reported wealth. Strategy-agnostic (a broker
      mechanic). *)

val create :
  ?accounting_method:accounting_method ->
  ?exempt_closing_trades_from_cash_floor:bool ->
  initial_cash:cash_value ->
  unit ->
  t
(** Create a new portfolio with initial cash balance and optional accounting
    method (default: AverageCost). This is the only safe way to construct a
    valid portfolio.

    [exempt_closing_trades_from_cash_floor] (default: [false]) controls the
    cash-floor exemption for closing trades — see the field doc above and
    [apply_single_trade]. The default preserves the legacy floor behaviour. *)

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

    NS1 (#1557#3) closing-trade exemption: when
    [exempt_closing_trades_from_cash_floor = true] on the portfolio, the floor
    is applied only to the {b opening portion} of a closing trade. A closing
    trade is one opposite-signed to a non-flat existing position (a long sell or
    a short cover). A {e genuinely-reducing} trade
    ([|trade_qty| <= |existing_qty|]) has no opening portion and is therefore
    always accepted — covering reduces risk and must not be blocked by stale
    paper-loss drag (the #1553 zombie root cause). An {e over-cover} that flips
    short->long exempts the closing portion but still applies the floor to the
    new-opening portion's cash change ([opening_qty * price] + pro-rata
    commission), mirroring [Portfolio_margin._classify_trade]'s
    [min(|trade_qty|, |existing_qty|)] split. When the flag is [false] (the
    default), the full trade faces the floor exactly as before.

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
    [unrealized_pnl_per_position], [locked_collateral], and [accrued_borrow_fee]
    fields are mark-to-market / margin-mode state, not derivable from trade
    history alone, so they are excluded from this check. *)

(** {1 Margin accounting (issue #859 Phase 1, margin M1b-2)}

    [Portfolio.t] carries the margin-mode bookkeeping fields
    ([locked_collateral], [accrued_borrow_fee], [long_margin_debit] in the
    record), but the margin-aware trade APIs and the margin-cash accessors
    ([available_cash], [equity_cash]) live in {!Portfolio_margin} to keep this
    module under the file-length linter's hard limit. *)
