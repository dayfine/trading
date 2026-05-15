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
      trading logic. *)

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
    [unrealized_pnl_per_position], [locked_collateral], and [accrued_borrow_fee]
    fields are mark-to-market / margin-mode state, not derivable from trade
    history alone, so they are excluded from this check. *)

(** {1 Margin accounting (issue #859 Phase 1)}

    Strict-broker semantics for short selling: collateral pre-locked at short
    entry, refunded on cover, plus a daily borrow-fee debit. Gated behind
    [Margin_config.enabled]. When the flag is [false], every API in this section
    is a bit-equal pass-through to the corresponding legacy entry point — no
    field outside [unrealized_pnl_per_position] is touched. *)

val available_cash : t -> cash_value
(** Spendable cash net of locked short collateral:
    [current_cash -. locked_collateral]. Equals [current_cash] under the legacy
    semantics (where [locked_collateral = 0.0]). Strategy code that needs to
    size new entries against actually-spendable cash should consume this rather
    than [current_cash] directly. *)

val apply_single_trade_with_margin :
  margin_config:Margin_config.t -> t -> trade -> t status_or
(** Margin-aware single-trade application.

    {b When [margin_config.enabled = false]}: bit-equal to [apply_single_trade].
    [locked_collateral] and [accrued_borrow_fee] are untouched.

    {b When [margin_config.enabled = true]}:
    - {b Opening a short} (Sell adding to a flat / short position): credits
      proceeds to [current_cash] as usual, then locks
      [(1.0 +. initial_margin_pct) *. (price *. quantity)] of cash into
      [locked_collateral]. The cash floor check uses [available_cash] rather
      than [current_cash], so an opening short that cannot meet the collateral
      requirement is rejected with an [error_invalid_argument].
    - {b Closing a short} (Buy reducing a short position): debits the cover cash
      as usual, then releases collateral proportional to the fraction of the
      short closed: [released = factor *. closed_qty *. existing_avg_cost].
      Per-symbol locked amounts are tracked implicitly through total
      [locked_collateral] under the Phase 1 design — the entry locks at cost
      basis, the cover releases at the same proportional fraction.
    - {b Long-side trades} (Buy opening / adding to long, Sell closing long):
      identical to [apply_single_trade]. [locked_collateral] unchanged.

    The function is the only writer of [locked_collateral]; all other portfolio
    APIs leave it alone. *)

val apply_trades_with_margin :
  margin_config:Margin_config.t -> t -> trade list -> t status_or
(** Margin-aware batch trade application. Folds [apply_single_trade_with_margin]
    over the list; returns Error on the first rejection. *)

val accrue_daily_borrow_fee :
  margin_config:Margin_config.t -> t -> (symbol * price) list -> t
(** Debit one trading day of borrow fee from [current_cash] and add it to
    [accrued_borrow_fee]. No-op when [margin_config.enabled = false] or when the
    portfolio holds no short positions.

    The fee is computed against current marked notional:
    [sum_of_short_notional *. daily_borrow_rate], where
    [daily_borrow_rate = short_borrow_fee_annual_pct /. trading_days_per_year]
    (see {!Margin_config.daily_borrow_rate}). Symbols missing from the price
    list are treated as zero-fee (the caller is expected to mark every short on
    each trading-day tick — same convention as [mark_to_market]). *)

val sum_short_notional : t -> (symbol * price) list -> float
(** Sum of [|qty *. price|] across all currently-open short positions whose
    symbol appears in the price list. Pure helper exposed for tests and for
    callers that need notional for sizing checks. *)

val check_maintenance_margin :
  margin_config:Margin_config.t -> t -> (symbol * price) list -> symbol list
(** Identify short positions whose equity ratio has fallen below the
    [maintenance_margin_pct] threshold. Returns the symbols (sorted) that should
    be forcibly covered by the caller's risk-management layer.

    For each short of [qty] shares at entry-avg-cost [c0] now marked at [p],
    total cash backing the position is
    [(1.0 +. initial_margin_pct) *. c0 *. qty]; the cover liability is
    [p *. qty]; equity is the difference, and equity_ratio is:
    {[
    equity_ratio = (((1.0 +. initial_margin_pct) *. c0) -. p) /. p
    ]}
    A position is flagged when
    [equity_ratio < margin_config.maintenance_margin_pct].

    Equivalent trigger price:
    [p_trigger = c0 *. (1.0 +. initial_margin_pct) /. (1.0 +.
     maintenance_margin_pct)]. With the defaults (0.50 / 0.25) this is
    [p_trigger = 1.2 *. c0], i.e., a 20% adverse move on the short.

    Returns the empty list when [margin_config.enabled = false], when there are
    no short positions, or when no shorts breach the threshold.

    {b Note}: the function is a pure check — it does not mutate the portfolio or
    fire any trade. The caller (strategy / simulator) is responsible for routing
    flagged symbols through the standard force-cover audit path. *)
