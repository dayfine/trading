(** Columnar memory-mapped on-disk format (v2) for a single symbol's dense daily
    {!Snapshot.t} series.

    This is the Phase-C "partial decode" format: a struct-of-arrays (kdb-style
    "splayed") layout on {!Core_unix.map_file} that supports {b range pruning}
    (binary-search the sorted date index, then map only the matching row range)
    and — in later steps — {b column pruning} (page-fault only the columns a
    caller reads). It lives {b alongside} the v1 sexp format {!Snapshot_format};
    v1 is retained until the warehouse is regenerated.

    {2 On-disk layout}

    One file holds one symbol's full daily series, sorted by date ascending. All
    multi-byte integers and all floats are stored {b little-endian} (the writer
    uses [Stdlib.Bytes.set_int64_le] / [set_int32_le]).

    {v
      magic        : 8 bytes  = "SNAPCOL1"
      header_len   : int32 LE = byte length of the header block
      header       : { format_version : int32; n_rows : int32;
                         n_fields : int32;
                         schema_hash : len-prefixed string;
                         symbol : len-prefixed string }
      dates        : int32[n_rows]    epoch-days, SORTED ascending
      col_0        : float64[n_rows]  struct-of-arrays, one dense column per
      col_1        : float64[n_rows]    schema field, in schema (column) order
      ...
      col_{n-1}    : float64[n_rows]
    v}

    The [magic] + [format_version] gate v1-vs-v2 and corrupt files loudly: a v1
    sexp file (or any non-v2 file) fails at {!open_reader} with
    [Error Internal].

    {2 Date encoding}

    A [Core.Date.t] is stored as [int32] {b epoch-days} = [Date.diff date epoch]
    where [epoch = 1970-01-01]. Decoding is [Date.add_days epoch days]. Both are
    exact pure-day arithmetic, so the round-trip is exact for any representable
    date; [int32] epoch-days spans ±5.8M years. The date column is sorted
    ascending so [read_range] can binary-search it.

    {2 Float bit-identity}

    Float64 cells are stored as the raw IEEE-754 bits ([Int64.bits_of_float]),
    so the round-trip is bit-identical including [Float.nan] (the canonical "not
    computable" marker). No sexp text encoding is involved on the payload. *)

type reader
(** An opaque open handle over a memory-mapped v2 file. Holds the open fd, the
    decoded header, and the mapped (zero-copy) date index. Must be released with
    {!close} (or use {!with_reader}). *)

val write : path:string -> Snapshot.t list -> unit Status.status_or
(** [write ~path rows] serializes [rows] to [path] in the v2 columnar layout,
    overwriting any existing file.

    Preconditions (all [Error Invalid_argument] on violation):
    - every row shares one [schema.schema_hash] (mixed schemas rejected, same
      style as {!Snapshot_format.write});
    - every row shares one [symbol] (this format is single-symbol per file).

    The empty list is permitted and writes a header-only file using
    {!Snapshot_schema.default} and the empty symbol [""].

    Rows are sorted by [date] ascending before writing — input order is not
    assumed. Each row's [values] is column-aligned to [schema.fields]: on-disk
    column [c] holds [values.(c)] across all rows.

    Returns [Error Internal] if the underlying file write raises. *)

val open_reader : path:string -> reader Status.status_or
(** [open_reader ~path] opens [path], memory-maps it, and reads + validates the
    header.

    Returns [Error Internal "Snapshot_columnar: bad magic / not a v2 file"] when
    the leading bytes are not the v2 magic (e.g. a v1 {!Snapshot_format} sexp
    file), or [Error Internal] on an unexpected [format_version] or any I/O
    failure. The caller owns the returned handle and must {!close} it. *)

val close : reader -> unit
(** [close r] closes the underlying fd and drops references to the mapped
    bigarrays so the GC can reclaim them (which unmaps the file region).
    Idempotent: closing an already-closed reader is a no-op. *)

val with_reader :
  path:string -> f:(reader -> 'a Status.status_or) -> 'a Status.status_or
(** [with_reader ~path ~f] opens a reader, runs [f] on it, and always {!close}s
    it afterwards — even if [f] returns [Error] or raises. Use this to avoid
    leaking fds. If {!open_reader} fails, [f] is not run and the error is
    returned. *)

val read_all : reader -> Snapshot.t list Status.status_or
(** [read_all r] returns every row in the file, ordered chronologically (oldest
    first). Reconstructs full {!Snapshot.t} rows (all schema fields). *)

val read_range :
  reader ->
  from:Core.Date.t ->
  until:Core.Date.t ->
  Snapshot.t list Status.status_or
(** [read_range r ~from ~until] returns the rows whose date is in the inclusive
    range [[from, until]], ordered chronologically.

    The date index is binary-searched and only the matching row range is mapped
    ([Array1.sub]) — the prune is real. An empty range (including
    [until < from], a window entirely before the first date, or entirely after
    the last date) yields [Ok []], not an error — mirroring
    {!Daily_panels.read_history}.

    For S1, reconstructs full rows over the matching range; field-column pruning
    is a later step. *)

val read_with_expected_schema :
  path:string -> expected:Snapshot_schema.t -> Snapshot.t list Status.status_or
(** [read_with_expected_schema ~path ~expected] is {!open_reader} + {!read_all}
    (closing the reader) composed with a schema-hash gate: returns
    [Error Failed_precondition] when the file's [schema_hash] differs from
    [expected.schema_hash]. Mirrors {!Snapshot_format.read_with_expected_schema}
    — used by the runtime to refuse files produced under a different indicator
    set. *)
