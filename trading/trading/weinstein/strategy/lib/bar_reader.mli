(** Bar source abstraction for the Weinstein strategy.

    Backend-agnostic facade over the OHLCV bar reads the strategy needs (daily
    bar lists, weekly aggregates, daily / weekly views).

    - {!of_snapshot_views} — backed by {!Snapshot_runtime.Snapshot_callbacks},
      the LRU-bounded daily-snapshot reader that streams rows from per-symbol
      [.snap] files on demand. The canonical production constructor for runs
      with a pre-built snapshot directory.
    - {!of_in_memory_bars} — convenience constructor that materialises a tmp
      snapshot directory from in-memory [(symbol, bars)] pairs. Used by tests
      and tools that hold bar histories in memory.
    - {!empty} — closures return the empty list / empty view on every call.
      Useful for tests that never reach a bar consumer.

    Internally [Bar_reader.t] is a record of closures; the constructors capture
    their backing's read primitives and produce identical-shape closures, so the
    strategy's downstream callees see one bar-reading API regardless of backing.

    Phase F.3.a-4 (2026-05-04) retired [of_panels] and the legacy
    {!Data_panel.Bar_panels} backing — every reader now routes through the
    snapshot path. *)

open Core

type t
(** Opaque bar source. *)

val of_snapshot_views : Snapshot_runtime.Snapshot_callbacks.t -> t
(** [of_snapshot_views cb] produces a reader backed by
    {!Snapshot_runtime.Snapshot_bar_views} over [cb]. Reads fan out through
    {!Snapshot_runtime.Snapshot_callbacks.read_field_history} (LRU-bounded via
    {!Snapshot_runtime.Daily_panels}); per-call cost is O(window-size) plus an
    at-most-one-symbol disk read on cache miss.

    Returns the empty view / empty list when the symbol is unknown, [as_of] is
    before any resident snapshot row, or any underlying field-read failure
    fires. The view types ({!Data_panel.Bar_panels.weekly_view} / [daily_view])
    are shared with the panel module's view definitions for historical reasons;
    {!Panel_callbacks} consumes them directly. *)

val of_in_memory_bars : (string * Types.Daily_price.t list) list -> t
(** [of_in_memory_bars symbol_bars] produces a snapshot-backed reader from a
    list of in-memory [(symbol, bars)] pairs.

    Convenience constructor for tests and tools that hold bar histories in
    memory (rather than reading them from a CSV corpus). Materialises a tmp
    snapshot directory and routes reads through {!of_snapshot_views} — no
    {!Data_panel.Bar_panels.t} allocation.

    Internally: 1. A fresh tmp directory is allocated via
    [Stdlib.Filename.temp_dir]. 2. For each [(symbol, bars)] pair,
    {!Snapshot_pipeline.Pipeline.build_for_symbol} computes per-day
    {!Snapshot.t} rows under {!Snapshot_schema.default} and
    {!Snapshot_format.write} serialises them to [<tmp>/<symbol>.snap]. No
    benchmark is supplied, so [RS_line] / [Macro_composite] columns are
    [Float.nan]; the bar-shaped views ({!Snapshot_bar_views}) only read the
    OHLCV columns, so the strategy's bar reads are unaffected. 3. A directory
    manifest is written to [<tmp>/manifest.sexp]. 4. A
    {!Snapshot_runtime.Daily_panels.t} is opened over the tmp dir with a small
    in-memory cache cap, and a {!Snapshot_runtime.Snapshot_callbacks.t} is built
    over it. 5. The result is the same closure-shaped reader returned by
    {!of_snapshot_views}.

    The tmp directory is left in place after the function returns — the
    [Daily_panels.t] reads from it lazily on each cache miss. Callers that care
    about cleanup (long-running tests, perf rigs) should plumb a teardown hook;
    for short-lived test usage the OS reaps it on reboot.

    Returns a reader that fails-soft on bad inputs the same way
    {!of_snapshot_views} does — unknown symbol returns the empty list / empty
    view. Raises [Failure] only on filesystem / pipeline errors that indicate a
    programming mistake (e.g., schema validation failed during write). *)

val ma_cache : t -> Weekly_ma_cache.t option
(** [ma_cache t] returns the cache the reader was constructed with, or [None]
    when no cache was provided. After Phase F.3.a-4 retired the panel-backed
    [of_panels] constructor every reader sets this to [None]; the accessor and
    the strategy's cache-aware paths remain wired but inactive until a follow-up
    cleanup removes them. *)

val empty : unit -> t
(** [empty ()] produces a reader whose every read returns the empty list / empty
    view. Useful for tests that exercise control paths where the strategy never
    reaches a bar read (e.g., empty universe, no held positions).

    Opens no snapshot directory — the closures are direct empty-returning
    lambdas. *)

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
