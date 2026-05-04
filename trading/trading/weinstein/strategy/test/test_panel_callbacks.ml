(** Parity tests for {!Weinstein_strategy.Panel_callbacks}.

    For each callee (Stage / Rs / Stock_analysis / Sector / Macro /
    Weinstein_stops.Support_floor), build callbacks two ways on the same input
    data:

    - {b bar-list path}: existing [callbacks_from_bars] over a
      [Daily_price.t list].
    - {b panel-shaped path}: {!Panel_callbacks.X_callbacks_of_*} over a
      {!Bar_panels.weekly_view} / {!Bar_panels.daily_view} produced by writing
      the same bars into an [Ohlcv_panels] + calendar.

    Run the corresponding [analyze_with_callbacks] on each and assert the
    results are bit-identical (structural [equal_to] over the float fields). Any
    drift indicates a divergence in the panel-shaped constructor. *)

open OUnit2
open Core
open Matchers
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Panel_callbacks = Weinstein_strategy.Panel_callbacks

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
  }

(** Build [n] consecutive Friday weekly bars starting at [start_friday]. The
    dates are spaced 7 days apart (Friday-anchored). The price walks with [step]
    per bar. *)
let make_friday_bars ~start_friday ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_friday (i * 7) in
      make_weekly_bar ~date ~price:(start_price +. (Float.of_int i *. step)))

(** Pack [(symbol, bars)] pairs into a {!Bar_panels.t}. The calendar is the
    union of all dates (sorted, deduped). *)
let panels_of_symbols
    (symbols_with_bars : (string * Types.Daily_price.t list) list) =
  let universe = List.map symbols_with_bars ~f:fst in
  let symbol_index =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> failwith ("Symbol_index.create: " ^ err.Status.message)
  in
  let calendar =
    symbols_with_bars
    |> List.concat_map ~f:(fun (_, bars) ->
        List.map bars ~f:(fun b -> b.Types.Daily_price.date))
    |> List.dedup_and_sort ~compare:Date.compare
    |> Array.of_list
  in
  let ohlcv =
    Ohlcv_panels.create symbol_index ~n_days:(Array.length calendar)
  in
  let date_to_col = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add date_to_col ~key:d ~data:i
      |> (ignore : [ `Ok | `Duplicate ] -> unit));
  List.iter symbols_with_bars ~f:(fun (symbol, bars) ->
      match Symbol_index.to_row symbol_index symbol with
      | None -> ()
      | Some row ->
          List.iter bars ~f:(fun bar ->
              match Hashtbl.find date_to_col bar.Types.Daily_price.date with
              | None -> ()
              | Some day ->
                  Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day bar));
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwith ("Bar_panels.create: " ^ err.Status.message)

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
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let view =
    Bar_panels.weekly_view_for panels ~symbol:"AAPL" ~n:60
      ~as_of_day:(Bar_panels.n_days panels - 1)
  in
  let config = Stage.default_config in
  let bar_list_callbacks = Stage.callbacks_from_bars ~config ~bars in
  let panel_callbacks =
    Panel_callbacks.stage_callbacks_of_weekly_view ~config ~weekly:view ()
  in
  let bar_list_result =
    Stage.classify_with_callbacks ~config ~get_ma:bar_list_callbacks.get_ma
      ~get_close:bar_list_callbacks.get_close ~prior_stage:None
  in
  let panel_result =
    Stage.classify_with_callbacks ~config ~get_ma:panel_callbacks.get_ma
      ~get_close:panel_callbacks.get_close ~prior_stage:None
  in
  assert_that panel_result
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
  let panels =
    panels_of_symbols [ ("STOCK", stock_bars); ("BENCH", bench_bars) ]
  in
  let stock_view =
    Bar_panels.weekly_view_for panels ~symbol:"STOCK" ~n:60
      ~as_of_day:(Bar_panels.n_days panels - 1)
  in
  let bench_view =
    Bar_panels.weekly_view_for panels ~symbol:"BENCH" ~n:60
      ~as_of_day:(Bar_panels.n_days panels - 1)
  in
  let bar_list_callbacks =
    Rs.callbacks_from_bars ~stock_bars ~benchmark_bars:bench_bars
  in
  let panel_cb =
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
  let panel_result =
    Rs.analyze_with_callbacks ~config ~get_stock_close:panel_cb.get_stock_close
      ~get_benchmark_close:panel_cb.get_benchmark_close
      ~get_date:panel_cb.get_date
  in
  match (bar_list_result, panel_result) with
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
  let panels =
    panels_of_symbols [ ("AAPL", stock_bars); ("SPY", bench_bars) ]
  in
  let n = Bar_panels.n_days panels in
  let stock_view =
    Bar_panels.weekly_view_for panels ~symbol:"AAPL" ~n:60 ~as_of_day:(n - 1)
  in
  let bench_view =
    Bar_panels.weekly_view_for panels ~symbol:"SPY" ~n:60 ~as_of_day:(n - 1)
  in
  let config = Stock_analysis.default_config in
  let bar_cbs =
    Stock_analysis.callbacks_from_bars ~config ~bars:stock_bars
      ~benchmark_bars:bench_bars
  in
  let panel_cbs =
    Panel_callbacks.stock_analysis_callbacks_of_weekly_views ~config
      ~stock:stock_view ~benchmark:bench_view ()
  in
  let bar_list_result =
    Stock_analysis.analyze_with_callbacks ~config ~ticker:"AAPL"
      ~callbacks:bar_cbs ~prior_stage:None
      ~as_of_date:(Date.of_string "2025-02-21")
  in
  let panel_result =
    Stock_analysis.analyze_with_callbacks ~config ~ticker:"AAPL"
      ~callbacks:panel_cbs ~prior_stage:None
      ~as_of_date:(Date.of_string "2025-02-21")
  in
  assert_that panel_result
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
  let panels =
    panels_of_symbols [ ("XLK", sector_bars); ("SPY", bench_bars) ]
  in
  let n = Bar_panels.n_days panels in
  let sector_view =
    Bar_panels.weekly_view_for panels ~symbol:"XLK" ~n:60 ~as_of_day:(n - 1)
  in
  let bench_view =
    Bar_panels.weekly_view_for panels ~symbol:"SPY" ~n:60 ~as_of_day:(n - 1)
  in
  let config = Sector.default_config in
  let bar_cbs =
    Sector.callbacks_from_bars ~config ~sector_bars ~benchmark_bars:bench_bars
  in
  let panel_cbs =
    Panel_callbacks.sector_callbacks_of_weekly_views ~config ~sector:sector_view
      ~benchmark:bench_view ()
  in
  let bar_list_result =
    Sector.analyze_with_callbacks ~config ~sector_name:"Information Technology"
      ~callbacks:bar_cbs ~constituent_analyses:[] ~prior_stage:None
  in
  let panel_result =
    Sector.analyze_with_callbacks ~config ~sector_name:"Information Technology"
      ~callbacks:panel_cbs ~constituent_analyses:[] ~prior_stage:None
  in
  assert_that panel_result
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
  let panels =
    panels_of_symbols [ ("SPY", index_bars); ("GDAXI", global_bars) ]
  in
  let n = Bar_panels.n_days panels in
  let index_view =
    Bar_panels.weekly_view_for panels ~symbol:"SPY" ~n:60 ~as_of_day:(n - 1)
  in
  let global_view =
    Bar_panels.weekly_view_for panels ~symbol:"GDAXI" ~n:60 ~as_of_day:(n - 1)
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
  let panel_cbs =
    Panel_callbacks.macro_callbacks_of_weekly_views ~config ~index:index_view
      ~globals:[ ("DAX", global_view) ]
      ~ad_bars ()
  in
  let bar_list_result =
    Macro.analyze_with_callbacks ~config ~callbacks:bar_cbs ~prior_stage:None
      ~prior:None
  in
  let panel_result =
    Macro.analyze_with_callbacks ~config ~callbacks:panel_cbs ~prior_stage:None
      ~prior:None
  in
  assert_that panel_result
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
        })
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let as_of_day = Bar_panels.n_days panels - 1 in
  let view =
    Bar_panels.daily_view_for panels ~symbol:"AAPL" ~as_of_day ~lookback:30
  in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let bar_cbs =
    Weinstein_stops.Support_floor.callbacks_from_bars ~bars ~as_of
      ~lookback_bars:30
  in
  let panel_cbs = Panel_callbacks.support_floor_callbacks_of_daily_view view in
  let bar_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:bar_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
  in
  let panel_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:panel_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
  in
  match (bar_result, panel_result) with
  | None, None -> ()
  | Some r1, Some r2 -> assert_that r2 (float_equal r1)
  | Some r, None ->
      assert_failure
        (Printf.sprintf "panel returned None; bar-list returned Some %f" r)
  | None, Some r ->
      assert_failure
        (Printf.sprintf "bar-list returned None; panel returned Some %f" r)

(* Volume parity: weekly bars run through Volume.analyze_breakout via both the
   bar-list and panel callback paths. *)
let test_volume_callbacks_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:8 ~start_price:100.0 ~step:1.0
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let n = Bar_panels.n_days panels in
  let view =
    Bar_panels.weekly_view_for panels ~symbol:"AAPL" ~n:8 ~as_of_day:(n - 1)
  in
  let bar_cbs = Volume.callbacks_from_bars ~bars in
  let panel_cbs =
    Panel_callbacks.volume_callbacks_of_weekly_view ~weekly:view
  in
  let config = Volume.default_config in
  (* Read at event_offset:0 (newest bar). Both paths must agree. *)
  let bar_result =
    Volume.analyze_breakout_with_callbacks ~config ~callbacks:bar_cbs
      ~event_offset:0
  in
  let panel_result =
    Volume.analyze_breakout_with_callbacks ~config ~callbacks:panel_cbs
      ~event_offset:0
  in
  match (bar_result, panel_result) with
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
   the bar-list and panel callback paths. *)
let test_resistance_callbacks_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:30 ~start_price:50.0 ~step:1.0
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let n = Bar_panels.n_days panels in
  let view =
    Bar_panels.weekly_view_for panels ~symbol:"AAPL" ~n:30 ~as_of_day:(n - 1)
  in
  let bar_cbs = Resistance.callbacks_from_bars ~bars in
  let panel_cbs =
    Panel_callbacks.resistance_callbacks_of_weekly_view ~weekly:view
  in
  let config = Resistance.default_config in
  let breakout_price = 65.0 in
  let as_of_date = Date.of_string "2025-02-21" in
  let bar_result =
    Resistance.analyze_with_callbacks ~config ~callbacks:bar_cbs ~breakout_price
      ~as_of_date
  in
  let panel_result =
    Resistance.analyze_with_callbacks ~config ~callbacks:panel_cbs
      ~breakout_price ~as_of_date
  in
  assert_that panel_result
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

(* Stage parity with PR-D cache: classify on a 60-week rising series,
   build callbacks two ways — one with [?ma_cache] passed (cache hit on
   the latest Friday date), one without — and require bit-identical
   Stage.result. The default ma_type is WMA; the cache returns the
   same MA values as inline because WMA is sliding-window. *)
let test_stage_callbacks_parity_with_cache _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let view =
    Bar_panels.weekly_view_for panels ~symbol:"AAPL" ~n:60
      ~as_of_day:(Bar_panels.n_days panels - 1)
  in
  let config = Stage.default_config in
  let cache = Weinstein_strategy.Weekly_ma_cache.create panels in
  let inline_callbacks =
    Panel_callbacks.stage_callbacks_of_weekly_view ~config ~weekly:view ()
  in
  let cached_callbacks =
    Panel_callbacks.stage_callbacks_of_weekly_view ~ma_cache:cache
      ~symbol:"AAPL" ~config ~weekly:view ()
  in
  let inline_result =
    Stage.classify_with_callbacks ~config ~get_ma:inline_callbacks.get_ma
      ~get_close:inline_callbacks.get_close ~prior_stage:None
  in
  let cached_result =
    Stage.classify_with_callbacks ~config ~get_ma:cached_callbacks.get_ma
      ~get_close:cached_callbacks.get_close ~prior_stage:None
  in
  assert_that cached_result
    (all_of
       [
         field
           (fun (r : Stage.result) -> r.ma_value)
           (float_equal inline_result.ma_value);
         field
           (fun (r : Stage.result) -> r.ma_slope_pct)
           (float_equal inline_result.ma_slope_pct);
         field
           (fun (r : Stage.result) -> r.above_ma_count)
           (equal_to inline_result.above_ma_count);
       ])

(* ------------------------------------------------------------------ *)
(* Snapshot-views parity (Phase F.3.c)                                  *)
(* ------------------------------------------------------------------ *)
(* Pin that {!Panel_callbacks.X_of_snapshot_views} produces bit-equal
   callee-analysis output to {!Panel_callbacks.X_of_*_view} on the same
   underlying bar history. The legacy [_of_*_view] constructors take a
   pre-built {!Bar_panels.weekly_view} / [daily_view]; the new
   [_of_snapshot_views] constructors take a {!Snapshot_callbacks.t}
   plus the symbol / window the view should cover and fetch via
   {!Snapshot_runtime.Snapshot_bar_views.weekly_view_for} /
   [daily_view_for]. The view types are type-equal (declared via [type =]
   in [snapshot_bar_views.mli]), so the delegation requires no per-call
   adapter and the output is bit-identical. *)

module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

(* Mirror of {!Test_weekly_ma_cache._build_snapshot_callbacks}: build a
   {!Snapshot_callbacks.t} from in-memory [(symbol, bars)] pairs by
   materialising a tmp snapshot directory under
   {!Snapshot_schema.default}. Same setup as {!Bar_reader.of_in_memory_bars}
   but exposes the {!Snapshot_callbacks.t} directly so the parity tests
   can also drive {!Bar_panels.weekly_view_for} from the same input. *)
let _build_snapshot_callbacks
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

(* Stage parity (snapshot vs panel): same 60-bar fixture as the bar-list
   parity test, run through {!Stage.classify_with_callbacks} via both
   constructors. *)
let test_stage_snapshot_parity _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let panel_view =
    Bar_panels.weekly_view_for panels ~symbol:"AAPL" ~n:60
      ~as_of_day:(Bar_panels.n_days panels - 1)
  in
  let cb = _build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let config = Stage.default_config in
  let panel_cbs =
    Panel_callbacks.stage_callbacks_of_weekly_view ~config ~weekly:panel_view ()
  in
  let snap_cbs =
    Panel_callbacks.stage_callbacks_of_snapshot_views ~config ~cb ~symbol:"AAPL"
      ~n:60 ~as_of ()
  in
  let panel_result =
    Stage.classify_with_callbacks ~config ~get_ma:panel_cbs.get_ma
      ~get_close:panel_cbs.get_close ~prior_stage:None
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
           (float_equal panel_result.ma_value);
         field
           (fun (r : Stage.result) -> r.ma_slope_pct)
           (float_equal panel_result.ma_slope_pct);
         field
           (fun (r : Stage.result) -> r.above_ma_count)
           (equal_to panel_result.above_ma_count);
       ])

(* Support_floor parity (snapshot vs panel): daily lookback over a
   rally-then-pullback fixture; the daily_view fetch is the load-bearing
   path for the daily_view-based snapshot constructor (the only daily
   constructor; every other [_of_snapshot_views] uses [weekly_view_for]
   which is exercised by {!test_stage_snapshot_parity}). *)
let test_support_floor_snapshot_parity _ =
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
        })
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let as_of_day = Bar_panels.n_days panels - 1 in
  let panel_view =
    Bar_panels.daily_view_for panels ~symbol:"AAPL" ~as_of_day ~lookback:30
  in
  let cb = _build_snapshot_callbacks [ ("AAPL", bars) ] in
  let as_of = (List.last_exn bars).Types.Daily_price.date in
  let panel_cbs =
    Panel_callbacks.support_floor_callbacks_of_daily_view panel_view
  in
  let snap_cbs =
    Panel_callbacks.support_floor_callbacks_of_snapshot_views ~cb ~symbol:"AAPL"
      ~as_of ~lookback:30
  in
  let panel_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:panel_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
  in
  let snap_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:snap_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
  in
  match (panel_result, snap_result) with
  | None, None -> ()
  | Some r1, Some r2 -> assert_that r2 (float_equal r1)
  | Some r, None ->
      assert_failure
        (Printf.sprintf "snapshot returned None; panel returned Some %f" r)
  | None, Some r ->
      assert_failure
        (Printf.sprintf "panel returned None; snapshot returned Some %f" r)

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
    _build_snapshot_callbacks [ ("SPY", index_bars); ("GDAXI", global_bars) ]
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

let suite =
  "Panel_callbacks parity"
  >::: [
         "Stage parity" >:: test_stage_callbacks_parity;
         "Stage parity (cache vs inline)"
         >:: test_stage_callbacks_parity_with_cache;
         "Rs parity" >:: test_rs_callbacks_parity;
         "Stock_analysis parity" >:: test_stock_analysis_callbacks_parity;
         "Sector parity" >:: test_sector_callbacks_parity;
         "Macro parity" >:: test_macro_callbacks_parity;
         "Weinstein_stops.Support_floor parity"
         >:: test_support_floor_callbacks_parity;
         "Volume parity" >:: test_volume_callbacks_parity;
         "Resistance parity" >:: test_resistance_callbacks_parity;
         "Snapshot Stage parity" >:: test_stage_snapshot_parity;
         "Snapshot Support_floor parity" >:: test_support_floor_snapshot_parity;
         "Snapshot Macro globals filter missing"
         >:: test_macro_snapshot_globals_filter_missing;
       ]

let () = run_test_tt_main suite
