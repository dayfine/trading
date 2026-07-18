(** Per-Friday entry-price-denominated notional / sector-exposure seeds for the
    screening entry walk. Extracted from {!Weinstein_strategy_screening} to keep
    that coordinator under its line cap — pure, no behavior change. *)

open Core
open Trading_strategy

val initial_short_notional : Position.t Map.M(String).t -> float
(** Sum entry-price-denominated short notional across all open [Holding] shorts.
    Seeds the per-Friday short-notional accumulator before the entry walk begins
    (entry-price-denominated so the cap measures committed-at-entry exposure).
*)

val initial_long_notional : Position.t Map.M(String).t -> float
(** Sum entry-price-denominated long notional across all open [Holding] longs.
    Mirror of {!initial_short_notional}; seeds the per-Friday long-notional
    accumulator before the entry walk begins.

    Entry-price-denominated ([shares * entry_price], NOT marked value) is
    deliberate: the P0b long-exposure cap targets entries funded
    {e beyond NAV at entry time} (the 2026-07-13 Run-E artifact — the long book
    levering on short proceeds). Marked exposure above 100% of NAV from
    unrealized appreciation of held winners is legitimate (not leverage) and
    must not trigger the cap. Entry-denominated also stays symmetric with the
    short cap and avoids threading a [get_price] mark into the walk. *)

val initial_sector_exposures :
  positions:Position.t Map.M(String).t ->
  sector_lookup:(string -> string option) ->
  (string, float) Hashtbl.t
(** Build the per-sector exposure accumulator seeded with existing [Holding]
    positions' entry-price-denominated absolute notional. [sector_lookup]
    resolves each held symbol to its sector — same source the entry walk uses
    for new candidates; symbols it can't resolve bucket under the empty string
    (which the cap exempts). *)

type entry_walk_state = {
  remaining_cash : float ref;
  short_notional_acc : float ref;
  short_notional_cap : float;
  long_notional_acc : float ref;
      (** Running entry-price-denominated long notional, seeded from held
          [Holding] longs via {!initial_long_notional} and bumped by each funded
          long entry. Checked against {!long_notional_cap} by
          [Entry_audit_capture.check_long_notional_cap]. *)
  long_notional_cap : float;
      (** Absolute cap on aggregate long entry notional: [Float.infinity] when
          [config.max_long_exposure_pct_entry <= 0.0] (the default no-op — every
          long admits), else
          [config.max_long_exposure_pct_entry * portfolio_value]. *)
  sector_exposure_acc : (string, float) Hashtbl.t;
  max_sector_exposure_pct : float option;
  leverage_enabled : bool;
      (** M1b long-margin leverage switch: [true] iff
          [config.initial_long_margin_req < 1.0] (a fractional Reg-T
          requirement, e.g. [0.5] = 2x buying power). When [true], the
          entry-walk cash gate ([Entry_audit_capture.check_cash_and_deduct]) may
          fund a long beyond available cash — driving [remaining_cash] negative
          (a debit / borrowed balance) — with the buying-power ceiling
          ([long_notional_cap]) the sole bound. When [false] (the default
          cash-account setting [1.0]) the cash gate is byte-identical to
          pre-M1b: a long costing more than [remaining_cash] is rejected (R1).
      *)
}
(** Bundle of per-Friday entry-walk accumulators + caps, seeded from the
    portfolio and config. The accumulators are mutated in-place by the gates
    inside [Entry_audit_capture.classify_candidate] as the walk funds
    candidates. *)

val borrowed_balance : entry_walk_state -> float
(** The long-margin debit accrued so far in this walk:
    [max 0 (-remaining_cash)]. [remaining_cash] only goes negative when
    [leverage_enabled] lets a long draw beyond available cash, so this derives
    the borrowed balance directly. Returns [0.0] whenever the walk stayed within
    cash (always so at the default cash-account setting, where
    [leverage_enabled = false]). *)

val make_entry_walk_state :
  cash:float ->
  config:Weinstein_strategy_config.config ->
  portfolio:Portfolio_view.t ->
  portfolio_value:float ->
  sector_lookup:(string -> string option) option ->
  entry_walk_state
(** Seed an {!entry_walk_state}: [remaining_cash] starts at [cash], the
    short-notional accumulator at the portfolio's open [Holding] short notional,
    the long-notional accumulator at the open [Holding] long notional
    ({!initial_long_notional}), and the sector-exposure accumulator at held
    positions' notional (empty when [sector_lookup] is [None]). The short/sector
    caps come from [config.portfolio_config]; the long cap comes from
    [config.max_long_exposure_pct_entry] ([Float.infinity] when [<= 0.0]). *)

val reserve_reduced_walk_state :
  config:Weinstein_strategy_config.config ->
  portfolio:Portfolio_view.t ->
  portfolio_value:float ->
  sector_lookup:(string -> string option) option ->
  float * entry_walk_state
(** Cash-reserve knob: hold back [config.cash_reserve_pct] of portfolio value
    from the per-Friday entry-funding budget and seed the walk state with the
    remainder — [spendable = max 0 (cash - cash_reserve_pct * portfolio_value)],
    returned alongside the state. Default [0.0] => [spendable = cash],
    bit-identical to baseline. The reserve is subtracted exactly once here (off
    the top-level budget); the short-sleeve split derives from [spendable] so it
    is never charged twice. Scoped to NEW entries only — exits/covers/stops do
    not flow through the entry walk. See
    [Weinstein_strategy_config.cash_reserve_pct]. *)
