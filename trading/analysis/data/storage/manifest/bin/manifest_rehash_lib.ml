open Core

let _data_csv_name = "data.csv"
let _max_failure_paths_to_print = 5

(* Walk [data_dir] and collect (shard_dir, csv_path) pairs.

   Shape: [data_dir / <L1> / <L2> / <SYM> / data.csv]. Anything that doesn't
   match the layout is ignored. *)
let _is_shard_dir name = String.length name = 1

let _scan_symbol_dir ~shard_dir ~sym_dir =
  let csv = Filename.concat sym_dir _data_csv_name in
  if Stdlib.Sys.file_exists csv then Some (shard_dir, csv) else None

let _scan_l2_shard l2_dir =
  if not (Stdlib.Sys.is_directory l2_dir) then []
  else
    Stdlib.Sys.readdir l2_dir |> Array.to_list
    |> List.filter_map ~f:(fun sym ->
        let sym_dir = Filename.concat l2_dir sym in
        if Stdlib.Sys.is_directory sym_dir then
          _scan_symbol_dir ~shard_dir:l2_dir ~sym_dir
        else None)

let _scan_l1_shard l1_dir =
  if not (Stdlib.Sys.is_directory l1_dir) then []
  else
    Stdlib.Sys.readdir l1_dir |> Array.to_list
    |> List.filter ~f:_is_shard_dir
    |> List.concat_map ~f:(fun l2 -> _scan_l2_shard (Filename.concat l1_dir l2))

let _scan_data_dir data_dir =
  if not (Stdlib.Sys.is_directory data_dir) then []
  else
    Stdlib.Sys.readdir data_dir
    |> Array.to_list
    |> List.filter ~f:_is_shard_dir
    |> List.concat_map ~f:(fun l1 ->
        _scan_l1_shard (Filename.concat data_dir l1))

(* Load each unique shard's manifest at most once. [None] means "no manifest or
   unreadable", so a missing entry is treated identically to a missing
   manifest. *)
let _load_manifests_per_shard csvs =
  let shard_paths =
    csvs |> List.map ~f:fst |> List.dedup_and_sort ~compare:String.compare
  in
  let table = Hashtbl.create (module String) in
  List.iter shard_paths ~f:(fun shard ->
      let mpath = Filename.concat shard "manifest.sexp" in
      let m =
        if Stdlib.Sys.file_exists mpath then
          match Manifest.read ~path:mpath with
          | Ok m -> Some m
          | Error _ -> None
        else None
      in
      Hashtbl.set table ~key:shard ~data:m);
  table

let _has_manifest_entry shard_table ~shard ~symbol =
  match Hashtbl.find shard_table shard with
  | None | Some None -> false
  | Some (Some m) -> Option.is_some (Manifest.find m ~symbol)

type counters = {
  mutable walked : int;
  mutable skipped_existing : int;
  mutable rehashed : int;
  mutable failures : (string * string) list;
}

let empty_counters () =
  { walked = 0; skipped_existing = 0; rehashed = 0; failures = [] }

let _record_failure counters ~csv_path ~msg =
  if List.length counters.failures < _max_failure_paths_to_print then
    counters.failures <- counters.failures @ [ (csv_path, msg) ]

let _symbol_of_csv_path csv_path = Filename.basename (Filename.dirname csv_path)

(* Render [endpoint_fmt] for [symbol]: if the format string contains [%s] use
   printf substitution, otherwise return verbatim. Defensive against malformed
   format strings — falls back to the verbatim form. *)
let _render_endpoint endpoint_fmt symbol =
  try Printf.sprintf (Scanf.format_from_string endpoint_fmt "%s") symbol
  with _ -> endpoint_fmt

let _process_one ~data_dir ~source ~endpoint_fmt ~dry_run ~only_missing
    ~shard_table counters (shard, csv_path) =
  counters.walked <- counters.walked + 1;
  let symbol = _symbol_of_csv_path csv_path in
  let already_present = _has_manifest_entry shard_table ~shard ~symbol in
  if only_missing && already_present then
    counters.skipped_existing <- counters.skipped_existing + 1
  else if dry_run then counters.rehashed <- counters.rehashed + 1
  else
    let endpoint = _render_endpoint endpoint_fmt symbol in
    match
      Csv.Csv_storage_manifest.update_for_save ~data_dir ~symbol ~path:csv_path
        ~source ~endpoint ~vendor_revision_tag:"" ~fetch_id:""
        ~api_key_id:"manifest_rehash"
    with
    | Ok () -> counters.rehashed <- counters.rehashed + 1
    | Error err -> _record_failure counters ~csv_path ~msg:err.message

let print_summary counters =
  printf "Manifest rehash summary\n";
  printf "  walked              = %d\n" counters.walked;
  printf "  manifests present   = %d\n" counters.skipped_existing;
  printf "  rehashed            = %d\n" counters.rehashed;
  printf "  failures            = %d\n" (List.length counters.failures);
  if not (List.is_empty counters.failures) then (
    printf "  first failures:\n";
    List.iter counters.failures ~f:(fun (p, msg) ->
        printf "    %s : %s\n" p msg))

let run ~data_dir_str ~source ~endpoint_fmt ~dry_run ~only_missing =
  let csvs = _scan_data_dir data_dir_str in
  let shard_table = _load_manifests_per_shard csvs in
  let data_dir = Fpath.v data_dir_str in
  let counters = empty_counters () in
  List.iter csvs
    ~f:
      (_process_one ~data_dir ~source ~endpoint_fmt ~dry_run ~only_missing
         ~shard_table counters);
  print_summary counters;
  counters
