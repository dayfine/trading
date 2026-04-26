open Core

type t = Legacy | Panel [@@deriving sexp, show, eq]

let of_string s =
  match String.lowercase s with
  | "legacy" -> Legacy
  | "panel" -> Panel
  | other ->
      failwith
        (sprintf "Loader_strategy.of_string: expected legacy|panel, got %S"
           other)
