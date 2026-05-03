(** Phase F.2 PR 2 parity gate — snapshot-mode vs CSV-mode [Bar_reader] return
    identical [weekly_view] / [daily_view] reads on the same input bars.

    Sibling of [test_snapshot_mode_parity.ml]: that test pinned the simulator's
    per-tick price-read seam at [Market_data_adapter]; this test pins the
    strategy's per-tick bar-read seam at [Bar_reader]. The two cover the two
    distinct surfaces snapshot mode now subsumes.

    {1 What we assert}

    Build the same in-memory bar stream into BOTH a CSV directory (for
    [Ohlcv_panels.load_from_csv_calendar] -> [Bar_panels.create]) and a snapshot
    directory (for [Daily_panels.create]). Wrap each in a [Bar_reader.t] via the
    appropriate constructor. Walk every (symbol, date) pair in the fixture and
    assert the two readers' views are array-equal.

    If this holds, the strategy's bar-shaped reads
    ([Stage.classify_with_callbacks], [Stock_analysis.analyze], etc.) observe
    the same input series in either mode by construction — every downstream
    consumer is a pure function of these reads. *)

open OUnit2
open Core
open Matchers
module Bar_panels = Data_panel.Bar_panels
module Bar_reader = Weinstein_strategy.Bar_reader
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Pipeline = Snapshot_pipeline.Pipeline
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels

(* -------------------------------------------------------------------- *)
(* Fixture helpers — adapted from [test_snapshot_mode_parity.ml].        *)
(* -------------------------------------------------------------------- *)

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* Synthetic bars: deterministic per-(symbol, day_index) so any drift
   shows up as a per-cell mismatch. Volumes < 2^53 round-trip exactly. *)
let _make_bar ~symbol ~day_index ~start =
  let date = Date.add_days start day_index in
  let base = 100.0 +. (Float.of_int (String.hash symbol mod 50) *. 0.1) in
  let drift = Float.of_int day_index *. 0.05 in
  let close = base +. drift in
  {
    Types.Daily_price.date;
    open_price = close -. 0.10;
    high_price = close +. 0.20;
    low_price = close -. 0.30;
    close_price = close;
    volume = 1_000_000 + (day_index * 1000);
    adjusted_close = close;
  }

(* Filter a bar list to weekdays only — the calendar [Bar_panels.create]
   consumes is weekday-only ([Panel_runner._build_calendar]); to compare
   apples-to-apples the snapshot path must store the same weekday subset.
   The Phase B pipeline accepts an arbitrary date list, so passing the
   pre-filtered list keeps both paths in lockstep. *)
let _bars_for ~symbol ~start ~n =
  List.init n ~f:(fun i -> _make_bar ~symbol ~day_index:i ~start)
  |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
      let dow = Date.day_of_week b.date in
      not
        (Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun))

let _make_tmp_dir prefix = Filename_unix.temp_dir ~in_dir:"/tmp" prefix ""

(* CSV writer: identical schema to [test_snapshot_mode_parity._write_csv_dir];
   the [Ohlcv_panels.load_from_csv_calendar] path resolves
   [data_dir/<F>/<L>/<SYM>/data.csv] for each symbol. *)
let _write_csv_dir ~data_dir bars_by_symbol =
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      let f = String.sub symbol ~pos:0 ~len:1 in
      let l = String.sub symbol ~pos:(String.length symbol - 1) ~len:1 in
      let dir = Filename.of_parts [ data_dir; f; l; symbol ] in
      Core_unix.mkdir_p dir;
      let path = Filename.concat dir "data.csv" in
      Out_channel.with_file path ~f:(fun oc ->
          Out_channel.output_string oc
            "date,open,high,low,close,adjusted_close,volume\n";
          List.iter bars ~f:(fun (b : Types.Daily_price.t) ->
              Out_channel.output_string oc
                (sprintf "%s,%.17g,%.17g,%.17g,%.17g,%.17g,%d\n"
                   (Date.to_string b.date) b.open_price b.high_price b.low_price
                   b.close_price b.adjusted_close b.volume))))

let _write_snapshot_dir ~snapshot_dir bars_by_symbol =
  let schema = Snapshot_schema.default in
  let entries =
    List.map bars_by_symbol ~f:(fun (symbol, bars) ->
        let rows =
          match Pipeline.build_for_symbol ~symbol ~bars ~schema () with
          | Ok r -> r
          | Error err ->
              assert_failure ("Pipeline.build_for_symbol: " ^ Status.show err)
        in
        let path = Filename.concat snapshot_dir (symbol ^ ".snap") in
        (match Snapshot_format.write ~path rows with
        | Ok () -> ()
        | Error err ->
            assert_failure ("Snapshot_format.write: " ^ Status.show err));
        let stat = Core_unix.stat path in
        ({
           symbol;
           path;
           byte_size = Int64.to_int_exn stat.st_size;
           payload_md5 = "ignored";
           csv_mtime = stat.st_mtime;
         }
          : Snapshot_manifest.file_metadata))
  in
  Snapshot_manifest.create ~schema ~entries

(* Generate the calendar [Bar_panels.create] expects: every weekday from
   [start..start + n - 1] (inclusive). Same shape as
   [Panel_runner._build_calendar]. *)
let _calendar_of ~start ~n =
  let rec loop i acc =
    if i >= n then List.rev acc
    else
      let d = Date.add_days start i in
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (i + 1) acc'
  in
  Array.of_list (loop 0 [])

(* Build a [Bar_panels.t] from CSV files using the canonical pipeline. *)
let _build_bar_panels ~data_dir ~symbols ~calendar =
  let symbol_index =
    match Symbol_index.create ~universe:symbols with
    | Ok t -> t
    | Error err -> assert_failure ("Symbol_index.create: " ^ Status.show err)
  in
  let ohlcv =
    match
      Ohlcv_panels.load_from_csv_calendar symbol_index
        ~data_dir:(Fpath.v data_dir) ~calendar
    with
    | Ok t -> t
    | Error err ->
        assert_failure
          ("Ohlcv_panels.load_from_csv_calendar: " ^ Status.show err)
  in
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> assert_failure ("Bar_panels.create: " ^ Status.show err)

let _build_snapshot_callbacks ~snapshot_dir ~manifest =
  match Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb:64 with
  | Ok p -> Snapshot_callbacks.of_daily_panels p
  | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)

(* -------------------------------------------------------------------- *)
(* Tests                                                                 *)
(* -------------------------------------------------------------------- *)

let _default_symbols = [ "AAPL"; "MSFT"; "JPM" ]
let _default_start = _ymd 2024 1 2
let _default_n = 60

(* Bundle returned to tests so each test isn't repeating the dual-fixture
   setup. *)
type fixtures = {
  csv_reader : Bar_reader.t;
  snap_reader : Bar_reader.t;
  bars_by_symbol : (string * Types.Daily_price.t list) list;
}

let _setup_dual_readers () =
  let data_dir = _make_tmp_dir "snapshot_strategy_parity_csv_" in
  let snapshot_dir = _make_tmp_dir "snapshot_strategy_parity_snap_" in
  let bars_by_symbol =
    List.map _default_symbols ~f:(fun s ->
        (s, _bars_for ~symbol:s ~start:_default_start ~n:_default_n))
  in
  _write_csv_dir ~data_dir bars_by_symbol;
  let manifest = _write_snapshot_dir ~snapshot_dir bars_by_symbol in
  let calendar = _calendar_of ~start:_default_start ~n:_default_n in
  let bar_panels =
    _build_bar_panels ~data_dir ~symbols:_default_symbols ~calendar
  in
  let csv_reader = Bar_reader.of_panels bar_panels in
  let cb = _build_snapshot_callbacks ~snapshot_dir ~manifest in
  let snap_reader = Bar_reader.of_snapshot_views cb in
  { csv_reader; snap_reader; bars_by_symbol }

(* Per-cell parity helpers. The [weekly_view] / [daily_view] records are
   pure-data float arrays + dates + an [n] counter; we compare component-
   wise. Float equality is structural ([Bar_panels] writes the exact float
   we put into the CSV at %.17g, [Snapshot_format] carries the float
   verbatim) so [equal_to] suffices. *)
let _assert_weekly_views_equal ~snap ~csv =
  assert_that snap (equal_to (csv : Bar_panels.weekly_view))

let _assert_daily_views_equal ~snap ~csv =
  assert_that snap (equal_to (csv : Bar_panels.daily_view))

(* {1 Weekly view parity}

   Walk every (symbol, date) and assert weekly_view_for matches between the
   two readers. [n=8] covers the screener's typical lookback window (the
   strategy reads 8 weekly bars for stage / volume / resistance). *)
let test_weekly_view_bit_equal _ =
  let { csv_reader; snap_reader; bars_by_symbol } = _setup_dual_readers () in
  let n = 8 in
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      List.iter bars ~f:(fun (bar : Types.Daily_price.t) ->
          let csv_view =
            Bar_reader.weekly_view_for csv_reader ~symbol ~n ~as_of:bar.date
          in
          let snap_view =
            Bar_reader.weekly_view_for snap_reader ~symbol ~n ~as_of:bar.date
          in
          _assert_weekly_views_equal ~snap:snap_view ~csv:csv_view))

(* {1 Daily view parity}

   Same shape, [lookback=20] covering the support-floor primitive's typical
   window (Weinstein 90-day support floor scaled down to fit the fixture). *)
let test_daily_view_bit_equal _ =
  let { csv_reader; snap_reader; bars_by_symbol } = _setup_dual_readers () in
  let lookback = 20 in
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      List.iter bars ~f:(fun (bar : Types.Daily_price.t) ->
          let csv_view =
            Bar_reader.daily_view_for csv_reader ~symbol ~as_of:bar.date
              ~lookback
          in
          let snap_view =
            Bar_reader.daily_view_for snap_reader ~symbol ~as_of:bar.date
              ~lookback
          in
          _assert_daily_views_equal ~snap:snap_view ~csv:csv_view))

(* {1 Daily bar list parity (excluding [open_price])}

   The snapshot path's [daily_bars_for] does not surface [Snapshot_schema.Open]
   today (see [Snapshot_bar_views.daily_bars_for]'s [open_price = NaN]
   contract). The in-tree consumers of [Bar_reader.daily_bars_for] read
   close / high / low / volume / adjusted_close — never open — so the parity
   we care about is "every consumer-relevant field matches". Compare the two
   paths' bar lists element-wise, asserting equality on every field except
   [open_price]. *)
let _assert_bars_equal_except_open ~snap ~csv =
  assert_that snap
    (elements_are
       (List.map csv ~f:(fun (cb : Types.Daily_price.t) ->
            all_of
              [
                field
                  (fun (b : Types.Daily_price.t) -> b.date)
                  (equal_to cb.date);
                field
                  (fun (b : Types.Daily_price.t) -> b.high_price)
                  (float_equal cb.high_price);
                field
                  (fun (b : Types.Daily_price.t) -> b.low_price)
                  (float_equal cb.low_price);
                field
                  (fun (b : Types.Daily_price.t) -> b.close_price)
                  (float_equal cb.close_price);
                field
                  (fun (b : Types.Daily_price.t) -> b.adjusted_close)
                  (float_equal cb.adjusted_close);
                field
                  (fun (b : Types.Daily_price.t) -> b.volume)
                  (equal_to cb.volume);
              ])))

let test_daily_bars_for_consumer_fields_equal _ =
  let { csv_reader; snap_reader; bars_by_symbol } = _setup_dual_readers () in
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      List.iter bars ~f:(fun (bar : Types.Daily_price.t) ->
          let csv_bars =
            Bar_reader.daily_bars_for csv_reader ~symbol ~as_of:bar.date
          in
          let snap_bars =
            Bar_reader.daily_bars_for snap_reader ~symbol ~as_of:bar.date
          in
          _assert_bars_equal_except_open ~snap:snap_bars ~csv:csv_bars))

(* {1 Edge case parity}

   Both readers must return the empty view under the same conditions:
   (1) date with no bar (probe before fixture start), and
   (2) unknown symbol. *)
let test_missing_returns_empty_in_both _ =
  let { csv_reader; snap_reader; _ } = _setup_dual_readers () in
  let probes =
    [
      ("AAPL", Date.add_days _default_start (-10));
      ("UNKNOWN", Date.add_days _default_start 5);
    ]
  in
  List.iter probes ~f:(fun (symbol, date) ->
      let csv_w =
        Bar_reader.weekly_view_for csv_reader ~symbol ~n:8 ~as_of:date
      in
      let snap_w =
        Bar_reader.weekly_view_for snap_reader ~symbol ~n:8 ~as_of:date
      in
      _assert_weekly_views_equal ~snap:snap_w ~csv:csv_w;
      let csv_d =
        Bar_reader.daily_view_for csv_reader ~symbol ~as_of:date ~lookback:20
      in
      let snap_d =
        Bar_reader.daily_view_for snap_reader ~symbol ~as_of:date ~lookback:20
      in
      _assert_daily_views_equal ~snap:snap_d ~csv:csv_d)

let suite =
  "Snapshot_mode_strategy_parity"
  >::: [
         "test_weekly_view_bit_equal" >:: test_weekly_view_bit_equal;
         "test_daily_view_bit_equal" >:: test_daily_view_bit_equal;
         "test_daily_bars_for_consumer_fields_equal"
         >:: test_daily_bars_for_consumer_fields_equal;
         "test_missing_returns_empty_in_both"
         >:: test_missing_returns_empty_in_both;
       ]

let () = run_test_tt_main suite
