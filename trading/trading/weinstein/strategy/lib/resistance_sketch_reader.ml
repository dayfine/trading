open Core
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Reshape a flat band-major cell vector ([band * n_buckets + bucket]) into the
   [Resistance_supply.sketch.hist_bands] age-band matrix. *)
let _bands_of_flat cells ~n_buckets =
  Array.init Snapshot_schema.n_age_bands ~f:(fun band ->
      Array.init n_buckets ~f:(fun bucket ->
          cells.((band * n_buckets) + bucket)))

(* Read the histogram, detecting the warehouse width. A v4 (age-banded)
   warehouse carries [n_hist_cells] columns; a v3 warehouse carries only the
   [n_hist_buckets] age-blind columns (its trailing [Res_hist] cells are absent,
   so the probe read fails). The v3 histogram maps to the youngest age band via
   [hist_bands_of_legacy], scoring bit-identically under default band weights —
   so existing v3 warehouses keep working with no rebuild. *)
let _read_hist_bands ~read =
  let n_buckets = Snapshot_schema.n_hist_buckets in
  let n_cells = Snapshot_schema.n_hist_cells in
  let read_cells n =
    List.init n ~f:(fun k -> read (Snapshot_schema.Res_hist k)) |> Option.all
  in
  match read (Snapshot_schema.Res_hist (n_cells - 1)) with
  | Some _ ->
      Option.map (read_cells n_cells) ~f:(fun cells ->
          _bands_of_flat (Array.of_list cells) ~n_buckets)
  | None ->
      Option.map (read_cells n_buckets) ~f:(fun flat ->
          Resistance_supply.hist_bands_of_legacy (Array.of_list flat))

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
  let%map hist_bands = _read_hist_bands ~read in
  Resistance_supply.
    {
      max_high_130w;
      max_high_260w;
      max_high_520w;
      bars_seen;
      hist_bands;
      anchor_close;
    }

let closure ?snapshot_cb ?stock_symbol ~(stock : Snapshot_bar_views.weekly_view)
    () : unit -> Resistance_supply.sketch option =
  match (snapshot_cb, stock_symbol) with
  | Some cb, Some symbol when stock.n > 0 ->
      let as_of = stock.dates.(stock.n - 1) in
      fun () -> read_sketch ~cb ~symbol ~as_of
  | _ -> fun () -> None
