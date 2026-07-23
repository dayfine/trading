open Core
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

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

(* v5 leaf: derive the sketch from the loaded side-table, anchored at the row's
   raw [Close] (still a dense column — only the [Res_*] histogram columns are
   retired by v5). A failed [Close] read collapses to [None], the same
   partial-read discipline [read_sketch] applies. *)
let _read_sketch_v5 ~(cb : Snapshot_callbacks.t) ~symbol ~as_of ~entries =
  match
    cb.Snapshot_callbacks.read_field ~symbol ~date:as_of
      ~field:Snapshot_schema.Close
  with
  | Ok close ->
      Some (Weekly_sidetable_reader.sketch_of_entries ~entries ~as_of ~close)
  | Error _ -> None

(* Sketch-v5 PR 4: a NEW-schema (13-col) warehouse retired the dense [Res_*]
   columns, so [read_sketch] returns [None] on it. If resistance scoring is
   [armed] and the symbol also has NO side-table, silently returning [None] would
   change armed backtest results invisibly (the score just drops the supply
   term). Fail LOUD instead — a thin (v5) warehouse must carry a [SYMBOL.weekly]
   side-table for every scored symbol. Unarmed configs never consult the sketch,
   so a thin warehouse with a missing side-table is fully valid for them; an OLD
   dense warehouse always resolves via [read_sketch], so this never fires there.

   [sketch_warehouse] gates the loud-fail to a genuine sketch warehouse (2026-07-23
   bundle promotion, which arms resistance scoring by DEFAULT). Before the
   promotion, "armed" implied a deliberate sketch-warehouse run, so the loud-fail
   was safe. With arming now the default, an in-process CSV snapshot / panel-mode
   run (no side-tables AND no dense [Res_*] columns, [sketch_warehouse = false])
   also reaches here — it must DEGRADE to [None] (the v1 binary grade), not crash.
   Only a warehouse that advertises side-tables (manifest
   [weekly_sidetable_format_hash = Some _], [sketch_warehouse = true]) still fails
   loud when a scored symbol's side-table is absent — the #2038 data-integrity
   guard, preserved exactly. *)
let _dense_fallback_or_raise ~symbol ~armed ~sketch_warehouse :
    Resistance_supply.sketch option -> Resistance_supply.sketch option =
  function
  | Some _ as s -> s
  | None when armed && sketch_warehouse ->
      failwithf
        "Resistance_sketch_reader: resistance scoring is armed but symbol %s \
         has no weekly side-table and no readable dense resistance columns — a \
         thin (sketch-v5) warehouse must carry a SYMBOL.weekly side-table for \
         every scored symbol (the dense Res_* columns were retired; see \
         sketch-v5 PR 4)"
        symbol ()
  | None -> None

let read ~(cb : Snapshot_callbacks.t) ~symbol ~as_of
    ?(weekly_sidetable : Weekly_sidetable.entry list option) ?(armed = false)
    ?(sketch_warehouse = false) () : Resistance_supply.sketch option =
  match weekly_sidetable with
  | Some entries -> _read_sketch_v5 ~cb ~symbol ~as_of ~entries
  | None ->
      _dense_fallback_or_raise ~symbol ~armed ~sketch_warehouse
        (read_sketch ~cb ~symbol ~as_of)

let closure ?snapshot_cb ?stock_symbol ?weekly_sidetable ?(armed = false)
    ?(sketch_warehouse = false) ~(stock : Snapshot_bar_views.weekly_view) () :
    unit -> Resistance_supply.sketch option =
  match (snapshot_cb, stock_symbol) with
  | Some cb, Some symbol when stock.n > 0 ->
      let as_of = stock.dates.(stock.n - 1) in
      fun () ->
        read ~cb ~symbol ~as_of ?weekly_sidetable ~armed ~sketch_warehouse ()
  | _ -> fun () -> None
