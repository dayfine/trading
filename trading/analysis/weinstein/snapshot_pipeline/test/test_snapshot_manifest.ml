open OUnit2
open Core
open Matchers
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let _tmp_path () =
  Filename_unix.temp_file ~in_dir:"/tmp" "snapshot_manifest_test_" ".sexp"

let _sample_entry ~symbol =
  {
    Snapshot_manifest.symbol;
    path = "/snapshots/" ^ symbol ^ ".snap";
    byte_size = 1024;
    payload_md5 = "deadbeef";
    csv_mtime = 1700000000.0;
  }

let _sample_manifest () =
  Snapshot_manifest.create ~schema:Snapshot_schema.default
    ~entries:
      [
        _sample_entry ~symbol:"AAPL";
        _sample_entry ~symbol:"MSFT";
        _sample_entry ~symbol:"GOOG";
      ]

let test_create_sets_schema_hash _ =
  let manifest = _sample_manifest () in
  assert_that manifest.schema_hash
    (equal_to Snapshot_schema.default.schema_hash)

let test_round_trip _ =
  let path = _tmp_path () in
  let manifest = _sample_manifest () in
  let result =
    Result.bind (Snapshot_manifest.write ~path manifest) ~f:(fun () ->
        Snapshot_manifest.read ~path)
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (m : Snapshot_manifest.t) -> m.schema_hash)
              (equal_to Snapshot_schema.default.schema_hash);
            field
              (fun (m : Snapshot_manifest.t) -> List.length m.entries)
              (equal_to 3);
          ]))

let test_round_trip_preserves_entries _ =
  let path = _tmp_path () in
  let manifest = _sample_manifest () in
  let result =
    Result.bind (Snapshot_manifest.write ~path manifest) ~f:(fun () ->
        Snapshot_manifest.read ~path)
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (m : Snapshot_manifest.t) ->
            List.map m.entries ~f:(fun e -> e.Snapshot_manifest.symbol))
          (equal_to [ "AAPL"; "MSFT"; "GOOG" ])))

let test_read_missing_file_returns_not_found _ =
  let path = "/tmp/snapshot_manifest_does_not_exist_xyz.sexp" in
  assert_that (Snapshot_manifest.read ~path) (is_error_with Status.NotFound)

let test_find_returns_entry _ =
  let manifest = _sample_manifest () in
  assert_that
    (Snapshot_manifest.find manifest ~symbol:"MSFT")
    (is_some_and
       (field (fun e -> e.Snapshot_manifest.symbol) (equal_to "MSFT")))

let test_find_returns_none_for_unknown _ =
  let manifest = _sample_manifest () in
  assert_that (Snapshot_manifest.find manifest ~symbol:"XYZ") is_none

(* Schema-hash mismatch detection: a manifest written under one schema and read
   into a record under a different one is detectable via the [schema_hash]
   field — the consumer (verifier, runtime) compares hashes explicitly. *)
let test_schema_hash_mismatch_detectable _ =
  let path = _tmp_path () in
  let manifest = _sample_manifest () in
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  let mismatch_detected =
    Result.bind (Snapshot_manifest.write ~path manifest) ~f:(fun () ->
        Result.map (Snapshot_manifest.read ~path) ~f:(fun loaded ->
            not (String.equal loaded.schema_hash other_schema.schema_hash)))
  in
  assert_that mismatch_detected (is_ok_and_holds (equal_to true))

let suite =
  "Snapshot_manifest tests"
  >::: [
         "create sets schema_hash" >:: test_create_sets_schema_hash;
         "round trip" >:: test_round_trip;
         "round trip preserves entries" >:: test_round_trip_preserves_entries;
         "read missing file returns not_found"
         >:: test_read_missing_file_returns_not_found;
         "find returns entry" >:: test_find_returns_entry;
         "find returns none for unknown" >:: test_find_returns_none_for_unknown;
         "schema hash mismatch detectable"
         >:: test_schema_hash_mismatch_detectable;
       ]

let () = run_test_tt_main suite
