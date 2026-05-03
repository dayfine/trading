(** Tests for [Snapshot_bar_views] — the bar-shaped shim over
    [Snapshot_callbacks].

    Strategy: build a small synthetic OHLCV fixture twice — once into an
    [Ohlcv_panels.t]/[Bar_panels.t] (the panel-backed reference), once into a
    [Daily_panels.t]/[Snapshot_callbacks.t] (the snapshot-backed shim) — then
    compare the views produced by [Bar_panels.weekly_view_for] /
    [daily_view_for] / [low_window] against [Snapshot_bar_views.weekly_view_for]
    / [daily_view_for] / [low_window] cell-by-cell.

    The synthetic fixture has full OHLCV history (no NaN, no holiday gaps) so
    the panel's row-count and the snapshot's row-count agree, and the parity is
    bit-exact. Edge cases (unknown symbol, empty range, NaN closes) are
    exercised separately. *)

open OUnit2
open Core
open Matchers
module Bar_panels = Data_panel.Bar_panels
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Symbol_index = Data_panel.Symbol_index
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* --- Calendar / fixture builders ----------------------------------- *)

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* Iterate weekday dates only (Mon-Fri). Approximates a trading calendar:
   skips Saturday and Sunday. *)
let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

let _weekdays_starting ~start ~n_trading_days =
  let rec loop acc d remaining =
    if remaining = 0 then List.rev acc
    else if _is_weekday d then
      loop (d :: acc) (Date.add_days d 1) (remaining - 1)
    else loop acc (Date.add_days d 1) remaining
  in
  loop [] start n_trading_days

(* Deterministic synthetic bar — encoded so each field has a unique value
   per (symbol_id, day_offset), so any field-aliasing bug would surface as
   a value mismatch rather than the test passing by accident. *)
let _make_bar ~date ~symbol_seed ~day_offset : Types.Daily_price.t =
  let s = Float.of_int symbol_seed in
  let i = Float.of_int day_offset in
  {
    date;
    open_price = 100.0 +. s +. (i *. 0.10);
    high_price = 110.0 +. s +. (i *. 0.20);
    low_price = 90.0 +. s -. (i *. 0.05);
    close_price = 105.0 +. s +. (i *. 0.15);
    volume = 1000 + ((symbol_seed + 1) * (day_offset + 1));
    adjusted_close = 102.0 +. s +. (i *. 0.13);
  }

(* --- Schema for the snapshot path. The shim only reads OHLCV fields, but
   tests pass the canonical 13-field schema; the indicator scalars are set
   to NaN so they're loud if they ever leak into a bar field. *)
let _full_schema = Snapshot_schema.default

let _values_for_bar (bar : Types.Daily_price.t) : float array =
  Array.map (Array.of_list _full_schema.fields) ~f:(fun field ->
      match field with
      | Snapshot_schema.Open -> bar.open_price
      | Snapshot_schema.High -> bar.high_price
      | Snapshot_schema.Low -> bar.low_price
      | Snapshot_schema.Close -> bar.close_price
      | Snapshot_schema.Volume -> Float.of_int bar.volume
      | Snapshot_schema.Adjusted_close -> bar.adjusted_close
      | _ -> Float.nan)

let _make_snapshot_row ~symbol ~bar : Snapshot.t =
  match
    Snapshot.create ~schema:_full_schema ~symbol
      ~date:bar.Types.Daily_price.date ~values:(_values_for_bar bar)
  with
  | Ok r -> r
  | Error err -> assert_failure ("Snapshot.create: " ^ Status.show err)

(* --- Build a Bar_panels.t over the synthetic universe -------------- *)
let _build_bar_panels ~symbols ~calendar ~bars_for_symbol : Bar_panels.t =
  let symbol_index =
    match Symbol_index.create ~universe:symbols with
    | Ok idx -> idx
    | Error err -> assert_failure ("Symbol_index.create: " ^ Status.show err)
  in
  let n_days = Array.length calendar in
  let ohlcv = Ohlcv_panels.create symbol_index ~n_days in
  List.iteri symbols ~f:(fun row symbol ->
      Array.iteri calendar ~f:(fun day date ->
          match bars_for_symbol ~symbol ~date with
          | None -> ()
          | Some bar -> Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day bar));
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok t -> t
  | Error err -> assert_failure ("Bar_panels.create: " ^ Status.show err)

(* --- Build a Snapshot_callbacks.t over the same fixture ------------ *)
let _make_tmp_dir () = Filename_unix.temp_dir ~in_dir:"/tmp" "snapshot_bv_" ""

let _build_snapshot_callbacks ~symbols ~calendar ~bars_for_symbol :
    Snapshot_callbacks.t =
  let dir = _make_tmp_dir () in
  let entries =
    List.map symbols ~f:(fun symbol ->
        let rows =
          Array.to_list calendar
          |> List.filter_map ~f:(fun date ->
              match bars_for_symbol ~symbol ~date with
              | None -> None
              | Some bar -> Some (_make_snapshot_row ~symbol ~bar))
        in
        let path = Filename.concat dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err ->
            assert_failure ("Snapshot_format.write: " ^ Status.show err));
        ({
           symbol;
           path;
           byte_size = 0;
           payload_md5 = "ignored";
           csv_mtime = 0.0;
         }
          : Snapshot_manifest.file_metadata))
  in
  let manifest = Snapshot_manifest.create ~schema:_full_schema ~entries in
  match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:4 with
  | Ok panels -> Snapshot_callbacks.of_daily_panels panels
  | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)

(* --- Standard 3-symbol fixture ------------------------------------- *)

let _start = _ymd 2024 1 2 (* Tuesday *)

(* 60 trading days (weekday-only) — enough to exercise multiple ISO weeks. *)
let _calendar_60 =
  Array.of_list (_weekdays_starting ~start:_start ~n_trading_days:60)

let _symbols_3 = [ "AAA"; "BBB"; "CCC" ]

let _bars_for_symbol ~symbol ~date =
  let symbol_seed =
    match symbol with "AAA" -> 0 | "BBB" -> 10 | "CCC" -> 20 | _ -> -1000
  in
  if symbol_seed < 0 then None
  else
    match Array.findi _calendar_60 ~f:(fun _ d -> Date.equal d date) with
    | Some (i, _) -> Some (_make_bar ~date ~symbol_seed ~day_offset:i)
    | None -> None

let _setup_3sym () =
  ( _build_bar_panels ~symbols:_symbols_3 ~calendar:_calendar_60
      ~bars_for_symbol:_bars_for_symbol,
    _build_snapshot_callbacks ~symbols:_symbols_3 ~calendar:_calendar_60
      ~bars_for_symbol:_bars_for_symbol )

(* --- Helper assertions --------------------------------------------- *)

let _float_arrays_bit_equal (a : float array) (b : float array) ~msg =
  if Array.length a <> Array.length b then
    assert_failure
      (sprintf "%s: length mismatch panel=%d snapshot=%d" msg (Array.length a)
         (Array.length b));
  Array.iteri a ~f:(fun i pv ->
      let sv = b.(i) in
      let same = Float.equal pv sv || (Float.is_nan pv && Float.is_nan sv) in
      if not same then
        assert_failure
          (sprintf "%s: index %d differs panel=%.18g snapshot=%.18g" msg i pv sv))

let _date_arrays_equal (a : Date.t array) (b : Date.t array) ~msg =
  if Array.length a <> Array.length b then
    assert_failure
      (sprintf "%s: length mismatch panel=%d snapshot=%d" msg (Array.length a)
         (Array.length b));
  Array.iteri a ~f:(fun i pd ->
      let sd = b.(i) in
      if not (Date.equal pd sd) then
        assert_failure
          (sprintf "%s: index %d differs panel=%s snapshot=%s" msg i
             (Date.to_string pd) (Date.to_string sd)))

let _assert_weekly_views_equal (panel : Bar_panels.weekly_view)
    (snapshot : Snapshot_bar_views.weekly_view) =
  assert_that snapshot.n (equal_to panel.n);
  _float_arrays_bit_equal panel.closes snapshot.closes ~msg:"weekly closes";
  _float_arrays_bit_equal panel.raw_closes snapshot.raw_closes
    ~msg:"weekly raw_closes";
  _float_arrays_bit_equal panel.highs snapshot.highs ~msg:"weekly highs";
  _float_arrays_bit_equal panel.lows snapshot.lows ~msg:"weekly lows";
  _float_arrays_bit_equal panel.volumes snapshot.volumes ~msg:"weekly volumes";
  _date_arrays_equal panel.dates snapshot.dates ~msg:"weekly dates"

let _assert_daily_views_equal (panel : Bar_panels.daily_view)
    (snapshot : Snapshot_bar_views.daily_view) =
  assert_that snapshot.n_days (equal_to panel.n_days);
  _float_arrays_bit_equal panel.highs snapshot.highs ~msg:"daily highs";
  _float_arrays_bit_equal panel.lows snapshot.lows ~msg:"daily lows";
  _float_arrays_bit_equal panel.closes snapshot.closes ~msg:"daily closes";
  _date_arrays_equal panel.dates snapshot.dates ~msg:"daily dates"

(* --- weekly_view_for parity ---------------------------------------- *)

let _column_of_date_exn bp date =
  match Bar_panels.column_of_date bp date with
  | Some i -> i
  | None ->
      assert_failure
        (sprintf "calendar lookup failed for %s" (Date.to_string date))

let test_weekly_view_parity_full _ =
  let bp, cb = _setup_3sym () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let as_of_day = _column_of_date_exn bp as_of in
  List.iter _symbols_3 ~f:(fun symbol ->
      let panel_view = Bar_panels.weekly_view_for bp ~symbol ~n:8 ~as_of_day in
      let snapshot_view =
        Snapshot_bar_views.weekly_view_for cb ~symbol ~n:8 ~as_of
      in
      _assert_weekly_views_equal panel_view snapshot_view)

let test_weekly_view_parity_mid_window _ =
  let bp, cb = _setup_3sym () in
  let as_of = _calendar_60.(40) in
  let as_of_day = _column_of_date_exn bp as_of in
  let panel_view =
    Bar_panels.weekly_view_for bp ~symbol:"BBB" ~n:5 ~as_of_day
  in
  let snapshot_view =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"BBB" ~n:5 ~as_of
  in
  _assert_weekly_views_equal panel_view snapshot_view

(* --- daily_view_for parity ----------------------------------------- *)

let test_daily_view_parity_full _ =
  let bp, cb = _setup_3sym () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let as_of_day = _column_of_date_exn bp as_of in
  List.iter _symbols_3 ~f:(fun symbol ->
      let panel_view =
        Bar_panels.daily_view_for bp ~symbol ~as_of_day ~lookback:30
      in
      let snapshot_view =
        Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback:30
      in
      _assert_daily_views_equal panel_view snapshot_view)

let test_daily_view_parity_short_lookback _ =
  let bp, cb = _setup_3sym () in
  let as_of = _calendar_60.(20) in
  let as_of_day = _column_of_date_exn bp as_of in
  let panel_view =
    Bar_panels.daily_view_for bp ~symbol:"AAA" ~as_of_day ~lookback:7
  in
  let snapshot_view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of ~lookback:7
  in
  _assert_daily_views_equal panel_view snapshot_view

(* --- low_window parity --------------------------------------------- *)

let _bigarray_to_list (arr : (float, _, _) Bigarray.Array1.t) =
  List.init (Bigarray.Array1.dim arr) ~f:(fun i -> Bigarray.Array1.get arr i)

let test_low_window_parity _ =
  let bp, cb = _setup_3sym () in
  let as_of = _calendar_60.(50) in
  let as_of_day = _column_of_date_exn bp as_of in
  let panel = Bar_panels.low_window bp ~symbol:"CCC" ~as_of_day ~len:30 in
  let snapshot =
    Snapshot_bar_views.low_window cb ~symbol:"CCC" ~as_of ~len:30
  in
  match (panel, snapshot) with
  | Some p, Some s ->
      let pa = Array.of_list (_bigarray_to_list p) in
      let sa = Array.of_list (_bigarray_to_list s) in
      _float_arrays_bit_equal pa sa ~msg:"low_window"
  | None, None -> ()
  | _ -> assert_failure "low_window parity: one side returned None"

(* --- Edge cases ----------------------------------------------------- *)

let test_unknown_symbol_yields_empty_views _ =
  let _, cb = _setup_3sym () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let weekly =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"ZZZ" ~n:5 ~as_of
  in
  assert_that weekly.n (equal_to 0);
  let daily =
    Snapshot_bar_views.daily_view_for cb ~symbol:"ZZZ" ~as_of ~lookback:10
  in
  assert_that daily.n_days (equal_to 0);
  let low = Snapshot_bar_views.low_window cb ~symbol:"ZZZ" ~as_of ~len:5 in
  assert_that low is_none

let test_pre_history_as_of_yields_empty_views _ =
  let _, cb = _setup_3sym () in
  let pre = Date.add_days _calendar_60.(0) (-30) in
  let weekly =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAA" ~n:5 ~as_of:pre
  in
  assert_that weekly.n (equal_to 0);
  let daily =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of:pre ~lookback:5
  in
  assert_that daily.n_days (equal_to 0);
  let low = Snapshot_bar_views.low_window cb ~symbol:"AAA" ~as_of:pre ~len:5 in
  assert_that low is_none

let test_zero_n_or_lookback_yields_empty_views _ =
  let _, cb = _setup_3sym () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let weekly =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAA" ~n:0 ~as_of
  in
  assert_that weekly.n (equal_to 0);
  let daily =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of ~lookback:0
  in
  assert_that daily.n_days (equal_to 0);
  let low = Snapshot_bar_views.low_window cb ~symbol:"AAA" ~as_of ~len:0 in
  assert_that low is_none

(* NaN handling: build a fixture where one mid-history close is NaN. The
   daily_view must drop that bar (matching Bar_panels semantics). The
   snapshot path's NaN-skip is gated on the [Close] field; we set Close to
   NaN at one date and leave the other fields populated.

   We compare against Bar_panels for the same fixture: writing a NaN-close
   bar via [write_row] propagates to [close_p], which is what daily_view's
   skip filter checks. *)

let _bars_with_nan_close ~nan_date ~symbol ~date =
  let symbol_seed = match symbol with "DDD" -> 30 | _ -> -1000 in
  if symbol_seed < 0 then None
  else
    match Array.findi _calendar_60 ~f:(fun _ d -> Date.equal d date) with
    | Some (i, _) ->
        let bar = _make_bar ~date ~symbol_seed ~day_offset:i in
        if Date.equal date nan_date then
          Some { bar with close_price = Float.nan; adjusted_close = Float.nan }
        else Some bar
    | None -> None

let test_nan_close_skipped_in_daily_view _ =
  let nan_date = _calendar_60.(15) in
  let bars = _bars_with_nan_close ~nan_date in
  let symbols = [ "DDD" ] in
  let bp =
    _build_bar_panels ~symbols ~calendar:_calendar_60 ~bars_for_symbol:bars
  in
  let cb =
    _build_snapshot_callbacks ~symbols ~calendar:_calendar_60
      ~bars_for_symbol:bars
  in
  let as_of = _calendar_60.(30) in
  let as_of_day = _column_of_date_exn bp as_of in
  let panel_view =
    Bar_panels.daily_view_for bp ~symbol:"DDD" ~as_of_day ~lookback:30
  in
  let snapshot_view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"DDD" ~as_of ~lookback:30
  in
  (* Both should skip the NaN-close bar. The panel's lookback walks back 30
     calendar columns; with one NaN-close skipped, both should report 30
     trading days minus 1 = at most 30 entries actually present (since the
     calendar has 31 columns ending at as_of, and one is NaN). The exact
     count may differ from the panel impl by edge effects of the
     [_daily_calendar_span] approximation; the load-bearing assertion is
     that the snapshot view excludes the NaN date. *)
  assert_that snapshot_view.n_days (equal_to panel_view.n_days);
  let snapshot_dates_set = Date.Set.of_array snapshot_view.dates in
  assert_that (Set.mem snapshot_dates_set nan_date) (equal_to false);
  _assert_daily_views_equal panel_view snapshot_view

(* --- Suite ---------------------------------------------------------- *)

let suite =
  "Snapshot_bar_views tests"
  >::: [
         "weekly_view_for parity (full window, all symbols)"
         >:: test_weekly_view_parity_full;
         "weekly_view_for parity (mid-window single symbol)"
         >:: test_weekly_view_parity_mid_window;
         "daily_view_for parity (full window, all symbols)"
         >:: test_daily_view_parity_full;
         "daily_view_for parity (short lookback)"
         >:: test_daily_view_parity_short_lookback;
         "low_window parity" >:: test_low_window_parity;
         "unknown symbol yields empty views"
         >:: test_unknown_symbol_yields_empty_views;
         "as_of before any data yields empty views"
         >:: test_pre_history_as_of_yields_empty_views;
         "n=0 / lookback=0 yields empty views"
         >:: test_zero_n_or_lookback_yields_empty_views;
         "NaN close skipped in daily_view"
         >:: test_nan_close_skipped_in_daily_view;
       ]

let () = run_test_tt_main suite
