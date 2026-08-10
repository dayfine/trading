open Core
open OUnit2
open Matchers
module Bar_source = Weekly_bars_dump_lib.Bar_source
module Pipeline = Snapshot_pipeline.Pipeline
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

let _symbol = "TSYM"

let _weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

let _weekdays ~from ~until =
  let rec loop d acc =
    if Date.( > ) d until then List.rev acc
    else loop (Date.add_days d 1) (if _weekday d then d :: acc else acc)
  in
  loop from []

(* No splits: [adjusted_close = close_price] throughout, so the sketch-v5
   builder's adjusted-basis rescale is a no-op (factor 1.0) and its output
   is directly comparable to our raw-basis weekly aggregation. *)
let _bar ~date ~index : Types.Daily_price.t =
  let base = 50.0 +. Float.of_int index in
  Types.Daily_price.make ~date ~open_price:base ~high_price:(base +. 2.0)
    ~low_price:(base -. 2.0) ~close_price:(base +. 0.5) ~volume:(1000 + index)
    ~adjusted_close:(base +. 0.5) ()

let _daily_bars () =
  _weekdays
    ~from:(Date.of_string "2024-01-01")
    ~until:(Date.of_string "2024-02-16")
  |> List.mapi ~f:(fun index date -> _bar ~date ~index)

let _tmp_dir prefix = Filename_unix.temp_dir ~in_dir:"/tmp" prefix ""

let _ok_or_fail ~what = function
  | Ok v -> v
  | Error e -> assert_failure (what ^ ": " ^ Status.show e)

let _write_csv ~csv_dir bars =
  let storage =
    _ok_or_fail ~what:"csv create"
      (Csv.Csv_storage.create ~data_dir:(Fpath.v csv_dir) _symbol)
  in
  _ok_or_fail ~what:"csv save" (Csv.Csv_storage.save storage bars)

let test_load_daily_from_csv_when_no_warehouse _ =
  let csv_dir = _tmp_dir "weekly_bars_dump_csv_" in
  let bars = _daily_bars () in
  _write_csv ~csv_dir bars;
  let result =
    Bar_source.load_daily ~symbol:_symbol ~warehouse_dir:None
      ~csv_data_dir:(Some csv_dir)
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field fst (elements_are (List.map bars ~f:equal_to));
            field snd (equal_to Bar_source.Csv);
          ]))

let test_load_daily_prefers_warehouse_over_csv _ =
  let csv_dir = _tmp_dir "weekly_bars_dump_csv2_" in
  let warehouse_dir = _tmp_dir "weekly_bars_dump_snap_" in
  let bars = _daily_bars () in
  (* CSV holds only half the history; the warehouse holds all of it, so a
     loader that mistakenly fell back to CSV would betray itself via the
     row count -- and, now, via the values themselves. *)
  _write_csv ~csv_dir (List.take bars (List.length bars / 2));
  let snap_rows =
    _ok_or_fail ~what:"build_for_symbol"
      (Pipeline.build_for_symbol ~symbol:_symbol ~bars
         ~schema:Snapshot_schema.default ())
  in
  _ok_or_fail ~what:"snap write"
    (Snapshot_columnar.write
       ~path:(Filename.concat warehouse_dir (_symbol ^ ".snap"))
       snap_rows);
  let result =
    Bar_source.load_daily ~symbol:_symbol ~warehouse_dir:(Some warehouse_dir)
      ~csv_data_dir:(Some csv_dir)
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field fst (elements_are (List.map bars ~f:equal_to));
            field snd (equal_to Bar_source.Warehouse);
          ]))

let test_load_daily_falls_back_to_csv_when_snap_absent _ =
  (* [warehouse_dir] is configured but holds no [.snap] for this symbol --
     the documented "the .snap file is absent" fallback trigger
     ([bar_source.mli]'s [load_daily]), previously untested. *)
  let csv_dir = _tmp_dir "weekly_bars_dump_csv4_" in
  let warehouse_dir = _tmp_dir "weekly_bars_dump_snap_absent_" in
  let bars = _daily_bars () in
  _write_csv ~csv_dir bars;
  let result =
    Bar_source.load_daily ~symbol:_symbol ~warehouse_dir:(Some warehouse_dir)
      ~csv_data_dir:(Some csv_dir)
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field fst (elements_are (List.map bars ~f:equal_to));
            field snd (equal_to Bar_source.Csv);
          ]))

let test_load_daily_falls_back_to_csv_when_snap_unreadable _ =
  (* The [.snap] file exists but is not a valid v2 columnar file -- the
     documented "or reading it errors" fallback trigger, previously
     untested. [Snapshot_columnar.with_reader] returns [Error] on a bad
     magic rather than raising, which is what makes the fallback possible. *)
  let csv_dir = _tmp_dir "weekly_bars_dump_csv5_" in
  let warehouse_dir = _tmp_dir "weekly_bars_dump_snap_corrupt_" in
  let bars = _daily_bars () in
  _write_csv ~csv_dir bars;
  Out_channel.write_all
    (Filename.concat warehouse_dir (_symbol ^ ".snap"))
    ~data:"not a v2 snapshot file";
  let result =
    Bar_source.load_daily ~symbol:_symbol ~warehouse_dir:(Some warehouse_dir)
      ~csv_data_dir:(Some csv_dir)
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field fst (elements_are (List.map bars ~f:equal_to));
            field snd (equal_to Bar_source.Csv);
          ]))

let test_load_daily_not_found _ =
  let dir = _tmp_dir "weekly_bars_dump_empty_" in
  assert_that
    (Bar_source.load_daily ~symbol:"NOPE" ~warehouse_dir:None
       ~csv_data_dir:(Some dir))
    is_error

(* The load-bearing cross-check: our weekly aggregation
   ([Bar_source.load_weekly], which folds daily bars through
   [Time_period.Conversion.daily_to_weekly]) must derive the same
   [(mid, high)] per week as the real sketch-v5 side-table builder
   ([Weekly_sidetable_builder.of_bars]) -- an independent production code
   path over the same daily bars. Agreement here is the evidence that
   [weekly_bars_dump]'s OHLCV table is on the same weekly-bar skeleton the
   rest of the codebase (resistance sketches, the strategy's Bar_reader)
   already relies on. *)
let test_weekly_aggregation_matches_sidetable_builder _ =
  let bars = _daily_bars () in
  let csv_dir = _tmp_dir "weekly_bars_dump_csv3_" in
  _write_csv ~csv_dir bars;
  let weekly, _source =
    _ok_or_fail ~what:"load_weekly"
      (Bar_source.load_weekly ~symbol:_symbol ~warehouse_dir:None
         ~csv_data_dir:(Some csv_dir))
  in
  let expected_entries = Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars in
  let our_entries =
    List.map weekly
      ~f:(fun (b : Types.Daily_price.t) : Weekly_sidetable.entry ->
        {
          week_end_date = b.date;
          mid = (b.high_price +. b.low_price) /. 2.0;
          high = b.high_price;
        })
  in
  assert_that our_entries (elements_are (List.map expected_entries ~f:equal_to))

let suite =
  "Bar_source"
  >::: [
         "load_daily_from_csv_when_no_warehouse"
         >:: test_load_daily_from_csv_when_no_warehouse;
         "load_daily_prefers_warehouse_over_csv"
         >:: test_load_daily_prefers_warehouse_over_csv;
         "load_daily_falls_back_to_csv_when_snap_absent"
         >:: test_load_daily_falls_back_to_csv_when_snap_absent;
         "load_daily_falls_back_to_csv_when_snap_unreadable"
         >:: test_load_daily_falls_back_to_csv_when_snap_unreadable;
         "load_daily_not_found" >:: test_load_daily_not_found;
         "weekly_aggregation_matches_sidetable_builder"
         >:: test_weekly_aggregation_matches_sidetable_builder;
       ]

let () = run_test_tt_main suite
