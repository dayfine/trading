(** Bar source abstraction for the Weinstein strategy.

    Backend-agnostic facade over the OHLCV bar reads the strategy needs (daily
    bar lists, weekly aggregates, daily / weekly views). Two backings are
    available:

    - {!of_panels} — backed by {!Data_panel.Bar_panels}, the in-memory panel
      reader populated up-front from CSV at runner start. The default for
      pre-Phase-F.2 runs.
    - {!of_snapshot_views} — backed by {!Snapshot_runtime.Snapshot_callbacks},
      the LRU-bounded daily-snapshot reader that streams rows from per-symbol
      [.snap] files on demand. Used by snapshot-mode runs (Phase F.2 PR 2),
      which skip the {!Bar_panels.t} build entirely.

    Internally [Bar_reader.t] is a record of closures; the constructors capture
    their backing's read primitives and produce identical-shape closures, so the
    strategy's downstream callees see one bar-reading API regardless of backing.

    Stage 3 PR 3.2 collapsed the dual-backend ([Bar_history] | [Bar_panels])
    abstraction into a single panel-backed reader. Phase F.2 PR 2 generalised
    [t] to closure-based and re-introduced a second backing — but this time the
    backings are purely an internal swap (no variant in [t], no per-call
    dispatch) so callers can stay backend-agnostic and the hot-path remains a
    direct closure invocation. *)

open Core

type t
(** Opaque bar source. *)

val of_panels : ?ma_cache:Weekly_ma_cache.t -> Data_panel.Bar_panels.t -> t
(** [of_panels ?ma_cache p] produces a reader backed by [Bar_panels]. The
    [as_of] parameter of the read functions is mapped to a panel column via
    {!Data_panel.Bar_panels.column_of_date}; when [as_of] is not in the
    underlying calendar (e.g., a date before the backtest start) the reader
    returns the empty list.

    Stage 4 PR-D: an optional [ma_cache] piggy-backs on the reader so the
    strategy's hot-path callees can fetch per-symbol MA values from the cache
    without threading a separate parameter through every helper. Populated
    lazily by {!Weekly_ma_cache.ma_values_for} on first access. *)

val of_snapshot_views : Snapshot_runtime.Snapshot_callbacks.t -> t
(** [of_snapshot_views cb] produces a reader backed by
    {!Snapshot_runtime.Snapshot_bar_views} over [cb]. Reads fan out through
    {!Snapshot_runtime.Snapshot_callbacks.read_field_history} (LRU-bounded via
    {!Snapshot_runtime.Daily_panels}); per-call cost is O(window-size) plus an
    at-most-one-symbol disk read on cache miss.

    Returns the empty view / empty list under the same conditions as
    {!of_panels}: unknown symbol, [as_of] before any resident snapshot row, or
    any underlying field-read failure. The view types
    ({!Data_panel.Bar_panels.weekly_view} / [daily_view]) are the same as those
    returned by {!of_panels}, so {!Panel_callbacks} consumes either backing's
    views without modification.

    No [?ma_cache] parameter — the snapshot path does not currently use a
    pre-computed weekly MA cache because {!Snapshot_runtime.Daily_panels} is
    symbol-keyed (loading a symbol's full history on first access is cheap), so
    MA recomputation per call is bounded. The cache hook can be revisited if the
    snapshot hot path shows up in future profiles. *)

val ma_cache : t -> Weekly_ma_cache.t option
(** [ma_cache t] returns the cache the reader was constructed with, or [None]
    when no cache was provided. The strategy's panel-callback constructors check
    this and dispatch to the cache-aware path on [Some], falling back to inline
    MA computation on [None]. *)

val empty : unit -> t
(** [empty ()] produces a reader with an empty universe / zero-day calendar. All
    reads return the empty list. Useful for tests that exercise control paths
    where the strategy never reaches a panel-backed read (e.g., empty universe,
    no held positions). *)

val daily_bars_for :
  t -> symbol:string -> as_of:Date.t -> Types.Daily_price.t list
(** [daily_bars_for t ~symbol ~as_of] returns daily bars for [symbol] up to and
    including [as_of], in chronological order (oldest first).

    Bars are reconstructed from the panel columns [0..as_of_day]. Returns the
    empty list when the symbol has no resident bars or [as_of] is out of the
    panel calendar. *)

val weekly_bars_for :
  t -> symbol:string -> n:int -> as_of:Date.t -> Types.Daily_price.t list
(** [weekly_bars_for t ~symbol ~n ~as_of] returns the most recent [n]
    weekly-aggregated bars for [symbol] as of [as_of]. Same semantics as
    {!Data_panel.Bar_panels.weekly_bars_for}.

    Returns the empty list when the symbol has no resident bars or [as_of] is
    out of the panel calendar. *)

(** {1 Float-array views (Stage 4 PR-A)}

    Pass-throughs to the underlying {!Data_panel.Bar_panels} float-array
    primitives. Use these in production hot paths to avoid materialising a
    {!Types.Daily_price.t list} per call site per tick. *)

val weekly_view_for :
  t ->
  symbol:string ->
  n:int ->
  as_of:Date.t ->
  Data_panel.Bar_panels.weekly_view
(** [weekly_view_for t ~symbol ~n ~as_of] returns the panel weekly view of the
    most recent [n] weeks ending at [as_of]. Maps [as_of] to a panel column via
    {!Data_panel.Bar_panels.column_of_date}; returns the empty view when [as_of]
    is not in the calendar. *)

val daily_view_for :
  t ->
  symbol:string ->
  as_of:Date.t ->
  lookback:int ->
  Data_panel.Bar_panels.daily_view
(** [daily_view_for t ~symbol ~as_of ~lookback] returns the panel daily view of
    the most recent [lookback] days ending at [as_of]. Same calendar- fallback
    semantics as {!weekly_view_for}. *)
