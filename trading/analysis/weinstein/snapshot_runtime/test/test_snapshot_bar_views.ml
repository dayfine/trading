(** Tests for [Snapshot_bar_views] — the bar-shaped shim over
    [Snapshot_callbacks].

    Strategy: build a small synthetic OHLCV fixture into a
    [Daily_panels.t]/[Snapshot_callbacks.t] and exercise
    [Snapshot_bar_views.weekly_view_for] / [daily_view_for] / [low_window].
    Since the panel-backed reference reader (Bar_panels) was retired in F.3.e-3,
    the tests assert against expected values derived from the fixture's known
    structure (rather than a parallel panel readout).

    Edge cases (unknown symbol, empty range, NaN closes, calendar walking with
    holiday gaps) are exercised in isolation. *)

open OUnit2
open Core
open Matchers
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

(* --- Build a Snapshot_callbacks.t over the synthetic universe ------- *)
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

let _setup_3sym_cb () =
  _build_snapshot_callbacks ~symbols:_symbols_3 ~calendar:_calendar_60
    ~bars_for_symbol:_bars_for_symbol

(* --- Helper assertions --------------------------------------------- *)

let _expect_n_days_eq ~msg snapshot expected =
  if snapshot <> expected then
    assert_failure
      (sprintf "%s: n_days mismatch snapshot=%d expected=%d" msg snapshot
         expected)

(* --- weekly_view_for smoke tests ----------------------------------- *)

(* Verify shape + monotonic dates for a full-window weekly view across all
   symbols. Closes / highs / lows arrays must each have length [n] equal to
   the dates array. *)
let test_weekly_view_for_full_window_shape _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  List.iter _symbols_3 ~f:(fun symbol ->
      let view = Snapshot_bar_views.weekly_view_for cb ~symbol ~n:8 ~as_of in
      assert_that view.n (gt (module Int_ord) 0);
      assert_that (Array.length view.closes) (equal_to view.n);
      assert_that (Array.length view.highs) (equal_to view.n);
      assert_that (Array.length view.lows) (equal_to view.n);
      assert_that (Array.length view.volumes) (equal_to view.n);
      assert_that (Array.length view.dates) (equal_to view.n);
      (* Dates must be ascending. *)
      Array.iteri view.dates ~f:(fun i d ->
          if i > 0 && Date.( < ) d view.dates.(i - 1) then
            assert_failure "weekly view dates not ascending"))

(* Mid-window weekly view: requesting [n=5] from index 40 should return at
   most 5 weekly buckets, all dated <= as_of. *)
let test_weekly_view_for_mid_window _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(40) in
  let view = Snapshot_bar_views.weekly_view_for cb ~symbol:"BBB" ~n:5 ~as_of in
  assert_that view.n (le (module Int_ord) 5);
  assert_that view.n (gt (module Int_ord) 0);
  Array.iter view.dates ~f:(fun d ->
      if Date.( > ) d as_of then
        assert_failure "weekly view contains date after as_of")

(* --- daily_view_for smoke tests ------------------------------------- *)

let test_daily_view_for_full_window_shape _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  List.iter _symbols_3 ~f:(fun symbol ->
      let view =
        Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback:30
          ~calendar:_calendar_60
      in
      _expect_n_days_eq ~msg:("full window " ^ symbol) view.n_days 30;
      assert_that (Array.length view.closes) (equal_to view.n_days);
      assert_that (Array.length view.highs) (equal_to view.n_days);
      assert_that (Array.length view.lows) (equal_to view.n_days);
      assert_that (Array.length view.dates) (equal_to view.n_days))

let test_daily_view_for_short_lookback _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(20) in
  let view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of ~lookback:7
      ~calendar:_calendar_60
  in
  _expect_n_days_eq ~msg:"short lookback" view.n_days 7

(* --- low_window smoke tests ---------------------------------------- *)

let _bigarray_to_list (arr : (float, _, _) Bigarray.Array1.t) =
  List.init (Bigarray.Array1.dim arr) ~f:(fun i -> Bigarray.Array1.get arr i)

let test_low_window_shape _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(50) in
  let snapshot =
    Snapshot_bar_views.low_window cb ~symbol:"CCC" ~as_of ~len:30
      ~calendar:_calendar_60
  in
  match snapshot with
  | Some s ->
      assert_that (Bigarray.Array1.dim s) (equal_to 30);
      (* All cells must be the symbol's [low_price] field — 90.0 + 20 + ...
         (CCC has symbol_seed = 20). Just check no NaN in this gap-free
         fixture. *)
      List.iter (_bigarray_to_list s) ~f:(fun v ->
          assert_that (Float.is_nan v) (equal_to false))
  | None -> assert_failure "low_window returned None"

(* --- Edge cases ----------------------------------------------------- *)

let test_unknown_symbol_yields_empty_views _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let weekly =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"ZZZ" ~n:5 ~as_of
  in
  assert_that weekly.n (equal_to 0);
  let daily =
    Snapshot_bar_views.daily_view_for cb ~symbol:"ZZZ" ~as_of ~lookback:10
      ~calendar:_calendar_60
  in
  assert_that daily.n_days (equal_to 0);
  let low =
    Snapshot_bar_views.low_window cb ~symbol:"ZZZ" ~as_of ~len:5
      ~calendar:_calendar_60
  in
  assert_that low is_none

let test_pre_history_as_of_yields_empty_views _ =
  let cb = _setup_3sym_cb () in
  let pre = Date.add_days _calendar_60.(0) (-30) in
  let weekly =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAA" ~n:5 ~as_of:pre
  in
  assert_that weekly.n (equal_to 0);
  let daily =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of:pre ~lookback:5
      ~calendar:_calendar_60
  in
  assert_that daily.n_days (equal_to 0);
  let low =
    Snapshot_bar_views.low_window cb ~symbol:"AAA" ~as_of:pre ~len:5
      ~calendar:_calendar_60
  in
  assert_that low is_none

let test_zero_n_or_lookback_yields_empty_views _ =
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let weekly =
    Snapshot_bar_views.weekly_view_for cb ~symbol:"AAA" ~n:0 ~as_of
  in
  assert_that weekly.n (equal_to 0);
  let daily =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of ~lookback:0
      ~calendar:_calendar_60
  in
  assert_that daily.n_days (equal_to 0);
  let low =
    Snapshot_bar_views.low_window cb ~symbol:"AAA" ~as_of ~len:0
      ~calendar:_calendar_60
  in
  assert_that low is_none

(* NaN handling: build a fixture where one mid-history close is NaN. The
   daily_view must drop that bar. The snapshot path's NaN-skip is gated on
   the [Close] field; we set Close to NaN at one date and leave the other
   fields populated. *)

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
  let cb =
    _build_snapshot_callbacks ~symbols ~calendar:_calendar_60
      ~bars_for_symbol:bars
  in
  let as_of = _calendar_60.(30) in
  (* lookback=30 walks calendar columns 1..30 (inclusive of as_of at 30).
     The NaN date at index 15 must be excluded. *)
  let snapshot_view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"DDD" ~as_of ~lookback:30
      ~calendar:_calendar_60
  in
  assert_that snapshot_view.n_days (equal_to 29);
  let snapshot_dates_set = Date.Set.of_array snapshot_view.dates in
  assert_that (Set.mem snapshot_dates_set nan_date) (equal_to false)

(* --- #848 forward-fix regression tests ----------------------------- *)
(* The pre-fix snapshot path computed its own calendar window from the
   fixture's [bars]; the post-fix path takes the panel's calendar as a
   parameter and walks it bit-identically. The fixture below builds a
   calendar with a "holiday gap" — a calendar weekday with no snapshot
   row for the symbol — and verifies:
   - daily_view_for n_days = lookback - gap_count
   - low_window includes a NaN cell at the gap day *)

(* A 20-weekday calendar starting Tue 2024-01-02. Within this calendar
   we'll build snapshot bars for every weekday EXCEPT day index 10 (a
   simulated holiday; symbol has no row there). *)
let _calendar_20 =
  Array.of_list (_weekdays_starting ~start:_start ~n_trading_days:20)

let _holiday_gap_idx = 10

let _bars_with_holiday_gap ~symbol ~date =
  let symbol_seed = match symbol with "EEE" -> 40 | _ -> -1000 in
  if symbol_seed < 0 then None
  else
    match Array.findi _calendar_20 ~f:(fun _ d -> Date.equal d date) with
    | Some (i, _) when i = _holiday_gap_idx -> None
    | Some (i, _) -> Some (_make_bar ~date ~symbol_seed ~day_offset:i)
    | None -> None

let test_daily_view_walks_calendar_with_holiday_gap _ =
  let symbols = [ "EEE" ] in
  let cb =
    _build_snapshot_callbacks ~symbols ~calendar:_calendar_20
      ~bars_for_symbol:_bars_with_holiday_gap
  in
  let as_of = _calendar_20.(15) in
  (* lookback=10 covers calendar indices 6..15; index 10 is the gap.
     The snapshot must produce 9 non-NaN bars excluding the gap date. *)
  let snap_view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"EEE" ~as_of ~lookback:10
      ~calendar:_calendar_20
  in
  assert_that snap_view.n_days (equal_to 9);
  let gap_date = _calendar_20.(_holiday_gap_idx) in
  let snap_dates_set = Date.Set.of_array snap_view.dates in
  assert_that (Set.mem snap_dates_set gap_date) (equal_to false)

let test_low_window_walks_calendar_with_holiday_gap _ =
  let symbols = [ "EEE" ] in
  let cb =
    _build_snapshot_callbacks ~symbols ~calendar:_calendar_20
      ~bars_for_symbol:_bars_with_holiday_gap
  in
  let as_of = _calendar_20.(15) in
  let snap =
    Snapshot_bar_views.low_window cb ~symbol:"EEE" ~as_of ~len:10
      ~calendar:_calendar_20
  in
  match snap with
  | Some s ->
      let sa = Array.of_list (_bigarray_to_list s) in
      (* The gap day at calendar index 10 is at offset (10 - 6) = 4 in
         the [len:10] window starting at index 6. The gap cell must be
         NaN. *)
      assert_that (Float.is_nan sa.(4)) (equal_to true);
      (* Other cells must be finite (the fixture has full coverage outside
         the gap). *)
      Array.iteri sa ~f:(fun i v ->
          if i <> 4 && Float.is_nan v then
            assert_failure
              (sprintf
                 "low_window cell %d unexpectedly NaN (fixture has full \
                  coverage outside the gap)"
                 i))
  | None -> assert_failure "expected Some on low_window with gap fixture"

let test_daily_bars_for_open_price_populated _ =
  (* Pin the Open-field fix: pre-#848 the snapshot path returned bars
     with [open_price = Float.nan]; the post-fix path reads
     [Snapshot_schema.Open] from the snapshot row. For the standard
     3-symbol fixture (no NaN, no gaps), every snapshot bar should have
     a finite open_price matching the fixture's _make_bar formula. *)
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let snap_bars = Snapshot_bar_views.daily_bars_for cb ~symbol:"AAA" ~as_of in
  assert_that (List.length snap_bars) (equal_to 60);
  List.iteri snap_bars ~f:(fun i bar ->
      let expected = 100.0 +. 0.0 +. (Float.of_int i *. 0.10) in
      assert_that bar.Types.Daily_price.open_price (float_equal expected))

let test_daily_bars_for_open_price_is_not_nan _ =
  (* Stronger assertion: every bar's open_price is finite. This catches
     a regression where Open is read but always returns NaN (e.g. the
     wrong schema field was wired). *)
  let cb = _setup_3sym_cb () in
  let as_of = _calendar_60.(Array.length _calendar_60 - 1) in
  let snap_bars = Snapshot_bar_views.daily_bars_for cb ~symbol:"BBB" ~as_of in
  assert_that (List.length snap_bars) (gt (module Int_ord) 0);
  List.iter snap_bars ~f:(fun bar ->
      assert_that
        (Float.is_nan bar.Types.Daily_price.open_price)
        (equal_to false))

let test_daily_view_as_of_not_in_calendar_yields_empty _ =
  let cb = _setup_3sym_cb () in
  (* A weekday that is NOT in the 60-day calendar (well past the end). *)
  let post = Date.add_days _calendar_60.(Array.length _calendar_60 - 1) 30 in
  let view =
    Snapshot_bar_views.daily_view_for cb ~symbol:"AAA" ~as_of:post ~lookback:10
      ~calendar:_calendar_60
  in
  assert_that view.n_days (equal_to 0);
  let low =
    Snapshot_bar_views.low_window cb ~symbol:"AAA" ~as_of:post ~len:5
      ~calendar:_calendar_60
  in
  assert_that low is_none

(* --- Suite ---------------------------------------------------------- *)

let suite =
  "Snapshot_bar_views tests"
  >::: [
         "weekly_view_for full-window shape (all symbols)"
         >:: test_weekly_view_for_full_window_shape;
         "weekly_view_for mid-window single symbol"
         >:: test_weekly_view_for_mid_window;
         "daily_view_for full-window shape (all symbols)"
         >:: test_daily_view_for_full_window_shape;
         "daily_view_for short lookback" >:: test_daily_view_for_short_lookback;
         "low_window full window shape" >:: test_low_window_shape;
         "unknown symbol yields empty views"
         >:: test_unknown_symbol_yields_empty_views;
         "as_of before any data yields empty views"
         >:: test_pre_history_as_of_yields_empty_views;
         "n=0 / lookback=0 yields empty views"
         >:: test_zero_n_or_lookback_yields_empty_views;
         "NaN close skipped in daily_view"
         >:: test_nan_close_skipped_in_daily_view;
         "daily_view_for walks calendar; holiday gap excluded"
         >:: test_daily_view_walks_calendar_with_holiday_gap;
         "low_window walks calendar; holiday gap is NaN cell"
         >:: test_low_window_walks_calendar_with_holiday_gap;
         "daily_bars_for open_price matches fixture formula"
         >:: test_daily_bars_for_open_price_populated;
         "daily_bars_for open_price is finite (not NaN)"
         >:: test_daily_bars_for_open_price_is_not_nan;
         "daily_view_for as_of not in calendar yields empty"
         >:: test_daily_view_as_of_not_in_calendar_yields_empty;
       ]

let () = run_test_tt_main suite
