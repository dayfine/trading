(** CSV-storage ↔ Manifest plumbing.

    Pure helpers extracted from [csv_storage] to keep the main module under the
    300-line file-length limit and to flatten nesting on the [update_for_save] /
    [verify] flows.

    Both entry points are non-fatal at the manifest layer: a manifest read or
    write failure returns [Ok ()] (the CSV operation succeeds either way) after
    logging a warning to stderr. The only exception is [verify] under [`Strict]
    when the sha256 actually mismatches — that surfaces a [Status.Internal]
    error so callers can act on detected corruption. *)

val shard_manifest_path : data_dir:Fpath.t -> string -> Fpath.t
(** Compute the per-shard manifest path for a symbol given the cache root. *)

val update_for_save :
  data_dir:Fpath.t ->
  symbol:string ->
  path:string ->
  source:string ->
  endpoint:string ->
  vendor_revision_tag:string ->
  fetch_id:string ->
  api_key_id:string ->
  unit Status.status_or
(** After [csv_storage.save] writes a CSV, call this to update the manifest
    entry. Hashes the on-disk file, derives the date range + row count, and
    upserts the entry into [<data_dir>/<L1>/<L2>/manifest.sexp].

    Always returns [Ok ()] — manifest failures log a warning but do not surface
    as errors. *)

val verify :
  data_dir:Fpath.t ->
  symbol:string ->
  path:string ->
  strictness:[ `Strict | `Warn | `Off ] ->
  unit Status.status_or
(** Verify the on-disk CSV against the manifest's sha256 claim under the given
    strictness:

    - [`Off]: no-op, returns [Ok ()].
    - [`Warn]: mismatch or missing-entry logs a warning, returns [Ok ()].
    - [`Strict]: mismatch returns [Status.Internal] error; missing entry still
      returns [Ok ()] (legacy data tolerance). *)
