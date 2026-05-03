(** Glue layer for [build_universe.exe] CLI.

    Companion plan: [dev/plans/wiki-eodhd-historical-universe-2026-05-03.md]
    §PR-C. Wires {!Wiki_sp500.Changes_parser}, {!Wiki_sp500.Membership_replay},
    and {!Wiki_sp500.Ticker_aliases} against the existing EODHD client to emit a
    historical-date universe sexp. All file I/O lives here so the underlying
    library remains pure. *)

open Core

type warning = { symbol : string; reason : string } [@@deriving show, eq]
(** Non-fatal observation, e.g. ["no local bars"] (cache miss without
    [--fetch-prices]) or ["EODHD returned 404"] (genuinely no history). *)

type outcome = {
  universe_sexp : Sexp.t;
      (** Emitted [(Pinned ((symbol …) (sector …)) …)] sexp. Symbols without
          local bars (and not skipped) are still included. *)
  warnings : warning list;
      (** Symbols where the local CSV cache was missing at output time. *)
  skipped : warning list;
      (** Symbols excluded from the output universe (e.g. EODHD 404). *)
  fetched_count : int;  (** Symbols newly fetched during this run. *)
}

val run_offline :
  as_of:Date.t ->
  current_csv_path:string ->
  wiki_html_path:string ->
  cache_dir:string ->
  outcome Status.status_or
(** Read fixtures, replay back via [Membership_replay.replay_back ~as_of],
    canonicalize each symbol via [Ticker_aliases.canonicalize ~as_of], and emit
    the universe sexp. Symbols whose CSV is missing under [cache_dir] appear in
    [warnings] but are still included in the output. Returns [Error] only on
    read/parse failures. *)

val run_with_fetch :
  as_of:Date.t ->
  current_csv_path:string ->
  wiki_html_path:string ->
  cache_dir:string ->
  token:string ->
  ?fetch:Eodhd.Http_client.fetch_fn ->
  unit ->
  outcome Status.status_or Async.Deferred.t
(** Same replay as {!run_offline}, then for every replay-membership symbol whose
    CSV is absent from [cache_dir], call EODHD's [/api/eod/<sym>] endpoint
    (window: 1996-01-01 → [as_of]) and write the result to
    [<cache_dir>/<sym>.csv]. Symbols where EODHD returns 404 are reported in
    [skipped] and omitted from the output. The [?fetch] hook is for tests;
    defaults to {!Eodhd.Http_client.default_fetch}. *)

val write_outcome_to_file :
  path:string -> as_of:Date.t -> outcome -> unit Status.status_or
(** Write [outcome.universe_sexp] to [path] prefixed with a comment header
    citing [as_of], the cardinality, and [outcome.skipped]. The consumer (e.g.
    {!Universe_file.load}) ignores the comment block. *)
