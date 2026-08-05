(** Private OHLCV-assembly helpers for [Snapshot_bar_views]. Not part of the
    public library surface. *)

open Core

val empty_weekly_view : Data_panel_snapshot.Panel_views.weekly_view
(** The [n = 0] weekly view returned whenever no rows are readable. Shared so
    every producer and every consumer-side sentinel is the same literal. *)

val empty_daily_view : Data_panel_snapshot.Panel_views.daily_view
(** The [n_days = 0] daily view returned whenever no rows are readable. *)

type daily_tables = {
  close_t : (Date.t, float) Hashtbl.t;  (** Raw [Close] cell by date. *)
  adj_t : (Date.t, float) Hashtbl.t;  (** [Adjusted_close] cell by date. *)
  high_t : (Date.t, float) Hashtbl.t;  (** Raw [High] cell by date. *)
  low_t : (Date.t, float) Hashtbl.t;  (** Raw [Low] cell by date. *)
}
(** The per-date field lookups {!walk_daily_view_window} reads, bundled so the
    walker keeps a small parameter list. *)

val walk_daily_view_window :
  calendar:Date.t array ->
  from_idx:int ->
  as_of_idx:int ->
  tables:daily_tables ->
  Data_panel_snapshot.Panel_views.daily_view
(** [walk_daily_view_window ~calendar ~from_idx ~as_of_idx ~tables] walks
    calendar columns [from_idx..as_of_idx] and emits one view row per column
    whose raw [Close] cell is present and non-NaN, in calendar order.

    Row emission is gated on the raw close alone: a column with a good close
    still emits when [High] / [Low] / [Adjusted_close] are missing, with
    [Float.nan] in those columns. Returns {!empty_daily_view} when no column
    qualifies. *)

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
