open Core

type t = {
  schema : Snapshot_schema.t;
  symbol : string;
  date : Date.t;
  values : float array;
}
[@@deriving sexp]

let create ~schema ~symbol ~date ~values =
  let expected = Snapshot_schema.n_fields schema in
  let actual = Array.length values in
  if String.is_empty symbol then
    Status.error_invalid_argument "Snapshot.create: empty symbol"
  else if expected <> actual then
    Status.error_invalid_argument
      (Printf.sprintf
         "Snapshot.create: values length %d does not match schema width %d"
         actual expected)
  else Ok { schema; symbol; date; values }

let index_of t f = Snapshot_schema.index_of t.schema f

let get t f =
  match index_of t f with None -> None | Some i -> Some t.values.(i)
