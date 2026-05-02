open Core

module Manifest = struct
  type t = {
    schema : Snapshot_schema.t;
    n_rows : int;
    payload_len : int;
    payload_md5 : string;
  }
  [@@deriving sexp]
end

(* Compact serializable shape for one row — values inlined as a float list so
   the payload sexp stays self-contained (no schema references). The row's
   schema is reattached at read time from the manifest. *)
module Row = struct
  type t = { symbol : string; date : Date.t; values : float array }
  [@@deriving sexp]
end

let _write_int64_le oc (v : int64) =
  let b = Bytes.create 8 in
  for i = 0 to 7 do
    let shifted = Int64.shift_right_logical v (i * 8) in
    let byte = Int64.to_int_exn (Int64.bit_and shifted 0xFFL) in
    Bytes.set b i (Char.of_int_exn byte)
  done;
  Out_channel.output_bytes oc b

let _read_int64_le ic =
  let b = Bytes.create 8 in
  In_channel.really_input_exn ic ~buf:b ~pos:0 ~len:8;
  let v = ref 0L in
  for i = 7 downto 0 do
    let byte = Int64.of_int (Char.to_int (Bytes.get b i)) in
    v := Int64.bit_or (Int64.shift_left !v 8) byte
  done;
  !v

let _validate_schemas (snapshots : Snapshot.t list) =
  match snapshots with
  | [] -> Ok ()
  | first :: rest -> (
      let h = first.schema.schema_hash in
      List.find rest ~f:(fun s -> not (String.equal s.schema.schema_hash h))
      |> function
      | None -> Ok ()
      | Some bad ->
          Status.error_invalid_argument
            (Printf.sprintf
               "Snapshot_format.write: mixed schema hashes (%s vs %s)" h
               bad.schema.schema_hash))

let _build_payload (snapshots : Snapshot.t list) =
  let rows : Row.t list =
    List.map snapshots ~f:(fun (s : Snapshot.t) ->
        { Row.symbol = s.symbol; date = s.date; values = s.values })
  in
  Sexp.to_string ([%sexp_of: Row.t list] rows)

let _schema_for_write snapshots =
  match snapshots with
  | first :: _ -> (first : Snapshot.t).schema
  | [] -> Snapshot_schema.default

let write ~path snapshots =
  match _validate_schemas snapshots with
  | Error _ as e -> e
  | Ok () -> (
      let schema = _schema_for_write snapshots in
      let payload = _build_payload snapshots in
      let payload_len = String.length payload in
      let payload_md5 = Stdlib.Digest.to_hex (Stdlib.Digest.string payload) in
      let manifest : Manifest.t =
        { schema; n_rows = List.length snapshots; payload_len; payload_md5 }
      in
      let manifest_bytes =
        manifest |> Manifest.sexp_of_t |> Sexp.to_string |> Bytes.of_string
      in
      try
        Out_channel.with_file path ~f:(fun oc ->
            _write_int64_le oc (Int64.of_int (Bytes.length manifest_bytes));
            Out_channel.output_bytes oc manifest_bytes;
            Out_channel.output_string oc payload);
        Ok ()
      with Sys_error msg | Failure msg ->
        Status.error_internal (Printf.sprintf "Snapshot_format.write: %s" msg))

let _decode_manifest_and_payload ~path =
  In_channel.with_file path ~f:(fun ic ->
      let manifest_len = _read_int64_le ic |> Int64.to_int_exn in
      let manifest_bytes = Bytes.create manifest_len in
      In_channel.really_input_exn ic ~buf:manifest_bytes ~pos:0
        ~len:manifest_len;
      let manifest =
        Sexp.of_string (Bytes.to_string manifest_bytes) |> Manifest.t_of_sexp
      in
      let payload = In_channel.input_all ic in
      (manifest, payload))

let _check_payload_integrity ~(manifest : Manifest.t) ~payload =
  if String.length payload <> manifest.payload_len then
    Status.error_internal
      (Printf.sprintf
         "Snapshot_format.read: payload length mismatch (file=%d manifest=%d)"
         (String.length payload) manifest.payload_len)
  else
    let actual = Stdlib.Digest.to_hex (Stdlib.Digest.string payload) in
    if not (String.equal actual manifest.payload_md5) then
      Status.error_internal
        (Printf.sprintf
           "Snapshot_format.read: md5 mismatch (file=%s manifest=%s)" actual
           manifest.payload_md5)
    else Ok ()

let _rows_to_snapshots ~(schema : Snapshot_schema.t) (rows : Row.t list) =
  List.map rows ~f:(fun (r : Row.t) ->
      Snapshot.create ~schema ~symbol:r.symbol ~date:r.date ~values:r.values)
  |> Result.all

let read ~path =
  let open Result.Let_syntax in
  try
    let manifest, payload = _decode_manifest_and_payload ~path in
    let%bind () = _check_payload_integrity ~manifest ~payload in
    let rows = Sexp.of_string payload |> [%of_sexp: Row.t list] in
    if List.length rows <> manifest.n_rows then
      Status.error_internal
        (Printf.sprintf
           "Snapshot_format.read: row count mismatch (payload=%d manifest=%d)"
           (List.length rows) manifest.n_rows)
    else _rows_to_snapshots ~schema:manifest.schema rows
  with
  | Sys_error msg | Failure msg ->
      Status.error_internal (Printf.sprintf "Snapshot_format.read: %s" msg)
  | Sexp.Of_sexp_error (exn, _) ->
      Status.error_internal
        (Printf.sprintf "Snapshot_format.read: sexp decode: %s"
           (Exn.to_string exn))

let read_with_expected_schema ~path ~(expected : Snapshot_schema.t) =
  let open Result.Let_syntax in
  let%bind snapshots = read ~path in
  match snapshots with
  | [] -> Ok snapshots
  | first :: _ ->
      if String.equal first.schema.schema_hash expected.schema_hash then
        Ok snapshots
      else
        Error
          {
            Status.code = Failed_precondition;
            message =
              Printf.sprintf
                "Snapshot_format.read_with_expected_schema: schema hash skew \
                 (file=%s expected=%s)"
                first.schema.schema_hash expected.schema_hash;
          }
