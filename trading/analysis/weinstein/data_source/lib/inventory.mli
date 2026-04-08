(** Inventory of locally cached price data.

    The inventory is a manifest of every symbol for which price data has been
    downloaded to disk. It is built by scanning [data_dir] for
    [data.metadata.sexp] files (one per symbol) and records the date range each
    symbol covers.

    Typical workflow:
    {[
      (* 1. Fetch prices for symbols of interest *)
      fetch_symbols.exe --symbols AAPL,MSFT,...

      (* 2. Rebuild the inventory from cached metadata *)
      build_inventory.exe

      (* 3. Bootstrap a universe.sexp from the inventory *)
      bootstrap_universe.exe
    ]}

    The inventory file ([inventory.sexp]) is the input to {!bootstrap_universe}
    and can be inspected directly to see what data is available locally. *)

open Core

type entry = {
  symbol : string;
  data_start_date : Date.t;
  data_end_date : Date.t;
}
[@@deriving sexp]
(** A single symbol entry in the inventory. *)

type t = { generated_at : Date.t; symbols : entry list } [@@deriving sexp]
(** The full inventory: all symbols with known cached price data. *)

val path : data_dir:Fpath.t -> Fpath.t
(** Path to the inventory file: [data_dir/inventory.sexp]. *)

val build : data_dir:Fpath.t -> t
(** [build ~data_dir] walks [data_dir] recursively, reads every
    [data.metadata.sexp] file, and returns an inventory sorted by symbol. Files
    that cannot be read are silently skipped. *)

val save : t -> data_dir:Fpath.t -> (unit, Status.t) result
(** Write inventory to [data_dir/inventory.sexp]. *)

val load : data_dir:Fpath.t -> (t, Status.t) result
(** Read inventory from [data_dir/inventory.sexp]. *)
