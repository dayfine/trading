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
  sector_exposure_acc : (string, float) Hashtbl.t;
  max_sector_exposure_pct : float option;
}
(** Bundle of per-Friday entry-walk accumulators + caps, seeded from the
    portfolio and config. The accumulators are mutated in-place by the gates
    inside [Entry_audit_capture.classify_candidate] as the walk funds
    candidates. *)

val make_entry_walk_state :
  cash:float ->
  config:Weinstein_strategy_config.config ->
  portfolio:Portfolio_view.t ->
  portfolio_value:float ->
  sector_lookup:(string -> string option) option ->
  entry_walk_state
(** Seed an {!entry_walk_state}: [remaining_cash] starts at [cash], the
    short-notional accumulator at the portfolio's open [Holding] short notional,
    and the sector-exposure accumulator at held positions' notional (empty when
    [sector_lookup] is [None]). Caps come from [config.portfolio_config]. *)

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
