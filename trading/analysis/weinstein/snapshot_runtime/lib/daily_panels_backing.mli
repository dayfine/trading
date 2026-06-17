(** The per-symbol backing store for {!Daily_panels}, with format detection.

    A cached symbol's data lives in one of two backings, chosen by inspecting
    the file's leading bytes against the v2 columnar magic
    ([Data_panel_snapshot.Snapshot_columnar_codec.magic]):

    - {b Mmap (v2)} — a {!Data_panel_snapshot.Snapshot_columnar} reader whose
      columns are memory-mapped once at open; reads slice the mapped columns on
      demand. Holds an open fd, so the cache caps the number of resident mmap
      backings.
    - {b Decoded (v1 fallback)} — the whole v1 sexp file decoded into a sorted
      [Snapshot.t array] on load, binary-searched by date.

    This module isolates the format-specific load + read logic so
    {!Daily_panels} stays the cache/LRU coordinator. It is intentionally
    counter-free: the open-handle accounting lives in {!Daily_panels.t}, which
    uses {!is_mmap} to know when a backing holds an fd. *)

type t =
  | Mmap of Data_panel_snapshot.Snapshot_columnar.reader
  | Decoded of Data_panel_snapshot.Snapshot.t array

val is_columnar_file : string -> bool
(** [is_columnar_file path] is [true] iff [path]'s leading bytes equal the v2
    columnar magic. A short, absent, or unreadable file reads as non-v2 (so the
    v1 decoder then surfaces the real error). *)

val load :
  path:string ->
  expected:Data_panel_snapshot.Snapshot_schema.t ->
  t Status.status_or
(** [load ~path ~expected] format-detects [path] and loads the matching backing,
    gating both formats on the schema hash:

    - v2 magic → an {!Mmap} reader; [Error Failed_precondition] on schema-hash
      skew (the reader is closed before returning).
    - otherwise → a {!Decoded} array via
      [Snapshot_format.read_with_expected_schema] (its own loud schema gate).

    [Error Internal] / [Error NotFound] propagate from the underlying reader on
    I/O or decode failure. *)

val is_mmap : t -> bool
(** [is_mmap b] is [true] for an {!Mmap} backing (which owns an open fd). The
    cache uses this to maintain its open-handle count. *)

val read_today :
  t ->
  symbol:string ->
  date:Core.Date.t ->
  Data_panel_snapshot.Snapshot.t Status.status_or
(** [read_today b ~symbol ~date] returns the row dated [date], or
    [Error NotFound] when the symbol has no row for that date (same message
    shape for both backings). *)

val read_history :
  t ->
  from:Core.Date.t ->
  until:Core.Date.t ->
  Data_panel_snapshot.Snapshot.t list Status.status_or
(** [read_history b ~from ~until] returns the rows whose date is in the
    inclusive range [[from, until]], chronological. An empty / inverted range
    yields [Ok []], never an error. *)

val estimate_bytes : schema:Data_panel_snapshot.Snapshot_schema.t -> t -> int
(** [estimate_bytes ~schema b] is the heap-byte contribution of [b] to the cache
    budget. A {!Decoded} backing's estimate scales with its row count; an
    {!Mmap} backing's is small (the mapped int32 date array + a fixed per-handle
    constant — the float-column pages are OS-page-cache resident, not counted).
*)

val close : t -> unit
(** [close b] releases the OS resources [b] holds. For {!Mmap} it closes the
    reader's fd (unmapping its columns); for {!Decoded} it is a no-op. *)
