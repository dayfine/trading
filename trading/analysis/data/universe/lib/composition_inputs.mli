(** Input file loaders used by {!Build_from_individuals}.

    Three on-disk artifacts feed the composition build:

    - [inventory.sexp] — [{ generated_at; symbols : entry list }] where each
      [entry] is [{ symbol; data_start_date; data_end_date }]. Produced by
      [weinstein.data_source/Inventory].
    - [symbol_types.sexp] — produced by [asset_type_enrichment]. Per-entry
      [(symbol, asset_type)] pairs; equity-like asset types are
      [Common_stock | Preferred_stock | ADR | GDR].
    - [sectors.csv] — header [symbol,sector]. Missing symbols default to the
      empty sector.

    Loaders are isolated here so {!Build_from_individuals} stays focused on the
    ranking algorithm itself. *)

open Core

type inventory_entry = {
  symbol : string;
  data_start_date : Date.t;
  data_end_date : Date.t;
}
[@@deriving sexp]

type inventory = { generated_at : Date.t; symbols : inventory_entry list }
[@@deriving sexp]

val load_inventory : string -> inventory Status.status_or
(** [load_inventory path] parses the canonical [inventory.sexp]. Returns
    [Error Status.Internal] on read or decode failure. *)

val load_equity_like_lookup :
  string -> (string, bool) Hashtbl.t Status.status_or
(** [load_equity_like_lookup path] parses the canonical [symbol_types.sexp] and
    returns a [symbol -> is_equity_like] map. Symbols whose [asset_type] is
    anything other than [Common_stock], [Preferred_stock], [ADR], [GDR] map to
    [false]; entries unrecognised by the sexp shape are dropped silently. *)

val load_sectors : string -> (string, string) Hashtbl.t Status.status_or
(** [load_sectors path] parses [sectors.csv] (header [symbol,sector]) into a
    [symbol -> sector] map. Returns [Error Status.Internal] on read failure;
    malformed CSV rows are silently dropped. *)
