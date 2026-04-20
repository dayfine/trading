open Core

type t = Legacy | Tiered [@@deriving sexp, show, eq]

let of_string s =
  match String.lowercase s with
  | "legacy" -> Legacy
  | "tiered" -> Tiered
  | other ->
      failwith
        (sprintf "Loader_strategy.of_string: expected legacy|tiered, got %S"
           other)
