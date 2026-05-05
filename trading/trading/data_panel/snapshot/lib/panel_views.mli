(** Bar-shaped view records shared by panel and snapshot bar readers.

    Phase F.3.e-1 placement (2026-05-06): the [weekly_view] and [daily_view]
    record types live here, in [trading.data_panel.snapshot] — a neutral hub
    library that depends only on [core] + [status] and has no edge to any
    [analysis/] code. Both consumers — {!Data_panel.Bar_panels} (the
    panel-backed bar reader, in [trading/trading/data_panel/]) and
    {!Snapshot_runtime.Snapshot_bar_views} (the snapshot-backed bar reader, in
    [trading/analysis/weinstein/snapshot_runtime/]) — re-export these record
    types via manifest type aliases so callers can keep using the names they
    already know.

    Putting the records here avoids the otherwise-required [analysis/weinstein/]
    → [trading/trading/data_panel/] dune dep that would cross the A2
    architecture boundary (see [.claude/rules/qc-structural-authority.md] §A2).
    The previous arrangement had {!Snapshot_runtime.Snapshot_bar_views} as the
    canonical home and [Data_panel.Bar_panels] re-exporting from it; that
    introduced an [analysis/] → [trading/] import. The neutral-hub arrangement
    here removes the bad edge while keeping a single canonical record
    definition.

    {2 Record-shape contract}

    These are pure data shapes — float-array snapshots of bar history for one
    symbol over one window. The two consumer modules implement matching
    aggregation semantics ({!Time_period.Conversion.daily_to_weekly} with
    [include_partial_week:true]) so a [weekly_view] from the panel reader and a
    [weekly_view] from the snapshot reader for the same input data are
    bit-equal. *)

type weekly_view = {
  closes : float array;
      (** Adjusted close per weekly bar (chronological, oldest at index 0). *)
  raw_closes : float array;
      (** Raw (un-adjusted) close per weekly bar — the close panel's value at
          the last trading day of each weekly bucket. Used together with
          [closes] to compute per-bar split-adjustment factors
          ([closes.(i) /. raw_closes.(i)]). *)
  highs : float array;  (** Max high within each weekly bucket. *)
  lows : float array;  (** Min low within each weekly bucket. *)
  volumes : float array;
      (** Sum of daily volumes within each weekly bucket. Stored as float to
          align with the panel layout; consumers that need int can round-nearest
          and convert. *)
  dates : Core.Date.t array;
      (** Date of the last trading day in each weekly bucket (Friday for
          complete weeks). *)
  n : int;  (** Length of every array. *)
}
(** Float-array view of weekly-aggregated bars for one symbol.

    Aggregation semantics match {!Time_period.Conversion.daily_to_weekly} with
    [include_partial_week:true]: weeks are ISO weeks (Monday–Sunday); the
    aggregate's date is the latest trading day in the week (typically Friday);
    the trailing partial week is retained. *)

type daily_view = {
  highs : float array;
      (** Daily high prices, oldest at index 0, newest at index [n_days - 1]. *)
  lows : float array;  (** Daily low prices, same indexing as [highs]. *)
  closes : float array;  (** Daily adjusted closes, same indexing. *)
  dates : Core.Date.t array;  (** Daily dates, same indexing. *)
  n_days : int;  (** Length of every array. *)
}
(** Float-array view of daily bars for one symbol within a lookback window. *)
