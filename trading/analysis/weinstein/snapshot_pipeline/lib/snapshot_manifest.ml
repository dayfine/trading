open Core
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

type file_metadata = {
  symbol : string;
  path : string;
  byte_size : int;
  payload_md5 : string;
  csv_mtime : float;
  active_through : Date.t option; [@sexp.option]
}
[@@deriving sexp, compare, equal]

type t = {
  schema_hash : string;
  schema : Snapshot_schema.t;
  entries : file_metadata list;
  weekly_sidetable_format_hash : string option; [@sexp.option]
}
[@@deriving sexp]

let create ~schema ~entries =
  {
    schema_hash = schema.Snapshot_schema.schema_hash;
    schema;
    entries;
    weekly_sidetable_format_hash = None;
  }

let set_weekly_sidetable_format_hash t hash =
  { t with weekly_sidetable_format_hash = Some hash }

let write ~path manifest =
  try
    let sexp = sexp_of_t manifest in
    Out_channel.write_all path ~data:(Sexp.to_string_hum sexp);
    Ok ()
  with Sys_error msg | Failure msg ->
    Status.error_internal (Printf.sprintf "Snapshot_manifest.write: %s" msg)

let _decode_sexp ~path =
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

let read ~path =
  if not (Stdlib.Sys.file_exists path) then
    Status.error_not_found
      (Printf.sprintf "Snapshot_manifest.read: %s does not exist" path)
  else _decode_sexp ~path

let find t ~symbol =
  List.find t.entries ~f:(fun e -> String.equal e.symbol symbol)

let upsert_entry t entry =
  let replaced = ref false in
  let entries =
    List.map t.entries ~f:(fun e ->
        if String.equal e.symbol entry.symbol then (
          replaced := true;
          entry)
        else e)
  in
  let entries = if !replaced then entries else entries @ [ entry ] in
  { t with entries }

let _atomic_write ~path manifest =
  let tmp_path = path ^ ".tmp" in
  try
    let sexp = sexp_of_t manifest in
    Out_channel.write_all tmp_path ~data:(Sexp.to_string_hum sexp);
    Stdlib.Sys.rename tmp_path path;
    Ok ()
  with Sys_error msg | Failure msg ->
    (* Best-effort cleanup of the temp file; ignore any error. *)
    (try Stdlib.Sys.remove tmp_path with _ -> ());
    Status.error_internal
      (Printf.sprintf "Snapshot_manifest._atomic_write: %s" msg)

let _load_if_exists ~path =
  if Stdlib.Sys.file_exists path then
    match read ~path with Ok m -> Some m | Error _ -> None
  else None

let _validate_and_write ~path ~schema entry m =
  if not (String.equal m.schema_hash schema.Snapshot_schema.schema_hash) then
    Status.error_internal
      (Printf.sprintf
         "Snapshot_manifest.update_for_symbol: schema_hash mismatch \
          (existing=%s new=%s)"
         m.schema_hash schema.Snapshot_schema.schema_hash)
  else _atomic_write ~path (upsert_entry m entry)

let update_for_symbol ~path ~schema entry =
  match _load_if_exists ~path with
  | None ->
      let manifest = create ~schema ~entries:[ entry ] in
      _atomic_write ~path manifest
  | Some m -> _validate_and_write ~path ~schema entry m
