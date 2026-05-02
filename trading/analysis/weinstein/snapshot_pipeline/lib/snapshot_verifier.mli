(** Round-trip verification for a snapshot directory built by Phase B.

    Walks every entry in a {!Snapshot_manifest.t}, opens the file via
    {!Snapshot_format.read} (which already runs payload-md5 + schema-hash +
    row-count integrity checks), and accumulates pass/fail counts. The
    file-format layer is the source of truth for byte-level integrity; this
    verifier adds the directory-level sweep + summary.

    The verifier does {b not} re-derive indicator values from the source CSV.
    Phase B's parity guarantee (plan §R2) is structural: the pipeline calls the
    same kernels the runtime would, so file values and re-derived values are
    bit-identical by construction. A separate "rebuild from CSV and compare"
    spike is Phase E's territory.

    Use this verifier:
    - Inside [bin/build_snapshots.exe] as a post-write self-check.
    - From a release-gate workflow to confirm a checked-out warehouse hasn't
      drifted (e.g. from filesystem corruption or a partial copy). *)

type file_result = {
  symbol : string;  (** Symbol from the manifest entry under verification. *)
  path : string;  (** Filesystem path that was checked. *)
  status : (int, Status.t) Result.t;
      (** [Ok n] when the file round-trips and produced [n] rows. [Error err]
          when {!Snapshot_format.read} failed (md5, schema, parse). *)
}
(** Per-file verification outcome. *)

type t = {
  total : int;  (** Total entries in the manifest. *)
  passed : int;  (** Entries whose [status] is [Ok _]. *)
  failed : int;  (** Entries whose [status] is [Error _]. *)
  results : file_result list;  (** Per-file outcomes, in manifest entry order. *)
}
(** Directory-level verification result. *)

val verify_directory : manifest_path:string -> t Status.status_or
(** [verify_directory ~manifest_path] reads the manifest at [manifest_path],
    iterates every entry, and round-trips each file via
    {!Snapshot_format.read_with_expected_schema} using the manifest's schema as
    the expected schema. Returns a {!t} summarizing the sweep.

    Returns [Error] only when the manifest itself cannot be loaded; per-file
    failures are reported in the [results] list (and counted in [failed]) so a
    caller can distinguish "a few bad files" from "the warehouse index is gone".
*)
