(** Phase C runtime: per-symbol snapshot cache with LRU eviction.

    Phase C of the daily-snapshot streaming pipeline (see
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase C).
    {!Daily_panels.t} sits on top of the directory of per-symbol snapshot files
    written by Phase B and exposes per-(symbol, date) reads to the strategy
    runtime, with a bounded in-memory cache that evicts the least-recently-used
    symbol once a configurable byte budget is exceeded.

    {2 Why "per-symbol" and not "per-day"}

    The Phase B writer produces one [<output-dir>/<SYMBOL>.snap] per universe
    symbol — every date for that symbol lives in one file (see
    [snapshot_pipeline/lib/pipeline.mli] and the directory manifest at
    [<output-dir>/manifest.sexp]). Strategy hot reads are "for symbol X, what
    was its snapshot on day D?" or "the last 30 days of X leading up to D". A
    per-symbol file lets a single load satisfy any window of dates for one
    symbol; a per-date file would force [N] file reads to serve a 30-day history
    for one symbol.

    {2 "mmap" in Phase C}

    Phase A's file format is sexp-encoded ([Snapshot_format] header docstring),
    so the cache cannot literally [Bigarray.map_file] cells today. Phase C uses
    "mmap-style" semantics in spirit — the entire file is decoded into a
    [Snapshot.t list] on first access for a symbol, held in the cache until
    evicted. Plan §C5 calls out the eventual upgrade to a raw-bytes payload with
    [Bigarray.Array2.map_file] (Phase F); the API surface here is shaped so that
    swap is local to {!Daily_panels} — [read_today] / [read_history] callers
    don't see the difference. Until then, eviction is via dropping the
    OCaml-heap rows and letting the GC reclaim them.

    {2 Memory budget}

    Plan §C5: at N=10K symbols × 30-day window, ~22 MB of snapshot rows live in
    the cache window. {!create}'s [max_cache_mb] sets a hard ceiling; once
    inserting a new symbol's rows would push total tracked bytes above the cap,
    the LRU symbol is evicted. The byte estimate is conservative (each row is
    [Snapshot_schema.n_fields schema * 8] bytes plus per-row OCaml overhead), so
    the actual memory pressure stays at or below the configured cap.

    {2 Concurrency}

    {!Daily_panels.t} is not thread-safe. The simulator runs single-threaded
    today; Phase D integrates the runtime with the simulator under that
    assumption. Adding a mutex around the cache + LRU list would suffice for
    multi-threaded callers if that ever becomes a need; deferring it is a
    deliberate scope choice. *)

type t
(** Opaque cache handle. Backed by:

    - the directory's manifest (read at {!create} time),
    - the schema the manifest was written under,
    - a byte-budget cap, and
    - an internal per-symbol cache that maps symbol → loaded snapshot rows,
      ordered by recency for LRU eviction. *)

val create :
  snapshot_dir:string ->
  manifest:Snapshot_pipeline.Snapshot_manifest.t ->
  max_cache_mb:int ->
  t Status.status_or
(** [create ~snapshot_dir ~manifest ~max_cache_mb] builds a cache rooted at
    [snapshot_dir]. The [manifest] indexes per-symbol snapshot files (typically
    obtained via [Snapshot_pipeline.Snapshot_manifest.read]); the runtime uses
    the manifest's [schema] field as the expected schema for every file it opens
    (schema-skew → loud error per {!read_today} / {!read_history}).

    [snapshot_dir] is the directory containing the per-symbol [<SYMBOL>.snap]
    files. Manifest entries' [path] fields may be absolute or relative; when
    relative they are resolved against [snapshot_dir]. The directory is not
    scanned eagerly — files are opened lazily on first access for a symbol.

    [max_cache_mb] is the LRU byte cap in megabytes (1 MB = 1,048,576 bytes).
    Must be positive. The smallest sensible value is enough to hold one symbol's
    full file (Phase B writes a few hundred KB per symbol at T=2520 days × 7
    fields × 8 bytes ≈ 140 KB).

    Returns [Error Invalid_argument] when [max_cache_mb <= 0]. *)

val schema : t -> Data_panel_snapshot.Snapshot_schema.t
(** [schema t] returns the schema all files under this cache must conform to.
    Same value as [t]'s manifest's [schema]. *)

val read_today :
  t ->
  symbol:string ->
  date:Core.Date.t ->
  Data_panel_snapshot.Snapshot.t Status.status_or
(** [read_today t ~symbol ~date] returns the snapshot row for [symbol] on
    [date]. Loads the symbol's snapshot file via the LRU cache.

    Errors:
    - [Error NotFound] when [symbol] is not in the manifest
    - [Error NotFound] when [symbol]'s file does not contain a row dated [date]
    - [Error Failed_precondition] when the file's schema-hash differs from the
      manifest's expected schema-hash (loud schema-drift detection per
      [Snapshot_format.read_with_expected_schema])
    - [Error Internal] for filesystem / decode errors *)

val read_history :
  t ->
  symbol:string ->
  from:Core.Date.t ->
  until:Core.Date.t ->
  Data_panel_snapshot.Snapshot.t list Status.status_or
(** [read_history t ~symbol ~from ~until] returns the snapshot rows for [symbol]
    whose date falls in the inclusive range [[from, until]], ordered
    chronologically (oldest first).

    The window may legitimately be empty when no rows fall in the range (e.g.
    [until < from], or pre-IPO dates) — the result is [Ok []], not an error.
    [Error] is reserved for hard failures (unknown symbol, schema skew, decode
    error).

    Errors are the same as {!read_today} except a date with no matching row
    yields [Ok []] rather than [Error NotFound]. *)

val cache_bytes : t -> int
(** [cache_bytes t] returns the current sum of estimated bytes resident in the
    cache. Useful for tests that assert eviction kicked in. *)

val close : t -> unit
(** [close t] drops every cached symbol. After {!close}, [t] is logically empty;
    subsequent {!read_today} / {!read_history} calls will reload from disk on
    demand. The handle is otherwise still usable.

    Provided so callers (notably the simulator in Phase D) can release snapshot
    memory at well-defined points (e.g. between scenarios). *)
