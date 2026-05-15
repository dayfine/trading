(** Margin accounting for short positions (issue #859 Phase 1).

    Strict-broker semantics for short selling: collateral pre-locked at short
    entry, refunded on cover, plus a daily borrow-fee debit and a maintenance
    margin check. Gated behind [Margin_config.enabled]. When the flag is
    [false], every API in this module is a bit-equal pass-through to the
    corresponding legacy [Portfolio] entry point — no field outside
    [unrealized_pnl_per_position] is touched.

    This module operates on [Portfolio.t] values; it does not introduce a new
    type. The fields [locked_collateral] and [accrued_borrow_fee] live on
    [Portfolio.t] so that the rest of the portfolio API (validation,
    serialization, [available_cash]) can read them without a cross-module
    dependency cycle.

    Extracted from [Portfolio] to keep that module under the file-length
    linter's hard limit — see [dev/notes/short-side-margin-2026-05-13.md]. *)

open Trading_base.Types
open Status

val apply_single_trade_with_margin :
  margin_config:Margin_config.t -> Portfolio.t -> trade -> Portfolio.t status_or
(** Margin-aware single-trade application.

    {b When [margin_config.enabled = false]}: bit-equal to
    [Portfolio.apply_single_trade]. [locked_collateral] and [accrued_borrow_fee]
    are untouched.

    {b When [margin_config.enabled = true]}:
    - {b Opening a short} (Sell adding to a flat / short position): credits
      proceeds to [current_cash] as usual, then locks
      [(1.0 +. initial_margin_pct) *. (price *. quantity)] of cash into
      [locked_collateral]. The cash floor check uses [Portfolio.available_cash]
      rather than [current_cash], so an opening short that cannot meet the
      collateral requirement is rejected with an [error_invalid_argument].
    - {b Closing a short} (Buy reducing a short position): debits the cover cash
      as usual, then releases collateral proportional to the fraction of the
      short closed: [released = factor *. closed_qty *. existing_avg_cost].
      Per-symbol locked amounts are tracked implicitly through total
      [locked_collateral] under the Phase 1 design — the entry locks at cost
      basis, the cover releases at the same proportional fraction.
    - {b Long-side trades} (Buy opening / adding to long, Sell closing long):
      identical to [Portfolio.apply_single_trade]. [locked_collateral]
      unchanged.

    The function is the only writer of [locked_collateral]; all other portfolio
    APIs leave it alone. *)

val apply_trades_with_margin :
  margin_config:Margin_config.t ->
  Portfolio.t ->
  trade list ->
  Portfolio.t status_or
(** Margin-aware batch trade application. Folds [apply_single_trade_with_margin]
    over the list; returns Error on the first rejection. *)

val accrue_daily_borrow_fee :
  margin_config:Margin_config.t ->
  Portfolio.t ->
  (symbol * price) list ->
  Portfolio.t
(** Debit one trading day of borrow fee from [current_cash] and add it to
    [accrued_borrow_fee]. No-op when [margin_config.enabled = false] or when the
    portfolio holds no short positions.

    The fee is computed against current marked notional:
    [sum_of_short_notional *. daily_borrow_rate], where
    [daily_borrow_rate = short_borrow_fee_annual_pct /. trading_days_per_year]
    (see {!Margin_config.daily_borrow_rate}). Symbols missing from the price
    list are treated as zero-fee (the caller is expected to mark every short on
    each trading-day tick — same convention as [Portfolio.mark_to_market]). *)

val sum_short_notional : Portfolio.t -> (symbol * price) list -> float
(** Sum of [|qty *. price|] across all currently-open short positions whose
    symbol appears in the price list. Pure helper exposed for tests and for
    callers that need notional for sizing checks. *)

val check_maintenance_margin :
  margin_config:Margin_config.t ->
  Portfolio.t ->
  (symbol * price) list ->
  symbol list
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
