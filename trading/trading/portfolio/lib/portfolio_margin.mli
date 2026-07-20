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
open Types

val available_cash : Portfolio.t -> cash_value
(** Spendable cash net of locked short collateral:
    [current_cash -. locked_collateral]. Equals [current_cash] under the legacy
    semantics (where [locked_collateral = 0.0]). Strategy code that needs to
    size new entries against actually-spendable cash should consume this rather
    than [current_cash] directly. Lives here (not on {!Portfolio}) to keep that
    module under the file-length hard limit — it reads the [locked_collateral]
    field this module maintains. *)

val equity_cash : Portfolio.t -> cash_value
(** Cash component of portfolio equity net of borrowed long-margin debt:
    [current_cash -. long_margin_debit] (margin M1b-2). Portfolio equity is
    [equity_cash + marked position value]; NAV / drawdown / metric reads must
    consume this so a levered book's borrowed cash does not inflate reported
    wealth. Equals [current_cash] under a cash account (where
    [long_margin_debit = 0.0]), so all pre-M1b valuations are bit-identical. *)

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

    The fee is accrued {b per short position} at its marked price using the
    price-tiered daily rate {!Margin_config.daily_borrow_rate_for_price} (margin
    M3a): low-priced hard-to-borrow names can carry a higher rate. When
    [margin_config.short_borrow_rate_tiers] is empty (the default) every price
    resolves to the flat {!Margin_config.daily_borrow_rate}, so the per-position
    sum equals the legacy [sum_of_short_notional *. daily_borrow_rate]
    bit-for-bit. Symbols missing from the price list are treated as zero-fee
    (the caller is expected to mark every short on each trading-day tick — same
    convention as [Portfolio.mark_to_market]). *)

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
    A position is flagged when [equity_ratio < threshold], where [threshold] is
    the price-tiered {!Margin_config.maintenance_pct_for_price} for the short's
    marked price (margin M3a) — so low-priced HTB shorts are flagged sooner.
    When [margin_config.short_maintenance_tiers] is empty (the default) the
    threshold resolves to the flat [maintenance_margin_pct], bit-identical to
    pre-M3a.

    Equivalent trigger price:
    [p_trigger = c0 *. (1.0 +. initial_margin_pct) /. (1.0 +.
     maintenance_margin_pct)]. With the defaults (0.50 / 0.25) this is
    [p_trigger = 1.2 *. c0], i.e., a 20% adverse move on the short.

    Returns the empty list when [margin_config.enabled = false], when there are
    no short positions, or when no shorts breach the threshold.

    {b Note}: the function is a pure check — it does not mutate the portfolio or
    fire any trade. The caller (strategy / simulator) is responsible for routing
    flagged symbols through the standard force-cover audit path. *)

(** {1 Long-margin (levered long) accounting — margin M1b-2 (Option A)}

    The long-side mirror of the short collateral surface: a levered long BUY
    whose cost exceeds available cash borrows the shortfall into
    [Portfolio.long_margin_debit] instead of being rejected by the cash floor,
    and the debit is priced with per-tick interest. Gated by
    [initial_long_margin_req]: at a cash account ([req >= 1.0]) every entry
    point here is a bit-equal pass-through to the corresponding [Portfolio] API,
    so the default is byte-identical to pre-M1b behaviour. *)

val apply_single_trade_with_long_margin :
  initial_long_margin_req:float -> Portfolio.t -> trade -> Portfolio.t status_or
(** Long-margin-aware single-trade application, routed at the simulator fill
    seam ([Cancel_handler]).

    {b When [initial_long_margin_req >= 1.0]} (cash account / leverage
    disarmed): bit-equal to [Portfolio.apply_single_trade]. [long_margin_debit]
    is untouched (stays [0.0]).

    {b When [0.0 < initial_long_margin_req < 1.0]} (leverage armed):
    - {b Long BUY} (Buy with [existing_qty >= 0.0]) whose cost
      ([qty *. price +. commission]) exceeds [available_cash]: own cash is spent
      first and the shortfall is borrowed into [long_margin_debit].
      [current_cash] never goes negative — Option A funds the debit as a
      dedicated liability rather than relaxing the cash floor, whose semantics
      stay byte-identical. A BUY that fits within available cash takes the base
      apply path unchanged.
    - {b Long SELL} (Sell reducing a long) with a positive prior debit: the sale
      proceeds pay down [long_margin_debit] to [0.0] before any remainder is
      added to [current_cash].
    - {b Everything else} (shorts, covers, unlevered buys): identical to
      [Portfolio.apply_single_trade].

    {b Bound.} The buying-power ceiling ([equity /. initial_long_margin_req]) is
    enforced upstream by the strategy entry walk (M1a/M1b-1); this fill-seam
    function honours the sized order and does not re-derive the ceiling (no
    marks are available at the fill seam — mirrors the short side, whose
    collateral lock is likewise not re-checked at the sim fill). *)

val accrue_daily_long_margin_interest :
  rate_annual_pct:float -> Portfolio.t -> Portfolio.t
(** Capitalize one trading day of interest on the outstanding
    [long_margin_debit] into the debit balance (a levered book finances its own
    carry, so [current_cash] is not touched — it may be [0.0] on a fully-levered
    book). The charge equals
    [long_margin_debit *. (rate_annual_pct /. trading_days_per_year)] — the same
    252 day-count and quantity as
    [Long_buying_power.long_margin_interest_charge], computed here at the
    portfolio layer (which cannot depend on the strategy layer where that helper
    lives).

    No-op when [rate_annual_pct <= 0.0] (the default) or when there is no debit,
    so a cash account and the default rate leave the portfolio unchanged.
    Mirrors {!accrue_daily_borrow_fee} for the short side. *)
