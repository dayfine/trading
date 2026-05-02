open OUnit2
open Core
open Matchers
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _schema =
  Snapshot_schema.create
    ~fields:[ Snapshot_schema.EMA_50; Snapshot_schema.SMA_50 ]

let _make_row ~symbol ~date ~ema ~sma =
  match
    Snapshot.create ~schema:_schema ~symbol ~date ~values:[| ema; sma |]
  with
  | Ok r -> r
  | Error err -> assert_failure ("Snapshot.create: " ^ Status.show err)

let _start = Date.create_exn ~y:2024 ~m:Month.Jan ~d:2

let _series ~symbol ~n =
  List.init n ~f:(fun i ->
      _make_row ~symbol ~date:(Date.add_days _start i)
        ~ema:(100.0 +. Float.of_int i)
        ~sma:(200.0 +. Float.of_int i))

let _setup ~symbols ~n_days =
  let dir = Filename_unix.temp_dir ~in_dir:"/tmp" "snapshot_cb_" "" in
  let entries =
    List.map symbols ~f:(fun symbol ->
        let rows = _series ~symbol ~n:n_days in
        let path = Filename.concat dir (symbol ^ ".snap") in
        let _ =
          match Snapshot_format.write ~path rows with
          | Ok () -> ()
          | Error err ->
              assert_failure ("Snapshot_format.write: " ^ Status.show err)
        in
        ({
           symbol;
           path;
           byte_size = 0;
           payload_md5 = "ignored";
           csv_mtime = 0.0;
         }
          : Snapshot_manifest.file_metadata))
  in
  let manifest = Snapshot_manifest.create ~schema:_schema ~entries in
  let panels =
    match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:1 with
    | Ok t -> t
    | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)
  in
  Snapshot_callbacks.of_daily_panels panels

(* --- read_field ----------------------------------------------------- *)

let test_read_field_returns_correct_scalar _ =
  let cb = _setup ~symbols:[ "AAPL" ] ~n_days:5 in
  let date = Date.add_days _start 3 in
  assert_that
    (cb.read_field ~symbol:"AAPL" ~date ~field:Snapshot_schema.EMA_50)
    (is_ok_and_holds (float_equal 103.0))

let test_read_field_unknown_symbol _ =
  let cb = _setup ~symbols:[ "AAPL" ] ~n_days:5 in
  assert_that
    (cb.read_field ~symbol:"ZZZ" ~date:_start ~field:Snapshot_schema.EMA_50)
    (is_error_with Status.NotFound)

(* The shim returns Failed_precondition when callers ask for a field the
   underlying schema doesn't carry. The schema set in _setup carries EMA_50
   and SMA_50 but not RSI_14, so RSI_14 reads should fail at the per-field
   layer (not at the file layer — the file is fine). *)
let test_read_field_missing_field_returns_failed_precondition _ =
  let cb = _setup ~symbols:[ "AAPL" ] ~n_days:5 in
  assert_that
    (cb.read_field ~symbol:"AAPL" ~date:_start ~field:Snapshot_schema.RSI_14)
    (is_error_with Status.Failed_precondition)

(* --- read_field_history --------------------------------------------- *)

let test_read_field_history_chronological _ =
  let cb = _setup ~symbols:[ "AAPL" ] ~n_days:5 in
  let from = Date.add_days _start 1 in
  let until = Date.add_days _start 3 in
  assert_that
    (cb.read_field_history ~symbol:"AAPL" ~from ~until
       ~field:Snapshot_schema.SMA_50)
    (is_ok_and_holds
       (elements_are
          [
            equal_to ((Date.add_days _start 1, 201.0) : Date.t * float);
            equal_to ((Date.add_days _start 2, 202.0) : Date.t * float);
            equal_to ((Date.add_days _start 3, 203.0) : Date.t * float);
          ]))

let test_read_field_history_empty_range _ =
  let cb = _setup ~symbols:[ "AAPL" ] ~n_days:5 in
  let from = Date.add_days _start 100 in
  let until = Date.add_days _start 110 in
  assert_that
    (cb.read_field_history ~symbol:"AAPL" ~from ~until
       ~field:Snapshot_schema.EMA_50)
    (is_ok_and_holds (size_is 0))

let suite =
  "Snapshot_callbacks tests"
  >::: [
         "read_field returns correct scalar"
         >:: test_read_field_returns_correct_scalar;
         "read_field unknown symbol" >:: test_read_field_unknown_symbol;
         "read_field missing field returns failed_precondition"
         >:: test_read_field_missing_field_returns_failed_precondition;
         "read_field_history chronological"
         >:: test_read_field_history_chronological;
         "read_field_history empty range"
         >:: test_read_field_history_empty_range;
       ]

let () = run_test_tt_main suite
