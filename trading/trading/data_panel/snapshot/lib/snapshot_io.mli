(** Format-detecting reader over a single snapshot file — the seam that lets a
    whole-file consumer read a warehouse that mixes v1 sexp ({!Snapshot_format})
    and v2 columnar mmap ({!Snapshot_columnar}) files during the format
    transition.

    Detection peeks the leading {!Snapshot_columnar_codec.magic} bytes: a v2
    file starts with that magic, anything else is treated as v1 sexp. This
    mirrors the magic-peek {!Daily_panels} performs internally, but lives here
    so consumers that want full-file decode (e.g. the build-time verifier) can
    dispatch without a cross-library dependency. *)

val is_columnar_file : string -> bool
(** [is_columnar_file path] is [true] when [path] begins with the v2 magic
    ({!Snapshot_columnar_codec.magic}). Returns [false] for a v1 sexp file, a
    file shorter than the magic, or any path that cannot be opened — the
    negative answer routes such inputs to the v1 reader, which then reports the
    real error. *)

val read_with_expected_schema :
  path:string -> expected:Snapshot_schema.t -> Snapshot.t list Status.status_or
(** [read_with_expected_schema ~path ~expected] reads every row of the file at
    [path], detecting its format:
    - v2 columnar → {!Snapshot_columnar.read_with_expected_schema};
    - otherwise (v1 sexp) → {!Snapshot_format.read_with_expected_schema}.

    Both paths gate on the schema hash, returning [Error Failed_precondition]
    when the file's [schema_hash] differs from [expected.schema_hash]. The two
    underlying readers preserve their own row ordering (v1 write order, v2
    chronological). *)
