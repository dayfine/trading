open Core

type pinned_entry = { symbol : string; sector : string } [@@deriving sexp]
type t = Pinned of pinned_entry list | Full_sector_map [@@deriving sexp]

let load path = t_of_sexp (Sexp.load_sexp path)

let symbol_count = function
  | Pinned entries -> Some (List.length entries)
  | Full_sector_map -> None

let to_sector_map_override = function
  | Full_sector_map -> None
  | Pinned entries ->
      let tbl = Hashtbl.create (module String) in
      List.iter entries ~f:(fun e ->
          Hashtbl.set tbl ~key:e.symbol ~data:e.sector);
      Some tbl
