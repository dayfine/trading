open OUnit2
open Core
open Matchers
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_io = Data_panel_snapshot.Snapshot_io

let _tmp_path () =
  Filename_unix.temp_file ~in_dir:"/tmp" "snapshot_io_test_" ".snap"

let _make_row ~date_seed =
  let n = Snapshot_schema.n_fields Snapshot_schema.default in
  let date = Date.add_days (Date.of_string "2024-01-01") date_seed in
  let values = Array.init n ~f:(fun i -> Float.of_int ((date_seed * 10) + i)) in
  match
    Snapshot.create ~schema:Snapshot_schema.default ~symbol:"AAPL" ~date ~values
  with
  | Ok s -> s
  | Error err -> failwith (Status.show err)

let _rows () = List.init 5 ~f:(fun i -> _make_row ~date_seed:i)

let _write_exn ~write ~path rows =
  match write ~path rows with
  | Ok () -> ()
  | Error err -> assert_failure (Status.show err)

(* The bit pattern of every cell, row by row — the round-trip invariant. *)
let _bits rows =
  List.map rows ~f:(fun (s : Snapshot.t) ->
      Array.to_list s.values |> List.map ~f:Int64.bits_of_float)

(* A v2 file is detected as columnar and round-trips through the detecting
   reader. *)
let test_v2_is_detected_and_round_trips _ =
  let path = _tmp_path () in
  let rows = _rows () in
  _write_exn ~write:Snapshot_columnar.write ~path rows;
  assert_that (Snapshot_io.is_columnar_file path) (equal_to true);
  assert_that
    (Snapshot_io.read_with_expected_schema ~path
       ~expected:Snapshot_schema.default)
    (is_ok_and_holds (field _bits (equal_to (_bits rows))))

(* A v1 sexp file is NOT detected as columnar and round-trips through the v1
   branch of the detecting reader. *)
let test_v1_is_not_detected_and_round_trips _ =
  let path = _tmp_path () in
  let rows = _rows () in
  _write_exn ~write:Snapshot_format.write ~path rows;
  assert_that (Snapshot_io.is_columnar_file path) (equal_to false);
  assert_that
    (Snapshot_io.read_with_expected_schema ~path
       ~expected:Snapshot_schema.default)
    (is_ok_and_holds (field _bits (equal_to (_bits rows))))

(* The schema-hash gate fires on the v2 branch. *)
let test_v2_schema_skew_is_error _ =
  let path = _tmp_path () in
  _write_exn ~write:Snapshot_columnar.write ~path (_rows ());
  assert_that
    (Snapshot_io.read_with_expected_schema ~path
       ~expected:(Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]))
    (is_error_with Status.Failed_precondition)

(* A path that cannot be opened is reported as not-columnar, routing it to the
   v1 reader (which then surfaces the real error). *)
let test_missing_file_is_not_columnar _ =
  assert_that
    (Snapshot_io.is_columnar_file "/tmp/snapshot_io_no_such_file.snap")
    (equal_to false)

let suite =
  "Snapshot_io tests"
  >::: [
         "v2 is detected and round-trips"
         >:: test_v2_is_detected_and_round_trips;
         "v1 is not detected and round-trips"
         >:: test_v1_is_not_detected_and_round_trips;
         "v2 schema skew is error" >:: test_v2_schema_skew_is_error;
         "missing file is not columnar" >:: test_missing_file_is_not_columnar;
       ]

let () = run_test_tt_main suite
