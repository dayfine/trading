open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

(** Fallback LRU cache cap (MB) when [SNAPSHOT_CACHE_MB] is unset — sized for a
    ~500-symbol sp500 working set. *)
let _fallback_cache_mb = 256

let default_cache_mb () =
  match Sys.getenv "SNAPSHOT_CACHE_MB" with
  | Some s -> (
      try Int.of_string (String.strip s) with _ -> _fallback_cache_mb)
  | None -> _fallback_cache_mb

(** Read a pre-built warehouse's [manifest.sexp] (same convention as
    [Bar_source_resolver]) and return [(dir, manifest)] for
    [Daily_panels.create]. *)
let _load_warehouse ~warehouse_dir =
  let manifest_path = Filename.concat warehouse_dir "manifest.sexp" in
  match Snapshot_pipeline.Snapshot_manifest.read ~path:manifest_path with
  | Ok manifest ->
      eprintf "snapshot_world: using snapshot warehouse %s (%d entries)\n%!"
        warehouse_dir
        (List.length manifest.entries);
      (warehouse_dir, manifest)
  | Error err ->
      failwithf "snapshot_world: manifest read failed at %s: %s" manifest_path
        (Status.show err) ()

let build_callbacks ~warehouse_dir ~data_dir ~index_symbol ~universe ~start
    ~end_ ~max_cache_mb : Snapshot_callbacks.t =
  let symbols =
    index_symbol :: universe |> List.dedup_and_sort ~compare:String.compare
  in
  let snapshot_dir, manifest =
    match warehouse_dir with
    | Some dir -> _load_warehouse ~warehouse_dir:dir
    | None ->
        Csv_snapshot_builder.build ~data_dir ~universe:symbols ~start_date:start
          ~end_date:end_
  in
  let panels =
    match Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb with
    | Ok p -> p
    | Error err ->
        failwithf "snapshot_world: Daily_panels.create failed: %s"
          (Status.show err) ()
  in
  Snapshot_callbacks.of_daily_panels panels
