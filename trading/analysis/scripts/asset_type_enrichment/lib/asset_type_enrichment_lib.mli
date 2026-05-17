(** Bulk-enrich a list of inventory symbols with their EODHD [Asset_type]
    classification.

    Companion plan: Q1 PR2 of
    [dev/plans/custom-universe-bidirectional-2026-05-17.md]. The enriched output
    is consumed by Q1 PR3's [filter_by_asset_type] to drop mutual funds, ETFs,
    and other non-equity-like instruments from Weinstein universe-build.

    Design note: rather than extend {!Eodhd.Asset_type.t} with a
    "not-in-listing" sentinel (which would widen the parser's narrow contract),
    this library wraps {!Eodhd.Asset_type.t} in a sibling sum type and adds the
    sentinel here. *)

open Core

(** {1 Enriched type — wraps [Asset_type.t] with an "absent" sentinel} *)

type enriched_asset_type =
  | Listed of Eodhd.Asset_type.t
      (** Symbol was found in EODHD's [/api/exchange-symbol-list] response with
          the given classification. *)
  | Not_in_eodhd_listing
      (** Symbol is present in the local inventory but is absent from EODHD's
          exchange-symbol-list. This typically indicates a delisted symbol that
          has aged out of the active feed or a symbol whose listing is on an
          exchange we did not query. *)
[@@deriving show, eq]

(** {1 Records} *)

type entry = {
  symbol : string;
  asset_type : enriched_asset_type;
  name : string;
      (** Human-readable issuer name from EODHD. Empty string when
          [asset_type = Not_in_eodhd_listing] or when EODHD returned a
          null/empty value. *)
  exchange : string;
      (** Listing exchange from EODHD. Empty string when
          [asset_type = Not_in_eodhd_listing]. *)
}
[@@deriving show, eq]
(** One enriched entry per inventory symbol. *)

type t = {
  generated_at : Date.t;
  source_endpoints : (string * Date.t) list;
      (** [(endpoint, fetch_date)] pairs for the EODHD endpoints whose response
          populated [symbols]. Recorded for provenance. *)
  symbols : entry list;
      (** One [entry] per inventory symbol, in original inventory order. *)
}
[@@deriving show, eq]

(** {1 Pure join} *)

val join :
  inventory_symbols:string list ->
  eodhd_listings:Eodhd.Http_client.symbol_metadata list ->
  generated_at:Date.t ->
  source_endpoints:(string * Date.t) list ->
  t
(** [join ~inventory_symbols ~eodhd_listings ~generated_at ~source_endpoints] is
    a pure many-to-one join: every inventory symbol gets exactly one [entry].
    Symbols absent from [eodhd_listings] map to [Not_in_eodhd_listing] with
    empty [name] / [exchange]. Inventory order is preserved. If the same symbol
    appears multiple times in [eodhd_listings], the first occurrence wins. *)

(** {1 I/O} *)

val save : t -> path:Fpath.t -> Status.status
(** Write the enriched index to [path] as a sexp. Overwrites any existing file.
*)

val load : path:Fpath.t -> t Status.status_or
(** Read an enriched index from [path]. Errors if the file is missing or
    malformed. *)

(** {1 Summary} *)

type type_count = {
  asset_type_label : string;
      (** Human-readable label, e.g. "Common_stock", "Not_in_eodhd_listing",
          "Other:Brand New Type EODHD Just Invented". *)
  count : int;
}
[@@deriving show, eq]

val per_type_counts : t -> type_count list
(** Count entries per [enriched_asset_type]. Output is sorted by [count]
    descending, then by [asset_type_label] ascending for deterministic
    reporting. Pure. *)
