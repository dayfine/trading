(** End-to-end pin for the build-time series-tail pass (#2672): build a tiny
    warehouse from CSV fixtures and check what actually landed in the [.snap]
    files and the manifest. *)

open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _end_date = Date.of_string "2021-12-31"
let _stub_last_real = Date.of_string "2021-10-04"
let _early_last = Date.of_string "2021-01-08"

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_build_runner_tail" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let _bar date close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:10_000 ~adjusted_close:close ()

let _series ~start closes =
  List.mapi closes ~f:(fun i close -> _bar (Date.add_days start i) close)

let _write_csv ~data_dir ~symbol bars =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error e -> assert_failure ("csv create: " ^ Status.show e)
  | Ok storage -> (
      match Csv.Csv_storage.save storage ~override:true bars with
      | Error e -> assert_failure ("csv save: " ^ Status.show e)
      | Ok () -> ())

(* STUB is the STMP shape (real prints, then an administrative penny tail);
   EARLY simply stops trading mid-window; ALIVE prints through the build's end
   date. *)
let _write_fixtures ~data_dir =
  _write_csv ~data_dir ~symbol:"STUB"
    (_series
       ~start:(Date.of_string "2021-10-03")
       [ 320.0; 329.61; 0.045; 0.04; 0.03 ]);
  _write_csv ~data_dir ~symbol:"EARLY"
    (_series
       ~start:(Date.of_string "2021-01-04")
       [ 50.0; 51.0; 52.0; 53.0; 54.0 ]);
  _write_csv ~data_dir ~symbol:"ALIVE"
    (_series
       ~start:(Date.of_string "2021-12-27")
       [ 10.0; 11.0; 12.0; 13.0; 14.0 ])

let _build ~data_dir ~output_dir =
  Build_runner.build
    ~symbols:[ "STUB"; "EARLY"; "ALIVE" ]
    ~csv_data_dir:data_dir ~output_dir ~benchmark_symbol:None ~start_date:None
    ~end_date:(Some _end_date)
    ~sketch_deep_days:Build_runner.default_sketch_deep_days ~incremental:false
    ~progress_every:Build_runner.default_progress_every
    ~tail_config:Series_tail.Config.default ~tail_exceptions_path:None ()

let _manifest_of ~output_dir =
  match
    Snapshot_manifest.read ~path:(Filename.concat output_dir "manifest.sexp")
  with
  | Error e -> assert_failure ("manifest read: " ^ Status.show e)
  | Ok m -> m

let _panels ~output_dir manifest =
  match
    Snapshot_runtime.Daily_panels.create ~snapshot_dir:output_dir ~manifest
      ~max_cache_mb:8
  with
  | Error e -> assert_failure ("panels create: " ^ Status.show e)
  | Ok p -> p

let _run_build f =
  _with_temp_dir (fun dir ->
      let data_dir = Filename.concat dir "csv" in
      let output_dir = Filename.concat dir "snap" in
      Core_unix.mkdir_p data_dir;
      _write_fixtures ~data_dir;
      _build ~data_dir ~output_dir;
      f ~output_dir)

let _active_through ~output_dir ~symbol =
  Snapshot_runtime.Daily_panels.active_through_for
    (_panels ~output_dir (_manifest_of ~output_dir))
    ~symbol

let _history ~output_dir ~symbol =
  Snapshot_runtime.Daily_panels.read_history
    (_panels ~output_dir (_manifest_of ~output_dir))
    ~symbol
    ~from:(Date.of_string "2021-01-01")
    ~until:_end_date

let _markers ~output_dir =
  List.map [ "STUB"; "EARLY"; "ALIVE" ] ~f:(fun symbol ->
      _active_through ~output_dir ~symbol)

let _is_date d = is_some_and (equal_to ~cmp:Date.equal d)

let _row_date_is d =
  field
    (fun (r : Data_panel_snapshot.Snapshot.t) -> r.date)
    (equal_to ~cmp:Date.equal d)

(* The manifest's delisting marker is the series end for a symbol that stopped
   printing, and stays [None] for one still trading at the build's end date.
   Read back through the runtime seam the screener's PI filter uses. *)
let _check_markers ~output_dir =
  assert_that (_markers ~output_dir)
    (elements_are [ _is_date _stub_last_real; _is_date _early_last; is_none ])

(* The stub bars are gone from the stored series, not merely marked: the last
   row in the [.snap] is the last real print. *)
let _stub_rows_are =
  is_ok_and_holds
    (elements_are
       [
         _row_date_is (Date.of_string "2021-10-03");
         _row_date_is _stub_last_real;
       ])

let _check_stub_history ~output_dir =
  assert_that (_history ~output_dir ~symbol:"STUB") _stub_rows_are

(* A symbol that simply ends early is NOT truncated — only its marker moves. *)
let _check_early_history ~output_dir =
  assert_that
    (_history ~output_dir ~symbol:"EARLY")
    (is_ok_and_holds (size_is 5))

let _check_report ~output_dir =
  let path = Filename.concat output_dir Build_runner.tail_report_name in
  assert_that (In_channel.read_all path)
    (all_of
       [
         contains_substring Series_tail.csv_header;
         contains_substring "STUB,stub_tail,2021-10-04,329.6100,3,";
         contains_substring ",truncated\n";
       ])

let test_active_through_from_series_end _ = _run_build _check_markers
let test_snap_ends_at_last_real_bar _ = _run_build _check_stub_history
let test_early_series_kept_whole _ = _run_build _check_early_history
let test_terminal_runs_report_written _ = _run_build _check_report

let suite =
  "build_runner_tail"
  >::: [
         "active_through_from_series_end"
         >:: test_active_through_from_series_end;
         "snap_ends_at_last_real_bar" >:: test_snap_ends_at_last_real_bar;
         "early_series_kept_whole" >:: test_early_series_kept_whole;
         "terminal_runs_report_written" >:: test_terminal_runs_report_written;
       ]

let () = run_test_tt_main suite
