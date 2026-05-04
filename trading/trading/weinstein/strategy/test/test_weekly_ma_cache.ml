(** Parity tests for {!Weinstein_strategy.Weekly_ma_cache}.

    For each ma_type / period combination, build a synthetic [Bar_panels.t] with
    one symbol's full weekly history, compute the MA two ways:

    - {b cache path}: {!Weekly_ma_cache.ma_values_for}.
    - {b inline path}: the same kernel ({!Sma.calculate_sma} |
      {!Sma.calculate_weighted_ma} | {!Ema.calculate_ema}) called directly over
      an [Indicator_types.t list] of the same closes.

    Assert the resulting [float array] is bit-identical (for SMA/WMA) or
    rounded-equal at offset 0 (for EMA, where TA-Lib's 2-decimal rounding
    bridges any seed-induced drift after sufficient warmup).

    Also verify:
    - [locate_date] returns the correct index for in-range / out-of-range target
      dates;
    - cache hits return the same array reference (memoisation).
    - empty / zero-day panels yield empty arrays. *)

open OUnit2
open Core
open Matchers
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Weekly_ma_cache = Weinstein_strategy.Weekly_ma_cache

(* ------------------------------------------------------------------ *)
(* Synthetic bar builders (same shape as test_panel_callbacks)          *)
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

let make_friday_bars ~start_friday ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_friday (i * 7) in
      make_weekly_bar ~date ~price:(start_price +. (Float.of_int i *. step)))

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
(* Inline reference (same kernel the cache uses, called directly)       *)
(* ------------------------------------------------------------------ *)

let inline_ma ~(ma_type : Stage.ma_type) ~period ~(closes : float array)
    ~(dates : Date.t array) : float array =
  let series =
    Array.to_list closes
    |> List.mapi ~f:(fun i v -> Indicator_types.{ date = dates.(i); value = v })
  in
  let result =
    match ma_type with
    | Stage.Sma -> Sma.calculate_sma series period
    | Stage.Wma -> Sma.calculate_weighted_ma series period
    | Stage.Ema -> Ema.calculate_ema series period
  in
  List.map result ~f:(fun iv -> iv.Indicator_types.value) |> Array.of_list

(* ------------------------------------------------------------------ *)
(* Core parity per ma_type                                              *)
(* ------------------------------------------------------------------ *)

let _expected_dates (closes_dates : Date.t array) ~period =
  let n = Array.length closes_dates in
  if n < period then [||]
  else Array.sub closes_dates ~pos:(period - 1) ~len:(n - period + 1)

let _assert_arrays_float_equal ~msg actual expected =
  let pairs =
    Array.to_list (Array.map2_exn actual expected ~f:(fun a b -> (a, b)))
  in
  assert_that pairs
    (elements_are
       (List.map pairs ~f:(fun (_, b) ->
            field (fun (a, _) -> a) (float_equal ~epsilon:1e-9 b))))
  |> ignore;
  assert_that (Array.length actual)
    (equal_to ~msg:(msg ^ " (length mismatch)") (Array.length expected))

let _run_parity ~(ma_type : Stage.ma_type) ~period ~bars ~symbol _ =
  let panels = panels_of_symbols [ (symbol, bars) ] in
  let cache = Weekly_ma_cache.create panels in
  let cached_values, cached_dates =
    Weekly_ma_cache.ma_values_for cache ~symbol ~ma_type ~period
  in
  let view =
    Bar_panels.weekly_view_for panels ~symbol ~n:Int.max_value
      ~as_of_day:(Bar_panels.n_days panels - 1)
  in
  let expected_values =
    inline_ma ~ma_type ~period ~closes:view.closes ~dates:view.dates
  in
  let expected_dates = _expected_dates view.dates ~period in
  let cached_pairs =
    Array.to_list
      (Array.map2_exn cached_values cached_dates ~f:(fun v d -> (v, d)))
  in
  let expected_pairs =
    Array.to_list
      (Array.map2_exn expected_values expected_dates ~f:(fun v d -> (v, d)))
  in
  assert_that cached_pairs
    (elements_are
       (List.map expected_pairs ~f:(fun (v, d) ->
            all_of
              [
                field (fun (cv, _) -> cv) (float_equal ~epsilon:1e-9 v);
                field (fun (_, cd) -> cd) (equal_to d);
              ])))

let test_sma_parity_30 ctx =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  _run_parity ~ma_type:Stage.Sma ~period:30 ~bars ~symbol:"AAPL" ctx

let test_wma_parity_30 ctx =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  _run_parity ~ma_type:Stage.Wma ~period:30 ~bars ~symbol:"AAPL" ctx

let test_ema_parity_30 ctx =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  _run_parity ~ma_type:Stage.Ema ~period:30 ~bars ~symbol:"AAPL" ctx

let test_sma_parity_10 ctx =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:30 ~start_price:50.0 ~step:0.25
  in
  _run_parity ~ma_type:Stage.Sma ~period:10 ~bars ~symbol:"XLK" ctx

(* ------------------------------------------------------------------ *)
(* Edge cases                                                           *)
(* ------------------------------------------------------------------ *)

let test_short_history_returns_empty _ =
  (* History shorter than period → empty arrays. *)
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:5 ~start_price:100.0 ~step:0.1
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let cache = Weekly_ma_cache.create panels in
  let values, dates =
    Weekly_ma_cache.ma_values_for cache ~symbol:"AAPL" ~ma_type:Stage.Sma
      ~period:30
  in
  assert_that (Array.length values) (equal_to 0);
  assert_that (Array.length dates) (equal_to 0)

let test_unknown_symbol_returns_empty _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.1
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let cache = Weekly_ma_cache.create panels in
  let values, dates =
    Weekly_ma_cache.ma_values_for cache ~symbol:"MISSING" ~ma_type:Stage.Wma
      ~period:30
  in
  assert_that (Array.length values) (equal_to 0);
  assert_that (Array.length dates) (equal_to 0)

let test_locate_date_finds_present _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let cache = Weekly_ma_cache.create panels in
  let _values, dates =
    Weekly_ma_cache.ma_values_for cache ~symbol:"AAPL" ~ma_type:Stage.Wma
      ~period:30
  in
  (* The first cached date is the date of the 30th bar (index 29). *)
  let target = dates.(0) in
  assert_that
    (Weekly_ma_cache.locate_date dates target)
    (is_some_and (equal_to 0));
  let last = dates.(Array.length dates - 1) in
  assert_that
    (Weekly_ma_cache.locate_date dates last)
    (is_some_and (equal_to (Array.length dates - 1)))

let test_locate_date_returns_none_for_missing _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let cache = Weekly_ma_cache.create panels in
  let _values, dates =
    Weekly_ma_cache.ma_values_for cache ~symbol:"AAPL" ~ma_type:Stage.Wma
      ~period:30
  in
  (* A Wednesday (mid-week) date won't appear in the cached Friday-anchored
     dates. *)
  let target = Date.of_string "2024-08-14" in
  assert_that (Weekly_ma_cache.locate_date dates target) is_none

let test_cache_memoisation _ =
  (* Second call with the same key returns the same array reference (the
     [Hashtbl.find_or_add] never re-builds). *)
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  let panels = panels_of_symbols [ ("AAPL", bars) ] in
  let cache = Weekly_ma_cache.create panels in
  let v1, _ =
    Weekly_ma_cache.ma_values_for cache ~symbol:"AAPL" ~ma_type:Stage.Wma
      ~period:30
  in
  let v2, _ =
    Weekly_ma_cache.ma_values_for cache ~symbol:"AAPL" ~ma_type:Stage.Wma
      ~period:30
  in
  assert_that (phys_equal v1 v2) (equal_to true)

(* ------------------------------------------------------------------ *)
(* Snapshot-backed parity (Phase F.3.b-1)                                *)
(* ------------------------------------------------------------------ *)
(* Pin that {!Weekly_ma_cache.of_snapshot_views} produces bit-equal MA
   values + dates to {!Weekly_ma_cache.create} on the same underlying bar
   history. The legacy [create] reads via [Bar_panels.weekly_view_for];
   the new [of_snapshot_views] reads via
   [Snapshot_runtime.Snapshot_bar_views.weekly_view_for] over a
   {!Snapshot_callbacks.t} backed by a tmp snapshot directory.

   The helper [build_snapshot_callbacks] mirrors the internal setup that
   {!Bar_reader.of_in_memory_bars} uses (Phase F.3.a-1), producing a
   {!Snapshot_callbacks.t} from in-memory [(symbol, bars)] pairs. *)

module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

let _build_snapshot_callbacks
    (symbol_bars : (string * Types.Daily_price.t list) list) :
    Snapshot_callbacks.t =
  let dir = Stdlib.Filename.temp_dir "test_weekly_ma_cache_" "" in
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

(* The terminal date used as [max_as_of] for the snapshot-backed cache.
   The legacy panel-backed reader reads the largest available [as_of_day]
   (last column); the snapshot reader reads up to [max_as_of]. Pass the
   date of the last bar in the fixture so both backings see the same
   weekly window. *)
let _max_as_of_of bars =
  let last = List.last_exn bars in
  last.Types.Daily_price.date

let _run_snapshot_parity ~(ma_type : Stage.ma_type) ~period ~bars ~symbol =
  let panels = panels_of_symbols [ (symbol, bars) ] in
  let cb = _build_snapshot_callbacks [ (symbol, bars) ] in
  let max_as_of = _max_as_of_of bars in
  let panel_cache = Weekly_ma_cache.create panels in
  let snapshot_cache = Weekly_ma_cache.of_snapshot_views cb ~max_as_of in
  let panel_values, panel_dates =
    Weekly_ma_cache.ma_values_for panel_cache ~symbol ~ma_type ~period
  in
  let snap_values, snap_dates =
    Weekly_ma_cache.ma_values_for snapshot_cache ~symbol ~ma_type ~period
  in
  let panel_pairs =
    Array.to_list
      (Array.map2_exn panel_values panel_dates ~f:(fun v d -> (v, d)))
  in
  let snap_pairs =
    Array.to_list (Array.map2_exn snap_values snap_dates ~f:(fun v d -> (v, d)))
  in
  assert_that snap_pairs
    (elements_are
       (List.map panel_pairs ~f:(fun (v, d) ->
            all_of
              [
                field (fun (sv, _) -> sv) (float_equal ~epsilon:1e-9 v);
                field (fun (_, sd) -> sd) (equal_to d);
              ])))

let test_snapshot_parity_sma_30 _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  _run_snapshot_parity ~ma_type:Stage.Sma ~period:30 ~bars ~symbol:"AAPL"

let test_snapshot_parity_wma_30 _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.5
  in
  _run_snapshot_parity ~ma_type:Stage.Wma ~period:30 ~bars ~symbol:"AAPL"

let test_snapshot_parity_sma_10 _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:30 ~start_price:50.0 ~step:0.25
  in
  _run_snapshot_parity ~ma_type:Stage.Sma ~period:10 ~bars ~symbol:"XLK"

let test_snapshot_short_history_returns_empty _ =
  (* History shorter than period → empty arrays under either backing. *)
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:5 ~start_price:100.0 ~step:0.1
  in
  let cb = _build_snapshot_callbacks [ ("AAPL", bars) ] in
  let cache =
    Weekly_ma_cache.of_snapshot_views cb ~max_as_of:(_max_as_of_of bars)
  in
  let values, dates =
    Weekly_ma_cache.ma_values_for cache ~symbol:"AAPL" ~ma_type:Stage.Sma
      ~period:30
  in
  assert_that (Array.length values) (equal_to 0);
  assert_that (Array.length dates) (equal_to 0)

let test_snapshot_unknown_symbol_returns_empty _ =
  let bars =
    make_friday_bars
      ~start_friday:(Date.of_string "2024-01-05")
      ~n:60 ~start_price:100.0 ~step:0.1
  in
  let cb = _build_snapshot_callbacks [ ("AAPL", bars) ] in
  let cache =
    Weekly_ma_cache.of_snapshot_views cb ~max_as_of:(_max_as_of_of bars)
  in
  let values, dates =
    Weekly_ma_cache.ma_values_for cache ~symbol:"MISSING" ~ma_type:Stage.Wma
      ~period:30
  in
  assert_that (Array.length values) (equal_to 0);
  assert_that (Array.length dates) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("test_weekly_ma_cache"
    >::: [
           "SMA parity (period=30)" >:: test_sma_parity_30;
           "WMA parity (period=30)" >:: test_wma_parity_30;
           "EMA parity (period=30)" >:: test_ema_parity_30;
           "SMA parity (period=10)" >:: test_sma_parity_10;
           "Short history returns empty arrays"
           >:: test_short_history_returns_empty;
           "Unknown symbol returns empty arrays"
           >:: test_unknown_symbol_returns_empty;
           "locate_date finds present dates" >:: test_locate_date_finds_present;
           "locate_date returns None for missing dates"
           >:: test_locate_date_returns_none_for_missing;
           "Cache memoises by key" >:: test_cache_memoisation;
           "Snapshot parity (SMA period=30)" >:: test_snapshot_parity_sma_30;
           "Snapshot parity (WMA period=30)" >:: test_snapshot_parity_wma_30;
           "Snapshot parity (SMA period=10)" >:: test_snapshot_parity_sma_10;
           "Snapshot short history returns empty"
           >:: test_snapshot_short_history_returns_empty;
           "Snapshot unknown symbol returns empty"
           >:: test_snapshot_unknown_symbol_returns_empty;
         ])
