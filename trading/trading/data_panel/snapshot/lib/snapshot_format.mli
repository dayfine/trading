(** On-disk serialization for a list of {!Snapshot.t}.

    Phase A file format ({!dev/plans/daily-snapshot-streaming-2026-04-27.md}
    §Decisions point 2: "Snapshot file = single contiguous binary with sexp
    manifest"):

    {v
      bytes 0..7        manifest_len : int64 little-endian
      bytes 8..(8+M-1)  manifest_sexp : ASCII sexp (M = manifest_len)
      bytes 8+M..       payload : sexp-encoded list of (symbol, date, values)
    v}

    The manifest records:
    - [schema] (full {!Snapshot_schema.t} including hash)
    - [n_rows] (count of {!Snapshot.t} rows)
    - [payload_len] (byte length of the payload)
    - [payload_md5] (hex digest of the payload bytes)

    Integrity checks at {!read} time:
    - manifest sexp parses cleanly → else [Error Internal "manifest decode"]
    - payload byte length matches manifest → else
      [Error Internal "payload length mismatch"]
    - payload MD5 matches manifest → else [Error Internal "md5 mismatch"]
    - every row's [schema.schema_hash] equals the manifest's
      [schema.schema_hash] → else [Error Internal "schema hash mismatch"]

    Phase A uses a sexp-encoded payload (not raw Float64 bytes) for portability
    and ease of debugging. The plan's risk note R3 calls out the Phase C upgrade
    to a Bigarray.map_file payload — file format will bump schema hash and the
    migration will be a full corpus rebuild. *)

val write : path:string -> Snapshot.t list -> unit Status.status_or
(** [write ~path snapshots] serializes [snapshots] to [path], overwriting any
    existing file.

    Returns [Error Invalid_argument] if [snapshots] mixes multiple schema hashes
    (every row must share one schema for the file). The empty list is permitted
    and writes a header-only file using {!Snapshot_schema.default}.

    Returns [Error Internal] if the underlying file write raises. *)

val read : path:string -> Snapshot.t list Status.status_or
(** [read ~path] deserializes a snapshot file written by {!write}.

    Returns the list of rows in write order. Returns [Error Internal] on any
    integrity-check failure (loud, not silent — see the integrity checks listed
    in the module docstring). *)

val read_with_expected_schema :
  path:string -> expected:Snapshot_schema.t -> Snapshot.t list Status.status_or
(** [read_with_expected_schema ~path ~expected] is {!read} composed with a
    schema-hash check: returns
    [Error Failed_precondition "schema hash skew: file=<X> expected=<Y>"] if the
    file's manifest schema hash differs from [expected.schema_hash]. Used by the
    Phase C runtime to refuse files produced under a different indicator set. *)
