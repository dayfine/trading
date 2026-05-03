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

(* upsert_entry: appending a symbol not in the manifest adds a new entry
   at the end; existing entries are preserved in order. *)
let test_upsert_entry_appends_new _ =
  let manifest = _sample_manifest () in
  let new_entry = _sample_entry ~symbol:"AMZN" in
  let updated = Snapshot_manifest.upsert_entry manifest new_entry in
  assert_that updated
    (field
       (fun (m : Snapshot_manifest.t) ->
         List.map m.entries ~f:(fun e -> e.Snapshot_manifest.symbol))
       (equal_to [ "AAPL"; "MSFT"; "GOOG"; "AMZN" ]))

(* upsert_entry: replacing an existing symbol keeps the entry list length
   constant and preserves the original order. *)
let test_upsert_entry_replaces_existing _ =
  let manifest = _sample_manifest () in
  let replacement =
    {
      Snapshot_manifest.symbol = "MSFT";
      path = "/snapshots/MSFT_v2.snap";
      byte_size = 2048;
      payload_md5 = "feedface";
      csv_mtime = 1800000000.0;
    }
  in
  let updated = Snapshot_manifest.upsert_entry manifest replacement in
  assert_that updated
    (all_of
       [
         field
           (fun (m : Snapshot_manifest.t) ->
             List.map m.entries ~f:(fun e -> e.Snapshot_manifest.symbol))
           (equal_to [ "AAPL"; "MSFT"; "GOOG" ]);
         field
           (fun (m : Snapshot_manifest.t) ->
             Snapshot_manifest.find m ~symbol:"MSFT")
           (is_some_and
              (all_of
                 [
                   field
                     (fun (e : Snapshot_manifest.file_metadata) -> e.byte_size)
                     (equal_to 2048);
                   field
                     (fun (e : Snapshot_manifest.file_metadata) ->
                       e.payload_md5)
                     (equal_to "feedface");
                 ]));
       ])

(* update_for_symbol: when no manifest exists at the path, a new one is
   created with [schema] and the single entry. *)
let test_update_for_symbol_creates_new _ =
  let path = _tmp_path () in
  (* Remove the temp file created by Filename_unix.temp_file so we exercise
     the "no manifest exists" branch. *)
  Stdlib.Sys.remove path;
  let entry = _sample_entry ~symbol:"AAPL" in
  let result =
    Result.bind
      (Snapshot_manifest.update_for_symbol ~path ~schema:Snapshot_schema.default
         entry) ~f:(fun () -> Snapshot_manifest.read ~path)
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (m : Snapshot_manifest.t) -> m.schema_hash)
              (equal_to Snapshot_schema.default.schema_hash);
            field
              (fun (m : Snapshot_manifest.t) ->
                List.map m.entries ~f:(fun e -> e.Snapshot_manifest.symbol))
              (equal_to [ "AAPL" ]);
          ]))

(* update_for_symbol: a sequence of upserts builds the manifest incrementally,
   matching the resume-from-interrupt contract. *)
let test_update_for_symbol_appends_incrementally _ =
  let path = _tmp_path () in
  Stdlib.Sys.remove path;
  let upsert sym =
    Snapshot_manifest.update_for_symbol ~path ~schema:Snapshot_schema.default
      (_sample_entry ~symbol:sym)
  in
  let result =
    Result.bind (upsert "AAPL") ~f:(fun () ->
        Result.bind (upsert "MSFT") ~f:(fun () ->
            Result.bind (upsert "GOOG") ~f:(fun () ->
                Snapshot_manifest.read ~path)))
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (m : Snapshot_manifest.t) ->
            List.map m.entries ~f:(fun e -> e.Snapshot_manifest.symbol))
          (equal_to [ "AAPL"; "MSFT"; "GOOG" ])))

(* update_for_symbol: schema mismatch returns Internal error. *)
let test_update_for_symbol_rejects_schema_mismatch _ =
  let path = _tmp_path () in
  Stdlib.Sys.remove path;
  let other_schema =
    Snapshot_schema.create ~fields:[ Snapshot_schema.EMA_50 ]
  in
  let result =
    Result.bind
      (Snapshot_manifest.update_for_symbol ~path ~schema:Snapshot_schema.default
         (_sample_entry ~symbol:"AAPL"))
      ~f:(fun () ->
        Snapshot_manifest.update_for_symbol ~path ~schema:other_schema
          (_sample_entry ~symbol:"MSFT"))
  in
  assert_that result (is_error_with Status.Internal)

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
         "upsert_entry appends new" >:: test_upsert_entry_appends_new;
         "upsert_entry replaces existing"
         >:: test_upsert_entry_replaces_existing;
         "update_for_symbol creates new manifest"
         >:: test_update_for_symbol_creates_new;
         "update_for_symbol appends incrementally"
         >:: test_update_for_symbol_appends_incrementally;
         "update_for_symbol rejects schema mismatch"
         >:: test_update_for_symbol_rejects_schema_mismatch;
       ]

let () = run_test_tt_main suite
