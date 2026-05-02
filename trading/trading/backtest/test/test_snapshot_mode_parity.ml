(** Phase D parity gate — snapshot-mode vs CSV-mode [Market_data_adapter] return
    identical OHLCV reads on the same input bars.

    Per [dev/plans/snapshot-engine-phase-d-2026-05-02.md] §Acceptance criteria
    #3: "small fixture (3 symbols × ~60 days) — trade lists + final PV
    byte-identical between modes". The cleanest, fastest way to pin parity is at
    the data-source seam: build the same OHLCV stream into BOTH a CSV directory
    and a snapshot directory, then assert the simulator's two consumers
    ([Market_data_adapter.get_price] / [get_previous_bar]) return bit-identical
    [Daily_price.t]s on every (symbol, date) pair. If this holds, the
    simulator's hot path observes the same input series in either mode by
    construction — every downstream consumer (engine update_market, MtM
    portfolio_value, split detection, benchmark return) is a pure function of
    these reads. *)

open OUnit2
open Core
open Matchers
module Bar_data_source = Backtest.Bar_data_source
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Pipeline = Snapshot_pipeline.Pipeline

(* -------------------------------------------------------------------- *)
(* Test fixture                                                          *)
(* -------------------------------------------------------------------- *)

let _ymd y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

(* Synthetic bars: deterministic per-(symbol, day_index) values so any drift
   shows up as a per-cell mismatch. The schema's volume cell stores [int]
   round-tripped via [float]; we keep volumes < 2^53 (trivially satisfied)
   so [Float.to_int (Float.of_int v) = v] holds exactly. *)
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

let _bars_for ~symbol ~start ~n =
  List.init n ~f:(fun i -> _make_bar ~symbol ~day_index:i ~start)

let _make_tmp_dir prefix = Filename_unix.temp_dir ~in_dir:"/tmp" prefix ""

(* CSV writer: emits the canonical 7-column [date,open,high,low,close,
   adjusted_close,volume] schema [Csv_storage] reads. Returns the per-symbol
   CSV root the [Market_data_adapter] CSV path expects (data_dir/<F>/<L>/<SYM>/
   data.csv). *)
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
          (* %.17g is round-trip-exact for IEEE 754 doubles — necessary so the
             CSV path's [float_of_string] reads back the bit-identical float
             we wrote, and the snapshot path (which carries the float
             verbatim) compares equal. Real-world CSVs use ~4-decimal
             precision and round-trip cleanly via %g; the bit-identity
             requirement is specific to this fixture's parity assertion. *)
          List.iter bars ~f:(fun (b : Types.Daily_price.t) ->
              Out_channel.output_string oc
                (sprintf "%s,%.17g,%.17g,%.17g,%.17g,%.17g,%d\n"
                   (Date.to_string b.date) b.open_price b.high_price b.low_price
                   b.close_price b.adjusted_close b.volume))))

(* Snapshot writer: builds one [.snap] file per symbol via the Phase B
   pipeline + Phase A file format, then a directory manifest. Returns the
   manifest so the parity test can hand it directly to [Bar_data_source]. *)
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

(* Build BOTH a CSV directory and a snapshot directory from the same
   in-memory bar stream. Returns [(data_dir, snapshot_dir, manifest)]. *)
let _setup_dual_fixtures ~symbols ~start ~n =
  let data_dir = _make_tmp_dir "snapshot_parity_csv_" in
  let snapshot_dir = _make_tmp_dir "snapshot_parity_snap_" in
  let bars_by_symbol =
    List.map symbols ~f:(fun s -> (s, _bars_for ~symbol:s ~start ~n))
  in
  _write_csv_dir ~data_dir bars_by_symbol;
  let manifest = _write_snapshot_dir ~snapshot_dir bars_by_symbol in
  (data_dir, snapshot_dir, manifest, bars_by_symbol)

let _build_csv_adapter ~data_dir =
  match
    Bar_data_source.build_adapter Bar_data_source.Csv
      ~data_dir:(Fpath.v data_dir) ~max_cache_mb:64
  with
  | Ok a -> a
  | Error err ->
      assert_failure ("Bar_data_source.build_adapter Csv: " ^ Status.show err)

let _build_snapshot_adapter ~data_dir ~snapshot_dir ~manifest =
  match
    Bar_data_source.build_adapter
      (Bar_data_source.Snapshot { snapshot_dir; manifest })
      ~data_dir:(Fpath.v data_dir) ~max_cache_mb:64
  with
  | Ok a -> a
  | Error err ->
      assert_failure
        ("Bar_data_source.build_adapter Snapshot: " ^ Status.show err)

(* -------------------------------------------------------------------- *)
(* Tests                                                                 *)
(* -------------------------------------------------------------------- *)

let _default_symbols = [ "AAPL"; "MSFT"; "JPM" ]
let _default_start = _ymd 2024 1 2
let _default_n = 60

(* Walk every (symbol, day) cell in the fixture and assert the two adapters
   return bit-identical [Daily_price.t]s. We compare via [@@deriving eq] on
   [Daily_price] (structural equality; no NaN by construction). *)
let test_get_price_bit_equal _ =
  let data_dir, snapshot_dir, manifest, bars_by_symbol =
    _setup_dual_fixtures ~symbols:_default_symbols ~start:_default_start
      ~n:_default_n
  in
  let csv = _build_csv_adapter ~data_dir in
  let snap = _build_snapshot_adapter ~data_dir ~snapshot_dir ~manifest in
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      List.iter bars ~f:(fun (bar : Types.Daily_price.t) ->
          let csv_bar =
            Trading_simulation_data.Market_data_adapter.get_price csv ~symbol
              ~date:bar.date
          in
          let snap_bar =
            Trading_simulation_data.Market_data_adapter.get_price snap ~symbol
              ~date:bar.date
          in
          assert_that snap_bar (equal_to csv_bar)))

(* Same parity check on [get_previous_bar]. The simulator uses this for split
   detection (T-1 bar) and benchmark return (the prior trading day); over a
   contiguous fixture the prior bar is always the day before. We sample every
   day starting at index 1 (index 0's prior is None for both adapters). *)
let test_get_previous_bar_bit_equal _ =
  let data_dir, snapshot_dir, manifest, bars_by_symbol =
    _setup_dual_fixtures ~symbols:_default_symbols ~start:_default_start
      ~n:_default_n
  in
  let csv = _build_csv_adapter ~data_dir in
  let snap = _build_snapshot_adapter ~data_dir ~snapshot_dir ~manifest in
  List.iter bars_by_symbol ~f:(fun (symbol, bars) ->
      List.iteri bars ~f:(fun i (bar : Types.Daily_price.t) ->
          if i > 0 then
            let csv_prev =
              Trading_simulation_data.Market_data_adapter.get_previous_bar csv
                ~symbol ~date:bar.date
            in
            let snap_prev =
              Trading_simulation_data.Market_data_adapter.get_previous_bar snap
                ~symbol ~date:bar.date
            in
            assert_that snap_prev (equal_to csv_prev)))

(* Edge cases — both adapters must return [None] under the same conditions:
   (1) date with no bar (probe before fixture start), and
   (2) unknown symbol. *)
let test_missing_returns_none_in_both _ =
  let data_dir, snapshot_dir, manifest, _bars =
    _setup_dual_fixtures ~symbols:_default_symbols ~start:_default_start
      ~n:_default_n
  in
  let csv = _build_csv_adapter ~data_dir in
  let snap = _build_snapshot_adapter ~data_dir ~snapshot_dir ~manifest in
  let probes =
    [
      ("AAPL", Date.add_days _default_start (-10));
      ("UNKNOWN", Date.add_days _default_start 5);
    ]
  in
  List.iter probes ~f:(fun (symbol, date) ->
      assert_that
        (Trading_simulation_data.Market_data_adapter.get_price csv ~symbol
           ~date)
        is_none;
      assert_that
        (Trading_simulation_data.Market_data_adapter.get_price snap ~symbol
           ~date)
        is_none)

let suite =
  "Snapshot_mode_parity"
  >::: [
         "test_get_price_bit_equal" >:: test_get_price_bit_equal;
         "test_get_previous_bar_bit_equal" >:: test_get_previous_bar_bit_equal;
         "test_missing_returns_none_in_both"
         >:: test_missing_returns_none_in_both;
       ]

let () = run_test_tt_main suite
