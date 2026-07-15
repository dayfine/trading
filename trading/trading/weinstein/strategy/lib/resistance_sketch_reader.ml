open Core
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let read_sketch ~(cb : Snapshot_callbacks.t) ~symbol ~as_of :
    Resistance_supply.sketch option =
  let read field =
    match cb.Snapshot_callbacks.read_field ~symbol ~date:as_of ~field with
    | Ok v -> Some v
    | Error _ -> None
  in
  let open Option.Let_syntax in
  let%bind max_high_130w = read Snapshot_schema.Res_max_high_130w in
  let%bind max_high_260w = read Snapshot_schema.Res_max_high_260w in
  let%bind max_high_520w = read Snapshot_schema.Res_max_high_520w in
  let%bind bars_seen = read Snapshot_schema.Res_bars_seen in
  let%bind anchor_close = read Snapshot_schema.Close in
  let%map hist =
    List.init Snapshot_schema.n_hist_buckets ~f:(fun k ->
        read (Snapshot_schema.Res_hist k))
    |> Option.all
  in
  Resistance_supply.
    {
      max_high_130w;
      max_high_260w;
      max_high_520w;
      bars_seen;
      hist = Array.of_list hist;
      anchor_close;
    }

let closure ?snapshot_cb ?stock_symbol ~(stock : Snapshot_bar_views.weekly_view)
    () : unit -> Resistance_supply.sketch option =
  match (snapshot_cb, stock_symbol) with
  | Some cb, Some symbol when stock.n > 0 ->
      let as_of = stock.dates.(stock.n - 1) in
      fun () -> read_sketch ~cb ~symbol ~as_of
  | _ -> fun () -> None
