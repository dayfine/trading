open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

type t =
  | Csv
  | Snapshot of {
      snapshot_dir : string;
      manifest : Snapshot_pipeline.Snapshot_manifest.t;
    }

let build_adapter_from_panels panels =
  let callbacks = Snapshot_callbacks.of_daily_panels panels in
  let get_price, get_previous_bar =
    Snapshot_bar_source.make_callbacks ~panels ~callbacks
  in
  Trading_simulation_data.Market_data_adapter.create_with_callbacks ~get_price
    ~get_previous_bar

let _build_snapshot_adapter ~snapshot_dir ~manifest ~max_cache_mb =
  let open Result.Let_syntax in
  let%bind panels = Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb in
  Ok (build_adapter_from_panels panels)

let build_adapter t ~data_dir ~max_cache_mb =
  match t with
  | Csv -> Ok (Trading_simulation_data.Market_data_adapter.create ~data_dir)
  | Snapshot { snapshot_dir; manifest } ->
      _build_snapshot_adapter ~snapshot_dir ~manifest ~max_cache_mb

let build_shared_panels t =
  match t with
  | Csv -> Ok None
  | Snapshot { snapshot_dir; manifest } ->
      let open Result.Let_syntax in
      let%bind panels =
        Daily_panels.create ~snapshot_dir ~manifest
          ~max_cache_mb:(Snapshot_cache_config.resolve_cache_mb ())
      in
      Ok (Some panels)

let close_shared_panels = Daily_panels.close
