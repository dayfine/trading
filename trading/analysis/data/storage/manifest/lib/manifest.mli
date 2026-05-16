(** CSV-layer manifest for the trading-system data cache.

    Phase 1 of {b dev/plans/data-inventory-and-reproducibility-2026-05-02.md}.
    The manifest captures per-symbol fetch provenance for every cached CSV under
    [data/<L1>/<L2>/<SYM>/data.csv]: source, endpoint, date range, row count,
    content hash, vendor revision tag, fetch timestamp, request id and API key
    id.

    {2 Sharding}

    Manifests are stored {b distributed by L1/L2 shard}. For a data root
    [cache-root/], the manifest for symbols sharing the same first/last
    character lives at [cache-root/<L1>/<L2>/manifest.sexp]. This mirrors the
    existing CSV layout (the per-symbol CSV is at
    [cache-root/<L1>/<L2>/<SYM>/data.csv]) and bounds the worst-case contention
    to 26 x 26 = 676 manifests so concurrent fetches across different shards do
    not race.

    {2 Hash algorithm}

    The [sha256] field is named for the long-term intent; the v1 implementation
    uses {b MD5} via [Stdlib.Digest] because the in-container opam set does not
    include a SHA-256 library. MD5 is sufficient for detecting accidental
    corruption or unintended overwrites (the threat model Phase 2 hash-verify
    will enforce) but is {b not} cryptographically secure. A follow-up should
    swap the implementation to true SHA-256 once [digestif] (or equivalent) is
    added to the toolchain; the field name and on-disk format stay the same so
    existing manifests continue to read.

    {2 Timestamps}

    [fetched_at], [created_at] and [last_updated] are serialized in UTC ISO-8601
    via [Time_ns.Alternate_sexp] rather than [Time_ns_unix]. The [Time_ns_unix]
    sexp converter resolves the local timezone at first call, which requires
    [/etc/localtime] to be present in the executing environment; this caused
    round-trip failures inside dune's test sandbox. The UTC form also keeps
    shard manifests diff-friendly across hosts. *)

open Core

type file_metadata = {
  symbol : string;  (** Vendor ticker, e.g. ["AAPL.US"]. *)
  source : string;
      (** Data provider tag, e.g. ["EODHD"], ["shiller"], ["stooq"]. Free-form
          string; per-source vocabulary lives in the source's ingest module. *)
  endpoint : string;
      (** API endpoint or URL pattern the row was fetched from, e.g.
          ["/eod/AAPL.US"]. Free-form string. *)
  date_range : (Date.t * Date.t) option; [@sexp.option]
      (** First and last bar dates in the CSV, inclusive. [None] when the source
          is empty or the writer did not record a range. *)
  rows_count : int;  (** Number of OHLCV rows in the CSV. *)
  sha256 : string;
      (** Hex digest of the CSV file contents at [fetched_at]. See module-level
          docstring for the v1 MD5 vs. long-term SHA-256 distinction. *)
  vendor_revision_tag : string;
      (** Vendor-side revision identifier when available (e.g. an [As-Of-Date]
          header, or an EODHD adjusted-close revision string). [""] when
          unavailable; in that case the [fetched_at] timestamp is the only
          revision proxy. *)
  fetched_at : Time_ns.t;
      (** Wall-clock timestamp at which the fetch completed and the CSV was
          written. *)
  fetch_id : string;
      (** Local fetch/request identifier — useful for cross-referencing the
          fetch_log (Phase 3). [""] permitted when the call site has no id. *)
  api_key_id : string;
      (** Identifier (not the secret) of the API key that issued the fetch, e.g.
          ["eodhd-prod"]. Audit-only; safe to store in plaintext. *)
}
[@@deriving sexp, compare, equal]
(** Per-symbol provenance record. *)

type t = {
  schema_version : int;
      (** Bumped on incompatible changes to {!file_metadata}. Readers check this
          before decoding the entries. *)
  created_at : Time_ns.t;  (** Time the manifest file was first created. *)
  last_updated : Time_ns.t;
      (** Time of the most recent {!upsert_entry} + {!write}. *)
  entries : file_metadata list;
      (** Per-symbol entries within this shard. Order is the order
          {!upsert_entry} produced (insertion-at-tail; replacements preserve
          position). *)
}
[@@deriving sexp]
(** Shard-level manifest, one per [<L1>/<L2>] directory. *)

val current_schema_version : int
(** [current_schema_version] is the {!t.schema_version} value emitted by
    {!create}. Tests pin this to detect accidental schema drift. *)

val create : ?entries:file_metadata list -> unit -> t
(** [create ~entries ()] builds a fresh manifest at the current [schema_version]
    with [created_at = last_updated = Time_ns.now ()] and the given entries
    (default: empty). *)

val write : path:string -> t -> unit Status.status_or
(** [write ~path t] serializes [t] to [path] using [Sexp.to_string_hum] for
    diff-friendly output. Writes via a [.tmp] sibling and [Stdlib.Sys.rename] so
    a crashed writer never produces a torn manifest. Returns [Error Internal] on
    filesystem error. *)

val read : path:string -> t Status.status_or
(** [read ~path] deserializes a manifest. Returns
    - [Error NotFound] if [path] does not exist;
    - [Error Internal] on parse failure or filesystem error;
    - [Error Failed_precondition] when the file's [schema_version] does not
      match {!current_schema_version}. The mismatch message includes both
      versions so the caller can decide whether to upgrade or refetch. *)

val upsert_entry : t -> file_metadata -> t
(** [upsert_entry t entry] returns a manifest in which [entry] replaces any
    existing record for [entry.symbol], or is appended at the tail when no prior
    entry exists. [last_updated] is refreshed to [Time_ns.now ()]. Pure apart
    from the clock read; does not touch disk. *)

val sha256_of_file : path:string -> string Status.status_or
(** [sha256_of_file ~path] computes the hex digest of the file at [path]. v1
    uses MD5 (32 hex chars) per the module docstring. Returns [Error NotFound]
    when [path] is missing; [Error Internal] on read failure. *)

val find : t -> symbol:string -> file_metadata option
(** [find t ~symbol] returns the entry for [symbol] or [None]. O(N) in entry
    count; per-shard manifests max out around 62 entries on average so a linear
    scan is fine. *)
