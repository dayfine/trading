(** Directory-level manifest for a snapshot warehouse built by Phase B.

    Phase B writes one {!Snapshot_format} file per universe symbol under
    [<output-dir>/<SYMBOL>.snap]. The directory manifest at
    [<output-dir>/manifest.sexp] records the schema used + per-symbol file
    metadata (path, byte size, payload md5, mtime).

    The manifest enables:
    - {b Incremental rebuild}: a second run of [bin/build_snapshots.exe]
      compares each universe symbol's CSV mtime against its manifest entry's
      [csv_mtime]; symbols whose CSV is unchanged are skipped (file already on
      disk, valid).
    - {b Schema drift detection}: the runtime layer (Phase C) reads the
      manifest's [schema_hash] and refuses to mmap files produced under a
      different indicator set.
    - {b Verification}: {!Snapshot_verifier.verify_directory} round-trips every
      file using the manifest as the index.

    Phase B does not include cross-file integrity (e.g. universe-wide hash) —
    each file is self-checking via {!Snapshot_format.read}. The manifest is a
    convenience index; the source of truth for byte-level integrity is the
    individual snapshot file's own header. *)

type file_metadata = {
  symbol : string;  (** Universe ticker, e.g. ["AAPL"]. *)
  path : string;
      (** Path to the snapshot file. Absolute or relative to the manifest
          location depending on how the writer was invoked. *)
  byte_size : int;  (** File size in bytes at write time. *)
  payload_md5 : string;
      (** Hex md5 of the file's payload section (mirrors the file's own
          [Snapshot_format] manifest). Recorded in the directory manifest so a
          subsequent run can detect tampering without opening every file. *)
  csv_mtime : float;
      (** Unix mtime of the source CSV at the time this snapshot was built.
          Drives the incremental-rebuild predicate: a CSV with [mtime > this]
          forces a rebuild for the symbol. *)
}
[@@deriving sexp, compare, equal]
(** Per-symbol metadata recorded in the directory manifest. *)

type t = {
  schema_hash : string;
      (** [Snapshot_schema.t.schema_hash] of the schema used to build every file
          in this directory. Used by the runtime to refuse a directory built
          under a different indicator set. *)
  schema : Data_panel_snapshot.Snapshot_schema.t;
      (** Full schema (fields + hash) so consumers can validate column layout,
          not just the hash. *)
  entries : file_metadata list;
      (** One entry per universe symbol that has a snapshot file in this
          directory. Order is the order the writer enumerated symbols. *)
}
[@@deriving sexp]
(** Directory manifest. *)

val create :
  schema:Data_panel_snapshot.Snapshot_schema.t ->
  entries:file_metadata list ->
  t
(** [create ~schema ~entries] constructs a manifest. The [schema_hash] field is
    set from [schema.schema_hash]; the [entries] are stored in the order given.
*)

val write : path:string -> t -> unit Status.status_or
(** [write ~path manifest] serializes [manifest] to [path] using
    [Sexp.to_string_hum] for human-readable diff-friendly output. Overwrites any
    existing file. Returns [Error Internal] on a filesystem error. *)

val read : path:string -> t Status.status_or
(** [read ~path] deserializes a manifest written by {!write}. Returns
    [Error Internal] on parse failure or filesystem error, [Error Not_found] if
    [path] does not exist. *)

val find : t -> symbol:string -> file_metadata option
(** [find t ~symbol] returns the entry for [symbol], or [None] if absent. O(N)
    in the entry count — Phase B universes (≤ 10K) scan in microseconds; if
    Phase C demands faster lookup it can build a hashtable on top. *)

val upsert_entry : t -> file_metadata -> t
(** [upsert_entry t entry] returns a manifest with [entry] added (if no entry
    matches its [symbol]) or replaced (if an entry for that symbol already
    exists). Pure: does not touch disk. The relative order of other entries is
    preserved; an inserted entry is appended at the end. *)

val update_for_symbol :
  path:string ->
  schema:Data_panel_snapshot.Snapshot_schema.t ->
  file_metadata ->
  unit Status.status_or
(** [update_for_symbol ~path ~schema entry] atomically updates the manifest at
    [path] with [entry]. If no manifest exists at [path], a new one is created
    with [schema] and [entry] as the only record. If a manifest exists, its
    schema_hash is checked against [schema.schema_hash] — on mismatch returns
    [Error Internal] (to refuse appending under a different indicator set). On
    match, the manifest's entries are upserted via {!upsert_entry} and written
    back.

    Atomic-rename semantics: the new manifest is written to [path ^ ".tmp"]
    first, then [Stdlib.Sys.rename] swaps it in. POSIX guarantees readers
    observe either the old or new file, never a torn write. This is the
    primitive the snapshot writer uses to checkpoint after every per-symbol
    [.snap] file lands, so [--incremental] can resume from any interrupt
    mid-run.

    Returns [Error Internal] on filesystem error or schema mismatch. *)
