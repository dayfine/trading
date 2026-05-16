open Core
open Result.Let_syntax

let shard_manifest_path ~data_dir symbol =
  let first_char = String.get symbol 0 in
  let last_char = String.get symbol (String.length symbol - 1) in
  Fpath.(
    data_dir / String.make 1 first_char / String.make 1 last_char
    / "manifest.sexp")

let _log_warning fmt = Printf.eprintf (fmt ^^ "\n%!")

let _read_or_create ~manifest_path =
  match Manifest.read ~path:manifest_path with
  | Ok m -> Ok m
  | Error { code = Status.NotFound; _ } -> Ok (Manifest.create ())
  | Error _ as e -> e

let _date_of_csv_line line =
  match line |> String.split ~on:',' |> List.hd with
  | None -> None
  | Some s -> ( try Some (Date.of_string s) with _ -> None)

let _date_range_of_path path =
  try
    let chan = In_channel.create path in
    let _header = In_channel.input_line chan in
    let first = Option.bind (In_channel.input_line chan) ~f:_date_of_csv_line in
    let last = ref first in
    In_channel.iter_lines chan ~f:(fun line ->
        match _date_of_csv_line line with
        | Some d -> last := Some d
        | None -> ());
    In_channel.close chan;
    match (first, !last) with
    | Some f, Some l -> Some (f, l)
    | Some f, None -> Some (f, f)
    | _ -> None
  with Sys_error _ -> None

let _row_count_of_path path =
  try
    let total =
      In_channel.with_file path ~f:(fun chan ->
          In_channel.fold_lines chan ~init:0 ~f:(fun acc _ -> acc + 1))
    in
    Int.max 0 (total - 1)
  with Sys_error _ -> 0

let _build_entry ~symbol ~path ~source ~endpoint ~vendor_revision_tag ~fetch_id
    ~api_key_id ~sha256 : Manifest.file_metadata =
  {
    symbol;
    source;
    endpoint;
    date_range = _date_range_of_path path;
    rows_count = _row_count_of_path path;
    sha256;
    vendor_revision_tag;
    fetched_at = Time_ns.now ();
    fetch_id;
    api_key_id;
  }

let _write_or_warn ~manifest_path ~symbol m =
  match Manifest.write ~path:manifest_path m with
  | Ok () -> Ok ()
  | Error err ->
      _log_warning "csv_storage: manifest write failed for %s: %s" symbol
        err.message;
      Ok ()

let _upsert_to_disk ~manifest_path ~symbol ~entry =
  match _read_or_create ~manifest_path with
  | Error err ->
      _log_warning "csv_storage: manifest read failed for %s: %s" symbol
        err.message;
      Ok ()
  | Ok m ->
      _write_or_warn ~manifest_path ~symbol (Manifest.upsert_entry m entry)

let update_for_save ~data_dir ~symbol ~path ~source ~endpoint
    ~vendor_revision_tag ~fetch_id ~api_key_id =
  let manifest_path = shard_manifest_path ~data_dir symbol |> Fpath.to_string in
  match Manifest.sha256_of_file ~path with
  | Error err ->
      _log_warning "csv_storage: sha256 failed for %s: %s" symbol err.message;
      Ok ()
  | Ok sha256 ->
      let entry =
        _build_entry ~symbol ~path ~source ~endpoint ~vendor_revision_tag
          ~fetch_id ~api_key_id ~sha256
      in
      _upsert_to_disk ~manifest_path ~symbol ~entry

let _corruption_msg ~symbol ~claimed ~actual =
  Printf.sprintf "data corruption: %s sha256 mismatch (manifest=%s, file=%s)"
    symbol claimed actual

let _verify_hash ~strictness ~symbol ~claimed ~actual =
  if String.equal claimed actual then Ok ()
  else
    match strictness with
    | `Off -> Ok ()
    | `Strict ->
        Status.error_internal (_corruption_msg ~symbol ~claimed ~actual)
    | `Warn ->
        _log_warning "csv_storage: %s"
          (_corruption_msg ~symbol ~claimed ~actual);
        Ok ()

let _warn_missing ~strictness ~symbol ~reason =
  match strictness with
  | `Warn ->
      _log_warning "csv_storage: no manifest entry for %s (%s); skipping verify"
        symbol reason
  | `Strict | `Off -> ()

let _verify_entry_against_file ~strictness ~symbol ~path ~entry =
  let%bind actual = Manifest.sha256_of_file ~path in
  _verify_hash ~strictness ~symbol ~claimed:entry.Manifest.sha256 ~actual

let _verify_loaded ~strictness ~symbol ~path m =
  match Manifest.find m ~symbol with
  | None ->
      _warn_missing ~strictness ~symbol ~reason:"no entry for symbol";
      Ok ()
  | Some entry -> _verify_entry_against_file ~strictness ~symbol ~path ~entry

let _verify_active ~strictness ~symbol ~path ~manifest_path =
  match Manifest.read ~path:manifest_path with
  | Error { code = Status.NotFound; _ } ->
      _warn_missing ~strictness ~symbol ~reason:"no manifest";
      Ok ()
  | Error err ->
      _warn_missing ~strictness ~symbol ~reason:err.message;
      Ok ()
  | Ok m -> _verify_loaded ~strictness ~symbol ~path m

let verify ~data_dir ~symbol ~path ~strictness =
  match strictness with
  | `Off -> Ok ()
  | `Strict | `Warn ->
      let manifest_path =
        shard_manifest_path ~data_dir symbol |> Fpath.to_string
      in
      _verify_active ~strictness ~symbol ~path ~manifest_path
