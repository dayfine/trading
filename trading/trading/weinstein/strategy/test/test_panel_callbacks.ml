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
      ~callbacks:bar_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
  in
  let snap_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:snap_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
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
      ~callbacks:bar_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
  in
  let snap_result =
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks
      ~callbacks:snap_cbs ~side:Trading_base.Types.Long ~min_pullback_pct:0.05
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
       ]

let () = run_test_tt_main suite
