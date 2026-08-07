(** Parity tests for {!Weinstein_strategy.Panel_callbacks}.

    For each callee (Stage / Rs / Stock_analysis / Sector / Macro /
    Weinstein_stops.Support_floor), build callbacks two ways on the same input
    data:

    - {b bar-list path}: existing [callbacks_from_bars] over a
      [Daily_price.t list].
    - {b snapshot view path}: {!Panel_callbacks.X_callbacks_of_*} over a
      {!Snapshot_runtime.Snapshot_bar_views.weekly_view} /
      {!Snapshot_runtime.Snapshot_bar_views.daily_view} produced by writing the
      same bars into a tmp snapshot directory and reading via
      {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} / [daily_view_for].

    Run the corresponding [analyze_with_callbacks] on each and assert the
    results are bit-identical (structural [equal_to] over the float fields). Any
    drift indicates a divergence in the snapshot-shaped constructor. *)

open OUnit2
open Core
open Matchers
module Panel_callbacks = Weinstein_strategy.Panel_callbacks
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Weekly_sidetable_reader = Weinstein_strategy.Weekly_sidetable_reader
module Bar_reader = Weinstein_strategy.Bar_reader
module Internal_for_test = Weinstein_strategy.Internal_for_test
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Synthetic bar builders                                               *)
(* ------------------------------------------------------------------ *)

let make_weekly_bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

(** Build [n] consecutive Friday weekly bars starting at [start_friday]. The
    dates are spaced 7 days apart (Friday-anchored). The price walks with [step]
    per bar. *)
let make_friday_bars ~start_friday ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_friday (i * 7) in
      make_weekly_bar ~date ~price:(start_price +. (Float.of_int i *. step)))

(** Build a {!Snapshot_callbacks.t} from in-memory [(symbol, bars)] pairs by
    materialising a tmp snapshot directory under {!Snapshot_schema.default}.
    Same setup as {!Bar_reader.of_in_memory_bars} but exposes the
    {!Snapshot_callbacks.t} directly so the parity tests can drive
    {!Snapshot_bar_views.weekly_view_for} from the same input. *)
let build_snapshot_callbacks
    (symbol_bars : (string * Types.Daily_price.t list) list) :
    Snapshot_callbacks.t =
  let dir = Stdlib.Filename.temp_dir "test_panel_callbacks_" "" in
  let entries =
    List.map symbol_bars ~f:(fun (symbol, bars) ->
        let rows =
          match
            Pipeline.build_for_symbol ~symbol ~bars
              ~schema:Snapshot_schema.default ()
          with
          | Ok rs -> rs
          | Error err ->
              failwithf "Pipeline.build_for_symbol %s: %s" symbol
                err.Status.message ()
        in
        let path = Filename.concat dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err ->
            failwithf "Snapshot_format.write %s: %s" symbol err.Status.message
              ());
        {
          Snapshot_manifest.symbol;
          path;
          byte_size = 0;
          payload_md5 = "ignored";
          csv_mtime = 0.0;
          active_through = None;
        })
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  let manifest_path = Filename.concat dir "manifest.sexp" in
  (match Snapshot_manifest.write ~path:manifest_path manifest with
  | Ok () -> ()
  | Error err -> failwithf "Snapshot_manifest.write: %s" err.Status.message ());
  let panels =
    match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:16 with
    | Ok p -> p
    | Error err -> failwithf "Daily_panels.create: %s" err.Status.message ()
  in
  Snapshot_callbacks.of_daily_panels panels

(* ------------------------------------------------------------------ *)
(* Parity tests                                                         *)
(* ------------------------------------------------------------------ *)

(* Stage parity: classify a 60-bar weekly rising series via both paths and
   require bit-identical results. *)
let test_stage_callbacks_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let cb = build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:60 ~as_of
  in
  let config = Stage.default_config in
  let bar_list_callbacks = Stage.callbacks_from_bars ~config ~bars in
  let snap_callbacks =
    Panel_callbacks.stage_callbacks_of_weekly_view ~config ~weekly:view ()
  in
  let bar_list_result =
    Stage.classify_with_callbacks ~config ~get_ma:bar_list_callbacks.get_ma
      ~get_close:bar_list_callbacks.get_close ~prior_stage:None
  in
  let snap_result =
    Stage.classify_with_callbacks ~config ~get_ma:snap_callbacks.get_ma
      ~get_close:snap_callbacks.get_close ~prior_stage:None
  in
  assert_that snap_result
    (all_of
       [
         field
           (fun (r : Stage.result) -> r.ma_value)
           (float_equal bar_list_result.ma_value);
         field
           (fun (r : Stage.result) -> r.ma_slope_pct)
           (float_equal bar_list_result.ma_slope_pct);
         field
           (fun (r : Stage.result) -> r.above_ma_count)
           (equal_to bar_list_result.above_ma_count);
       ])

(* Rs parity: stock outperforms benchmark over 60 weeks. *)
let test_rs_callbacks_parity _ =
  let stock_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:1.0
  in
  let bench_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let cb =
    build_snapshot_callbacks [ ("STOCK", stock_bars); ("BENCH", bench_bars) ]
  in
  let as_of = (List.last_exn stock_bars).Types.Daily_price.date in
  let stock_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"STOCK" ~n:60 ~as_of
  in
  let bench_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"BENCH" ~n:60 ~as_of
  in
  let bar_list_callbacks =
    Rs.callbacks_from_bars ~stock_bars ~benchmark_bars:bench_bars
  in
  let snap_cb =
    Panel_callbacks.rs_callbacks_of_weekly_views ~stock:stock_view
      ~benchmark:bench_view
  in
  let config = Rs.default_config in
  let bar_list_result =
    Rs.analyze_with_callbacks ~config
      ~get_stock_close:bar_list_callbacks.get_stock_close
      ~get_benchmark_close:bar_list_callbacks.get_benchmark_close
      ~get_date:bar_list_callbacks.get_date
  in
  let snap_result =
    Rs.analyze_with_callbacks ~config ~get_stock_close:snap_cb.get_stock_close
      ~get_benchmark_close:snap_cb.get_benchmark_close
      ~get_date:snap_cb.get_date
  in
  match (bar_list_result, snap_result) with
  | None, None -> ()
  | Some r1, Some r2 ->
      assert_that r2
        (all_of
           [
             field
               (fun (r : Rs.result) -> r.current_rs)
               (float_equal r1.current_rs);
             field
               (fun (r : Rs.result) -> r.current_normalized)
               (float_equal r1.current_normalized);
           ])
  | _ -> assert_failure "Rs result mismatch (one path returned None)"

(* Stock_analysis parity: full analyze_with_callbacks on synthetic data. *)
let test_stock_analysis_callbacks_parity _ =
  let stock_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let bench_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.4
  in
  let cb =
    build_snapshot_callbacks [ ("AAPL", stock_bars); ("SPY", bench_bars) ]
  in
  let as_of = (List.last_exn stock_bars).Types.Daily_price.date in
  let stock_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:60 ~as_of
  in
  let bench_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"SPY" ~n:60 ~as_of
  in
  let config = Stock_analysis.default_config in
  let bar_cbs =
    Stock_analysis.callbacks_from_bars ~config ~bars:stock_bars
      ~benchmark_bars:bench_bars
  in
  let snap_cbs =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views ~config
      ~stock:stock_view ~benchmark:bench_view ()
  in
  let bar_list_result =
    Stock_analysis.analyze_with_callbacks ~config ~ticker:"AAPL"
      ~callbacks:bar_cbs ~prior_stage:None
      ~as_of_date:(Date.of_string "2025-02-21")
  in
  let snap_result =
    Stock_analysis.analyze_with_callbacks ~config ~ticker:"AAPL"
      ~callbacks:snap_cbs ~prior_stage:None
      ~as_of_date:(Date.of_string "2025-02-21")
  in
  assert_that snap_result
    (all_of
       [
         field
           (fun (r : Stock_analysis.t) -> r.stage.ma_value)
           (float_equal bar_list_result.stage.ma_value);
         field
           (fun (r : Stock_analysis.t) -> r.breakout_price)
           (equal_to bar_list_result.breakout_price);
       ])

(* Sector parity: nested Stage + Rs delegation. *)
let test_sector_callbacks_parity _ =
  let sector_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let bench_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.4
  in
  let cb =
    build_snapshot_callbacks [ ("XLK", sector_bars); ("SPY", bench_bars) ]
  in
  let as_of = (List.last_exn sector_bars).Types.Daily_price.date in
  let sector_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"XLK" ~n:60 ~as_of
  in
  let bench_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"SPY" ~n:60 ~as_of
  in
  let config = Sector.default_config in
  let bar_cbs =
    Sector.callbacks_from_bars ~config ~sector_bars ~benchmark_bars:bench_bars
  in
  let snap_cbs =
    Panel_callbacks.sector_callbacks_of_weekly_views ~config ~sector:sector_view
      ~benchmark:bench_view ()
  in
  let bar_list_result =
    Sector.analyze_with_callbacks ~config ~sector_name:"Information Technology"
      ~callbacks:bar_cbs ~constituent_analyses:[] ~prior_stage:None
  in
  let snap_result =
    Sector.analyze_with_callbacks ~config ~sector_name:"Information Technology"
      ~callbacks:snap_cbs ~constituent_analyses:[] ~prior_stage:None
  in
  assert_that snap_result
    (all_of
       [
         field
           (fun (r : Sector.result) -> r.stage.ma_value)
           (float_equal bar_list_result.stage.ma_value);
         field
           (fun (r : Sector.result) -> r.bullish_constituent_pct)
           (float_equal bar_list_result.bullish_constituent_pct);
       ])

(* Macro parity: primary index + 1 global + ad_bars. *)
let test_macro_callbacks_parity _ =
  let index_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:4000.0 ~step:5.0
  in
  let global_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:15000.0 ~step:2.0
  in
  let cb =
    build_snapshot_callbacks [ ("SPY", index_bars); ("GDAXI", global_bars) ]
  in
  let as_of = (List.last_exn index_bars).Types.Daily_price.date in
  let index_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"SPY" ~n:60 ~as_of
  in
  let global_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"GDAXI" ~n:60 ~as_of
  in
  (* Build 60 weeks of synthetic A-D bars: ~1500 advancing, 1500 declining,
     small trend. *)
  let ad_bars =
    List.init 60 ~f:(fun i ->
        {
          Macro.date = Date.add_days (Date.of_string "2024-01-05") (i * 7);
          advancing = 1500 + i;
          declining = 1500 - i;
        })
  in
  let config = Macro.default_config in
  let bar_cbs =
    Macro.callbacks_from_bars ~config ~index_bars ~ad_bars
      ~global_index_bars:[ ("DAX", global_bars) ]
  in
  let snap_cbs =
    Panel_callbacks.macro_callbacks_of_weekly_views ~config ~index:index_view
      ~globals:[ ("DAX", global_view) ]
      ~ad_bars ()
  in
  let bar_list_result =
    Macro.analyze_with_callbacks ~config ~callbacks:bar_cbs ~prior_stage:None
      ~prior:None
  in
  let snap_result =
    Macro.analyze_with_callbacks ~config ~callbacks:snap_cbs ~prior_stage:None
      ~prior:None
  in
  assert_that snap_result
    (all_of
       [
         field
           (fun (r : Macro.result) -> r.confidence)
           (float_equal bar_list_result.confidence);
         field
           (fun (r : Macro.result) -> r.index_stage.ma_value)
           (float_equal bar_list_result.index_stage.ma_value);
       ])

(* Weinstein_stops.Support_floor parity: build daily bars and compare both paths. The
   Weinstein_stops.Support_floor algorithm is sensitive to indexing direction (day_offset:0 =
   newest), so this is the load-bearing parity check for that callback shape. *)
let test_support_floor_callbacks_parity _ =
  let dates =
    List.init 30 ~f:(fun i ->
        Date.add_days (Date.of_string "2024-01-02") (i * 1))
  in
  (* Build a "rally then pullback" pattern on a long-side test. *)
  let bars =
    List.mapi dates ~f:(fun i date ->
        let price =
          if i < 20 then 100.0 +. (Float.of_int i *. 1.0)
          else 120.0 -. (Float.of_int (i - 20) *. 0.5)
        in
        {
          Types.Daily_price.date;
          open_price = price;
          high_price = price *. 1.01;
          low_price = price *. 0.99;
          close_price = price;
          adjusted_close = price;
          volume = 100_000;
          active_through = None;
        })
  in
  let cb = build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let calendar =
    Array.of_list
      (List.map bars ~f:(fun b -> b.Types.Daily_price.date)
      |> List.dedup_and_sort ~compare:Date.compare)
  in
  let view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAPL" ~as_of ~lookback:30
      ~calendar
  in
  let bar_cbs =
    Weinstein_stops.Support_floor.callbacks_from_bars ~bars ~as_of
      ~lookback_bars:30
  in
  let snap_cbs = Panel_callbacks.support_floor_callbacks_of_daily_view view in
  let bar_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:bar_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05 ()
  in
  let snap_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:snap_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
      ()
  in
  match (bar_result, snap_result) with
  | None, None -> ()
  | Some r1, Some r2 -> assert_that r2 (float_equal r1)
  | Some r, None ->
      assert_failure
        (Printf.sprintf "snapshot returned None; bar-list returned Some %f" r)
  | None, Some r ->
      assert_failure
        (Printf.sprintf "bar-list returned None; snapshot returned Some %f" r)

(* Volume parity: weekly bars run through Volume.analyze_breakout via both the
   bar-list and snapshot callback paths. *)
let test_volume_callbacks_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:8 ~start_price:100.0 ~step:1.0
  in
  let cb = build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let view = Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:8 ~as_of in
  let bar_cbs = Volume.callbacks_from_bars ~bars in
  let snap_cbs = Panel_callbacks.volume_callbacks_of_weekly_view ~weekly:view in
  let config = Volume.default_config in
  (* Read at event_offset:0 (newest bar). Both paths must agree. *)
  let bar_result =
    Volume.analyze_breakout_with_callbacks ~config ~callbacks:bar_cbs
      ~event_offset:0
  in
  let snap_result =
    Volume.analyze_breakout_with_callbacks ~config ~callbacks:snap_cbs
      ~event_offset:0
  in
  match (bar_result, snap_result) with
  | None, None -> ()
  | Some r1, Some r2 ->
      assert_that r2
        (all_of
           [
             field
               (fun (r : Volume.result) -> r.event_volume)
               (equal_to (r1.event_volume : int));
             field
               (fun (r : Volume.result) -> r.avg_volume)
               (float_equal r1.avg_volume);
             field
               (fun (r : Volume.result) -> r.volume_ratio)
               (float_equal r1.volume_ratio);
           ])
  | _ -> assert_failure "Volume parity: one path returned None"

(* Resistance parity: weekly bars run through Resistance.analyze via both
   the bar-list and snapshot callback paths. *)
let test_resistance_callbacks_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:30 ~start_price:50.0 ~step:1.0
  in
  let cb = build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:30 ~as_of
  in
  let bar_cbs = Resistance.callbacks_from_bars ~bars in
  let snap_cbs =
    Panel_callbacks.resistance_callbacks_of_weekly_view ~weekly:view
  in
  let config = Resistance.default_config in
  let breakout_price = 65.0 in
  let as_of_date = Date.of_string "2025-02-21" in
  let bar_result =
    Resistance.analyze_with_callbacks ~config ~callbacks:bar_cbs ~breakout_price
      ~as_of_date
  in
  let snap_result =
    Resistance.analyze_with_callbacks ~config ~callbacks:snap_cbs
      ~breakout_price ~as_of_date
  in
  assert_that snap_result
    (all_of
       [
         field
           (fun (r : Resistance.result) -> r.quality)
           (equal_to bar_result.quality);
         field
           (fun (r : Resistance.result) -> r.breakout_price)
           (float_equal bar_result.breakout_price);
         field
           (fun (r : Resistance.result) -> List.length r.zones_above)
           (equal_to (List.length bar_result.zones_above));
       ])

(* Snapshot Stage callbacks: same fixture as test_stage_callbacks_parity, but
   built via the [_of_snapshot_views] entry-point (which folds the view fetch
   into the construction). Pins that the snapshot-views entry-point produces
   the same Stage.result as the bar-list path. *)
let test_stage_snapshot_views_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let cb = build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let config = Stage.default_config in
  let bar_list_callbacks = Stage.callbacks_from_bars ~config ~bars in
  let snap_cbs =
    Panel_callbacks.stage_callbacks_of_snapshot_views ~config ~cb ~symbol:"AAPL"
      ~n:60 ~as_of ()
  in
  let bar_result =
    Stage.classify_with_callbacks ~config ~get_ma:bar_list_callbacks.get_ma
      ~get_close:bar_list_callbacks.get_close ~prior_stage:None
  in
  let snap_result =
    Stage.classify_with_callbacks ~config ~get_ma:snap_cbs.get_ma
      ~get_close:snap_cbs.get_close ~prior_stage:None
  in
  assert_that snap_result
    (all_of
       [
         field
           (fun (r : Stage.result) -> r.ma_value)
           (float_equal bar_result.ma_value);
         field
           (fun (r : Stage.result) -> r.ma_slope_pct)
           (float_equal bar_result.ma_slope_pct);
         field
           (fun (r : Stage.result) -> r.above_ma_count)
           (equal_to bar_result.above_ma_count);
       ])

(* Support_floor snapshot-views entry-point: daily lookback over a
   rally-then-pullback fixture; pins that the daily_view fetch path produces
   the same support level as the bar-list path. *)
let test_support_floor_snapshot_views_parity _ =
  let dates =
    List.init 30 ~f:(fun i -> Date.add_days (Date.of_string "2024-01-02") i)
  in
  let bars =
    List.mapi dates ~f:(fun i date ->
        let price =
          if i < 20 then 100.0 +. (Float.of_int i *. 1.0)
          else 120.0 -. (Float.of_int (i - 20) *. 0.5)
        in
        {
          Types.Daily_price.date;
          open_price = price;
          high_price = price *. 1.01;
          low_price = price *. 0.99;
          close_price = price;
          adjusted_close = price;
          volume = 100_000;
          active_through = None;
        })
  in
  let cb = build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let bar_cbs =
    Weinstein_stops.Support_floor.callbacks_from_bars ~bars ~as_of
      ~lookback_bars:30
  in
  let calendar =
    Array.of_list
      (List.map bars ~f:(fun b -> b.Types.Daily_price.date)
      |> List.dedup_and_sort ~compare:Date.compare)
  in
  let snap_cbs =
    Panel_callbacks.support_floor_callbacks_of_snapshot_views ~cb ~symbol:"AAPL"
      ~as_of ~lookback:30 ~calendar
  in
  let bar_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:bar_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05 ()
  in
  let snap_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:snap_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
      ()
  in
  match (bar_result, snap_result) with
  | None, None -> ()
  | Some r1, Some r2 -> assert_that r2 (float_equal r1)
  | Some r, None ->
      assert_failure
        (Printf.sprintf "snapshot returned None; bar-list returned Some %f" r)
  | None, Some r ->
      assert_failure
        (Printf.sprintf "bar-list returned None; snapshot returned Some %f" r)

(* Edge case: macro globals filter — one valid + one missing symbol
   in the [globals] list. The snapshot constructor's [filter_map] over
   empty views must drop the missing entry and pass only the valid one
   through to {!macro_callbacks_of_weekly_views}, matching
   {!Macro_inputs.build_global_index_views}'s [view.n = 0] short-circuit. *)
let test_macro_snapshot_globals_filter_missing _ =
  let index_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:4000.0 ~step:5.0
  in
  let global_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:15000.0 ~step:2.0
  in
  let cb =
    build_snapshot_callbacks [ ("SPY", index_bars); ("GDAXI", global_bars) ]
  in
  let as_of = (List.last_exn index_bars).Types.Daily_price.date in
  let ad_bars =
    List.init 60 ~f:(fun i ->
        {
          Macro.date = Date.add_days (Date.of_string "2024-01-05") (i * 7);
          advancing = 1500 + i;
          declining = 1500 - i;
        })
  in
  let config = Macro.default_config in
  let snap_cbs =
    Panel_callbacks.macro_callbacks_of_snapshot_views ~config ~cb
      ~index_symbol:"SPY"
      ~globals:[ ("DAX", "GDAXI"); ("MISSING", "MISSING_SYMBOL") ]
      ~ad_bars ~n:60 ~as_of ()
  in
  (* Only DAX should be present in [global_index_stages]; MISSING is
     filtered out at view-fetch time. *)
  assert_that
    (List.map snap_cbs.global_index_stages ~f:fst)
    (elements_are [ equal_to "DAX" ])

(* Resistance-history feed ([?resistance_stock]): omitted, the resistance
   callbacks read the standard [stock] view (bit-identical to pre-feed
   behaviour); given a deeper view, only the resistance component sees it. *)
let test_resistance_stock_default_reads_stock_view _ =
  let stock_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2014-01-03")
      ~n:600 ~start_price:100.0 ~step:0.1
  in
  let cb = build_snapshot_callbacks [ ("AAPL", stock_bars) ] in
  let as_of = (List.last_exn stock_bars).Types.Daily_price.date in
  let stock_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:110 ~as_of
  in
  let snap_cbs =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ~config:Stock_analysis.default_config ~stock:stock_view
      ~benchmark:stock_view ()
  in
  assert_that snap_cbs.resistance.n_bars (equal_to stock_view.n)

let test_resistance_stock_deep_view_feeds_resistance_only _ =
  let stock_bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2014-01-03")
      ~n:600 ~start_price:100.0 ~step:0.1
  in
  let cb = build_snapshot_callbacks [ ("AAPL", stock_bars) ] in
  let as_of = (List.last_exn stock_bars).Types.Daily_price.date in
  let stock_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:110 ~as_of
  in
  let deep_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAPL" ~n:520 ~as_of
  in
  let snap_cbs =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views
      ~resistance_stock:deep_view ~config:Stock_analysis.default_config
      ~stock:stock_view ~benchmark:stock_view ()
  in
  assert_that snap_cbs
    (all_of
       [
         field
           (fun (c : Stock_analysis.callbacks) -> c.resistance.n_bars)
           (equal_to deep_view.n);
         (* Stage / volume components keep the standard window: a probe past
            the standard depth returns None. *)
         field
           (fun (c : Stock_analysis.callbacks) ->
             c.volume.get_volume ~week_offset:(stock_view.n + 5))
           is_none;
         field
           (fun (c : Stock_analysis.callbacks) ->
             c.resistance.get_high ~bar_offset:(stock_view.n + 5))
           (is_some_and (gt (module Float_ord) 0.0));
       ])

(* ------------------------------------------------------------------ *)
(* Sketch-v5 threading: presence of a weekly side-table selects the v5   *)
(* read path; absence keeps the dense-column path (PR 3).                *)
(* ------------------------------------------------------------------ *)

(* Mon-anchored weeks so calendar weeks align with ISO weeks. Each day of a
   week carries the same (close, high, low) so the weekly aggregate equals the
   override exactly. *)
let _v5_week_start = Date.of_string "2000-01-03"
let _v5_day ~w ~d = Date.add_days _v5_week_start ((7 * w) + d)

let _v5_bar ~date ~close ~high ~low =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000;
    active_through = None;
  }

let _v5_weeks_bars ~n_weeks ~shape =
  List.init n_weeks ~f:(fun w ->
      let close, high, low = shape w in
      List.init 5 ~f:(fun d -> _v5_bar ~date:(_v5_day ~w ~d) ~close ~high ~low))
  |> List.concat

(* Anchor 10; a couple of weeks put supply above the anchor so the derived
   sketch has populated hist bands (a meaningful, non-degenerate record). *)
let _v5_shape w =
  match w with
  | 5 -> (10.0, 11.0, 10.0)
  | 20 -> (10.0, 13.0, 12.0)
  | _ -> (10.0, 9.0, 8.0)

(* A snapshot shim that resolves ONLY [Close] (the v5 anchor + the dense path's
   histogram anchor); every other field errors. Under this cb the dense
   [read_sketch] path returns [None] (its first [Res_*] probe fails), so a
   [Some] sketch can only come from the v5 side-table path — the switch under
   test. *)
let _close_only_cb ~close : Snapshot_callbacks.t =
  {
    read_field =
      (fun ~symbol:_ ~date:_ ~field ->
        match field with
        | Snapshot_schema.Close -> Ok close
        | _ -> Error (Status.not_found_error "close-only cb: no dense column"));
    read_field_history =
      (fun ~symbol:_ ~from:_ ~until:_ ~field:_ ->
        Error (Status.not_found_error "close-only cb: no history"));
    active_through_for = (fun ~symbol:_ -> None);
  }

let _minimal_weekly_view ~date ~price : Snapshot_bar_views.weekly_view =
  {
    closes = [| price |];
    raw_closes = [| price |];
    highs = [| price |];
    lows = [| price |];
    volumes = [| 1.0 |];
    dates = [| date |];
    n = 1;
  }

(* Presence of a side-table -> v5 read path: [get_sketch ()] yields exactly the
   sketch [Weekly_sidetable_reader.sketch_of_entries] derives at the row's raw
   close. Absence -> dense path, which under the close-only cb returns None. *)
let test_weekly_sidetable_threading _ =
  let bars = _v5_weeks_bars ~n_weeks:40 ~shape:_v5_shape in
  let entries = Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars in
  let as_of = _v5_day ~w:39 ~d:4 in
  let close = 10.0 in
  let cb = _close_only_cb ~close in
  let view = _minimal_weekly_view ~date:as_of ~price:close in
  let config = Stock_analysis.default_config in
  let cbs_v5 : Stock_analysis.callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views ~snapshot_cb:cb
      ~stock_symbol:"AAA" ~weekly_sidetable:entries ~config ~stock:view
      ~benchmark:view ()
  in
  let cbs_dense : Stock_analysis.callbacks =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views ~snapshot_cb:cb
      ~stock_symbol:"AAA" ~config ~stock:view ~benchmark:view ()
  in
  assert_that
    (cbs_v5.get_sketch (), cbs_dense.get_sketch ())
    (all_of
       [
         (* v5 path active: the derived sketch, bit-for-bit. *)
         field
           (fun (v5, _) -> v5)
           (is_some_and
              (equal_to
                 (Weekly_sidetable_reader.sketch_of_entries ~entries ~as_of
                    ~close)));
         (* dense path selected when the side-table is absent -> no columns. *)
         field (fun (_, dense) -> dense) is_none;
       ])

(* ------------------------------------------------------------------ *)
(* #2133 — side-table basis threading, observed through the production  *)
(* screening path (Bar_reader -> screening -> Panel_callbacks ->        *)
(* Resistance_sketch_reader).                                           *)
(* ------------------------------------------------------------------ *)

let _thread_index_symbol = "GSPCX"
let _thread_stock_symbol = "SKETCHY"

(* One bar per calendar day; the weekly aggregator buckets them. A steadily
   rising series drives the index to a Bullish macro and the stock to Stage 2,
   so the stock survives Phase 1 and pays the full [Stock_analysis] cost — which
   is where [get_sketch] (and therefore the anchor read) fires. *)
let _thread_daily_bars ~start_date ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let price = start_price +. (Float.of_int i *. step) in
      {
        Types.Daily_price.date = Date.add_days start_date i;
        open_price = price;
        high_price = price *. 1.01;
        low_price = price *. 0.99;
        close_price = price;
        adjusted_close = price;
        volume = 1_000_000;
        active_through = None;
      })

(* Wrap [inner], recording every [read_field] issued for [watch].
   {!Weinstein_strategy.Resistance_sketch_reader} is the ONLY caller of
   [Snapshot_callbacks.read_field] in the tree (every bar / view read goes
   through [read_field_history]), so the recorded fields are exactly the sketch
   anchor column the run selected. *)
let _recording_cb ~watch ~(inner : Snapshot_callbacks.t) =
  let seen = ref [] in
  let cb : Snapshot_callbacks.t =
    {
      read_field =
        (fun ~symbol ~date ~field ->
          if String.equal symbol watch then seen := field :: !seen;
          inner.read_field ~symbol ~date ~field);
      read_field_history = inner.read_field_history;
      active_through_for = inner.active_through_for;
    }
  in
  (cb, seen)

let _drive_screen_tick ~bar_reader ~config ~current_date =
  Internal_for_test.on_market_close ~fold_start_date:None ~config ~ad_bars:[]
    ~stop_states:(ref String.Map.empty)
    ~last_stop_out_dates:(Hashtbl.create (module String))
    ~prior_macro:(ref Weinstein_types.Neutral)
    ~prior_macro_result:(ref None)
    ~prior_decline_character:(ref Decline_character.Not_declining)
    ~peak_tracker:(FL.Peak_tracker.create ())
    ~bar_reader
    ~prior_stages:(Hashtbl.create (module String))
    ~prior_stage_ma_values:(Hashtbl.create (module String))
    ~sector_prior_stages:(Hashtbl.create (module String))
    ~ticker_sectors:(Hashtbl.create (module String))
    ~stage3_streaks:(Hashtbl.create (module String))
    ~laggard_streaks:(Hashtbl.create (module String))
    ~audit_recorder:Weinstein_strategy.Audit_recorder.noop
    ~get_price:(fun symbol ->
      List.last
        (Bar_reader.daily_bars_for bar_reader ~symbol ~as_of:current_date))
    ~get_indicator:(fun _ _ _ _ -> None)
    ~portfolio:
      ({ cash = 1_000_000.0; positions = String.Map.empty }
        : Trading_strategy.Portfolio_view.t)

(* Run one production screening Friday against a side-table-backed reader
   constructed on [sidetable_basis]; return the tick result plus the distinct
   fields the sketch reader asked for. *)
let _anchor_fields_read_by_screen ~sidetable_basis =
  let current_date = Date.of_string "2024-04-26" in
  let n_days = 400 in
  let start_date = Date.add_days current_date (-(n_days - 1)) in
  let index_bars =
    _thread_daily_bars ~start_date ~n:n_days ~start_price:100.0 ~step:1.0
  in
  let stock_bars =
    _thread_daily_bars ~start_date ~n:n_days ~start_price:50.0 ~step:0.5
  in
  let backing =
    Bar_reader.of_in_memory_bars
      [ (_thread_index_symbol, index_bars); (_thread_stock_symbol, stock_bars) ]
  in
  let cb, seen =
    _recording_cb ~watch:_thread_stock_symbol
      ~inner:(Bar_reader.snapshot_callbacks backing)
  in
  let entries =
    Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars:stock_bars
  in
  let bar_reader =
    Bar_reader.of_snapshot_views
      ~weekly_sidetable_loader:(fun ~symbol:_ -> Some entries)
      ~sidetable_basis cb
  in
  let config =
    Weinstein_strategy.default_config ~universe:[ _thread_stock_symbol ]
      ~index_symbol:_thread_index_symbol
  in
  let result = _drive_screen_tick ~bar_reader ~config ~current_date in
  (result, List.dedup_and_sort !seen ~compare:Poly.compare)

(** The basis a {!Bar_reader} carries must reach
    {!Weinstein_strategy.Resistance_sketch_reader} through the real screening
    call chain, not merely be accepted by {!Panel_callbacks} in isolation. An
    [Adjusted]-basis warehouse anchors the sketch at [Adjusted_close]; the [Raw]
    default keeps the pre-migration [Close] anchor. Dropping the basis anywhere
    on that chain silently re-anchors an adjusted-basis side-table on raw
    [Close] — exactly the raw/adjusted mixing #2133 exists to eliminate — and
    the unit-level tests in [test_resistance_sketch_reader.ml] cannot see it. *)
let test_sidetable_basis_threads_through_screening _ =
  let adjusted_result, adjusted_fields =
    _anchor_fields_read_by_screen
      ~sidetable_basis:Weekly_sidetable_reader.Adjusted
  in
  let raw_result, raw_fields =
    _anchor_fields_read_by_screen ~sidetable_basis:Weekly_sidetable_reader.Raw
  in
  assert_that
    (adjusted_result, raw_result)
    (all_of [ field fst is_ok; field snd is_ok ]);
  assert_that
    (adjusted_fields, raw_fields)
    (all_of
       [
         field fst (elements_are [ equal_to Snapshot_schema.Adjusted_close ]);
         field snd (elements_are [ equal_to Snapshot_schema.Close ]);
       ])

(* ------------------------------------------------------------------ *)
(* split_safe_floors on the panel / callback path                       *)
(* ------------------------------------------------------------------ *)

(* Same 4:1 mid-window split fixture as the bar-list tests in
   [trading/weinstein/stops/test/test_support_floor.ml] — deliberately the same
   numbers so the two paths are visibly testing the same thing. Bars 1-4 are
   pre-split (raw ~4x the current price, [adjusted_close] = raw / 4 → factor
   0.25); bar 5 is post-split (factor 1.0).

   Long: on the {b adjusted} basis a clean peak 110 + correction low 98; on the
   {b raw} basis the pre-split high 440 is a phantom peak and the post-split low
   104 reads as the "correction low" of a bogus 76% drawdown — a garbage floor
   sitting right at the ~104 entry. *)
let _split_bar ~date ~high ~low ~close ~adjusted_close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close;
    volume = 1_000_000;
    active_through = None;
  }

let _split_long_bars =
  [
    _split_bar ~date:"2024-01-01" ~high:408.0 ~low:400.0 ~close:404.0
      ~adjusted_close:101.0;
    _split_bar ~date:"2024-01-02" ~high:440.0 ~low:432.0 ~close:436.0
      ~adjusted_close:109.0;
    _split_bar ~date:"2024-01-03" ~high:404.0 ~low:396.0 ~close:400.0
      ~adjusted_close:100.0;
    _split_bar ~date:"2024-01-04" ~high:412.0 ~low:392.0 ~close:408.0
      ~adjusted_close:102.0;
    _split_bar ~date:"2024-01-05" ~high:105.0 ~low:104.0 ~close:104.0
      ~adjusted_close:104.0;
  ]

(* Short mirror: on the adjusted basis a clean trough (low 90) + counter-rally
   (high 102); on the raw basis the lowest bar is the LAST one, so there is no
   counter-rally after the trough and the scan finds no ceiling at all. *)
let _split_short_bars =
  [
    _split_bar ~date:"2024-01-01" ~high:400.0 ~low:396.0 ~close:398.0
      ~adjusted_close:99.5;
    _split_bar ~date:"2024-01-02" ~high:368.0 ~low:360.0 ~close:364.0
      ~adjusted_close:91.0;
    _split_bar ~date:"2024-01-03" ~high:400.0 ~low:392.0 ~close:396.0
      ~adjusted_close:99.0;
    _split_bar ~date:"2024-01-04" ~high:408.0 ~low:388.0 ~close:392.0
      ~adjusted_close:98.0;
    _split_bar ~date:"2024-01-05" ~high:95.0 ~low:92.0 ~close:93.0
      ~adjusted_close:93.0;
  ]

let _split_as_of = Date.of_string "2024-01-05"
let _split_fallback_buffer = 1.02
let _cfg_split_off = Weinstein_stops.default_config

let _cfg_split_on =
  {
    Weinstein_stops.default_config with
    Weinstein_stops.split_safe_floors = true;
  }

(* Bars → the exact callbacks bundle the strategy hot path uses: through the
   real snapshot roundtrip (Pipeline.build_for_symbol → Snapshot_format.write →
   daily_view_for) and then [support_floor_callbacks_of_daily_view], the same
   two calls [Entry_audit_helpers.initial_stop_and_kind] makes. *)
let _panel_callbacks_of_bars bars =
  let cb = build_snapshot_callbacks [ ("SPLT", bars) ] in
  let calendar =
    Array.of_list (List.map bars ~f:(fun b -> b.Types.Daily_price.date))
  in
  let view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"SPLT" ~as_of:_split_as_of
      ~lookback:90 ~calendar
  in
  Panel_callbacks.support_floor_callbacks_of_daily_view view

let _panel_stop ~config ~side ~entry_price bars =
  Weinstein_stops.compute_initial_stop_with_floor_with_callbacks ~config ~side
    ~entry_price
    ~callbacks:(_panel_callbacks_of_bars bars)
    ~fallback_buffer:_split_fallback_buffer

(* The pre-2026-08-05 panel path, transcribed: scan the bundle exactly as
   supplied (no rescale — the flag did not reach this path at all), then place
   the stop. R1 asserts the default-off path still equals this. *)
let _pre_flag_panel_stop ~config ~side ~entry_price bars =
  let callbacks = _panel_callbacks_of_bars bars in
  let reference_level =
    match
      Weinstein_stops.Support_floor.find_recent_level_with_callbacks
        ~anchor_mode:config.Weinstein_stops.support_floor_anchor_mode ~callbacks
        ~side ~min_pullback_pct:config.Weinstein_stops.min_correction_pct ()
    with
    | Some level -> level
    | None -> (
        match side with
        | Trading_base.Types.Long -> entry_price *. _split_fallback_buffer
        | Trading_base.Types.Short -> entry_price /. _split_fallback_buffer)
  in
  Weinstein_stops.compute_initial_stop ~config ~side ~reference_level

let _initial_reference matcher =
  matching ~msg:"Expected Initial state"
    (function
      | Weinstein_stops.Initial { reference_level; _ } -> Some reference_level
      | _ -> None)
    matcher

(* R1 — default-off is bit-identical over a split-straddling window. Compared
   against a literal transcription of the pre-change code path (structural
   [equal_to] over the whole [stop_state], so exact float equality on both
   [stop_level] and [reference_level]), and pinned to the phantom 104.0 the raw
   basis yields — the same value the bar-list default-off test asserts. *)
let test_panel_split_safe_off_matches_pre_flag_path _ =
  assert_that
    (_panel_stop ~config:_cfg_split_off ~side:Trading_base.Types.Long
       ~entry_price:104.0 _split_long_bars)
    (all_of
       [
         equal_to
           (_pre_flag_panel_stop ~config:_cfg_split_off
              ~side:Trading_base.Types.Long ~entry_price:104.0 _split_long_bars
             : Weinstein_stops.stop_state);
         _initial_reference (float_equal 104.0);
       ])

(* R2 — flag-on now actually controls the panel path: the floor moves off the
   raw phantom (104.0, right at the entry) onto the adjusted-basis correction
   low (98.0), and agrees exactly with the bar-list path on the same bars. *)
let test_panel_split_safe_on_uses_adjusted_floor _ =
  assert_that
    (_panel_stop ~config:_cfg_split_on ~side:Trading_base.Types.Long
       ~entry_price:104.0 _split_long_bars)
    (all_of
       [
         equal_to
           (Weinstein_stops.compute_initial_stop_with_floor
              ~config:_cfg_split_on ~side:Trading_base.Types.Long
              ~entry_price:104.0 ~bars:_split_long_bars ~as_of:_split_as_of
              ~fallback_buffer:_split_fallback_buffer
             : Weinstein_stops.stop_state);
         _initial_reference (float_equal 98.0);
       ])

(* Short mirror, through [floor_is_structural_with_callbacks] — the single
   source [Entry_audit_helpers] now tags [stop_floor_kind] with. Raw basis: the
   trough is the last bar, so no counter-rally → non-structural. Adjusted basis:
   a real trough + counter-rally → structural. *)
let test_panel_split_safe_short_structural_flag _ =
  let callbacks = _panel_callbacks_of_bars _split_short_bars in
  let is_structural config =
    Weinstein_stops.floor_is_structural_with_callbacks ~config
      ~side:Trading_base.Types.Short ~callbacks
  in
  assert_that
    (is_structural _cfg_split_off, is_structural _cfg_split_on)
    (all_of [ field fst (equal_to false); field snd (equal_to true) ])

(* B1 panel sibling. The close-replacement half of the rescale is only
   observable under [Close] anchor, and [(Close x split_safe_floors=true)] is an
   expressible [Variant_matrix] cell. Same 100.0 the bar-list test pins: on the
   adjusted basis the closes peak at 109 and bottom at 100 post-peak. Leave
   [get_close] on [raw_closes] and this returns the phantom 104.0 — adjusted
   highs/lows scanned against raw closes.

   Pinning this only on the bar-list path would repeat the shape of the defect
   this PR exists to fix, so it is asserted here too. *)
let test_panel_split_safe_close_anchor_uses_adjusted_closes _ =
  assert_that
    (_panel_stop
       ~config:
         {
           _cfg_split_on with
           Weinstein_stops.support_floor_anchor_mode =
             Weinstein_stops.Support_floor.Close;
         }
       ~side:Trading_base.Types.Long ~entry_price:104.0 _split_long_bars)
    (_initial_reference (float_equal 100.0))

(* B2 panel sibling — the "legacy warehouse" case, built as a [daily_view]
   literal because that is exactly what the producer yields for a snapshot whose
   schema predates [Adjusted_close]: the field read fails,
   [Snapshot_bar_views._read_history_or_empty] maps it to [], and every
   adjusted cell reads NaN. Constructing the view directly reaches the state
   without needing a second on-disk schema.

   The flag must be inert here, not merely safe: with the whole window
   un-rescalable the scan runs raw, so flag-on is structurally identical to
   flag-off. Inertness that equals baseline is diagnosable in a walk-forward
   surface ("on == off in every row"); the alternative — collapsing every scan
   to the buffer fallback — would read as a genuine negative result. *)
let _split_long_daily_view () =
  let cb = build_snapshot_callbacks [ ("SPLT", _split_long_bars) ] in
  let calendar =
    Array.of_list
      (List.map _split_long_bars ~f:(fun b -> b.Types.Daily_price.date))
  in
  Snapshot_bar_views.daily_view_for cb ~symbol:"SPLT" ~as_of:_split_as_of
    ~lookback:90 ~calendar

(* [_split_long_daily_view] with [adjusted_closes] blanked at every index where
   [blank i] holds — how the missing-adjusted-cell fixtures below are built. *)
let _split_long_view_blanked ~blank =
  let view = _split_long_daily_view () in
  {
    view with
    Snapshot_bar_views.adjusted_closes =
      Array.mapi view.Snapshot_bar_views.adjusted_closes ~f:(fun i v ->
          if blank i then Float.nan else v);
  }

let test_panel_split_safe_legacy_warehouse_all_nan_adjusted_is_inert _ =
  let legacy_view = _split_long_view_blanked ~blank:(fun _ -> true) in
  let callbacks =
    Panel_callbacks.support_floor_callbacks_of_daily_view legacy_view
  in
  let stop config =
    Weinstein_stops.compute_initial_stop_with_floor_with_callbacks ~config
      ~side:Trading_base.Types.Long ~entry_price:104.0 ~callbacks
      ~fallback_buffer:_split_fallback_buffer
  in
  assert_that (stop _cfg_split_on)
    (equal_to (stop _cfg_split_off : Weinstein_stops.stop_state))

(* B3 panel sibling. [daily_view] is oldest-first and the callbacks flip the
   index, so blanking [adjusted_closes.(0)] (2024-01-01) puts the unusable cell
   at day_offset 4 — the far end of the window. Every other panel NaN fixture
   blanks the whole column, which an offset-0-only window check would still
   catch; this is the only panel fixture that pins the {b universal} quantifier
   in [_window_is_adjustable].

   It also closes the coverage asymmetry noted in the previous rework round,
   where the per-bar-vs-whole-window mutation reddened only the bar-list suite.
   Leaving the panel side without a non-zero-offset fixture would repeat the
   exact shape of the defect this PR exists to fix: a contract covered on the
   bar-list path and silently unexercised on the panel path. *)
let test_panel_split_safe_nan_adjusted_at_far_offset_degrades_whole_window _ =
  let blanked_view = _split_long_view_blanked ~blank:(fun i -> i = 0) in
  let callbacks =
    Panel_callbacks.support_floor_callbacks_of_daily_view blanked_view
  in
  let stop config =
    Weinstein_stops.compute_initial_stop_with_floor_with_callbacks ~config
      ~side:Trading_base.Types.Long ~entry_price:104.0 ~callbacks
      ~fallback_buffer:_split_fallback_buffer
  in
  assert_that (stop _cfg_split_on)
    (all_of
       [
         equal_to (stop _cfg_split_off : Weinstein_stops.stop_state);
         _initial_reference (float_equal 104.0);
       ])

(* ---- F5: whole-window fallback telemetry on the panel path ---- *)

let _panel_basis ~config view =
  Weinstein_stops.split_safe_basis_of_callbacks ~config
    ~callbacks:(Panel_callbacks.support_floor_callbacks_of_daily_view view)

(* The two tests above pin that flag-on and flag-off produce the {b same} stop
   state when the window is unrescalable — which is exactly why the level cannot
   tell a caller whether the mechanism ran. This pins that the basis tag can:
   on the identical view, flag-off reports [Flag_off] and flag-on reports
   [Raw_fallback]. Conflating those two would leave a walk-forward arm unable to
   say what fraction of it was inert. *)
let test_panel_split_safe_basis_separates_fallback_from_flag_off _ =
  let view = _split_long_view_blanked ~blank:(fun _ -> true) in
  assert_that
    ( _panel_basis ~config:_cfg_split_off view,
      _panel_basis ~config:_cfg_split_on view )
    (all_of
       [
         field fst
           (equal_to
              (Weinstein_stops.Flag_off : Weinstein_stops.split_safe_basis));
         field snd
           (equal_to
              (Weinstein_stops.Raw_fallback : Weinstein_stops.split_safe_basis));
       ])

(* The positive state: the same window the R2 test measures at 98.0 reports
   [Adjusted], so the tag is not stuck at [Raw_fallback]. *)
let test_panel_split_safe_basis_adjusted_when_window_rescalable _ =
  assert_that
    (_panel_basis ~config:_cfg_split_on (_split_long_daily_view ()))
    (equal_to (Weinstein_stops.Adjusted : Weinstein_stops.split_safe_basis))

(* The telemetry inherits the universal quantifier: one unusable cell at
   day_offset 4 still reports the fallback. Panel sibling of the bar-list B3
   fixture. *)
let test_panel_split_safe_basis_far_offset_reports_fallback _ =
  assert_that
    (_panel_basis ~config:_cfg_split_on
       (_split_long_view_blanked ~blank:(fun i -> i = 0)))
    (equal_to (Weinstein_stops.Raw_fallback : Weinstein_stops.split_safe_basis))

(* B5. The fourth basis state, on the panel path. When [Empty_window] was
   introduced (#2220 rework, B3) it was pinned only on the bar-list path, while
   the panel path acquired siblings for the other three. "Covered on one path
   and silently unexercised on the other" is this track's documented recurring
   defect class — it was #2213's B3 and the shape #2220's B1 landed in.

   The empty view is reached the way production reaches it rather than by
   writing the [empty_daily_view] sentinel literal: [daily_view_for] is asked
   for a symbol the snapshot holds no rows for, on a calendar that {b does}
   contain [_split_as_of]. So the emptiness comes from [_read_daily_tables]
   finding no raw-close rows — the newly-listed / snapshot-missing-symbol route,
   one of the three live routes to [empty_daily_view] — and not from an
   unresolvable [as_of] or a [lookback <= 0]. That view carries [n_days = 0]
   into the callbacks, which is [_scan_basis]'s empty branch.

   Both configs are asserted on the one view because the pair is the claim.
   Flag-off must still short-circuit to [Flag_off]: no basis decision is taken
   when the mechanism is off, whatever the window looks like. Flag-on must
   report [Empty_window] and not [Raw_fallback]: folding the non-event into the
   fallback would inflate the inert-fraction numerator with symbols the
   mechanism was never given a chance to act on — a correctness bug in the very
   number this telemetry exists to produce. *)
let _absent_symbol_daily_view () =
  let cb = build_snapshot_callbacks [ ("SPLT", _split_long_bars) ] in
  let calendar =
    Array.of_list
      (List.map _split_long_bars ~f:(fun b -> b.Types.Daily_price.date))
  in
  Snapshot_bar_views.daily_view_for cb ~symbol:"ABSENT" ~as_of:_split_as_of
    ~lookback:90 ~calendar

let test_panel_split_safe_basis_empty_window_is_not_fallback _ =
  let view = _absent_symbol_daily_view () in
  assert_that
    ( _panel_basis ~config:_cfg_split_off view,
      _panel_basis ~config:_cfg_split_on view )
    (all_of
       [
         field fst
           (equal_to
              (Weinstein_stops.Flag_off : Weinstein_stops.split_safe_basis));
         field snd
           (equal_to
              (Weinstein_stops.Empty_window : Weinstein_stops.split_safe_basis));
       ])

let suite =
  "Panel_callbacks parity"
  >::: [
         "Stage parity" >:: test_stage_callbacks_parity;
         "Rs parity" >:: test_rs_callbacks_parity;
         "Stock_analysis parity" >:: test_stock_analysis_callbacks_parity;
         "Sector parity" >:: test_sector_callbacks_parity;
         "Macro parity" >:: test_macro_callbacks_parity;
         "Weinstein_stops.Support_floor parity"
         >:: test_support_floor_callbacks_parity;
         "Volume parity" >:: test_volume_callbacks_parity;
         "Resistance parity" >:: test_resistance_callbacks_parity;
         "Snapshot-views Stage parity" >:: test_stage_snapshot_views_parity;
         "Snapshot-views Support_floor parity"
         >:: test_support_floor_snapshot_views_parity;
         "Snapshot Macro globals filter missing"
         >:: test_macro_snapshot_globals_filter_missing;
         "Resistance-stock default reads stock view"
         >:: test_resistance_stock_default_reads_stock_view;
         "Resistance-stock deep view feeds resistance only"
         >:: test_resistance_stock_deep_view_feeds_resistance_only;
         "Sketch-v5 side-table threading selects v5 vs dense"
         >:: test_weekly_sidetable_threading;
         "Side-table basis threads through the screening path"
         >:: test_sidetable_basis_threads_through_screening;
         "split_safe_floors off — panel path matches the pre-flag path"
         >:: test_panel_split_safe_off_matches_pre_flag_path;
         "split_safe_floors on — panel path uses the adjusted-basis floor"
         >:: test_panel_split_safe_on_uses_adjusted_floor;
         "split_safe_floors on — panel structural flag (short mirror)"
         >:: test_panel_split_safe_short_structural_flag;
         "split_safe_floors on + Close anchor — panel uses adjusted closes"
         >:: test_panel_split_safe_close_anchor_uses_adjusted_closes;
         "legacy warehouse (all-NaN adjusted) — panel flag is inert"
         >:: test_panel_split_safe_legacy_warehouse_all_nan_adjusted_is_inert;
         "unusable adjusted cell at a far offset — panel degrades whole window"
         >:: test_panel_split_safe_nan_adjusted_at_far_offset_degrades_whole_window;
         "split_safe basis separates the fallback from flag-off (panel)"
         >:: test_panel_split_safe_basis_separates_fallback_from_flag_off;
         "split_safe basis is Adjusted when the panel window is rescalable"
         >:: test_panel_split_safe_basis_adjusted_when_window_rescalable;
         "split_safe basis reports the fallback for a far-offset bad cell"
         >:: test_panel_split_safe_basis_far_offset_reports_fallback;
         "split_safe basis is Empty_window, not a fallback, for an empty panel \
          window" >:: test_panel_split_safe_basis_empty_window_is_not_fallback;
       ]

let () = run_test_tt_main suite
