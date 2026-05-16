open Core
open Result.Let_syntax

type time_ns = Time_ns.Alternate_sexp.t [@@deriving sexp, compare, equal]

type reconcile_entry = {
  reconcile_at : time_ns;
  symbol : string;
  old_sha256 : string;
  new_sha256 : string;
  old_date_range : (Date.t * Date.t) option; [@sexp.option]
  new_date_range : (Date.t * Date.t) option; [@sexp.option]
  old_rows_count : int;
  new_rows_count : int;
  fetch_id : string;
}
[@@deriving sexp, compare, equal]

type reconcile_result = Reconciled of reconcile_entry | Unchanged

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

(* {1 Phase 3 — reconcile-on-refetch diff log} *)

let _reconcile_log_dir = "_reconcile_log"

let _date_shard_of_time t =
  let date = Time_ns.to_date t ~zone:Time_float.Zone.utc in
  Date.to_string date

let reconcile_log_path ~data_dir ~reconcile_at symbol =
  let date_shard = _date_shard_of_time reconcile_at in
  Fpath.(data_dir / _reconcile_log_dir / date_shard / (symbol ^ ".sexp"))

let _build_reconcile_entry ~prior ~new_sha256 ~new_path ~fetch_id =
  {
    reconcile_at = Time_ns.now ();
    symbol = prior.Manifest.symbol;
    old_sha256 = prior.Manifest.sha256;
    new_sha256;
    old_date_range = prior.Manifest.date_range;
    new_date_range = _date_range_of_path new_path;
    old_rows_count = prior.Manifest.rows_count;
    new_rows_count = _row_count_of_path new_path;
    fetch_id;
  }

let _ensure_parent_dir ~path =
  let dir = Filename.dirname path in
  match Bos.OS.Dir.create ~path:true (Fpath.v dir) with
  | Ok _ -> Ok ()
  | Error (`Msg msg) -> Status.error_internal msg

let _append_sexp_to_file ~path sexp =
  let oc = Stdlib.open_out_gen [ Open_append; Open_creat ] 0o644 path in
  Exn.protect
    ~f:(fun () ->
      Out_channel.output_string oc (Sexp.to_string_hum sexp);
      Out_channel.newline oc;
      Ok ())
    ~finally:(fun () -> Out_channel.close oc)
  |> Result.map_error ~f:(fun e ->
      Status.internal_error
        (Printf.sprintf "Reconcile log write failed: %s" (Exn.to_string e)))

let _write_reconcile_entry ~data_dir entry =
  let path =
    reconcile_log_path ~data_dir ~reconcile_at:entry.reconcile_at entry.symbol
    |> Fpath.to_string
  in
  let%bind () = _ensure_parent_dir ~path in
  _append_sexp_to_file ~path (sexp_of_reconcile_entry entry)

let _persist_or_warn ~data_dir ~symbol entry =
  match _write_reconcile_entry ~data_dir entry with
  | Ok () -> Ok (Reconciled entry)
  | Error err ->
      _log_warning "csv_storage: reconcile log write failed for %s: %s" symbol
        err.message;
      Ok Unchanged

let _reconcile_against_prior ~data_dir ~new_path ~fetch_id prior =
  match Manifest.sha256_of_file ~path:new_path with
  | Error err ->
      _log_warning "csv_storage: reconcile sha256 failed for %s: %s"
        prior.Manifest.symbol err.message;
      Ok Unchanged
  | Ok new_sha256 when String.equal new_sha256 prior.Manifest.sha256 ->
      Ok Unchanged
  | Ok new_sha256 ->
      let entry =
        _build_reconcile_entry ~prior ~new_sha256 ~new_path ~fetch_id
      in
      _persist_or_warn ~data_dir ~symbol:prior.Manifest.symbol entry

let _reconcile_with_loaded ~data_dir ~symbol ~new_path ~fetch_id m =
  match Manifest.find m ~symbol with
  | None -> Ok Unchanged
  | Some prior -> _reconcile_against_prior ~data_dir ~new_path ~fetch_id prior

let reconcile_on_save ~data_dir ~symbol ~new_path ~fetch_id =
  let manifest_path = shard_manifest_path ~data_dir symbol |> Fpath.to_string in
  match Manifest.read ~path:manifest_path with
  | Error { code = Status.NotFound; _ } -> Ok Unchanged
  | Error err ->
      _log_warning "csv_storage: reconcile manifest read failed for %s: %s"
        symbol err.message;
      Ok Unchanged
  | Ok m -> _reconcile_with_loaded ~data_dir ~symbol ~new_path ~fetch_id m
