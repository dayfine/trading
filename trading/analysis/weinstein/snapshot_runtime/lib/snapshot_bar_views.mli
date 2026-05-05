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

type weekly_view = Data_panel.Bar_panels.weekly_view
(** Type-equal to {!Data_panel.Bar_panels.weekly_view} so the strategy's
    panel-callback constructors
    ({!Panel_callbacks.stage_callbacks_of_weekly_view} et al.) can consume views
    produced by either backing without a per-call adapter or variant dispatch.

    Phase F.2 PR 2 uses this equality to wire snapshot reads through the
    strategy in place of [Bar_panels.t]. PR 3 (Phase F.3) deletes
    {!Data_panel.Bar_panels} and hoists the record definition into a neutral
    location; the [type =] is the temporary bridge between PR 1 (this module
    standalone) and PR 3 (sole owner of the record).

    Field semantics — populated by {!weekly_view_for}:
    - [closes] = adjusted close of the last trading day in each weekly bucket
    - [raw_closes] = the [Snapshot_schema.Close] field's value at the last
      trading day of each weekly bucket (the un-adjusted close)
    - [highs] = max raw high within each weekly bucket
    - [lows] = min raw low within each weekly bucket
    - [volumes] = sum of raw daily volumes within each weekly bucket
    - [dates] = date of the last trading day in each weekly bucket (typically
      Friday for complete weeks, last traded day for partial / holiday weeks)
    - [n] = length of every array. *)

type daily_view = Data_panel.Bar_panels.daily_view
(** Type-equal to {!Data_panel.Bar_panels.daily_view} for the same reason as
    {!weekly_view}. Field semantics — populated by {!daily_view_for}:
    - [highs] = daily raw high prices, oldest at index 0
    - [lows] = daily raw low prices, same indexing
    - [closes] = daily raw closes (the [Snapshot_schema.Close] field), same
      indexing — matches {!Bar_panels.daily_view_for}, which also uses the raw
      close panel rather than the adjusted close panel
    - [dates] = daily dates, same indexing
    - [n_days] = length of every array. *)

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

    Window definition matches {!Data_panel.Bar_panels.daily_view_for}: walks the
    [lookback] weekday dates (Mon-Fri) ending at [as_of] inclusive — not the
    NYSE-trading-day calendar — and looks each up in the snapshot. Dates absent
    from the snapshot (holidays / pre-IPO / suspended days) and dates whose
    [Close] field is NaN are skipped, so [n_days] = [lookback] −
    [n_skipped_in_window]. The bar at index 0 is the oldest non-skipped bar.

    Returns the empty view ([n_days = 0], all arrays empty) when:
    - [lookback <= 0]
    - [as_of] is a Saturday or Sunday (matches the panel calendar's "no weekend
      columns" semantics — [Bar_panels.column_of_date] returns [None] for
      weekends and the panel caller treats that as empty)
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

    Reads the [Open], [Adjusted_close], [Close], [High], [Low], and [Volume]
    field histories from [cb] over a fixed-width calendar window (10 years ≈
    3653 days, conservatively wide so historical strategies see the symbol's
    full backtest history), aligns them by date, drops bars where [Close] is NaN
    or where any other read field has no row for the date, and returns the
    assembled list.

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
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t option
(** [low_window cb ~symbol ~as_of ~len] returns a freshly-allocated
    [Bigarray.Array1.t] holding [len] daily [Low] values ending on [as_of]
    (inclusive).

    Unlike {!Data_panel.Bar_panels.low_window}, the result is a copy, not a
    zero-copy panel slice — the snapshot path has no contiguous source array to
    slice. The buffer is owned by the caller; mutations are local.

    Window definition matches {!Data_panel.Bar_panels.low_window}: walks the
    [len] weekday dates (Mon-Fri) ending at [as_of] inclusive and fetches Low
    per date. Dates absent from the snapshot (holidays / pre-IPO / suspended
    days) are NaN-filled in the output (the panel slice contains the panel's NaN
    cells; this matches that). NaN Low values from the snapshot are also passed
    through. The caller (the support-floor primitive) decides what NaN means.

    Returns [None] when:
    - [len <= 0]
    - [as_of] is a Saturday or Sunday
    - [symbol] is not in the snapshot manifest
    - no resident snapshot rows fall in the resulting weekday window
    - the [Low] field read fails.

    [Some buf] guarantees [Bigarray.Array1.dim buf = len], with the most recent
    low at index [len - 1] (chronological order). *)
