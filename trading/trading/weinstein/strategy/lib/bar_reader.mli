(** Bar source abstraction for the Weinstein strategy.

    Backend-agnostic facade over the OHLCV bar reads the strategy needs (daily
    bar lists, weekly aggregates, daily / weekly views).

    - {!of_snapshot_views} — backed by {!Snapshot_runtime.Snapshot_callbacks},
      the LRU-bounded daily-snapshot reader that streams rows from per-symbol
      [.snap] files on demand. The production runner uses this for the strategy
      after the #848 forward fix landed (#864 + #866).
    - {!of_in_memory_bars} — convenience constructor that materialises a tmp
      snapshot directory from in-memory [(symbol, bars)] pairs. Used by tests
      and tools that hold bar histories in memory.
    - {!empty} — closures return the empty list / empty view on every call.
      Useful for tests that never reach a bar consumer.

    Internally [Bar_reader.t] is a record of closures; the constructors capture
    their backing's read primitives and produce identical-shape closures, so the
    strategy's downstream callees see one bar-reading API regardless of backing.

    {b Phase F.3.e-2 (#869)}: the legacy [Data_panel.Bar_panels]-backed
    [of_panels] constructor + [_panel_*] helpers were deleted; production code
    has been on {!of_snapshot_views} since #864/#866.

    {b Phase F.3.e-3}: [Data_panel.Bar_panels] itself was deleted; every reader
    is now snapshot-backed. *)

open Core

type t
(** Opaque bar source. *)

val of_snapshot_views :
  ?calendar:Date.t array -> Snapshot_runtime.Snapshot_callbacks.t -> t
(** [of_snapshot_views ?calendar cb] produces a reader backed by
    {!Snapshot_runtime.Snapshot_bar_views} over [cb]. Reads fan out through
    {!Snapshot_runtime.Snapshot_callbacks.read_field_history} (LRU-bounded via
    {!Snapshot_runtime.Daily_panels}); per-call cost is O(window-size) plus an
    at-most-one-symbol disk read on cache miss.

    The [?calendar] parameter is the trading-day calendar (Mon–Fri including
    holidays) the production runner uses. When supplied, [daily_view_for] walks
    calendar columns deterministically — the cell-by-cell parity surface that
    closed #848. When omitted, the reader synthesizes a Mon–Fri calendar bounded
    to each call's window; this is sufficient for tests and the in-memory
    convenience constructor but does not guarantee deterministic window
    definition at the boundary of long histories. The production runner should
    always pass its real calendar.

    Returns the empty view / empty list when the symbol is unknown, [as_of] is
    before any resident snapshot row, or any underlying field-read failure
    fires. {!Panel_callbacks} consumes the view types
    ({!Snapshot_runtime.Snapshot_bar_views.weekly_view} / [daily_view])
    directly. *)

val of_in_memory_bars : (string * Types.Daily_price.t list) list -> t
(** [of_in_memory_bars symbol_bars] produces a snapshot-backed reader from a
    list of in-memory [(symbol, bars)] pairs.

    Convenience constructor for tests and tools that hold bar histories in
    memory (rather than reading them from a CSV corpus). Materialises a tmp
    snapshot directory and routes reads through {!of_snapshot_views} — no panel
    allocation.

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
    when no cache was provided. After F.3.e-2 every constructor sets this to
    [None]; the strategy's cache-aware MA paths now route through
    {!Panel_callbacks.X_of_snapshot_views}'s built-in caching. Kept on the
    public surface so existing strategy callsites
    ([Bar_reader.ma_cache bar_reader]) continue to compile and degrade to the
    inline-MA path uniformly. *)

val snapshot_callbacks : t -> Snapshot_runtime.Snapshot_callbacks.t
(** [snapshot_callbacks t] returns the underlying field-accessor shim for
    snapshot-backed readers ({!of_snapshot_views} / {!of_in_memory_bars}).
    Consumed by the strategy's macro / sector entry points (Phase F.3.b-2 / c-2
    / d-2 caller migration) via the [*_of_snapshot_views] APIs on
    {!Macro_inputs}.

    For empty readers ({!empty}), returns a sentinel cb whose every [read_field]
    / [read_field_history] returns [Error NotFound].
    {!Snapshot_runtime.Snapshot_bar_views} folds these NotFound results to the
    empty view / empty list, so callers see the "no bars" surface that matches
    {!empty}'s contract. Production runs use only snapshot-backed readers, so
    the sentinel is exercised only in tests that never reach a macro / sector
    read (typically the no-primary-bar short-circuit in [_on_market_close]). *)

val empty : unit -> t
(** [empty ()] produces a reader whose every read returns the empty list / empty
    view. Useful for tests that exercise control paths where the strategy never
    reaches a bar read (e.g., empty universe, no held positions).

    Opens no snapshot directory — the closures are direct empty-returning
    lambdas. *)

val daily_bars_for :
  t -> symbol:string -> as_of:Date.t -> Types.Daily_price.t list
(** [daily_bars_for t ~symbol ~as_of] returns daily bars for [symbol] up to and
    including [as_of], in chronological order (oldest first). Returns the empty
    list when the symbol has no resident bars or [as_of] is before any resident
    snapshot row. *)

val weekly_bars_for :
  t -> symbol:string -> n:int -> as_of:Date.t -> Types.Daily_price.t list
(** [weekly_bars_for t ~symbol ~n ~as_of] returns the most recent [n]
    weekly-aggregated bars for [symbol] as of [as_of]. Same aggregation
    semantics as {!Snapshot_runtime.Snapshot_bar_views.weekly_bars_for}. *)

(** {1 Float-array views (Stage 4 PR-A)}

    Pass-throughs to the underlying {!Snapshot_runtime.Snapshot_bar_views}
    float-array primitives. Use these in production hot paths to avoid
    materialising a {!Types.Daily_price.t list} per call site per tick. *)

val weekly_view_for :
  t ->
  symbol:string ->
  n:int ->
  as_of:Date.t ->
  Snapshot_runtime.Snapshot_bar_views.weekly_view
(** [weekly_view_for t ~symbol ~n ~as_of] returns the snapshot weekly view of
    the most recent [n] weeks ending at [as_of]. Returns the empty view when
    [as_of] is before any resident snapshot row. *)

val daily_view_for :
  t ->
  symbol:string ->
  as_of:Date.t ->
  lookback:int ->
  Snapshot_runtime.Snapshot_bar_views.daily_view
(** [daily_view_for t ~symbol ~as_of ~lookback] returns the snapshot daily view
    of the most recent [lookback] days ending at [as_of]. Same calendar fallback
    semantics as {!of_snapshot_views}'s [?calendar] parameter (uses a
    synthesized Mon–Fri calendar when none was supplied at construction). *)
