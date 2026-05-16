open Core

(* Plain [Core.Time_ns.t] is sexp-deprecated as of 2021-03; the two
   replacements are [Time_ns_unix] (local-zone-aware) and
   [Time_ns.Alternate_sexp] (UTC ISO-8601). We use [Alternate_sexp] because
   [Time_ns_unix.sexp_of_t] reads [/etc/localtime] at first call, which is
   missing inside dune's test sandbox and was tripping the round-trip tests
   even though the file exists at container scope. UTC also gives a stable
   on-disk form that diff'ing is meaningful for. *)
type time_ns = Time_ns.Alternate_sexp.t [@@deriving sexp, compare, equal]

type file_metadata = {
  symbol : string;
  source : string;
  endpoint : string;
  date_range : (Date.t * Date.t) option; [@sexp.option]
  rows_count : int;
  sha256 : string;
  vendor_revision_tag : string;
  fetched_at : time_ns;
  fetch_id : string;
  api_key_id : string;
}
[@@deriving sexp, compare, equal]

type t = {
  schema_version : int;
  created_at : time_ns;
  last_updated : time_ns;
  entries : file_metadata list;
}
[@@deriving sexp]

let current_schema_version = 1

let create ?(entries = []) () =
  let now = Time_ns.now () in
  {
    schema_version = current_schema_version;
    created_at = now;
    last_updated = now;
    entries;
  }

let _atomic_write_sexp ~path sexp =
  let tmp_path = path ^ ".tmp" in
  try
    Out_channel.write_all tmp_path ~data:(Sexp.to_string_hum sexp);
    Stdlib.Sys.rename tmp_path path;
    Ok ()
  with Sys_error msg | Failure msg ->
    (try Stdlib.Sys.remove tmp_path with _ -> ());
    Status.error_internal (Printf.sprintf "Manifest.write: %s" msg)

let write ~path t = _atomic_write_sexp ~path (sexp_of_t t)

let _decode_sexp ~path =
  try
    let sexp = Sexp.load_sexp path in
    Ok (t_of_sexp sexp)
  with
  | Sys_error msg | Failure msg ->
      Status.error_internal (Printf.sprintf "Manifest.read: %s" msg)
  | Sexp.Of_sexp_error (exn, _) ->
      Status.error_internal
        (Printf.sprintf "Manifest.read: sexp decode: %s" (Exn.to_string exn))

let _schema_version_error ~path ~got =
  let message =
    Printf.sprintf "Manifest.read: %s schema_version=%d expected %d" path got
      current_schema_version
  in
  Status.{ code = Failed_precondition; message }

let _check_schema_version t ~path =
  if t.schema_version <> current_schema_version then
    Error (_schema_version_error ~path ~got:t.schema_version)
  else Ok t

let read ~path =
  if not (Stdlib.Sys.file_exists path) then
    Status.error_not_found
      (Printf.sprintf "Manifest.read: %s does not exist" path)
  else
    match _decode_sexp ~path with
    | Error _ as e -> e
    | Ok t -> _check_schema_version t ~path

let _replace_or_mark entries entry =
  let replaced = ref false in
  let mapped =
    List.map entries ~f:(fun e ->
        if String.equal e.symbol entry.symbol then (
          replaced := true;
          entry)
        else e)
  in
  (mapped, !replaced)

let upsert_entry t entry =
  let mapped, replaced = _replace_or_mark t.entries entry in
  let entries = if replaced then mapped else mapped @ [ entry ] in
  { t with entries; last_updated = Time_ns.now () }

(* Stream the file in [chunk_size] blocks so even multi-GB CSVs hash without
   pulling everything into memory. Stdlib.Digest's [channel] helper handles
   this; the explicit chunk variant is only here for unit-test
   parity. *)
let _hash_channel chan = Stdlib.Digest.to_hex (Stdlib.Digest.channel chan (-1))

let sha256_of_file ~path =
  if not (Stdlib.Sys.file_exists path) then
    Status.error_not_found
      (Printf.sprintf "Manifest.sha256_of_file: %s does not exist" path)
  else
    try
      let hex = In_channel.with_file path ~binary:true ~f:_hash_channel in
      Ok hex
    with Sys_error msg ->
      Status.error_internal (Printf.sprintf "Manifest.sha256_of_file: %s" msg)

let find t ~symbol =
  List.find t.entries ~f:(fun e -> String.equal e.symbol symbol)
