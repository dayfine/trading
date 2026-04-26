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
       ]

let () = run_test_tt_main suite
