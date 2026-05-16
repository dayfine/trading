(** CSV-storage ↔ Manifest plumbing.

    Pure helpers extracted from [csv_storage] to keep the main module under the
    300-line file-length limit and to flatten nesting on the [update_for_save] /
    [verify] flows.

    Both entry points are non-fatal at the manifest layer: a manifest read or
    write failure returns [Ok ()] (the CSV operation succeeds either way) after
    logging a warning to stderr. The only exception is [verify] under [`Strict]
    when the sha256 actually mismatches — that surfaces a [Status.Internal]
    error so callers can act on detected corruption. *)

open Core

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

(** {2 Phase 3 — reconcile-on-refetch diff log}

    When a refetch replaces a previously-cached CSV, the old manifest entry's
    sha256 records the previous content's digest. If the new on-disk hash
    differs, we capture a structured diff entry under
    [<data-dir>/_reconcile_log/<YYYY-MM-DD>/<symbol>.sexp] {b before} the
    manifest upsert overwrites the prior entry. Subsequent inspections /
    alerting tooling can fold over these per-day shards to surface vendor
    revision drift, accidental overwrites, or upstream point-in-time changes.

    The reconcile layer is best-effort: any failure to read the prior manifest
    or write the log entry is logged to stderr and {b never} surfaces as an
    error from {!reconcile_on_save}. The CSV write itself has already completed
    by the time this is called. *)

type reconcile_entry = {
  reconcile_at : Time_ns.Alternate_sexp.t;
      (** Wall-clock at which the reconcile diff was captured. Serialized in UTC
          ISO-8601 via [Time_ns.Alternate_sexp] for parity with the manifest
          on-disk format. *)
  symbol : string;
  old_sha256 : string;  (** Hex digest from the prior manifest entry. *)
  new_sha256 : string;  (** Hex digest of the on-disk file post-save. *)
  old_date_range : (Date.t * Date.t) option;
      (** First/last bar dates of the prior cached file as recorded by the
          manifest. [None] when the prior entry had no recorded range. *)
  new_date_range : (Date.t * Date.t) option;
      (** First/last bar dates of the new on-disk file derived post-save. *)
  old_rows_count : int;  (** Row count from the prior manifest entry. *)
  new_rows_count : int;  (** Row count of the new on-disk file. *)
  fetch_id : string;
      (** Fetch / request id supplied by the caller; [""] when unavailable. *)
}
[@@deriving sexp, compare, equal]
(** Single reconcile diff record. One per refetch where the content changed. *)

type reconcile_result =
  | Reconciled of reconcile_entry
      (** A prior manifest entry existed and its sha256 differed from the new
          on-disk hash. A diff entry has been written to the reconcile log. *)
  | Unchanged
      (** Either no prior manifest entry existed (first save for this symbol),
          or the prior sha256 matched the new on-disk hash (refetch produced
          identical content). No diff entry written. *)

val reconcile_log_path :
  data_dir:Fpath.t -> reconcile_at:Time_ns.t -> string -> Fpath.t
(** [reconcile_log_path ~data_dir ~reconcile_at symbol] returns the file path
    where a reconcile entry for [symbol] captured at [reconcile_at] is written:
    [data_dir / "_reconcile_log" / "YYYY-MM-DD" / "<symbol>.sexp"]. The date
    shard uses UTC so log entries are stable across hosts. Pure path
    computation. *)

val reconcile_on_save :
  data_dir:Fpath.t ->
  symbol:string ->
  new_path:string ->
  fetch_id:string ->
  reconcile_result Status.status_or
(** [reconcile_on_save ~data_dir ~symbol ~new_path ~fetch_id] is called by
    {!Csv_storage.save} {b after} the new CSV has been written but {b before}
    {!update_for_save} overwrites the manifest entry. It:

    + reads the prior manifest entry for [symbol] (if any);
    + hashes [new_path] and compares against the prior entry's [sha256];
    + on mismatch, builds a {!reconcile_entry} from the prior entry's
      [(sha256, date_range, rows_count)] and the new file's
      [(sha256, date_range, rows_count)] and appends it to the per-day shard
      under [<data_dir>/_reconcile_log/<YYYY-MM-DD>/<symbol>.sexp].

    Always returns [Ok _] under happy-path conditions. Manifest read failures,
    sha256 failures, or reconcile-log write failures are logged to stderr and
    surface as [Ok Unchanged] — the CSV write has already succeeded and a failed
    reconcile log is not worth blocking the save on. *)

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
