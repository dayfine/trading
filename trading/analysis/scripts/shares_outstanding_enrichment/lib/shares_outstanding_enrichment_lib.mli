(** Bulk-enrich a list of inventory symbols with current shares-outstanding
    sourced from EODHD's [/api/fundamentals/{symbol}] endpoint.

    Companion plan: Q2-A PR1 of
    [dev/plans/custom-universe-bidirectional-2026-05-17.md]. The enriched output
    is consumed by Q2-A PR2's composition builder, which ranks symbols by
    [current_shares × historical_close_price] to construct market-cap-weighted
    historical universes.

    Design choices:

    - "Current shares × historical price" is an approximation (buyback
      distortion, IPO phantom market cap pre-listing). A separate
      cross-validation PR (not in this stack) will check drift vs the Shiller
      SP500 composite to bound the error.

    - Sentinel for "no fundamentals data": **skip the symbol entirely**. The
      output [entries] list omits symbols whose EODHD fundamentals response came
      back as missing or with [shares_outstanding = 0.0]. Downstream consumers
      (Q2-A PR2) treat absent symbols as "ineligible for ranking".

    - This library is pure (no HTTP). The bin/ executable handles fetching and
      passes a list of [Eodhd.Fundamentals_endpoint.fundamentals] records to
      [join]. *)

open Core

(** {1 Records} *)

type entry = { symbol : string; shares_outstanding : float }
[@@deriving show, eq]
(** One enriched entry per equity-like symbol with non-zero shares outstanding.
*)

type t = {
  generated_at : Date.t;
  source_endpoints : (string * Date.t) list;
      (** [(endpoint, fetch_date)] pairs for the EODHD endpoints whose response
          populated [entries]. Recorded for provenance. *)
  entries : entry list;
      (** One [entry] per symbol that returned non-zero shares. Sorted by
          [symbol] ascending for deterministic round-trip. *)
}
[@@deriving show, eq]

(** {1 Pure join} *)

val join :
  fundamentals:Eodhd.Fundamentals_endpoint.fundamentals list ->
  generated_at:Date.t ->
  source_endpoints:(string * Date.t) list ->
  t
(** [join ~fundamentals ~generated_at ~source_endpoints] keeps every
    fundamentals record with [shares_outstanding > 0.0] and drops the rest.
    Output [entries] is sorted by [symbol] ascending. If the same symbol appears
    multiple times in [fundamentals], the first occurrence wins. *)

(** {1 I/O} *)

val save : t -> path:Fpath.t -> Status.status
(** Write the enriched index to [path] as a sexp. Overwrites any existing file.
*)

val load : path:Fpath.t -> t Status.status_or
(** Read an enriched index from [path]. Errors if the file is missing or
    malformed. *)
