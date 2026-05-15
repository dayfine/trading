(** Glue layer for [build_iwv_universe.exe] CLI.

    Companion plan: [dev/plans/iwv-scraper-2026-05-16.md] §PR-D. Reads a
    snapshot cache produced by [fetch_iwv_history.exe] (PR-C), pipes the parsed
    snapshots through {!Ishares.Ishares_membership_replay.replay} (PR-B), and
    emits a point-in-time universe sexp matching the existing
    [broad-3000-2010-01-01.sexp] shape (PR #1103).

    All file I/O lives in this module; the [.ml] CLI is a thin wrapper. The
    underlying replay + parser layers remain pure. *)

open Core

type cache_entry = { as_of : Date.t; csv_path : string } [@@deriving show, eq]
(** A single cached snapshot to load: file at [csv_path] holds the raw CSV body
    fetched on [as_of]. Sentinel marker files (extension [.sentinel]) are
    deliberately excluded from this list — the loader skips them. *)

val list_cache_entries :
  cache_dir:string ->
  from:Date.t ->
  until:Date.t ->
  cache_entry list Status.status_or
(** [list_cache_entries ~cache_dir ~from ~until] scans [cache_dir] for files
    matching [YYYY-MM-DD.csv], parses the date from the filename, filters to
    [from <= as_of <= until], and returns the entries sorted by [as_of]
    ascending. Sentinel marker files are skipped. Returns [Error] if [cache_dir]
    cannot be opened. Returns [Ok []] if no in-window CSV files are found. *)

type filter_config = {
  require_equity_asset_class : bool;
      (** When [true], drop rows whose [asset_class] is not ["Equity"] (futures
          hedges, cash, bonds). Default: [true]. *)
  require_us_location : bool;
      (** When [true], drop rows whose [location] is not ["United States"]
          (pre-2012 cross-listings on LSE / XETRA). Default: [true]. *)
}
[@@deriving show, eq]

val default_filter_config : filter_config
(** Production defaults: equity-only + US-only. Per plan §2.3.3 these filters
    belong in the universe-builder, not in the replay layer, so callers can vary
    them per backtest. *)

val load_and_filter :
  entries:cache_entry list ->
  filter:filter_config ->
  (Date.t * Ishares.Ishares_holdings_client.snapshot) list Status.status_or
(** [load_and_filter ~entries ~filter] reads each [csv_path], parses via
    {!Ishares.Ishares_holdings_client.parse}, drops [No_data_sentinel] outcomes
    (cached sentinel bodies that slipped past the marker-file check), and
    returns the surviving snapshots paired with their [as_of] dates.

    Each snapshot's holdings are filtered per [filter] BEFORE the replay layer
    consumes them. Returns [Error] on the first structural parse failure (header
    drift, malformed row, unparseable date); a sentinel body in the body is
    treated as "skip this entry, keep going". *)

type outcome = {
  universe_sexp : Sexp.t;
      (** Emitted [(Pinned ((symbol …) (sector …)) …)] sexp matching
          [broad-3000-2010-01-01.sexp]. Symbols sorted by ticker ascending. *)
  member_count : int;  (** Cardinality of the emitted universe. *)
  snapshot_count : int;  (** Number of in-window snapshots replayed. *)
  removed_count : int;
      (** Number of [tenure_record]s closed during the replay (tickers that
          exited the index during the window). These are NOT in the output sexp.
      *)
}

val build_universe :
  snapshots:(Date.t * Ishares.Ishares_holdings_client.snapshot) list ->
  threshold_consecutive_misses:int ->
  as_of:Date.t ->
  outcome
(** [build_universe ~snapshots ~threshold_consecutive_misses ~as_of] replays the
    input snapshots, filters the resulting tenure records to those that were
    active on [as_of] (i.e. [first_seen <= as_of <= last_seen]), and renders the
    surviving members as a universe sexp.

    The [as_of] filter pins the universe to a single point-in-time: a tenure
    that closed before [as_of] is excluded; a tenure that opened after [as_of]
    is excluded. For full-membership emission across the whole window, callers
    can set [as_of] to the most recent snapshot date.

    The function is total — empty input yields an empty universe sexp. *)

val run :
  cache_dir:string ->
  output:string ->
  from:Date.t ->
  until:Date.t ->
  as_of:Date.t ->
  threshold_consecutive_misses:int ->
  ?filter:filter_config ->
  unit ->
  outcome Status.status_or
(** End-to-end pipeline: list cache entries → load and filter → build universe →
    write to [output] (atomic rename). Writes a comment-header block at the top
    of [output] citing [as_of], [from..until] window, snapshot count, and member
    count.

    Defaults: [filter = default_filter_config]. *)

val write_outcome_to_file :
  path:string ->
  as_of:Date.t ->
  from:Date.t ->
  until:Date.t ->
  outcome ->
  unit Status.status_or
(** Write [outcome.universe_sexp] to [path] prefixed with a comment header. The
    comment block cites [as_of], window, snapshot count, member count, and notes
    the IWV-tracks-but-is-not-exactly-Russell-3000 caveat. Used by both [run]
    and tests that exercise the file-shape directly. *)
