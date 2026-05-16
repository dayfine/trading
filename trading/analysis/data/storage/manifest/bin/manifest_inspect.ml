(** [manifest_inspect <data-dir>] walks the L1/L2-sharded data directory and
    prints an inventory summary: total symbols on disk, count of manifest
    entries found, missing-manifest count (CSVs with no entry), stale-manifest
    count (entry whose recorded sha256 disagrees with the current file hash), a
    per-source breakdown, and the oldest/newest [fetched_at] across all entries.

    Phase 1 does not yet wire manifest writes into [Csv_storage.save] — so the
    expected baseline output on the existing cache is "0 manifests / N missing",
    where N is the number of [<L1>/<L2>/<SYM>/data.csv] files. The CLI is
    shipped so Phase 2 can use it as a probe / smoke-test once the writes are
    integrated. *)

open Core

(* Walk [data_dir] and collect (shard_dir, csv_path) pairs.

   Shape: [data_dir / <L1> / <L2> / <SYM> / data.csv]. Anything that doesn't
   match the layout is ignored (e.g. [breadth/], [backtest_scenarios/],
   [universes/] under [trading/test_data/]). *)
let _is_shard_dir name = String.length name = 1

let _scan_symbol_dir ~shard_dir ~sym_dir =
  let csv = Filename.concat sym_dir "data.csv" in
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

(* For each unique L1/L2 shard we discover, load its [manifest.sexp] (if any)
   and tally entries by symbol. Returns a hashtable keyed by L2 shard
   directory path -> (manifest option). *)
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

(* Returns [(sym, entry option, csv_path)] tuples. *)
let _zip_csvs_with_manifest csvs shard_table =
  List.map csvs ~f:(fun (shard, csv_path) ->
      let sym = Filename.basename (Filename.dirname csv_path) in
      let entry =
        match Hashtbl.find shard_table shard with
        | None | Some None -> None
        | Some (Some m) -> Manifest.find m ~symbol:sym
      in
      (sym, entry, csv_path))

type summary = {
  total_symbols : int;
  manifest_entries : int;
  missing_manifests : int;
  stale_manifests : int;
  per_source : (string * int) list;
  oldest_fetched_at : Time_ns.Alternate_sexp.t option;
  newest_fetched_at : Time_ns.Alternate_sexp.t option;
}

let _is_stale (entry : Manifest.file_metadata) ~csv_path =
  match Manifest.sha256_of_file ~path:csv_path with
  | Error _ ->
      false (* unreadable file is reported by missing/total count, not stale *)
  | Ok actual -> not (String.equal actual entry.sha256)

let _accumulate (sym, entry, csv_path) acc =
  let entries, missing, stale, sources, oldest, newest = acc in
  match entry with
  | None ->
      let _ = sym in
      let _ = csv_path in
      (entries, missing + 1, stale, sources, oldest, newest)
  | Some (e : Manifest.file_metadata) ->
      let stale' = if _is_stale e ~csv_path then stale + 1 else stale in
      let sources' =
        List.Assoc.find sources ~equal:String.equal e.source
        |> Option.value ~default:0
        |> fun n -> List.Assoc.add sources ~equal:String.equal e.source (n + 1)
      in
      let oldest' =
        match oldest with
        | None -> Some e.fetched_at
        | Some o when Time_ns.( < ) e.fetched_at o -> Some e.fetched_at
        | _ -> oldest
      in
      let newest' =
        match newest with
        | None -> Some e.fetched_at
        | Some n when Time_ns.( > ) e.fetched_at n -> Some e.fetched_at
        | _ -> newest
      in
      (entries + 1, missing, stale', sources', oldest', newest')

let _summarize zipped =
  let entries, missing, stale, sources, oldest, newest =
    List.fold zipped ~init:(0, 0, 0, [], None, None) ~f:(fun acc x ->
        _accumulate x acc)
  in
  {
    total_symbols = List.length zipped;
    manifest_entries = entries;
    missing_manifests = missing;
    stale_manifests = stale;
    per_source =
      List.sort sources ~compare:(fun (a, _) (b, _) -> String.compare a b);
    oldest_fetched_at = oldest;
    newest_fetched_at = newest;
  }

let _time_str = function
  | None -> "<none>"
  | Some t -> Sexp.to_string (Time_ns.Alternate_sexp.sexp_of_t t)

let _print_summary s =
  printf "Manifest inventory summary\n";
  printf "  total_symbols      = %d\n" s.total_symbols;
  printf "  manifest_entries   = %d\n" s.manifest_entries;
  printf "  missing_manifests  = %d\n" s.missing_manifests;
  printf "  stale_manifests    = %d\n" s.stale_manifests;
  printf "  oldest_fetched_at  = %s\n" (_time_str s.oldest_fetched_at);
  printf "  newest_fetched_at  = %s\n" (_time_str s.newest_fetched_at);
  printf "  per_source:\n";
  if List.is_empty s.per_source then printf "    (no manifest entries)\n"
  else List.iter s.per_source ~f:(fun (src, n) -> printf "    %-20s %d\n" src n)

let run ~data_dir =
  let csvs = _scan_data_dir data_dir in
  let shard_table = _load_manifests_per_shard csvs in
  let zipped = _zip_csvs_with_manifest csvs shard_table in
  let summary = _summarize zipped in
  _print_summary summary

let () =
  let argv = Sys.get_argv () in
  if Array.length argv <> 2 then (
    prerr_endline "usage: manifest_inspect <data-dir>";
    Stdlib.exit 2);
  run ~data_dir:argv.(1)
