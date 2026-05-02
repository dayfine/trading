(** Sexp parser for {!Weekly_snapshot.t}.

    Inverse of {!Snapshot_writer.serialize}. The round-trip property
    [parse (serialize t) = Ok t] is pinned by [test_round_trip.ml].

    {1 Schema-version handling}

    The parser checks [schema_version] against
    {!Weekly_snapshot.current_schema_version} and returns
    [Error Invalid_argument] if they do not match. This is intentional: silently
    accepting an older or newer schema risks misinterpreting fields that have
    been added, removed, or repurposed. Future migrations should land as an
    explicit [migrate_v<N>_to_v<M>] utility, not as silent acceptance. *)

val parse : string -> Weekly_snapshot.t Status.status_or
(** [parse s] parses a snapshot from its sexp string form.

    Returns:
    - [Ok t] on success.
    - [Error Invalid_argument] if [s] is not valid sexp or does not match the
      snapshot schema (missing required fields, wrong types).
    - [Error Invalid_argument] (with a "schema_version mismatch" message) if [s]
      parses but its [schema_version] does not match
      {!Weekly_snapshot.current_schema_version}. The error message names both
      the expected and actual versions so callers can decide whether to migrate.
*)

val read_from_file : string -> Weekly_snapshot.t Status.status_or
(** [read_from_file path] reads and parses a snapshot from disk.

    Returns:
    - [Ok t] on success.
    - [Error NotFound] if [path] does not exist.
    - Errors from {!parse} otherwise. *)
