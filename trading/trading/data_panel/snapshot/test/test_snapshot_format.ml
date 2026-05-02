open OUnit2
open Core
open Matchers
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format

let _tmp_path () =
  Filename_unix.temp_file ~in_dir:"/tmp" "snapshot_format_test_" ".snap"

let _values_for n = Array.init n ~f:(fun i -> Float.of_int i +. 0.25)

let _make_row ~symbol ~date =
  let n = Snapshot_schema.n_fields Snapshot_schema.default in
  match
    Snapshot.create ~schema:Snapshot_schema.default ~symbol ~date
      ~values:(_values_for n)
  with
  | Ok s -> s
  | Error err -> failwith (Status.show err)

let _sample_rows () =
  [
    _make_row ~symbol:"AAPL" ~date:(Date.of_string "2024-01-02");
    _make_row ~symbol:"MSFT" ~date:(Date.of_string "2024-01-02");
    _make_row ~symbol:"GOOG" ~date:(Date.of_string "2024-01-03");
  ]

let _write_then_read path rows =
  Result.bind (Snapshot_format.write ~path rows) ~f:(fun () ->
      Snapshot_format.read ~path)

let test_round_trip_three_rows _ =
  let path = _tmp_path () in
  let rows = _sample_rows () in
  assert_that
    (_write_then_read path rows)
    (is_ok_and_holds
       (elements_are
          [
            all_of
              [
                field (fun s -> s.Snapshot.symbol) (equal_to "AAPL");
                field
                  (fun s -> Array.to_list s.Snapshot.values)
                  (equal_to (Array.to_list (_values_for 7)));
              ];
            field (fun s -> s.Snapshot.symbol) (equal_to "MSFT");
            field (fun s -> s.Snapshot.symbol) (equal_to "GOOG");
          ]))

let test_round_trip_preserves_schema_hash _ =
  let path = _tmp_path () in
  let rows = _sample_rows () in
  let expected_hash = Snapshot_schema.default.schema_hash in
  assert_that
    (_write_then_read path rows)
    (is_ok_and_holds
       (each
          (field
             (fun s -> s.Snapshot.schema.schema_hash)
             (equal_to expected_hash))))

let test_empty_list_round_trip _ =
  let path = _tmp_path () in
  assert_that (_write_then_read path []) (is_ok_and_holds is_empty)

let test_write_rejects_mixed_schemas _ =
  let path = _tmp_path () in
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  let other_row =
    match
      Snapshot.create ~schema:other_schema ~symbol:"X"
        ~date:(Date.of_string "2024-01-02")
        ~values:[| 1.0 |]
    with
    | Ok s -> s
    | Error err -> failwith (Status.show err)
  in
  let rows =
    [ _make_row ~symbol:"AAPL" ~date:(Date.of_string "2024-01-02"); other_row ]
  in
  assert_that
    (Snapshot_format.write ~path rows)
    (is_error_with Status.Invalid_argument)

(* Integrity check: corrupt one byte of the payload (the file's last byte) and
   read must fail with an md5 mismatch. *)
let _flip_last_byte path =
  let bytes = In_channel.read_all path |> Bytes.of_string in
  let n = Bytes.length bytes in
  let last = Char.to_int (Bytes.get bytes (n - 1)) in
  Bytes.set bytes (n - 1) (Char.of_int_exn (last lxor 0xFF));
  Out_channel.write_all path ~data:(Bytes.to_string bytes)

let _write_corrupt_then_read path rows =
  Result.bind (Snapshot_format.write ~path rows) ~f:(fun () ->
      _flip_last_byte path;
      Snapshot_format.read ~path)

let test_corrupted_payload_detected _ =
  let path = _tmp_path () in
  assert_that
    (_write_corrupt_then_read path (_sample_rows ()))
    (is_error_with Status.Internal)

let _write_then_read_with_schema path rows ~expected =
  Result.bind (Snapshot_format.write ~path rows) ~f:(fun () ->
      Snapshot_format.read_with_expected_schema ~path ~expected)

let test_schema_hash_skew_detected _ =
  let path = _tmp_path () in
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  assert_that
    (_write_then_read_with_schema path (_sample_rows ()) ~expected:other_schema)
    (is_error_with Status.Failed_precondition)

let test_schema_hash_match_succeeds _ =
  let path = _tmp_path () in
  assert_that
    (_write_then_read_with_schema path (_sample_rows ())
       ~expected:Snapshot_schema.default)
    (is_ok_and_holds (size_is 3))

(* Two writes of the same input must produce byte-identical files. The hashing
   primitive depends on this for cross-machine reproducibility. *)
let _write_pair_and_read_bytes ~path_a ~path_b rows =
  Result.bind (Snapshot_format.write ~path:path_a rows) ~f:(fun () ->
      Result.map (Snapshot_format.write ~path:path_b rows) ~f:(fun () ->
          (In_channel.read_all path_a, In_channel.read_all path_b)))

let test_write_byte_identical _ =
  let path_a = _tmp_path () in
  let path_b = _tmp_path () in
  assert_that
    (_write_pair_and_read_bytes ~path_a ~path_b (_sample_rows ()))
    (is_ok_and_holds
       (matching ~msg:"two writes byte-equal"
          (fun (a, b) -> if String.equal a b then Some () else None)
          (equal_to ())))

let suite =
  "Snapshot_format tests"
  >::: [
         "round trip three rows" >:: test_round_trip_three_rows;
         "round trip preserves schema hash"
         >:: test_round_trip_preserves_schema_hash;
         "empty list round trip" >:: test_empty_list_round_trip;
         "write rejects mixed schemas" >:: test_write_rejects_mixed_schemas;
         "corrupted payload detected" >:: test_corrupted_payload_detected;
         "schema hash skew detected" >:: test_schema_hash_skew_detected;
         "schema hash match succeeds" >:: test_schema_hash_match_succeeds;
         "write byte identical" >:: test_write_byte_identical;
       ]

let () = run_test_tt_main suite
