open Core

type field =
  | EMA_50
  | SMA_50
  | ATR_14
  | RSI_14
  | Stage
  | RS_line
  | Macro_composite
[@@deriving sexp, compare, equal, show]

let all_fields =
  [ EMA_50; SMA_50; ATR_14; RSI_14; Stage; RS_line; Macro_composite ]

let field_name = function
  | EMA_50 -> "EMA_50"
  | SMA_50 -> "SMA_50"
  | ATR_14 -> "ATR_14"
  | RSI_14 -> "RSI_14"
  | Stage -> "Stage"
  | RS_line -> "RS_line"
  | Macro_composite -> "Macro_composite"

(* Canonical sexp form drives the hash. We use [Sexp.to_string] (not
   [to_string_hum]) because the compact form omits whitespace entirely, so
   trivial formatter changes can never perturb the hash. *)
let compute_hash fields =
  let sexp = [%sexp_of: field list] fields in
  Sexp.to_string sexp |> Stdlib.Digest.string |> Stdlib.Digest.to_hex

type t = { fields : field list; schema_hash : string } [@@deriving sexp]

let create ~fields = { fields; schema_hash = compute_hash fields }
let default = create ~fields:all_fields
let n_fields t = List.length t.fields

let index_of t f =
  List.findi t.fields ~f:(fun _ g -> equal_field f g)
  |> Option.map ~f:(fun (i, _) -> i)
