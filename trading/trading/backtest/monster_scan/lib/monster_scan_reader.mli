(** Thin read-only adapter from a snapshot warehouse to the weekly bar arrays
    {!Monster_scan_analytics} consumes.

    No new binary parser lives here: the [.snap] daily columns are read through
    {!Data_panel_snapshot.Snapshot_columnar} (the same reader the panel runtime
    uses), rescaled onto the split/dividend-adjusted basis by
    {!Snapshot_pipeline.Adjusted_basis}, and folded to weeks by
    {!Snapshot_pipeline.Weekly_prefix} — whose aggregation is documented to be
    bit-identical to [Time_period.Conversion.daily_to_weekly]. This module
    invents no aggregation and no price basis of its own. *)

val symbols : snapshot_dir:string -> string list Status.status_or
(** [symbols ~snapshot_dir] lists the symbols the warehouse holds a [.snap]
    panel for, sorted ascending so a scan's output order is deterministic across
    runs and filesystems. Returns [Error Internal] when [snapshot_dir] cannot be
    read. *)

val weekly_bars :
  snapshot_dir:string ->
  symbol:string ->
  Types.Daily_price.t array Status.status_or
(** [weekly_bars ~snapshot_dir ~symbol] reads [<snapshot_dir>/<symbol>.snap] and
    returns its complete ISO weeks, chronological oldest first, on the adjusted
    price basis (open/high/low rescaled by [adjusted_close /. close];
    [close_price] is [adjusted_close]). Volume is the week's summed RAW share
    volume — the warehouse carries no adjusted volume.

    The trailing partial week is excluded: a breakout scored mid-week is not a
    decision-time-stable event, and every consumer here works at week close.

    Returns [Error Not_found] when the [.snap] file is absent, and
    [Error Internal] when it is present but unreadable. A file with no daily
    rows yields an empty array (not an error) — an empty history is a legitimate
    warehouse state, and every analytics entry point already declines a series
    too short for its window. *)
