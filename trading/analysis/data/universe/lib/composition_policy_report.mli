(** Adapt a {!Snapshot.t} into composition-policy
    {!Composition_policy_types.candidate}s and render the policy's drop
    {!Composition_policy_types.result} as a human-readable text report.

    This is the glue between the existing universe snapshots and the pure policy
    in {!Composition_policy}: it pulls per-symbol [asset_type] from the same
    [symbol_types.sexp] the build uses, takes [sector] straight off the snapshot
    entry, and assigns [rank] from the entry's position in the snapshot (entries
    are emitted in dollar-volume-descending order by {!Build_from_individuals}).
*)

open Core

val candidates_of_snapshot :
  Snapshot.t ->
  equity_like:(string, bool) Hashtbl.t ->
  asset_type:(string, Eodhd.Asset_type.t) Hashtbl.t ->
  ?dollar_volume:(string, float) Hashtbl.t ->
  unit ->
  Composition_policy_types.candidate list
(** [candidates_of_snapshot snapshot ~equity_like:_ ~asset_type ?dollar_volume
     ()] converts each snapshot entry to a {!Composition_policy_types.candidate}
    in entry order, assigning [rank] = entry index.

    - [asset_type] supplies each symbol's classification; symbols absent from
      the map default to {!Eodhd.Asset_type.Common_stock} (the dominant case and
      the value that makes the ADR / preferred filters no-ops).
    - [dollar_volume], when given, supplies [avg_dollar_volume] per symbol;
      symbols absent from it — and the whole map when [dollar_volume] is omitted
      — default to [Float.infinity], so the ADR liquidity floor never drops a
      symbol whose volume is unknown (a conservative, no-surprise default).
    - [equity_like] is accepted for symmetry with the build inputs but is not
      consulted: the snapshot is already equity-like-filtered upstream.

    Pure: same inputs -> same output. *)

val render_reports : Composition_policy_types.result -> string
(** [render_reports result] formats the per-filter drop reports as a plain-text
    block: one section per filter with its kept-count and each dropped symbol +
    reason, followed by a totals line. Deterministic; intended for stdout / a
    [.txt] artifact alongside the filtered snapshot. *)
