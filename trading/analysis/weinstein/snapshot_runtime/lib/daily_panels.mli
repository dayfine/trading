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

    {2 Dual backing: mmap (v2) and decoded (v1 fallback)}

    A cache entry is one of two backings, chosen by {b format-detecting} each
    file's first bytes against the v2 columnar magic
    ([Snapshot_columnar_codec.magic]):

    - {b Mmap (v2)} — a columnar {!Data_panel_snapshot.Snapshot_columnar}
      reader. The file's columns are memory-mapped once at open; each read
      {b slices} the mapped columns over the requested date range. The OCaml
      heap holds only the reader handle (fd + header + the int32 date index +
      column descriptors); the float-column cells live in the OS page cache and
      fault in lazily, so a resident entry is cheap. This is the path the
      snapshot-format-v2 migration (S3/S4) moves the warehouses to.
    - {b Decoded (v1 fallback)} — for files still in the v1 sexp format
      ([Snapshot_format]), the entire file is decoded into a sorted
      [Snapshot.t array] on first access and held until evicted. This is the
      pre-v2 behaviour, preserved bit-for-bit so existing goldens are unaffected
      until the warehouse is regenerated in v2.

    Both backings are transparent to {!read_today} / {!read_history} callers —
    they see the same row-level results. A single cache may hold a mix of v1 and
    v2 files (e.g. during a partial migration).

    {2 Memory budget + open-handle cap}

    Two limits bound resident state, enforced by the same LRU eviction loop:

    - {b Byte budget.} {!create}'s [max_cache_mb] sets the heap-byte ceiling. A
      [Decoded] entry's bytes ≈ [n_rows * (n_fields * 8 + overhead)]; an [Mmap]
      entry's bytes is small (the int32 date array + a fixed per-handle constant
      — the column pages are page-cache resident, not counted). Once inserting a
      new symbol pushes tracked bytes above the cap, the LRU symbol is evicted.
    - {b Open-handle cap.} Each [Mmap] entry holds an open fd. An internal cap
      ([_max_open_mmap_handles], well under a typical 1024 fd ulimit) bounds the
      number of resident [Mmap] readers; the eviction loop closes the LRU
      reader's fd once the cap is exceeded, even if the byte budget alone would
      admit more. This is the "LRU for handle count" the v2 plan calls for and
      is {b not} a {!create} parameter.

    Evicting an [Mmap] entry {!Data_panel_snapshot.Snapshot_columnar.close}s its
    reader (releasing the fd + unmapping). {!close} closes every resident
    reader.

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
    - a byte-budget cap + an open-handle cap, and
    - an internal per-symbol cache that maps symbol → its loaded backing (an
      mmap reader for v2 files, decoded rows for v1), ordered by recency for LRU
      eviction. *)

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

val active_through_for : t -> symbol:string -> Core.Date.t option
(** [active_through_for t ~symbol] returns the per-symbol delisting marker
    recorded in the directory manifest's [file_metadata.active_through]. [None]
    when [symbol] is not in the manifest or its [active_through] field is absent
    (still trading / unknown). This is the seam the [Snapshot_callbacks] layer
    reads to populate [Daily_price.active_through] on every reconstituted bar;
    the screener PI filter consumes the propagated value via
    {!Bar_reader.daily_bars_for}. *)

val cache_bytes : t -> int
(** [cache_bytes t] returns the current sum of estimated bytes resident in the
    cache. Useful for tests that assert eviction kicked in. *)

type stats = { hits : int; misses : int; evictions : int }
[@@deriving sexp, equal]
(** Cumulative cache-access counters observed since {!create}.

    - [hits] — reads served from a resident (already-decoded) symbol entry.
    - [misses] — reads that had to load + decode a symbol file from disk. Each
      miss is one full sexp decode, the dominant per-read cost.
    - [evictions] — LRU evictions that actually dropped a resident entry to
      restore the byte budget.

    The decisive thrash metric is [misses / n_symbols]: ≈1 means each symbol was
    decoded roughly once (the cache held the working set), whereas a value
    approaching the number of strategy cycles means the cache is thrashing —
    every cycle re-decoding a symbol it just evicted. *)

val cache_stats : t -> stats
(** [cache_stats t] returns the cumulative {!stats} since {!create}. {!close}
    does not reset the counters — they measure lifetime cache behaviour, so a
    caller can read them after the run to diagnose cache thrash. *)

val close : t -> unit
(** [close t] drops every cached symbol, closing every resident mmap reader's fd
    (so no file descriptors leak). After {!close}, [t] is logically empty;
    subsequent {!read_today} / {!read_history} calls will reload from disk on
    demand. The handle is otherwise still usable.

    Provided so callers (notably the simulator in Phase D) can release snapshot
    memory + file descriptors at well-defined points (e.g. between scenarios).
*)
