open Core

type t = { name : string; period : int; cadence : Types.Cadence.t }
[@@deriving sexp, eq, compare, hash]

let to_string t =
  Printf.sprintf "%s-%d-%s" t.name t.period
    (Types.Cadence.sexp_of_t t.cadence |> Sexp.to_string)
