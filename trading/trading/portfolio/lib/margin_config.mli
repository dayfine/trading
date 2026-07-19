(** Margin accounting configuration (issue #859 Phase 1).

    Captures the broker-side parameters needed to model Reg-T-style short
    selling: initial collateral above-and-beyond proceeds, maintenance margin
    threshold, and the daily borrow fee.

    The [enabled] field is the master switch. When [enabled = false] (the
    default), all margin-aware portfolio APIs are bit-equal no-ops: short
    proceeds credit cash exactly as in the legacy Stance A semantics and no
    collateral is locked, no fee accrues, no maintenance check fires.

    The fields are intentionally strategy-agnostic — they describe broker
    mechanics, not Weinstein-specific entry rules. Any strategy that opens short
    positions in this simulator benefits from realistic margin modeling without
    leaking strategy state into the portfolio layer.

    Authority: [dev/plans/short-side-margin-2026-05-13.md] §1. *)

type t = {
  enabled : bool;  (** Master switch; default [false]. *)
  initial_margin_pct : float;
      (** Reg-T initial-margin requirement on top of short proceeds (default
          [0.50] — i.e., 50% of notional locked alongside the proceeds, for a
          total of 150% notional in collateral). *)
  maintenance_margin_pct : float;
      (** Maintenance equity ratio: when
          [(entry_price * qty + initial_locked - current_price * qty) /
           (current_price * qty) < maintenance_margin_pct] the position is
          flagged for forced buy-to-cover (default [0.25]). *)
  short_borrow_fee_annual_pct : float;
      (** Annualized borrow fee charged on short notional (default [0.005] = 50
          bps — liquid SP500 reference rate per issue #859). Accrued daily as
          [notional * rate / trading_days_per_year]. This is the {b flat
          fallback}: consulted for any short whose marked price is not covered
          by a {!short_borrow_rate_tiers} band. *)
  short_borrow_rate_tiers : Short_margin_tiers.tier list;
      (** Hard-to-borrow price-tiered {b annual borrow rate} table (margin M3a),
          default [[]] (empty). When empty, every short pays the flat
          [short_borrow_fee_annual_pct] — bit-identical to pre-M3a. When armed,
          a short marked below a band's [price_below] pays that band's rate
          instead (low-priced HTB names carry higher rates); see
          {!Short_margin_tiers.tier_value} for the piecewise-constant lookup and
          [dev/notes/long-short-margin-mechanics-2026-06-12.md] §3 for the
          economics. Searchable via the nested overlay key
          [margin_config.short_borrow_rate_tiers]
          ([.claude/rules/experiment-flag-discipline.md] R2). *)
  short_maintenance_tiers : Short_margin_tiers.tier list;
      (** Price-tiered {b maintenance equity ratio} table (margin M3a), default
          [[]] (empty). When empty, every short uses the flat
          [maintenance_margin_pct] — bit-identical to pre-M3a. When armed,
          supersedes the flat 25% with the FINRA-style per-price schedule
          (sub-$5 → 100%, ~$5-17 → ≈83%, ≥ ~$16.67 → 30% base), so low-priced
          shorts are flagged for force-cover far sooner. See
          {!Short_margin_tiers.tier_value} and
          [dev/notes/long-short-margin-mechanics-2026-06-12.md] §1. Searchable
          via the nested overlay key [margin_config.short_maintenance_tiers]
          ([.claude/rules/experiment-flag-discipline.md] R2). *)
}
[@@deriving show, eq, sexp]

val default_config : t
(** Default config: margin off, 50% initial extra, 25% maintenance, 50bps annual
    borrow fee, {b empty} borrow-rate and maintenance tier tables. With
    [enabled = false] the other fields are dormant; with the tier tables empty
    the tiered lookups fall back to the flat rates (M3a is default-off). *)

val trading_days_per_year : float
(** Conventional trading-day count (252) used to convert annual borrow fee to a
    daily rate. Exposed so tests can pin expectations against the same constant
    the production code uses. *)

val total_collateral_factor : t -> float
(** Total cash factor backing one unit of short notional, expressed as a
    multiplier on [entry_price * qty]: [1.0 + initial_margin_pct]. With the
    default [0.50] this is [1.50], i.e., 150% of notional ties up cash on a new
    short entry (100% from the credited proceeds + 50% from existing cash). *)

val daily_borrow_rate : t -> float
(** Per-trading-day borrow rate:
    [short_borrow_fee_annual_pct /. trading_days_per_year]. The flat-fallback
    daily rate; per-symbol tiered accrual should consume
    {!daily_borrow_rate_for_price}. *)

val borrow_fee_annual_for_price : t -> price:float -> float
(** Annual borrow-fee fraction for a short marked at [price] (margin M3a):
    the price-tiered rate from {!short_borrow_rate_tiers} when a band covers
    [price], else the flat {!short_borrow_fee_annual_pct}. An empty tier table
    always returns the flat rate, so a disarmed config is bit-identical to
    pre-M3a. *)

val daily_borrow_rate_for_price : t -> price:float -> float
(** Per-trading-day borrow rate for a short marked at [price]:
    [borrow_fee_annual_for_price cfg ~price /. trading_days_per_year]. Equals
    {!daily_borrow_rate} for every price when {!short_borrow_rate_tiers} is
    empty (the default). *)

val maintenance_pct_for_price : t -> price:float -> float
(** Maintenance equity-ratio threshold for a short marked at [price] (margin
    M3a): the price-tiered value from {!short_maintenance_tiers} when a band
    covers [price], else the flat {!maintenance_margin_pct}. An empty tier table
    always returns the flat threshold, so a disarmed config is bit-identical to
    pre-M3a. *)
