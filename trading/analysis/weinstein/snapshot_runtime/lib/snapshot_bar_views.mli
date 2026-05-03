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
      (** Raw (un-adjusted) close per weekly bar — the [Snapshot_schema.Close]
          field's value at the last trading day of each weekly bucket. Used
          together with [closes] to compute per-bar split-adjustment factors
          ([closes.(i) /. raw_closes.(i)]). *)
  highs : float array;  (** Max raw high within each weekly bucket. *)
  lows : float array;  (** Min raw low within each weekly bucket. *)
  volumes : float array;
      (** Sum of raw daily volumes within each weekly bucket. Stored as float to
          align with the snapshot column layout. *)
  dates : Core.Date.t array;
      (** Date of the last trading day in each weekly bucket (typically Friday
          for complete weeks, last traded day for partial / holiday weeks). *)
  n : int;  (** Length of every array. *)
}
(** Float-array view of weekly-aggregated bars for one symbol — same shape as
    {!Data_panel.Bar_panels.weekly_view}. *)

type daily_view = {
  highs : float array;
      (** Daily raw high prices, oldest at index 0, newest at index
          [n_days - 1]. *)
  lows : float array;  (** Daily raw low prices, same indexing as [highs]. *)
  closes : float array;
      (** Daily raw closes (the [Snapshot_schema.Close] field), same indexing.
      *)
  dates : Core.Date.t array;  (** Daily dates, same indexing. *)
  n_days : int;  (** Length of every array. *)
}
(** Float-array view of daily bars for one symbol within a lookback window —
    same shape as {!Data_panel.Bar_panels.daily_view}. *)

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
  daily_view
(** [daily_view_for cb ~symbol ~as_of ~lookback] returns up to [lookback] daily
    bars ending on or before [as_of] for [symbol].

    Reads the [High], [Low], [Close] field histories from [cb] over a calendar
    window slightly longer than [lookback] (to account for weekends / holidays
    in the date-keyed range), aligns them by date, drops bars where [Close] is
    NaN, and truncates to the trailing [lookback] entries.

    Returns the empty view ([n_days = 0], all arrays empty) when:
    - [lookback <= 0]
    - [symbol] is not in the snapshot manifest
    - no resident snapshot rows fall in the calendar window
    - any required field read fails. *)

val low_window :
  Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  len:int ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t option
(** [low_window cb ~symbol ~as_of ~len] returns a freshly-allocated
    [Bigarray.Array1.t] holding [len] daily [Low] values ending on [as_of]
    (inclusive).

    Unlike {!Data_panel.Bar_panels.low_window}, the result is a copy, not a
    zero-copy panel slice — the snapshot path has no contiguous source array to
    slice. The buffer is owned by the caller; mutations are local.

    Returns [None] when:
    - [len <= 0]
    - [symbol] is not in the snapshot manifest
    - the snapshot has fewer than [len] resident bars ending at [as_of]
    - the [Low] field read fails.

    [Some buf] guarantees [Bigarray.Array1.dim buf = len], with the most recent
    low at index [len - 1] (chronological order). *)
