(** Client for Stooq's free daily OHLCV CSV endpoint.

    Authority: [dev/notes/deep-history-data-pointers-2026-05-16.md] §"Stooq
    cross-check design" + companion memory
    [memory/reference_deep_history_data_sources.md]. Stooq is the chosen free
    second source for the 41,575-symbol EODHD cache: pairs naturally with the
    manifest/hash-verify Phase 1 plan as an independent integrity audit that
    catches EODHD silent split-revisions (G14-class) and adjusted-close drift.

    {b Survivorship caveat.} Stooq is NOT survivorship-bias-free. Use this
    module for {b validation} (drift detection vs a primary source), never as
    the primary source itself.

    {b Adjustment caveat.} Stooq's [Close] column is split-adjusted but NOT
    dividend-adjusted by default. This module is the pure parser; the
    comparison-field decision (Stooq [close] vs EODHD [adjusted_close] vs EODHD
    [close_price]) lives in [bin/stooq_drift_check_core.mli]'s "Comparison
    field" section — comparing against the wrong EODHD field introduces large
    structural drift (e.g. ~300% post-split false positives if comparing
    pre-split prices against EODHD [close_price]).

    {b Apikey gate (verified 2026-05-17).} Stooq's CSV endpoint
    [https://stooq.com/q/d/l/?s=<symbol>.us&i=d] {b requires an apikey} as of
    the verification probe — bare GETs return HTTP 200 with a plaintext body
    instructing the caller to obtain an apikey at
    [https://stooq.com/q/d/?s=<symbol>.us&get_apikey]. The apikey is free but
    requires manual captcha completion. Live fetches in
    [bin/stooq_curl_fetch.ml] take the apikey via env var [STOOQ_APIKEY] or CLI
    flag.

    This module is pure: no IO. {!parse} consumes a CSV body string;
    {!build_uri} constructs the canonical request URI; {!is_apikey_error_body}
    detects the apikey-error sentinel response (distinct from a real CSV). *)

open Core

type daily_observation = {
  date : Date.t;  (** Trading date. *)
  open_ : float;  (** Open price (split-adjusted, dividend-unadjusted). *)
  high : float;  (** High price (split-adjusted, dividend-unadjusted). *)
  low : float;  (** Low price (split-adjusted, dividend-unadjusted). *)
  close : float;
      (** Close price (split-adjusted, dividend-unadjusted). See module-level
          docstring for the comparison-field caveat. *)
  volume : int;
      (** Trading volume. Stooq emits this as an integer; 0 indicates the
          underlying was an index or otherwise non-volume-bearing. *)
}
[@@deriving show, eq]
(** A single daily OHLCV observation as Stooq emits it. *)

type series = { observations : daily_observation list } [@@deriving show, eq]
(** Parsed daily series, in source order. Stooq's CSV is ascending by date and
    we preserve that ordering; callers should not re-sort unless they need a
    different cadence. *)

val parse : string -> series Status.status_or
(** [parse csv] parses a Stooq daily-cadence CSV body.

    Expected header: [Date,Open,High,Low,Close,Volume] (6 columns). Each data
    row is [YYYY-MM-DD,OPEN,HIGH,LOW,CLOSE,VOLUME].

    Returns [Ok series] on success; [Error _] on structural failure (missing or
    drifted header, empty body, unparseable date, unparseable numeric, wrong
    column count on a data row).

    {!is_apikey_error_body} should be checked {b before} calling {!parse}: an
    apikey-error body is structurally not a CSV (no header line) and would
    produce an opaque [Error _] from {!parse}. *)

val build_uri : ?apikey:string -> symbol:string -> unit -> Uri.t
(** [build_uri ~symbol ?apikey ()] constructs the Stooq daily-CSV request URI.

    [symbol] is the bare ticker; this function lowercases it and appends [".us"]
    (Stooq's US-market suffix; e.g. [AAPL] becomes [aapl.us]).

    [?apikey] appends the [apikey] query parameter when provided. Without it,
    the live endpoint returns the apikey-error body rather than CSV — that
    response is structurally detectable via {!is_apikey_error_body}.

    The trailing [unit] is required so [?apikey] is erasable (OCaml's
    optional-arg conventions). *)

val is_apikey_error_body : string -> bool
(** [is_apikey_error_body body] returns [true] if [body] looks like Stooq's
    apikey-required sentinel response (verified 2026-05-17). The sentinel is
    HTTP 200 + a plaintext body that opens with [Get your apikey:] and contains
    a [get_apikey] hint URL.

    Callers should branch on this before attempting {!parse} so the
    "apikey-missing" failure mode produces a clear error message rather than a
    structural CSV-parse failure deep in the parser. *)
