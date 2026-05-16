(** Rehash logic for [manifest_rehash.exe]. Extracted to a library so the
    end-to-end walk+rehash flow is unit-testable without spawning the
    executable. *)

type counters = {
  mutable walked : int;
  mutable skipped_existing : int;
  mutable rehashed : int;
  mutable failures : (string * string) list;
}
(** Tally produced by a single rehash run. [failures] is bounded to the first
    five entries to keep the summary readable; the [walked] / [rehashed] /
    [skipped_existing] counts are not bounded.

    The pair shape is [(csv_path, error_message)]. *)

val empty_counters : unit -> counters
(** Fresh counters initialized to zero. *)

val run :
  data_dir_str:string ->
  source:string ->
  endpoint_fmt:string ->
  dry_run:bool ->
  only_missing:bool ->
  counters
(** [run ~data_dir_str ~source ~endpoint_fmt ~dry_run ~only_missing] walks
    [<data_dir_str>/<L1>/<L2>/<SYMBOL>/data.csv] and, for each CSV either:
    - skips it (when [only_missing] is set and the shard manifest already
      contains an entry for the symbol),
    - dry-counts it (when [dry_run] is set),
    - or invokes {!Csv.Csv_storage_manifest.update_for_save} to compute the file
      hash, derive date range + row count, and upsert a manifest entry.

    [endpoint_fmt] is a printf-style format with a single [%s] substituted with
    the symbol (e.g. ["/eod/%s"]). If the format does not contain [%s] the
    string is used verbatim.

    Prints a summary to stdout via {!print_summary}. *)

val print_summary : counters -> unit
(** Print the counters in the form

    {[
      Manifest rehash summary
        walked              = N
        manifests present   = N
        rehashed            = N
        failures            = N
    ]}

    plus a [first failures:] block when [failures] is non-empty. *)
