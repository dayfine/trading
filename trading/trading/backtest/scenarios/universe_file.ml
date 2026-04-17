open Core

type pinned_entry = { symbol : string; sector : string } [@@deriving sexp]
type t = Pinned of pinned_entry list | Full_sector_map [@@deriving sexp]

let load path = t_of_sexp (Sexp.load_sexp path)

let symbol_count = function
  | Pinned entries -> Some (List.length entries)
  | Full_sector_map -> None
