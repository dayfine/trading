(** CSV-based implementation of the HistoricalDailyPriceStorage interface.

    {2 Phase 2 — manifest integration}

    Every successful {!save} also writes (or upserts) a per-shard manifest entry
    under [<data-dir>/<L1>/<L2>/manifest.sexp]. The entry records the file's MD5
    hash, row count, date range, and provenance fields supplied by the caller
    (source, endpoint, vendor revision tag, fetch id, api key id). Manifest
    write failures are {b non-fatal} — the CSV write itself returns [Ok ()] and
    a warning is logged to stderr so existing pipelines do not break when the
    manifest sidecar cannot be updated.

    {!load_with_verify} mirrors {!get} but additionally consults the manifest
    and compares the on-disk file's hash against the recorded value. The
    [strictness] parameter controls the response to a mismatch (or a missing
    manifest entry): [`Strict] fails with [Status.Internal]; [`Warn] (the
    default) logs and returns the data; [`Off] suppresses the check entirely so
    legacy callers can opt out. *)

open Storage
include HistoricalDailyPriceStorage
open Core

type t

val symbol_data_dir : data_dir:Fpath.t -> string -> Fpath.t
(** [symbol_data_dir ~data_dir symbol] returns the directory where a symbol's
    data files are stored: [data_dir / first_char / last_char / symbol]. Pure
    path computation — does not create directories. *)

val shard_manifest_path : data_dir:Fpath.t -> string -> Fpath.t
(** [shard_manifest_path ~data_dir symbol] returns the manifest path for the
    [<L1>/<L2>] shard containing [symbol]:
    [data_dir / first_char / last_char / manifest.sexp]. Pure path computation.
    Exposed so callers (e.g. inspectors, bulk-rehash tools) can locate the
    manifest without re-implementing the sharding rule. *)

val create : ?data_dir:Fpath.t -> string -> (t, Status.t) Result.t
(** Create a new CSV storage with the given symbol and optional data directory.
    If no data directory is provided, a default value is used. *)

val save :
  t ->
  ?override:bool ->
  ?source:string ->
  ?endpoint:string ->
  ?vendor_revision_tag:string ->
  ?fetch_id:string ->
  ?api_key_id:string ->
  Types.Daily_price.t list ->
  (unit, Status.t) Result.t
(** [save t ?override ?source ?endpoint ?vendor_revision_tag ?fetch_id
     ?api_key_id prices] writes [prices] to the CSV file and then upserts the
    matching manifest entry under the per-shard manifest.

    Provenance defaults:
    - [source]: ["unknown"]
    - [endpoint]: [""]
    - [vendor_revision_tag]: [""]
    - [fetch_id]: [""]
    - [api_key_id]: [""]

    Callers that have richer fetch context (EODHD client, Norgate ingest, etc.)
    should pass them explicitly. The manifest write is best-effort: a failure to
    update the shard manifest is logged to stderr but does not cause [save]
    itself to return [Error]. *)

val get :
  t ->
  ?start_date:Date.t ->
  ?end_date:Date.t ->
  unit ->
  (Types.Daily_price.t list, Status.t) Result.t
(** Get prices from CSV file, optionally filtered by date range. Does not verify
    the manifest hash — for that, use {!load_with_verify}. *)

val load_with_verify :
  t ->
  ?strictness:[ `Strict | `Warn | `Off ] ->
  ?start_date:Date.t ->
  ?end_date:Date.t ->
  unit ->
  (Types.Daily_price.t list, Status.t) Result.t
(** [load_with_verify t ?strictness ?start_date ?end_date ()] loads the CSV
    contents like {!get} and additionally checks the on-disk file's MD5 against
    the manifest entry for the symbol.

    Behavior is governed by [strictness] (default [`Warn]):
    - [`Strict]: a mismatch returns
      [Error Status.Internal "data corruption: <symbol> sha256 mismatch
       (manifest=<X>, file=<Y>)"]. A missing manifest or missing entry is
      tolerated (treated as "no claim to verify") so that data fetched before
      Phase 2 still loads.
    - [`Warn]: same checks as [`Strict] but a mismatch (or absent manifest /
      entry) is logged to stderr and the data is returned [Ok].
    - [`Off]: no manifest read or hash check; identical to {!get}.

    The CSV read itself can still fail with [Error] (file missing, malformed
    rows, invalid date range) just like {!get}. *)
