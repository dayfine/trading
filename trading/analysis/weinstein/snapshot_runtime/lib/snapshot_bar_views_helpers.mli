(** Private OHLCV-assembly helpers for [Snapshot_bar_views]. Not part of the
    public library surface. *)

open Core

val table_of : (Date.t * float) list -> (Date.t, float) Hashtbl.t
(** Build a date-keyed hashtable from a [(date, value)] row list. *)

val bar_for :
  open_t:(Date.t, float) Hashtbl.t ->
  active_through:Date.t option ->
  adj_t:(Date.t, float) Hashtbl.t ->
  high_t:(Date.t, float) Hashtbl.t ->
  low_t:(Date.t, float) Hashtbl.t ->
  vol_t:(Date.t, float) Hashtbl.t ->
  Date.t * float ->
  Types.Daily_price.t option
(** Build one [Daily_price.t] from a [(date, close)] pair and the OHLCV
    side-tables. Returns [None] for NaN-close or any missing field. Open
    degrades to [Float.nan] when the snapshot has no row for the date.
    [active_through] is stamped onto every reconstituted bar — callers pass the
    symbol-level value resolved via [Snapshot_callbacks.active_through_for]. *)
