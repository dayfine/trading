open Core

type t = Legacy | Tiered | Panel [@@deriving sexp, show, eq]

let of_string s =
  match String.lowercase s with
  | "legacy" -> Legacy
  | "tiered" -> Tiered
  | "panel" -> Panel
  | other ->
      failwith
        (sprintf
           "Loader_strategy.of_string: expected legacy|tiered|panel, got %S"
           other)
