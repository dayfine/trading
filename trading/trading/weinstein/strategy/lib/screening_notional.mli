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
