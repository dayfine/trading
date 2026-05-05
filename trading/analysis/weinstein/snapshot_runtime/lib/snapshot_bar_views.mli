(** Bar-shaped views over {!Snapshot_callbacks.t}.

    Phase F.2 PR 1 of the daily-snapshot streaming pipeline (see
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase F).
    Reproduces the {!Data_panel.Bar_panels} view shapes ([weekly_view] /
    [daily_view] / [low_window]) on top of {!Snapshot_callbacks.t}, which is
    backed by an LRU-bounded {!Daily_panels.t} cache rather than a whole-
    universe × all-days bigarray panel.

    {2 Why a separate module}

    {!Bar_panels.t} allocates an [N x T] bigarray per OHLCV field at runner
    startup. At N = 5000 symbols × T ~= 2520 trading days × 6 fields × 8 bytes
    that is ~27 GB of resident memory and OOMs an 8 GB host. The snapshot path
    holds at most [max_cache_mb] of decoded snapshot rows at once; bar reads fan
    out through {!Snapshot_callbacks.read_field_history}.

    PR 1 (this module) builds the shim + tests. PR 2 wires it through
    [Panel_runner] / [Weinstein_strategy] in place of [Bar_panels.t].

    {2 Semantics — match {!Bar_panels} bit-for-bit}

    The weekly view uses ISO-week buckets via
    {!Time_period.Conversion.daily_to_weekly} with [include_partial_week:true],
    matching {!Bar_panels.weekly_view_for}'s aggregation rules:

    - [closes] = adjusted close of the last trading day in the week
    - [raw_closes] = raw close of the last trading day in the week
    - [highs] = max raw high within the week
    - [lows] = min raw low within the week
    - [volumes] = sum of raw volumes within the week
    - [dates] = date of the last trading day in the week

    The daily view drops bars where the raw [Close] field is NaN (matching
    {!Bar_panels.daily_view_for}'s NaN-skip), and exposes raw OHLC plus dates.

    Unknown symbols, empty date ranges, or otherwise-unreadable snapshot rows
    yield the empty view. This matches {!Bar_panels}'s "missing data → empty
    list" surface — the strategy already handles empty bar histories. The shim
    does not surface schema-skew or filesystem errors to the caller; those
    failures degrade to "no bars" here. (PR 2 wiring sites can re-add explicit
    error handling if needed; today's [Bar_panels] callers don't have it
    either.)

    {2 Calling convention vs {!Bar_panels}}

    {!Bar_panels} takes [as_of_day:int] (a calendar column index). The snapshot
    path is keyed by date, so this module takes [as_of:Core.Date.t]. The
    strategy already has the date in scope (read from the primary index bar each
    tick), so the swap at the call site is straightforward.

    {!low_window} returns a freshly-allocated {!Bigarray.Array1.t} (a copy of
    the relevant Low-field history). {!Bar_panels.low_window} returned a
    zero-copy [Bigarray.Array2.sub_left] slice over its panel; the snapshot
    backing has no equivalent contiguous panel to slice, so the snapshot version
    owns its own buffer. Memory cost: at most [len * 8] bytes per call, freed by
    the GC. *)

type weekly_view = {
  closes : float array;
      (** Adjusted close per weekly bar (chronological, oldest at index 0). *)
  raw_closes : float array;
      (** Raw (un-adjusted) close per weekly bar — the close panel's value at
          the last trading day of each weekly bucket. Used together with
          [closes] to compute per-bar split-adjustment factors
          ([closes.(i) /. raw_closes.(i)]). The factor stays constant for spans
          without splits and changes at split boundaries (G14 — see
          [dev/notes/g14-deep-dive-2026-05-01.md]). *)
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
    the trailing partial week is retained.

    {b Phase F.3.e-1 (canonical home)}: this is now the canonical definition.
    [Data_panel.Bar_panels.weekly_view] aliases this type via [type =] until
    F.3.e-3 deletes {!Data_panel.Bar_panels} entirely. *)

type daily_view = {
  highs : float array;
      (** Daily high prices, oldest at index 0, newest at index [n_days - 1]. *)
  lows : float array;  (** Daily low prices, same indexing as [highs]. *)
  closes : float array;  (** Daily adjusted closes, same indexing. *)
  dates : Core.Date.t array;  (** Daily dates, same indexing. *)
  n_days : int;  (** Length of every array. *)
}
(** Float-array view of daily bars for one symbol within a lookback window.

    Used by {!Weinstein_stops.compute_initial_stop_with_floor} via the
    support-floor callbacks. The lookback windowing is applied at construction
    time, so the consumer scans [0..n_days-1] without further bounds checks.

    {b Phase F.3.e-1 (canonical home)}: aliased by
    [Data_panel.Bar_panels.daily_view] until F.3.e-3 deletes that module. *)

val weekly_view_for :
  Snapshot_callbacks.t ->
  symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  weekly_view
(** [weekly_view_for cb ~symbol ~n ~as_of] returns the most recent [n] weekly
    buckets ending on or before [as_of] for [symbol], using
    {!Snapshot_callbacks} as the data source.

    Walks back enough calendar days to cover [n] weeks plus weekend / holiday
    slack, fetches the [Adjusted_close], [Close], [High], [Low], and [Volume]
    histories from [cb], assembles per-day [Daily_price.t] tuples (NaN-skipped
    on the [Close] field), aggregates to weekly via
    {!Time_period.Conversion.daily_to_weekly} with [include_partial_week:true],
    and truncates the result to the most recent [n] buckets.

    Returns the empty view ([n = 0], all arrays empty) when:
    - [n <= 0]
    - [symbol] is not in the snapshot manifest
    - no resident snapshot rows fall in the calendar window
    - any required field read fails (schema skew, filesystem error). *)

val daily_view_for :
  Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  lookback:int ->
  calendar:Core.Date.t array ->
  daily_view
(** [daily_view_for cb ~symbol ~as_of ~lookback ~calendar] returns up to
    [lookback] daily bars ending at [as_of] for [symbol], walking [calendar]'s
    columns to determine which dates to include.

    The [~calendar] parameter is the trading-day calendar (Mon–Fri including
    holidays in the production runner — see [Panel_runner._build_calendar]) that
    the panel-backed reader uses internally. Passing the same calendar here
    makes the snapshot path's window definition bit-equal to
    [Bar_panels.daily_view_for]'s, closing #848. The fix walks
    [calendar.(as_of_idx - lookback + 1 .. as_of_idx)], looks up the snapshot
    row for each calendar date (NaN-passthrough on missing rows), and NaN-skips
    per close cell — the same per-cell semantics as the panel path's
    [_read_row_cells].

    Returns the empty view ([n_days = 0], all arrays empty) when:
    - [lookback <= 0]
    - [as_of] is not present in [calendar] (matches
      [Bar_panels.column_of_date]'s exact-match contract)
    - [symbol] is not in the snapshot manifest
    - no resident snapshot rows fall in the calendar window
    - any required field read fails. *)

val daily_bars_for :
  Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  Types.Daily_price.t list
(** [daily_bars_for cb ~symbol ~as_of] returns daily bars for [symbol] up to and
    including [as_of], in chronological order (oldest first). Used by
    {!Bar_reader.of_snapshot_views} to satisfy the [Bar_reader.daily_bars_for]
    surface (consumed by [Stops_split_runner._last_two_bars] for split detection
    and [Entry_audit_capture._effective_entry_price]).

    Reads the [Adjusted_close], [Close], [High], [Low], and [Volume] field
    histories from [cb] over a fixed-width calendar window (10 years ≈ 3653
    days, conservatively wide so historical strategies see the symbol's full
    backtest history), aligns them by date, drops bars where [Close] is NaN, and
    returns the assembled list.

    {b open_price.} The [Snapshot_schema.Open] field is read from the snapshot
    row alongside the other OHLCV fields, so [open_price] matches the panel
    path's [Bar_panels.daily_bars_for] cell-for-cell. Days where the snapshot
    has no row degrade to [Float.nan], mirroring the panel's NaN cell. (Pre-#848
    the field was hard-coded to NaN; the schema has included [Open] since Phase
    A.1, the read just wasn't wired.)

    Returns the empty list when:
    - [symbol] is not in the snapshot manifest
    - no resident snapshot rows fall in the calendar window
    - any required field read fails. *)

val weekly_bars_for :
  Snapshot_callbacks.t ->
  symbol:string ->
  n:int ->
  as_of:Core.Date.t ->
  Types.Daily_price.t list
(** [weekly_bars_for cb ~symbol ~n ~as_of] returns the most recent [n]
    weekly-aggregated bars for [symbol] as of [as_of], in chronological order.
    Same aggregation rules as {!weekly_view_for} (ISO-week buckets,
    [include_partial_week:true]).

    Returns the empty list when [n <= 0] or under the same conditions as
    {!daily_bars_for}. *)

val low_window :
  Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  len:int ->
  calendar:Core.Date.t array ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t option
(** [low_window cb ~symbol ~as_of ~len ~calendar] returns a freshly-allocated
    [Bigarray.Array1.t] holding [len] daily [Low] values over the calendar
    columns [as_of_idx - len + 1 .. as_of_idx], where [as_of_idx] is the index
    of [as_of] in [calendar].

    The [~calendar] parameter is the trading-day calendar (Mon–Fri including
    holidays) the panel-backed reader uses internally — passing the same
    calendar makes the snapshot path bit-equal to {!Bar_panels.low_window}'s
    panel-slice semantics (#848 forward fix). Cells where the snapshot has no
    row for the calendar date are filled with [Float.nan]; this matches the
    panel's NaN-cell behaviour.

    Unlike {!Data_panel.Bar_panels.low_window}, the result is a copy, not a
    zero-copy panel slice — the snapshot path has no contiguous source array to
    slice. The buffer is owned by the caller; mutations are local.

    Returns [None] when:
    - [len <= 0]
    - [as_of] is not present in [calendar]
    - the window underflows the calendar's start ([as_of_idx - len + 1 < 0])
    - [symbol] is not in the snapshot manifest (the underlying
      {!Snapshot_callbacks.read_field_history} returns [Error]).

    [Some buf] guarantees [Bigarray.Array1.dim buf = len], with the most recent
    low at index [len - 1] (chronological order). *)
