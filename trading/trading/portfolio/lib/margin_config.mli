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
          [notional * rate / trading_days_per_year]. *)
}
[@@deriving show, eq, sexp]

val default_config : t
(** Default config: margin off, 50% initial extra, 25% maintenance, 50bps annual
    borrow fee. With [enabled = false] the other fields are dormant. *)

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
    [short_borrow_fee_annual_pct /. trading_days_per_year]. *)
