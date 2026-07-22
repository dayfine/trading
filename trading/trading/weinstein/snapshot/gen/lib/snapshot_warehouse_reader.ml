open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Bar_reader = Weinstein_strategy.Bar_reader
module Weekly_sidetable_reader = Weinstein_strategy.Weekly_sidetable_reader

let _fallback_cache_mb = 256

let default_cache_mb () =
  match Sys.getenv "SNAPSHOT_CACHE_MB" with
  | Some s -> (
      try Int.of_string (String.strip s) with _ -> _fallback_cache_mb)
  | None -> _fallback_cache_mb

(* Trading-day calendar: every weekday (Mon-Fri) in the inclusive range
   [start..end_]. Holidays are not removed — [daily_view_for] walks calendar
   columns NaN-passthrough deterministically. Mirrors
   [Panel_runner._build_calendar] so the snapshot-backed reader defines its
   windows identically to the production backtest path. *)
let _build_calendar ~start ~end_ : Date.t array =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (Date.add_days d 1) acc'
  in
  Array.of_list (loop start [])

let _read_manifest ~warehouse_dir =
  let manifest_path = Filename.concat warehouse_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path:manifest_path with
  | Ok m -> m
  | Error err ->
      failwithf "Snapshot_warehouse_reader: cannot read %s: %s" manifest_path
        (Status.show err) ()

let _open_panels ~warehouse_dir ~manifest ~max_cache_mb =
  match
    Daily_panels.create ~snapshot_dir:warehouse_dir ~manifest ~max_cache_mb
  with
  | Ok p -> p
  | Error err ->
      failwithf "Snapshot_warehouse_reader: Daily_panels.create failed: %s"
        (Status.show err) ()

let build ~warehouse_dir ~as_of ~warmup_days
    ?(max_cache_mb = default_cache_mb ()) () : Bar_reader.t =
  let manifest = _read_manifest ~warehouse_dir in
  let panels = _open_panels ~warehouse_dir ~manifest ~max_cache_mb in
  let calendar =
    _build_calendar ~start:(Date.add_days as_of (-warmup_days)) ~end_:as_of
  in
  let callbacks = Snapshot_callbacks.of_daily_panels panels in
  (* Sketch-v5 side-table loader gated on the manifest's format hash: [None]
     hash (non-v5 warehouse) -> every symbol reads the dense columns; a
     mismatched hash raises (loud staleness refusal). *)
  let weekly_sidetable_loader =
    Weekly_sidetable_reader.loader_for ~snapshot_dir:warehouse_dir
      ~manifest_format_hash:
        manifest.Snapshot_manifest.weekly_sidetable_format_hash
  in
  Bar_reader.of_snapshot_views ~calendar ~weekly_sidetable_loader callbacks
