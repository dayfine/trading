open Core
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

type file_metadata = {
  symbol : string;
  path : string;
  byte_size : int;
  payload_md5 : string;
  csv_mtime : float;
}
[@@deriving sexp, compare, equal]

type t = {
  schema_hash : string;
  schema : Snapshot_schema.t;
  entries : file_metadata list;
}
[@@deriving sexp]

let create ~schema ~entries =
  { schema_hash = schema.Snapshot_schema.schema_hash; schema; entries }

let write ~path manifest =
  try
    let sexp = sexp_of_t manifest in
    Out_channel.write_all path ~data:(Sexp.to_string_hum sexp);
    Ok ()
  with Sys_error msg | Failure msg ->
    Status.error_internal (Printf.sprintf "Snapshot_manifest.write: %s" msg)

let read ~path =
  if not (Stdlib.Sys.file_exists path) then
    Status.error_not_found
      (Printf.sprintf "Snapshot_manifest.read: %s does not exist" path)
  else
    try
      let sexp = Sexp.load_sexp path in
      Ok (t_of_sexp sexp)
    with
    | Sys_error msg | Failure msg ->
        Status.error_internal (Printf.sprintf "Snapshot_manifest.read: %s" msg)
    | Sexp.Of_sexp_error (exn, _) ->
        Status.error_internal
          (Printf.sprintf "Snapshot_manifest.read: sexp decode: %s"
             (Exn.to_string exn))

let find t ~symbol =
  List.find t.entries ~f:(fun e -> String.equal e.symbol symbol)
